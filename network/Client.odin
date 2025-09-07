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
	event_mutex 			: sync.Mutex,
	to_clean : [dynamic]Event,

	interface : union {
		Client_tcp_base,
	},

	params : Network_commands,

    //threading stuff used internally
	handeling_events : bool,
    recive_thread : ^thread.Thread,
}

@(require_results)
client_create :: proc (commands_map : map[Message_id_type]typeid) -> ^Client {

	client := new(Client)

	client^ = {
		interface = init_tcp_base(nil), //TODO, when supporting other this should be moved into connect as it is connect which determines the interface type
		params = make_commands(commands_map),
		handeling_events = false,
		recive_thread = nil,
	}

	queue.init(&client.events);
	client.to_clean = make([dynamic]Event);
	
	return client;
}

@(require_results)
client_connect :: proc (client : ^Client, target : Host_or_endpoint, thread_logger : Maybe(log.Logger) = nil, thread_allocator : Maybe(mem.Allocator) = nil,) -> (err : Network_Error) {
	
	when ODIN_OS == .JS || ODIN_OS == .WASI {
		panic("When target is WASM or WASI you cannot connect via the odin interface, this must happen in the Javascript and then you can pass the data to the client by calling ");
	}

	Client_logger_allocator :: struct {
		client : ^Client,
		logger : Maybe(log.Logger),
		allocator : Maybe(mem.Allocator),
	}

	client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		
		cla : ^Client_logger_allocator = cast(^Client_logger_allocator)t.data;
		client : ^Client = cla.client;
		
		this_logger := context.logger;
		this_allocator := context.allocator;

		if l, ok := cla.logger.?; ok {
			this_logger = l;
		}

		if a, ok := cla.allocator.?; ok {
			this_allocator = a;
		}
		
		context.logger = this_logger;
		context.allocator = this_allocator;
		
		free(cla);
		
		switch &base in client.interface { 
			case Client_tcp_base: {
				log.debugf("begining client tcp parse loop")
				recv_tcp_parse_loop(&base, client.params);
			}
		}
	}

	/////////// setup recive thread ///////////
	switch &base in client.interface { 
		case Client_tcp_base: {
			
			sock, s_err := net.dial_tcp_from_host_or_endpoint(target);
			err = s_err;
			base.user_data = client;
			base.sock = sock;
			base.events = &client.events;
			base.event_mutex = &client.event_mutex;
			 
			if err != nil {
				log.errorf("Failed to connect to server got error : %v", err);
				return err;
			}
			
			log.infof("Client connected to server");

			queue.clear(&base.current_bytes_recv);
			queue.clear(&client.events);

			assert(net.set_blocking(sock, true) == nil); //We want it to be blocking
			//assert(net.set_option(base.sock, .Linger, time.Second) == nil);
			//assert(net.set_option(base.sock, .Keep_Alive, true) == nil);
			//TODO a timeout is needed (and maybe keep alive settings?)
			
			cla := new(Client_logger_allocator);
			cla^ = {
				client,
				thread_logger,
				thread_allocator,
			}

			client.recive_thread = thread.create(client_recive_loop);
			client.recive_thread.data = cla;
			
			queue.append(&client.events, Event{nil, time.now(), Event_connected{}});

			thread.start(client.recive_thread);
		}
	}
	
	return nil;
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

	clean_up_events(&client.to_clean, _client_destroy);
}

@(require_results)
client_wait_for_event :: proc (client : ^Client, timeout := 3 * time.Second, sleep_time := 100 * time.Microsecond, loc := #caller_location) -> (timedout : bool) { 

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

	log.warnf("client_wait_for_event timed out");
	return true;
}

@(require_results)
client_send :: proc (client : ^Client, value : any, loc := #caller_location) -> (err : Error) {

	log.warnf("sending : %v", 123);
	switch base in client.interface {
		case Client_tcp_base: {
			return send_tcp_message_commands(base.sock, client.params, value, loc);
		}
	}
	
	unreachable();
}

@(require_results)
client_send_raw :: proc (client : ^Client, command_id : Message_id_type, value : []u8, loc := #caller_location) -> (err : Error) {
	command_id := command_id;
	
	switch base in client.interface {
		case Client_tcp_base: {
			to_send := make([]u8, size_of(Message_id_type) + len(value));
			defer delete(to_send);
			runtime.mem_copy(&to_send[0], &command_id, size_of(Message_id_type));
			if len(value) != 0 {
				runtime.mem_copy(&to_send[size_of(Message_id_type)], &value[0], len(value));
			}
			
			bytes_send, serr := net.send_tcp(base.sock, to_send[:]);
			
			if serr != nil {
				log.errorf("Failed to send, got err %v\n", serr);
				return serr;
			}
			if bytes_send != len(to_send) {
				log.errorf("Failed to send all bytes, tried to send %i, but only sent %i\n", len(to_send), bytes_send);
				return .Unknown;
			}

			return;
		}
	}
	
	unreachable();
}

//Will disconnect, but there might still be unhanded commands in the buffer these can be handled before calling destroy
@(require_results)
client_disconnect :: proc (client : ^Client) -> net.Shutdown_Error {
	
	switch &base in client.interface {
		case Client_tcp_base: {
			assert(base.did_open, "the client was never opened");
			
			base.should_close = true;
			
			err := net.shutdown(base.sock, .Send)  // disable send/recv
			net.close(base.sock)                             // free the socket

			return err;
		}
	}
	
	return nil;
}

@(private)
_client_destroy :: proc (client : rawptr) {
	client : ^Client = auto_cast client;
	
	//Join the recive thread
	thread.destroy(client.recive_thread); //also joins

	switch &base in client.interface {
		case Client_tcp_base: {
			assert(base.should_close == true, "recive thread should have been signaled to close");
			destroy_tcp_base(&base);
		}
	}
	
	delete(client.to_clean);
	delete_commands(&client.params);
	queue.destroy(&client.events);
	free(client);	
}
