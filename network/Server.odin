package furbs_network

import "core:container/queue"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:slice"
import "core:time"

import "../utils"

//////////////////////////////////////////////////////////////
// 				This is a singled threaded API				//
//////////////////////////////////////////////////////////////

//All members are private
Server_side_client :: struct {
	interface : Interface_handle,
	user_data : rawptr,
}

//All members are private
Server :: struct {
	events       	: queue.Queue(Event),     //This should be handle in the main thread
	to_clean 		: [dynamic]Event,
	
	interface_index : Interface_handle,
	interfaces : map[Interface_handle]Server_interface,
	
	//clients
	clients : map[^Server_side_client]struct{}, // a set
	
	//threading stuff
	is_open : bool,
	should_close : bool,
	
	mutex 	: sync.Mutex,
	handeling_events : bool,
}

@(require_results)
server_create :: proc(loc := #caller_location) -> (server : ^Server) {
	server = new(Server);
	queue.init(&server.events);
	server.to_clean = make([dynamic]Event)
	server.interfaces = make(map[Interface_handle]Server_interface);
	
	return server;
}

register_interface :: proc (server : ^Server, interface : Server_interface) -> Interface_handle {
	assert(server.is_open == false, "interfaces must be registered before opening the server");
	
	server.interface_index += 1;
	server.interfaces[server.interface_index] = interface;

	return server.interface_index;
}

//Start reciving clients from all interfaces
server_start_accepting :: proc (server : ^Server, loc := #caller_location) {
	server.is_open = true;
	for handle, interface in server.interfaces {
		interface.listen(server, handle, interface.server_data);
	}
}

//Stop accepecting and recving new clients and messages from clients (disconnects all clients), there might still be unhandeled messages, which can be handled before server_destroy.
server_close :: proc(server : ^Server) {
	for handle, interface in server.interfaces {
		interface.close(server, interface.server_data); //this should also disconnect them all, leave a few messages.
	}
}

server_destroy :: proc (server : ^Server) {
	for handle, interface in server.interfaces {
		interface.destroy(server, interface.server_data);
	}
}

server_begin_handle_events :: proc (server : ^Server, loc := #caller_location) {
	assert(server.handeling_events == false, "you must call server_end_handle_commands before calling server_begin_handle_commands twice", loc);
	for _, interface in server.interfaces {
		if interface.service != nil {
			interface.service(server, interface.server_data);
		}
	}
	sync.lock(&server.mutex);
	server.handeling_events = true;
}

@(require_results)
server_get_next_event :: proc (server : ^Server, loc := #caller_location) -> (event : Event, done : bool) {
	assert(server.handeling_events == true, "you must call begin_handle_commands first", loc)

	if queue.len(server.events) == 0 {
		return {}, true;
	}

	e := queue.pop_front(&server.events);
	append(&server.to_clean, e);
	
	return e, false;
}

server_end_handle_events :: proc (server : ^Server, loc := #caller_location) {
	assert(server.handeling_events == true, "you must call server_begin_handle_commands before calling server_end_handle_commands", loc);	
	server.handeling_events = false;
	sync.unlock(&server.mutex);
	
	clean_up_events(&server.to_clean, loc);
}

@(require_results)
server_send :: proc (server : ^Server, client : ^Server_side_client, value : any, loc := #caller_location) -> (err : Error) {
	i := server.interfaces[client.interface];
	return i.send(server, i.server_data, client.user_data, value);
}

//send to all clients
send_broadcast :: proc (server : ^Server, value : any, loc := #caller_location) {
	for client in server.clients {
		_ = server_send(server, client, value, loc);
	}
}

//Will disconnect and allow one to handle the remaining messages
server_disconnect_client :: proc (server : ^Server, client : ^Server_side_client, loc := #caller_location) {
	assert(server.handeling_events == true, "you must call begin_handle_commands first", loc)
	fmt.assertf(client in server.clients, "Not a valid client id : %v", client, loc = loc);
	
	interface := server.interfaces[client.interface];
	interface.disconnect(server, interface.server_data, client.user_data);
}

