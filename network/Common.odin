package furbs_network

import "base:runtime"

import "core:net"
import "core:container/queue"
import "core:thread"
import "core:mem"
import vmem "core:mem/virtual"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:sync"
import "core:time"

import "../utils"
import "../serialize"

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

Interface_handle :: distinct i32;

Server_interface :: struct {
	server_data : rawptr,
	
	listen : proc (server : ^Server, interface_handle : Interface_handle, user_data : rawptr) -> Error, //listen data is given by the user who starts it.
	send : proc (server : ^Server, user_data : rawptr, client : rawptr, data : any) -> Error,
	disconnect : proc (server : ^Server, user_data : rawptr, client_data : rawptr) -> Error, //disconnect the client forcefully (cannot fail)
	close : proc (server : ^Server, user_data : rawptr) -> Error, //Must stop accecpting and close all connections
	destroy : proc (server : ^Server, user_data : rawptr), //removes the interface, the interface must free all its internal data.
}

Client_interface :: struct {
	client_data : rawptr,

	connect : proc (client : ^Client, user_data : rawptr) -> Error,
	send : proc (client : ^Client, user_data : rawptr, data : any) -> Error,
	disconnect : proc (client : ^Client, user_data : rawptr) -> Error,
	destroy : proc (client : ^Client, user_data : rawptr)
}

Event_connected :: struct {

}

Event_error :: struct {
	err : Error,
}

Event_msg :: struct {
	value : any,
	
	free_proc : proc (value : any, data : rawptr),
	backing_data : rawptr, //For whatever thing
}

Event_disconnected :: struct {
	//TODO error msg
}

Event :: struct {
	user_data : union {
		^Server_side_client,
		^Client,
	},
	timestamp : time.Time,
	original_interface : Interface_handle,
	type : union {
		Event_connected,
		Event_error,
		Event_msg,
		Event_disconnected,
	}
}

destroy_event :: proc (e : Event, loc := #caller_location) {
	
	switch b in e.type {
		case Event_connected: {
			//nothing to free
		}
		case Event_msg: {
			b.free_proc(b.value, b.backing_data);
		}
		case Event_disconnected: {
			//nothing to free

		}
		case Event_error: {
			//nothing to free
		}
		case: {
			unreachable();
		}
	}
}

Error :: enum {
	ok,
	no_such_client,
	not_connected,
	already_open,
	not_open,
	refused,
	network_error,
	access_error,
	invalid_parameter,
	serialize_error,
	data_error,
	corrupted_stream,
	other,
	unknown,
}

clean_up_events :: proc (to_clean : ^[dynamic]Event, loc := #caller_location) {
	
	for e in to_clean {
		#partial switch b in e.type {
			case Event_msg: {
				//nothing to free
				if b.free_proc != nil {
					b.free_proc(b.value, b.backing_data);
				}
			}
		}
		destroy_event(e);
	}

	clear(to_clean);
}

begin_handle_events :: proc {client_begin_handle_events, server_begin_handle_events}
end_handle_events :: proc {client_end_handle_events, server_end_handle_events}
get_next_event :: proc {client_get_next_event, server_get_next_event}