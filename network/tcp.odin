package furbs_network

import "core:debug/pe"
import "core:math"
import "base:runtime"

import "core:net"
import "core:time"
import "core:container/queue"
import "core:thread"
import "core:mem"
import vmem "core:mem/virtual"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:sync"

import "../serialize"

//////////////////////////////////////////////////////////////////////
// 				This is only meant for internal use					//
//////////////////////////////////////////////////////////////////////

Client_tcp_base :: struct {
	//Data
	current_bytes_recv  : queue.Queue(u8),	  	//This fills up and must be handled somehow
	events	   			: ^queue.Queue(Event),	//This should be handle in the main thread
	event_mutex 		: ^sync.Mutex,
	
	sock : net.TCP_Socket,
	user_data : rawptr, //this is used by the server to figure out which client recived the command.

	did_open : bool,
	should_close : bool,
	mutex : sync.Mutex, //lock everything
}

init_tcp_base :: proc (user_data : rawptr, loc := #caller_location) -> Client_tcp_base {
	client : Client_tcp_base
	queue.init(&client.current_bytes_recv);
	client.user_data = user_data;
	return client;
}

destroy_tcp_base :: proc (client : ^Client_tcp_base) {
	queue.destroy(&client.current_bytes_recv);
}

recv_tcp_parse_loop :: proc(client : ^Client_tcp_base, params : Network_commands, buffer_size := 4096, loc := #caller_location) {

	client.did_open = true;
	
	new_data_buffer := make([]u8, buffer_size); //The max number of bytes that can be recived at a time (you can still recive messages larger then this)
	defer delete(new_data_buffer);

	for !client.should_close {
		bytes_recv, err := net.recv(client.sock, new_data_buffer[:]);
		
		if bytes_recv == 0 {
			break;
		}
		if (err == net.TCP_Recv_Error.Connection_Closed || err == net.TCP_Recv_Error.Interrupted) && client.should_close {
			log.warnf("Breakout of recv : %v", loc);
			continue;
		}
		else if (err == net.TCP_Recv_Error.Connection_Closed || err == net.TCP_Recv_Error.Interrupted) {
			log.warnf("Warning : a connection was close without should_close being set true. Automagicly closing now\n Caller : %v", loc);
			client.should_close = true;
			continue;
		}
		else if err != nil {
			log.errorf("failed recv, err : %v called from : %v", err, loc);
			sync.lock(client.event_mutex);
			queue.append(client.events, Event{client.user_data, time.now(), Event_error{}});
			sync.unlock(client.event_mutex);
			break;
		}

		sync.lock(&client.mutex);
		queue.append_elems(&client.current_bytes_recv, ..new_data_buffer[:bytes_recv]);
		sync.unlock(&client.mutex);
		
		status := parse_message(client, params, loc);
		for status == .finished {
			status = parse_message(client, params, loc);
			log.debugf("status is finished there might be more messages");
		}; //Parses all messages, if one finishes then do the next...
		
		if status == .failed {
			panic("TODO corrupt message disconnect client");
		}

		free_all(context.temp_allocator);
	}

	sync.lock(client.event_mutex);
	queue.append(client.events, Event{client.user_data, time.now(), Event_disconnected{}});
	sync.unlock(client.event_mutex);

	free_all(context.temp_allocator);
}

send_tcp_message_commands :: proc (socket : net.TCP_Socket, params : Network_commands, data : any, loc := #caller_location) -> (err : Error) {
		fmt.assertf(data.id in params.commands_inverse, "The data %v is not a command as it is not in the map : %#v", data.id, params.commands_inverse, loc);

	command_id : Message_id_type = params.commands_inverse[data.id];

	to_send := make([dynamic]u8, size_of(Message_id_type));
	runtime.mem_copy(&to_send[0], &command_id, size_of(Message_id_type));

	ser_err := serialize.serialize_to_bytes(data, &to_send, loc);
	defer delete(to_send);

	when ODIN_DEBUG {
		_, _ = serialize.deserialize_from_bytes(data.id, to_send[size_of(Message_id_type):], context.temp_allocator);
	}

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

Msg_pass_result :: enum {
	finished, 
	not_done,
	failed,
}

//returns true if it did parse something
@require_results
parse_message :: proc (client : ^Client_tcp_base, params : Network_commands, loc := #caller_location) -> Msg_pass_result {

	try_parse :: proc(using client : ^Client_tcp_base, params : Network_commands, message_id : Message_id_type, command : ^Command, loc := #caller_location) -> Msg_pass_result {

		message_typeid : typeid = params.commands[message_id];
		command.cmd_id = message_id;
		
		req_size := size_of(Message_id_type) + size_of(serialize.Header_size_type);
		if queue.len(client.current_bytes_recv) < req_size {
			return .not_done;
		}
		
		header_data : []u8 = make([]u8, size_of(serialize.Header_size_type));
		defer delete(header_data);
		for i : int = 0; i < size_of(serialize.Header_size_type); i += 1 {
			header_data[i] = queue.get(&current_bytes_recv, i + size_of(Message_id_type));
		}
		message_size := serialize.to_type(header_data, serialize.Header_size_type); //message_size includes the Header_size itself, so an empty message is size_of(serialize.Header_size_type) long
		
		total_size : int = size_of(Message_id_type) + cast(int)message_size;
		if queue.len(client.current_bytes_recv) < total_size {
			return .not_done;
		}
		
		data : []u8 = make([]u8, message_size);
		defer delete(data);

		for i : int = 0; i < cast(int)message_size; i += 1 {
			data[i] = queue.get(&current_bytes_recv, i + size_of(Message_id_type));
		}
		queue.consume_front(&client.current_bytes_recv, total_size);
		
		val : any;	
		err : serialize.Serialization_error;
		val, err = serialize.deserialize_from_bytes(message_typeid, data, command.alloc);

		//fmt.assertf(command_size != 0, "command_size was 0, for %v", message_typeid);

		if err == .ok {
			command.value = val;
		}
		else {
			log.errorf("Failed to deserialize_from_bytes! for message type %v with error %v, data was:\n%v", message_typeid, err, data);
			return .failed;
		}

		return .finished
	}

	{
		sync.lock(&client.mutex);
		defer sync.unlock(&client.mutex);

		//We want enough bytes to know the message_id, otherwise we know nothing.
		if queue.len(client.current_bytes_recv) < size_of(Message_id_type) {
			return .not_done;
		}
	}
	
	sync.lock(&client.mutex);
	message_data : []u8 = make([]u8, size_of(Message_id_type));
	defer delete(message_data);
	for i : int = 0; i < size_of(Message_id_type); i += 1 { //TODO no bounds check
		message_data[i] = queue.get(&client.current_bytes_recv, i);
	}
	sync.unlock(&client.mutex);
	
	message_id : Message_id_type = serialize.to_type(message_data, Message_id_type); //slice.reinterpret(client.data[:3], u32);

	if message_id in params.commands {
		//Yes, a valid message
		command : Command;
		
		/*
		command.arena_alloc = new(mem.Dynamic_Arena);
		mem.dynamic_arena_init(command.arena_alloc);
		command.alloc = mem.dynamic_arena_allocator(command.arena_alloc);
		*/
		command.arena_alloc = new(vmem.Arena);
		a_err := vmem.arena_init_growing(command.arena_alloc);
		assert(a_err == nil, "failed to make a virtual arena allocaor");
		command.alloc = vmem.arena_allocator(command.arena_alloc);

		sync.lock(&client.mutex);
		defer sync.unlock(&client.mutex);
		did_parse_message := try_parse(client, params, message_id, &command, loc);

		if did_parse_message == .finished {
			//Add command to command queue.
			sync.lock(client.event_mutex) //TODO look at if these mutexs are even needed? could we just have 1?
			queue.append(client.events, Event{client.user_data, time.now(), Event_msg{command}});
			sync.unlock(client.event_mutex)
			return .finished;
		}
		
		//failed, free resources
		free_all(command.alloc);
		vmem.arena_destroy(command.arena_alloc);
		free(command.arena_alloc);
		
		if did_parse_message == .failed {
			log.errorf("failed to parse message");
			return .failed;
		}
	}
	else {
		log.errorf("A none valid message %v was passed.\n params are : %#v.\n", message_id);
	}
	
	return .not_done;
}
