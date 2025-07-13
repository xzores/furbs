package furbs_network

import "base:runtime"

import "core:net"
import "core:container/queue"
import "core:thread"
import "core:mem"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:sync"

import "../utils"

//////////////////////////////////////////////////////////////////////
// 				This is only meant for internal use					//
//////////////////////////////////////////////////////////////////////

Client_tcp_base :: struct {
	//Data
	current_bytes_recv  : queue.Queue(u8),	  	//This fills up and must be handled somehow
	recv_commands	   : ^queue.Queue(Command),	//This should be handle in the main thread
	recv_mutex 			: ^sync.Mutex,
	to_clean : [dynamic]Command,
	
	sock : net.TCP_Socket,
	user_data : rawptr, //this is used by the server to figure out which client recived the command.

	did_open : bool,
	should_close : bool,
	mutex : sync.Mutex, //lock everything
}

init_tcp_base :: proc (user_data : rawptr) -> Client_tcp_base {
	client : Client_tcp_base
	queue.init(&client.current_bytes_recv);
	client.to_clean = make([dynamic]Command);
	client.user_data = user_data;
	return client;
}

destroy_tcp_base :: proc (client : ^Client_tcp_base) {
	
	queue.destroy(&client.current_bytes_recv);
	delete(client.to_clean);
}

recv_tcp_parse_loop :: proc(client : ^Client_tcp_base, params : Network_commands, buffer_size := 4*4096, loc := #caller_location) {
	
	client.did_open = true;
	
	new_data_buffer := make([]u8, buffer_size); //The max number of bytes that can be recived at a time (can still recive messages larger then this)

	for !client.should_close {
		bytes_recv, err := net.recv(client.sock, new_data_buffer[:]);
		
		if (err == net.TCP_Recv_Error.Connection_Closed) && client.should_close {
			continue;
		}
		else if (err == net.TCP_Recv_Error.Connection_Closed) {
			log.warnf("Warning : a connection was close without should_close being set true. Automagicly closing now\n Caller : %v\n", loc);
			client.should_close = true;
			continue;
		}
		else if err != nil {
			log.errorf("failed recv, err : %v called from : %v\n", err, loc);
			continue;
		}

		sync.lock(&client.mutex);
		for d in new_data_buffer[:bytes_recv] {
			queue.append(&client.current_bytes_recv, d); //TODO this is very slow, copy all at once
		}
		sync.unlock(&client.mutex);
		
		for parse_message(client, params, loc) {}; //Parses all messages...
		
		free_all(context.temp_allocator);
	}
	
	sync.lock(&client.mutex);
	defer sync.unlock(&client.mutex);

	free_all(context.temp_allocator);
}

//returns true if error
//where intrinsics.type_is_variant_of(message.Constant_size_union, T)
send_tcp_message_constant_size :: proc(socket : net.TCP_Socket, using params : Network_commands, data : any, loc := #caller_location) -> (err : Error) {
	fmt.assertf(data.id in commands_inverse, "The data %v (%i) is not a command as it is not in the map : %#v", data.id, data.id, commands_inverse, loc);
	
	assert(data != nil, "data is nil, cannot send nil");

	command_size : int = reflect.size_of_typeid(data.id);
	bytes_to_send_cnt : int = command_size + size_of(Message_id_type);
	command_id : Message_id_type = commands_inverse[data.id];
	
	to_send : []u8 = make([]u8, bytes_to_send_cnt);
	defer delete(to_send);

	runtime.mem_copy(&to_send[0], &command_id, size_of(Message_id_type));
	if command_size > 0 {
		runtime.mem_copy(&to_send[size_of(Message_id_type)], data.data, command_size);
	}
	
	log.debugf("Sending : %v\n", to_send);
	bytes_send, serr := net.send_tcp(socket, to_send);

	if serr != nil {
		log.errorf("Failed to send, recived err %v\n", serr);
		return serr;
	}
	if bytes_send != bytes_to_send_cnt {
		log.errorf("Failed to send all bytes, tried to send %i, but only sent %i\n", command_size, bytes_send);
		return .Unknown;
	}

	return nil;
}

//returns true if error
send_tcp_message_variable_size :: proc (socket : net.TCP_Socket, using params : Network_commands, data : any, loc := #caller_location) -> (err : Error) {
	fmt.assertf(data.id in commands_inverse, "The data %v is not a command as it is not in the map : %#v", data.id, commands_inverse, loc);

	command_id : Message_id_type = commands_inverse[data.id];

	to_send := make([dynamic]u8, size_of(Message_id_type));
	runtime.mem_copy(&to_send[0], &command_id, size_of(Message_id_type));

	ser_err := utils.serialize_to_bytes(data, &to_send, loc);
	defer delete(to_send);

	if ser_err != nil {
		log.errorf("Failed to serialize, got err %v\n", ser_err);
		return ;
	}
	
	bytes_send, serr := net.send_tcp(socket, to_send[:]);

	if serr != nil {
		log.errorf("Failed to send, got err %v\n", serr);
		return serr;
	}
	if bytes_send != len(to_send) {
		log.errorf("Failed to send all bytes, tried to send %i, but only sent %i\n", len(to_send), bytes_send);
		return .Unknown;
	}
	
	return nil;
}

send_tcp_message_commands :: proc (socket : net.TCP_Socket, params : Network_commands, data : any, loc := #caller_location) -> (err : Error) {
	if(utils.is_trivial_copied(data.id)) {
		return send_tcp_message_constant_size(socket, params, data, loc);
	}
	else {
		return send_tcp_message_variable_size(socket, params, data, loc);
	}
}

//returns true if it did parse something
parse_message :: proc (client : ^Client_tcp_base, params : Network_commands, loc := #caller_location) -> bool {

	try_parse :: proc(using client : ^Client_tcp_base, params : Network_commands, message_id : Message_id_type, command : ^Command, loc := #caller_location) -> bool{

		message_typeid : typeid = params.commands[message_id];		
		
		if utils.is_trivial_copied(message_typeid) {
			command.is_constant_size = true;
			log.debugf("Parsing trivical message : %v\n", message_typeid);

			command_size : int = reflect.size_of_typeid(message_typeid);
			total_size : int = size_of(Message_id_type) + command_size;
			
			if queue.len(client.current_bytes_recv) < total_size {
				return false;
			}
			
			command_data, err := mem.alloc_bytes(command_size, allocator = command.alloc);
			if err != nil { panic("Unable to allocate!!?!?"); }
			
			for i : int = 0; i < cast(int)command_size; i += 1 {
				command_data[i] = queue.get(&current_bytes_recv, i + size_of(Message_id_type));
			}
			
			command.value = {data = raw_data(command_data), id = message_typeid};
			log.debugf("Recived : %v\n", command);

			queue.consume_front(&client.current_bytes_recv, total_size);
		}
		else {
			command.is_constant_size = false;
			//We need another header, this header is the Utils.Header_size_type

			req_size := size_of(Message_id_type) + size_of(utils.Header_size_type);
			if queue.len(client.current_bytes_recv) < req_size {
				return false;
			}
			
			header_data : []u8 = make([]u8, size_of(utils.Header_size_type));
			defer delete(header_data);
			for i : int = 0; i < size_of(utils.Header_size_type); i += 1 {
				header_data[i] = queue.get(&current_bytes_recv, i + size_of(Message_id_type));
			}
			message_size := utils.to_type(header_data, utils.Header_size_type);
			
			total_size : int = size_of(Message_id_type) + cast(int)message_size;
			if queue.len(client.current_bytes_recv) < total_size {
				return false;
			}
			
			data : []u8 = make([]u8, message_size);
			defer delete(data);

			for i : int = 0; i < cast(int)message_size; i += 1 {
				data[i] = queue.get(&current_bytes_recv, i + size_of(Message_id_type));
			}
			queue.consume_front(&client.current_bytes_recv, total_size);
			
			val : any;
			err : utils.Serialization_error;
			val, err = utils.deserialize_from_bytes(message_typeid, data, command.alloc);
			
			//fmt.assertf(command_size != 0, "command_size was 0, for %v", message_typeid);

			if err == .ok {
				command.value = val;
			}
			else {
				panic("Failed to deserialize_from_bytes!");
			}
		}

		return true;
	}

	{
		sync.lock(&client.mutex);
		defer sync.unlock(&client.mutex);

		//We want enough bytes to know the message_id, otherwise we know nothing.
		if queue.len(client.current_bytes_recv) < size_of(Message_id_type) {
			return false;
		}
	}
	
	sync.lock(&client.mutex);
	message_data : []u8 = make([]u8, size_of(Message_id_type));
	defer delete(message_data);
	for i : int = 0; i < size_of(Message_id_type); i += 1 { //TODO no bounds check
		message_data[i] = queue.get(&client.current_bytes_recv, i);
	}
	sync.unlock(&client.mutex);
	
	//Note: Message_id_type :: u16
	message_id : Message_id_type = utils.to_type(message_data, Message_id_type); //slice.reinterpret(client.data[:3], u32);

	if message_id in params.commands {
		//Yes, a valid message
		command : Command;

		command.arena_alloc = new(mem.Dynamic_Arena);
		mem.dynamic_arena_init(command.arena_alloc);
		command.alloc = mem.dynamic_arena_allocator(command.arena_alloc);
		
		sync.lock(&client.mutex);
		defer sync.unlock(&client.mutex);
		did_parse_message := try_parse(client, params, message_id, &command, loc);

		if did_parse_message {
			//Add command to command queue.
			sync.lock(client.recv_mutex)
			queue.append(client.recv_commands, command);
			sync.unlock(client.recv_mutex)

			log.debugf("command value : %v\n", command.value);

			return true;
		}

		//failed, free resources
		free_all(command.alloc);
		mem.dynamic_arena_destroy(command.arena_alloc);
		free(command.arena_alloc);
	}
	else {
		log.errorf("A none valid message %v was passed.\n params are : %#v.\n", message_id);
	}
	
	return false;
}
