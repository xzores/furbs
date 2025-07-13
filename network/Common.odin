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

	user_data : rawptr, //used by server to indicate which client it recived this message from.
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
