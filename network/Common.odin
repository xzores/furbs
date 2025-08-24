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
import "core:time"

import "../utils"

Network_Error :: net.Network_Error;

Host_or_endpoint :: net.Host_Or_Endpoint;
Endpoint :: net.Endpoint;

IP4_Address :: net.IP4_Address;
IP6_Address :: net.IP6_Address;
Address :: net.Address;

IP4_Loopback :: net.IP4_Loopback;
IP6_Loopback :: net.IP6_Loopback;

//////////////////////////////////////////////////////////////////////
// 				This is only meant for internal use					//
//////////////////////////////////////////////////////////////////////

Command :: struct {
	arena_alloc : ^mem.Dynamic_Arena, //hold the memory for value, free when done with value.
	alloc :	mem.Allocator,
	value : any,
	is_constant_size : bool,
}

Event_connected :: struct {
	//TODO error msg	
}

Event_error :: struct {
	//TODO error msg
}

Event_msg :: struct {
	//client : ^Server_side_client,
	commad : Command,
}

Event_disconnected :: struct {
	//TODO error msg
}

Event :: struct {
	user_data : rawptr,
	timestamp : time.Time,
	type : union {
		Event_connected,
		Event_error,
		Event_msg,
		Event_disconnected,
	}
}

Message_id_type :: distinct u32;
client_id_type :: int;

Network_commands :: struct {
    commands                    : map[Message_id_type]typeid,
    commands_inverse            : map[typeid]Message_id_type,
}

Error :: union {
	net.TCP_Send_Error,
	utils.Serialization_error,
}

//The values must be kept alive for the whole program, by the caller.
make_commands :: proc(commands_map : map[Message_id_type]typeid) -> Network_commands {
    net_commands : Network_commands;

    net_commands.commands = make(map[Message_id_type]typeid);
	net_commands.commands_inverse = make(map[typeid]Message_id_type);

    for id, com in commands_map {
        net_commands.commands_inverse[com] = id;
		net_commands.commands[id] = com;
    }

    return net_commands;
}

delete_commands :: proc(using params : ^Network_commands) {
	delete(commands);
	delete(commands_inverse);
}

clean_up_events :: proc (to_clean : ^[dynamic]Event, client_clean : proc(c : rawptr), loc := #caller_location) {
	
	for e in to_clean {
		#partial switch b in e.type {
			case Event_connected: {
				//nothing to free
			}
			case Event_msg: {
				mem.free_all(b.commad.alloc);
				mem.dynamic_arena_destroy(b.commad.arena_alloc);
				mem.free(b.commad.arena_alloc);
			}
			case Event_disconnected: {
				//nothing to free
				client_clean(e.user_data);
			}
			case: {
				unreachable();
			}
		}
	}

	clear(to_clean);
}

