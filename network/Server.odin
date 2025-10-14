package furbs_network

import "core:container/queue"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:log"
import "core:fmt"
import "core:slice"
import "core:time"

import "../tracy"
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
	tracy.Zone();
	server = new(Server);
	queue.init(&server.events);
	server.to_clean = make([dynamic]Event)
	server.interfaces = make(map[Interface_handle]Server_interface);
	
	return server;
}

register_interface :: proc (server : ^Server, interface : Server_interface) -> Interface_handle {
	tracy.Zone();
	assert(server.is_open == false, "interfaces must be registered before opening the server");
	
	server.interface_index += 1;
	server.interfaces[server.interface_index] = interface;

	return server.interface_index;
}

//Start reciving clients from all interfaces
//You only recive the last error, there might be hidden errors.
server_start_accepting :: proc (server : ^Server, loc := #caller_location) -> (err : Error) {
	tracy.Zone();
	server.is_open = true;
	for handle, interface in server.interfaces {
		log.debugf("starting listening on interface %v", handle);
		e := interface.listen(server, handle, interface.server_data);
		if e != nil {
			err = e;
		}
	}

	return;
}

//Stop accepecting and recving new clients and messages from clients (disconnects all clients), there might still be unhandeled messages, which can be handled before server_destroy.
server_close :: proc(server : ^Server) {
	tracy.Zone();
	for handle, interface in server.interfaces {
		interface.close(server, interface.server_data); //this should also disconnect them all, leave a few messages.
	}
}

server_destroy :: proc (server : ^Server) {
	tracy.Zone();
	for handle, interface in server.interfaces {
		interface.destroy(server, interface.server_data);
	}

	assert(len(server.clients) == 0);
	delete(server.clients);
	queue.destroy(&server.events);
	delete(server.to_clean);
	delete(server.interfaces);
	free(server);
}

server_begin_handle_events :: proc (server : ^Server, loc := #caller_location) {
	tracy.Zone();
	assert(server.handeling_events == false, "you must call server_end_handle_commands before calling server_begin_handle_commands twice", loc);
	sync.lock(&server.mutex);
	server.handeling_events = true;
}

@(require_results)
server_get_next_event :: proc (server : ^Server, loc := #caller_location) -> (event : Event, done : bool) {
	tracy.Zone();
	assert(server.handeling_events == true, "you must call begin_handle_commands first", loc)

	if queue.len(server.events) == 0 {
		return {}, true;
	}

	e := queue.pop_front(&server.events);
	append(&server.to_clean, e);
	
	return e, false;
}

server_end_handle_events :: proc (server : ^Server, loc := #caller_location) {
	tracy.Zone();
	assert(server.handeling_events == true, "you must call server_begin_handle_commands before calling server_end_handle_commands", loc);	
	server.handeling_events = false;
	sync.unlock(&server.mutex);

	for e in server.to_clean {
		#partial switch b in e.type {
			case Event_msg: {
				//nothing to free
				if b.free_proc != nil {
					b.free_proc(b.value, b.backing_data);
				}
			}
			case Event_disconnected: {
				client := e.client.(^Server_side_client);
				assert(client in server.clients);
				delete_key(&server.clients, client);

				i := server.interfaces[client.interface];
				i.destroy_client(server, client, i.server_data, client.user_data);
				free(client);
			}
		}
	}

	clear(&server.to_clean);

}

@(require_results)
server_send :: proc (server : ^Server, client : ^Server_side_client, value : any, loc := #caller_location) -> (err : Error) {
	tracy.Zone();
	assert(client.interface in server.interfaces, "invalid interface handle")
	i := server.interfaces[client.interface];
	return i.send(server, client, i.server_data, client.user_data, value);
}

//send to all clients
send_broadcast :: proc (server : ^Server, value : any, loc := #caller_location) {
	tracy.Zone();
	for client in server.clients {
		_ = server_send(server, client, value, loc);
	}
}

//Will disconnect and allow one to handle the remaining messages
server_disconnect_client :: proc (server : ^Server, client : ^Server_side_client, loc := #caller_location) {
	tracy.Zone();
	fmt.assertf(client in server.clients, "Not a valid client id : %v", client, loc = loc);
	
	interface := server.interfaces[client.interface];
	interface.disconnect(server, client, interface.server_data, client.user_data);
}





