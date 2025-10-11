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
	
	listen 			: proc "contextless" (server : ^Server, interface_handle : Interface_handle, user_data : rawptr) -> Error, //listen data is given by the user who starts it.
	send 			: proc "contextless" (server : ^Server, client : ^Server_side_client, user_data : rawptr, client_user_data : rawptr, data : any) -> Error,
	disconnect 		: proc "contextless" (server : ^Server, client : ^Server_side_client, user_data : rawptr, client_user_data : rawptr) -> Error, //disconnect the client forcefully (cannot fail)
	destroy_client 	: proc "contextless" (server : ^Server, client : ^Server_side_client, user_data : rawptr, client_user_data : rawptr), //disconnect the client forcefully (cannot fail)
	close 			: proc "contextless" (server : ^Server, user_data : rawptr) -> Error, //Must stop accecpting and close all connections
	destroy 		: proc "contextless" (server : ^Server, user_data : rawptr), //removes the interface, the interface must free all its internal data.
}

Client_interface :: struct {
	client_data : rawptr,

	connect 	: proc "contextless" (client : ^Client, user_data : rawptr) -> Error,
	send 		: proc "contextless" (client : ^Client, user_data : rawptr, data : any) -> Error,
	disconnect 	: proc "contextless" (client : ^Client, user_data : rawptr) -> Error,
	destroy 	: proc "contextless" (client : ^Client, user_data : rawptr),
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
	client : union {
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

Error :: enum {
	ok,
	no_such_client,
	not_connected,
	already_open,
	not_open,
	refused,
	endpoint_error,
	dns_error,
	network_error,
	access_error,
	invalid_parameter,
	serialize_error,
	data_error,
	corrupted_stream,
	other,
	unknown,
}

begin_handle_events :: proc {client_begin_handle_events, server_begin_handle_events}
end_handle_events :: proc {client_end_handle_events, server_end_handle_events}
get_next_event :: proc {client_get_next_event, server_get_next_event}