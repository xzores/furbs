package furbs_network

import "core:net"
import "core:container/queue"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:time"
import "core:log"

import "base:runtime"

import "../utils"

//////////////////////////////////////////////////////////////
// 				This is a singled threaded API				//
//////////////////////////////////////////////////////////////

//All members are private
Client :: struct {
	//owned by this client 
    events       : queue.Queue(Event),     //This should be handle in the main thread
	event_mutex  : sync.Mutex,
	to_clean : [dynamic]Event,
	
	using client_i : Client_interface,
	
    //threading stuff used internally
	handeling_events : bool,
	mutex : sync.Mutex,
}

Client_interface_data :: distinct rawptr;

@(require_results)
client_create :: proc (client_interface : Client_interface) -> ^Client {
	client := new(Client);
	
	client^ = {
		client_i = client_interface,
		handeling_events = false,
	}
	
	queue.init(&client.events);
	client.to_clean = make([dynamic]Event);
	
	return client;
}

@(require_results)
client_connect :: proc (client : ^Client) -> (err : Error) {
	return client.connect(client, client.client_i.client_data);
}

//locks the mutex and return the current commands, the data must not be copied
client_begin_handle_events :: proc (client : ^Client, loc := #caller_location) {
	assert(client.handeling_events == false, "you must call client_end_handle_events before calling client_begin_handle_events twice", loc);
	sync.lock(&client.event_mutex);
	client.handeling_events = true;
}

@(require_results)
client_get_next_event :: proc (client : ^Client, loc := #caller_location) -> (e : Event, done : bool) {
	assert(client.handeling_events == true, "you must call client_begin_handle_events first", loc)

	if queue.len(client.events) == 0 {
		return {}, true;
	}

	c := queue.pop_front(&client.events);
	append(&client.to_clean, c);
	return c, false;
}

//Frees the mutex and frees the data (all the commands which you have just recived)
client_end_handle_events :: proc (client : ^Client, loc := #caller_location) {
	assert(client.handeling_events == true, "you must call client_begin_handle_events first", loc)	
	client.handeling_events = false;
	sync.unlock(&client.event_mutex);
	
	for e in client.to_clean {
		#partial switch b in e.type {
			case Event_msg: {
				//nothing to free
				if b.free_proc != nil {
					b.free_proc(b.value, b.backing_data);
				}
			}
		}
	}

	clear(&client.to_clean);
}

@(require_results)
client_wait_for_event :: proc (client : ^Client, timeout := 5 * time.Second, sleep_time := 100 * time.Microsecond, loc := #caller_location) -> (timedout : bool) { 
	
	start_time := time.now();
	
	for timeout == 0 || !(time.diff(start_time, time.now()) >= timeout) {
		{
			client_begin_handle_events(client);
			defer client_end_handle_events(client);
			if queue.len(client.events) != 0 {
				return false;
			}
		}
		
		time.sleep(sleep_time);
	}

	log.warnf("client_wait_for_event timed out", location = loc);
	return true;
}

@(require_results)
client_send :: proc (client : ^Client, value : any, loc := #caller_location) -> (err : Error) {
	return client.send(client, client.client_data, value);
}

//Will disconnect, but there might still be unhanded commands in the buffer these can be handled before calling destroy
@(require_results)
client_disconnect :: proc (client : ^Client) -> (err : Error) {
	return client.disconnect(client, client.client_data);
}

client_destroy :: proc (client : ^Client) {
	client.destroy(client, client.client_data);
	queue.destroy(&client.events);
	delete(client.to_clean);
	free(client);
}