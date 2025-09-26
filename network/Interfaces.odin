package furbs_network

import "core:net"
import "core:container/queue"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:time"
import "core:log"

import "base:runtime"

//////////////////////////////////////////////////////////////
// 			This is a multithread threaded API		 		//
// 			You should use these functions when				//
// 			creating a new backend for an interface			//
//////////////////////////////////////////////////////////////




///////////////////////// SERVER /////////////////////////

@(require_results)
push_connect_server :: proc (server : ^Server, inteface : Interface_handle, user_data : rawptr) -> ^Server_side_client {
	sync.guard(&server.mutex);
	
	assert(inteface in server.interfaces, "invalid inteface");

	new_client := new(Server_side_client);
	new_client^ = {
		inteface,
		user_data
	}

	server.clients[new_client] = {};
	queue.append(&server.events, Event{new_client, time.now(), 0, Event_connected{}});
	return new_client;
}

push_msg_server :: proc (server : ^Server, client : ^Server_side_client, value : any, free_proc : proc (value : any, data : rawptr), backing_data : rawptr) {
	sync.guard(&server.mutex);
	assert(client in server.clients);
	queue.append(&server.events, Event{client, time.now(), 0, Event_msg{value, free_proc, backing_data}});
}

push_error_server :: proc (server : ^Server, client : ^Server_side_client, error : Error) {
	sync.guard(&server.mutex);
	assert(client in server.clients);
	queue.append(&server.events, Event{client, time.now(), 0, Event_error{}});
}

push_disconnect_server :: proc (server : ^Server, client : ^Server_side_client) {
	sync.guard(&server.mutex);
	assert(client in server.clients);
	delete_key(&server.clients, client);
}



///////////////////////// CLIENT /////////////////////////

push_connect_client :: proc (client : ^Client) {
	sync.guard(&client.mutex);
	queue.append(&client.events, Event{client, time.now(), 0, Event_connected{}});
}

push_msg_client :: proc (client : ^Client, value : any, free_proc : proc (value : any, data : rawptr), backing_data : rawptr) {
	sync.guard(&client.mutex);
	queue.append(&client.events, Event{client, time.now(), 0, Event_msg{value, free_proc, backing_data}});
}

push_error_client :: proc (client : ^Client, err : Error) {
	sync.guard(&client.mutex);
	queue.append(&client.events, Event{client, time.now(), 0, Event_error{err}});
}

push_disconnect_client :: proc (client : ^Client) {
	sync.guard(&client.mutex);
	queue.append(&client.events, Event{client, time.now(), 0, Event_disconnected{}});
}

