package furbs_network

import "core:net"
import "core:container/queue"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:log"

import "../utils"

//All members are private
Client :: struct {
	
	//owned by this client 
    recv_commands       : queue.Queue(Command),     //This should be handle in the main thread
	recv_mutex 			: sync.Mutex,

	interface : union {
		Client_tcp_base,
	},

	params : Network_commands,

    //threading stuff used internally
	handeling_commands : bool,
    recive_thread : ^thread.Thread,
}

client_create :: proc (commands_map : map[Message_id_type]typeid) -> ^Client {

	client := new(Client)

	client^ = {
		interface = init_tcp_base(nil), //TODO, when supporting other this should be moved into connect as it is connect which determines the interface type
		params = make_commands(commands_map),
		handeling_commands = false,
		recive_thread = nil,
	}

	queue.init(&client.recv_commands);

	return client;
}

client_connect :: proc (client : ^Client, target : Host_or_endpoint) -> (err : Network_Error) {

	when ODIN_OS == .JS || ODIN_OS == .WASI {
		panic("When target is WASM or WASI you cannot connect via the odin interface, this must happen in the Javascript and then you can pass the data to the client by calling ");
	}

	client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		
		client : ^Client = cast(^Client)t.data;
		
		switch &base in client.interface { 
			case Client_tcp_base: {
				recv_tcp_parse_loop(&base, client.params);
			}
		}
	}

	/////////// setup recive thread ///////////
	switch &base in client.interface { 
		case Client_tcp_base: {
			
			sock, s_err := net.dial_tcp_from_host_or_endpoint(target);
			err = s_err;
			base.sock = sock;
			
			if err != nil {
				log.errorf("Failed to connect to server got error : %v", err);
				return err;
			}

			lock(client); //are these needed?... not really
			defer unlock(client);
			
			queue.clear(&base.current_bytes_recv);
			queue.clear(&client.recv_commands);

			assert(net.set_blocking(sock, false) == nil); //We want it to be blocking
			//TODO a timeout is needed (and maybe keep alive settings?)
			
			client.recive_thread = thread.create(client_recive_loop);
			client.recive_thread.data = client;
			
			thread.start(client.recive_thread);
		}
	}
	
	return nil;
}

//This will just ready the client to recive input by client_recived_data 
client_websocket :: proc (client : ^Client) {
	//TODO
}

client_recived_data :: proc (client : ^Client, data : []u8) {
	

}

//locks the mutex and return the current commands, the data must not be copied
client_begin_handle_commands :: proc (client : ^Client, loc := #caller_location) {
	assert(client.handeling_commands == false, "you must call end_handle_commands before calling begin_handle_commands twice", loc);

	lock(client);
	sync.lock(&client.recv_mutex);
	client.handeling_commands = true;
}

client_get_next_command :: proc (client : ^Client, loc := #caller_location) -> any {
	assert(client.handeling_commands == true, "you must call begin_handle_commands first", loc)

	switch &base in client.interface {
		case Client_tcp_base: {
			
			c := queue.pop_front(&client.recv_commands);
			
			append(&base.to_clean, c);
			return c;
		}
	}

	unreachable();
}

//Frees the mutex and frees the data (all the commands which you have just recived)
client_end_handle_commands :: proc (client : ^Client, loc := #caller_location) {
	assert(client.handeling_commands == true, "you must call begin_handle_commands first", loc)

	switch &base in client.interface {
		case Client_tcp_base: {
			for c in base.to_clean {
				mem.free_all(c.alloc);
				mem.dynamic_arena_destroy(c.arena_alloc);
			}

			clear(&base.to_clean);
		}
	}
	
	sync.unlock(&client.recv_mutex);
    unlock(client);
}

client_send :: proc (client : ^Client, value : any, loc := #caller_location) -> (err : Error) {

	switch base in client.interface {
		case Client_tcp_base: {
			return send_tcp_message_commands(base.sock, client.params, value, loc);
		}
	}
	
	unreachable();
}

//Will disconnect, but there might still be unhanded commands in the buffer these can be handled before calling destroy
client_disconnect :: proc (client : ^Client) -> net.Shutdown_Error {
	
	switch &base in client.interface {
		case Client_tcp_base: {
			assert(base.did_open, "the client was never opened");
			
			base.should_close = true;
			
			err := net.shutdown(base.sock, net.Shutdown_Manner.Both)  // disable send/recv
			net.close(base.sock)                             // free the socket

			return err;
		}
	}

	//Join the recive thread
	thread.join(client.recive_thread);

	return nil;
}

client_destroy :: proc (client : ^Client, loc := #caller_location) {
	//assert(client.is_connected == false, "disconnect first", loc);
	
	switch &base in client.interface {
		case Client_tcp_base: {
			assert(base.should_close == true, "recive thread should have been signaled to close");
			destroy_tcp_base(&base);
		}
	}

	delete_commands(&client.params);
	queue.destroy(&client.recv_commands);
}

@(private="file")
lock :: proc (client : ^Client) {
	switch &base in client.interface {
		case Client_tcp_base:
			sync.lock(&base.mutex);
	}
}

@(private="file")
unlock :: proc (client : ^Client) {
	switch &base in client.interface {
		case Client_tcp_base:
			sync.unlock(&base.mutex);
	}
}