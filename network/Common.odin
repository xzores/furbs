package network

import "core:net"
import "base:intrinsics"
import "core:fmt"
import "base:runtime"
import "core:mem"
import "core:reflect"
import "core:builtin"
import "core:time"

import mem_virtual "core:mem/virtual"

import queue "core:container/queue"

import utils "../../FurbLib/utils"
import thread "../../FurbLib/utils"
import tracy "shared:tracy"

typeid_set :: map[typeid]struct{};

message_id_type :: distinct u16;
client_id_type :: int;

lock :: utils.lock;
unlock :: utils.unlock;

Network_params :: struct {

    commands                    : map[message_id_type]typeid,
    commands_inverse            : map[typeid]message_id_type,

    command_allowing            : map[typeid][]typeid,
    command_disallowing         : map[typeid][]typeid,
    initial_allowed_commands    : typeid_set,
    
    custem_user_data_cleanup_func : proc(data_to_clean : any),
    
    is_init : bool,
}

////////////////////////////////////////////////

/*
steam_interface :: struct {
	//IDK steam ID?
}

net_interface :: struct {
	socket : net.TCP_Socket,
}
*/

Client_base :: struct {
    
    //Data
    current_bytes_recv  : queue.Queue(u8),      //This fills up and must be handled somehow
    recv_commands       : queue.Queue(Command),     //This should be handle in the main thread and is locked by commands_mutex
	commands_mutex 		: utils.Mutex,

    //What commands can this socket able to recive
    allowed_commands    : typeid_set,           //This is a "set" datastructure

	socket : net.TCP_Socket,

	/*
	interface : union {
		net_interface,
		steam_interface,
	}
	*/

    //threading stuff
    is_open : bool,
    should_close : bool,
    recive_thread : ^thread.Thread,
    mutex : utils.Mutex, //lock everything but recv_commands, recv_commands uses commands_mutex
}

Command :: struct {
	arena_alloc : ^mem_virtual.Arena, //hold the memory for value, free when done with value.
	alloc :	mem.Allocator,
	value : any,
	is_constant_size : bool,
}

////////////////////////////////////////////////

//The values must be kept alive for the whole program, by the caller.
make_params :: proc(data_cleanup_func : proc(data_to_clean : any), commands_map : map[message_id_type]typeid, initial_allowed_commands_set : typeid_set,
                        command_allowing_list : map[typeid][]typeid, command_disallowing_list : map[typeid][]typeid) -> Network_params {
    net_params : Network_params;
    using net_params;

    commands = commands_map;
    initial_allowed_commands = initial_allowed_commands_set;
    command_allowing = command_allowing_list;
    command_disallowing = command_disallowing_list;

    custem_user_data_cleanup_func = data_cleanup_func;

    for id, com in commands {
        commands_inverse[com] = id;
    }

    is_init = true;

    return net_params;
}

delete_params :: proc(using params : ^Network_params) {
	
	delete(commands_inverse);
}

//return true if error
//where intrinsics.type_is_variant_of(message.Constant_size_union, T)
send_message_constant_size :: proc(socket : net.TCP_Socket, using params : Network_params, data : any, loc := #caller_location) -> (err : bool) {
	tracy.Zone();
    fmt.assertf(data.id in commands_inverse, "The data %v (%i) is not a command as it is not in the map : %#v", data.id, data.id, commands_inverse, loc);

	assert(data != nil, "data is nil, cannot send nil");

    command_size : int = reflect.size_of_typeid(data.id);
    bytes_to_send_cnt : int = command_size + size_of(message_id_type);
    command_id : message_id_type = commands_inverse[data.id];
    
    to_send : []u8 = make([]u8, bytes_to_send_cnt);
    defer delete(to_send);

    runtime.mem_copy(&to_send[0], &command_id, size_of(message_id_type));
    if command_size > 0 {
        runtime.mem_copy(&to_send[size_of(message_id_type)], data.data, command_size);
    }
    
	//fmt.printf("Sending : %v\n", to_send);
	bytes_send, serr := net.send(socket, to_send);

    if serr != nil {
        fmt.printf("Failed to send, recived err %v\n", serr);
        return true;
    }
    if bytes_send != bytes_to_send_cnt {
        fmt.printf("Failed to send all bytes, tried to send %i, but only sent %i\n", command_size, bytes_send);
        return true;
    }

    return false;
}

send_message_variable_size :: proc (socket : net.TCP_Socket, using params : Network_params, data : any, loc := #caller_location) -> (err : bool) {
    tracy.Zone();
    fmt.assertf(data.id in commands_inverse, "The data %v is not a command as it is not in the map : %#v", data.id, commands_inverse, loc);

    command_id : message_id_type = commands_inverse[data.id];

    to_send : [dynamic]u8 = make([dynamic]u8, size_of(message_id_type));
    runtime.mem_copy(&to_send[0], &command_id, size_of(message_id_type));

    utils.serialize_to_bytes(data, &to_send, loc);
    defer delete(to_send);

    bytes_send, serr := net.send(socket, to_send[:]);

    if serr != nil {
        fmt.printf("Failed to send, recived err %v\n", serr);
        return true;
    }
    if bytes_send != len(to_send) {
        fmt.printf("Failed to send all bytes, tried to send %i, but only sent %i\n", len(to_send), bytes_send);
        return true;
    }

    return false;
}

send_message_params :: proc (socket : net.TCP_Socket, params : Network_params, data : any, loc := #caller_location) -> (err : bool) {
	tracy.Zone();
    if(utils.is_trivial_copied(data.id)) {
        return send_message_constant_size(socket, params, data, loc);
    }
    else {
        return send_message_variable_size(socket, params, data, loc);
    }
}

send_message_client :: proc (client : ^Client, data : any, loc := #caller_location) -> (err : bool) {
    return send_message_params(client.socket, client.params, data, loc);
}

send_message :: proc{send_message_client, send_message_params};

wait_for_message :: proc(using client : ^Client_base, $message_type : typeid, timeout : time.Duration = 5 * time.Second, loc := #caller_location) -> (mes : message_type, err : bool) {
    using time;
	tracy.Zone();

    mes = {};
    err = true;

    timer : time.Stopwatch;
    stopwatch_start(&timer);

    for true {
		
		{
			lock(&commands_mutex);
			defer unlock(&commands_mutex);
			if queue.len(recv_commands) != 0 {
				
				com : Command = queue.pop_front(&recv_commands);
				command := com.value;

				fmt.assertf(message_type == command.id, "Expected commands %v, got %v", 0, command.id, loc);
				mes = (cast(^message_type)command.data)^;
				err = false;
				
				stopwatch_stop(&timer);
				
				free_all(com.alloc);
				mem_virtual.arena_destroy(com.arena_alloc);
				free(com.arena_alloc);

				return;
			}
		}

        dur := stopwatch_duration(timer);

        if dur > timeout {
            break;
        }

        time.sleep(Millisecond);
    }

    stopwatch_stop(&timer);

    return;
}

recv_parse_loop :: proc(using client : ^Client_base, params : Network_params, loc := #caller_location) {
	tracy.Zone();

    is_open = true;
    
    new_data_buffer : [16384]u8; //We can max recive 16384 bytes at a time.

    for !should_close {
        bytes_recv, err := net.recv(socket, new_data_buffer[:]);

        if (err == net.TCP_Recv_Error.Aborted || err == net.TCP_Recv_Error.Connection_Closed) && should_close {
            continue;
        }
        else if (err == net.TCP_Recv_Error.Aborted || err == net.TCP_Recv_Error.Connection_Closed) {
            fmt.printf("Warning : a connection was close without should_close being set true. Automagicly closing now\n Caller : %v\n", loc);
            should_close = true;
            continue;
        }
        else if err != nil {
            fmt.printf("failed recv, err : %v called from : %v\n", err, loc);
            continue;
        }

        lock(&mutex);
        for d in new_data_buffer[:bytes_recv] {
            queue.append(&current_bytes_recv, d); //TODO this is very slow, copy all at once
        }
		unlock(&mutex);
        
        for parse_message(client, params, loc) {}; //Parses all messages...
	
		free_all(context.temp_allocator);
    }

    //fmt.printf("Closing client loop for index : %v\n", t.user_index);

	lock(&mutex);
	defer unlock(&mutex);
	lock(&commands_mutex);
	defer unlock(&commands_mutex);

    queue.destroy(&current_bytes_recv);
    queue.destroy(&recv_commands);
    delete(allowed_commands);

	free_all(context.temp_allocator);
}

//returns true if it did parse something
parse_message :: proc (using client : ^Client_base, params : Network_params, loc := #caller_location) -> bool {
    tracy.Zone();

	try_parse :: proc(using client : ^Client_base, params : Network_params, message_id : message_id_type, command : ^Command, loc := #caller_location) -> bool{

		message_typeid : typeid = params.commands[message_id];		
		
		tracy.Message(fmt.tprintf("trying to parsing message : %v", message_typeid));

		if utils.is_trivial_copied(message_typeid) {
			command.is_constant_size = true;
			//fmt.printf("Parsing trivical message : %v\n", message_typeid);

            command_size : int = reflect.size_of_typeid(message_typeid);
            total_size : int = size_of(message_id_type) + command_size;
            
            if queue.len(client.current_bytes_recv) < total_size {
                return false;
            }

            command_data, err := mem.alloc_bytes(command_size, allocator = command.alloc);
			if err != nil { panic("Unable to allocate!!?!?"); }
            
			for i : int = 0; i < cast(int)command_size; i += 1 {
				command_data[i] = queue.get(&current_bytes_recv, i + size_of(message_id_type));
			}
            
            command.value = {data = raw_data(command_data), id = message_typeid};
			//fmt.printf("Recived : %v\n", command);

            queue.consume_front(&client.current_bytes_recv, total_size);
        }
        else {
			command.is_constant_size = false;
            //We need another header, this header is the Utils.Header_size_type

            req_size := size_of(message_id_type) + size_of(utils.Header_size_type);
            if queue.len(client.current_bytes_recv) < req_size {
                return false;
            }
            
            header_data : []u8 = make([]u8, size_of(utils.Header_size_type));
			defer delete(header_data);
            for i : int = 0; i < size_of(utils.Header_size_type); i += 1 {
                header_data[i] = queue.get(&current_bytes_recv, i + size_of(message_id_type));
            }
            message_size := utils.to_type(header_data, utils.Header_size_type);
            
			total_size : int = size_of(message_id_type) + cast(int)message_size;
			if queue.len(client.current_bytes_recv) < total_size {
				return false;
			}
            
			data : []u8 = make([]u8, message_size);
            defer delete(data);

            for i : int = 0; i < cast(int)message_size; i += 1 {
                data[i] = queue.get(&current_bytes_recv, i + size_of(message_id_type));
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

		//TODO check if command is allowed for this user.
		if !(message_typeid in allowed_commands) {
			fmt.printf("The command : %v is not allowed disconnecting client. Caller : %v\n", message_typeid, loc);
			//TODO : queue.append(&recv_commands, message.Disconnect{});
			return false; //This blocks further messages from being parsed.
		}

		return true;
	}

	{
		lock(&mutex);
		defer unlock(&mutex);

		//We want enough bytes to know the message_id, otherwise we know nothing.
		if queue.len(client.current_bytes_recv) < size_of(message_id_type) {
			return false;
		}
	}
	
	lock(&mutex);
    message_data : []u8 = make([]u8, size_of(message_id_type));
	defer delete(message_data);
    for i : int = 0; i < size_of(message_id_type); i += 1 { //TODO no bounds check
        message_data[i] = queue.get(&current_bytes_recv, i);
    }
	unlock(&mutex);
	
    //Note: message_id_type :: u16
    message_id : message_id_type = utils.to_type(message_data, message_id_type); //slice.reinterpret(client.data[:3], u32);

    if message_id in params.commands {
        //Yes, a valid message
        
        command : Command;

		command.arena_alloc = new(mem_virtual.Arena);
		err_a := mem_virtual.arena_init_growing(command.arena_alloc);
		assert(err_a == nil);
		command.alloc = mem_virtual.arena_allocator(command.arena_alloc);

		lock(&mutex);
		did_parse_message := try_parse(client, params, message_id, &command, loc);
		unlock(&mutex);

        if did_parse_message {      
            //Add command to command queue.
			lock(&commands_mutex);
            queue.append(&recv_commands, command);
			defer unlock(&commands_mutex);

            //fmt.printf("command : %v\n", command.id);

            if command.value.id in params.command_allowing {
                for new_command in params.command_allowing[command.value.id] {
                    client.allowed_commands[new_command] = {};
                }
            }

            if command.value.id in params.command_disallowing {
                for to_remove_command in params.command_disallowing[command.value.id] {
                    builtin.delete_key(&client.allowed_commands, to_remove_command);
                }
            }
            
            return true;
        }

		free_all(command.alloc);
		mem_virtual.arena_destroy(command.arena_alloc);
		free(command.arena_alloc);
    }
    else {
        fmt.printf("A none valid message %v was passed.\n params are : %#v.\n", message_id);
        //TODO : queue.append(&recv_commands, message.Disconnect{});
    }

    return false;
}

//TODO 
//client_parse_message