package furbs_network

import "core:net"
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
	
	id : client_id_type,

	interface : union {
		Client_tcp_base,
	},
	
	//For TCP client
	endpoint : net.Endpoint,

	//user_data : rawprt, //TODO should we?

	client_id : client_id_type,
	recive_thread : ^thread.Thread,
}

/*
	Ok, new plan, dont do commands only, do events, so when a connections is made an onconnect event is sendt, or when disconnected a disconnect event is placed.
	This way there is no need for dead clients and it is the user which must call server_remove_client (or maybe we can infer this???)
	This means that there is not race condition on when the client disconnect and when the commands are handled, because they are handled as a part of the events.
	We must give a garentie that the disconnect event is the last event and that no events nor messages come after that.
*/

//All members are private
Server :: struct {

	events       	: queue.Queue(Event),     //This should be handle in the main thread
	to_clean 		: [dynamic]Event,
	
	//TCP stuff
	endpoint : net.Endpoint,
	
	accpector_interface : union {
		net.TCP_Socket,
	},
	
	//clients
	clients : map[int]^Server_side_client,
	current_client_index : client_id_type,              //increases whenever a new client connects.
	
	//threading stuff
	is_open : bool,
	should_close : bool,
	acceptor_thread : ^thread.Thread,
	
	params : Network_commands,
	
	mutex 	: sync.Mutex,
	handeling_events : bool,
}

@(require_results)
server_create :: proc(commands_map : map[Message_id_type]typeid, endpoint : Endpoint, loc := #caller_location) -> (server : ^Server) {
	
	server = new(Server);
	server^ = Server{
		endpoint = endpoint,
		params = make_commands(commands_map),
	}
	
	queue.init(&server.events);
	server.to_clean = make([dynamic]Event)

	return server;
}

//Start reciving clients
server_start_accepting :: proc (server : ^Server, thread_logger : Maybe(log.Logger) = nil, thread_allocator : Maybe(mem.Allocator) = nil, loc := #caller_location) {

	Server_and_client :: struct {
		c : ^Server_side_client,
		s : ^Server,
		logger : Maybe(log.Logger),
		allocator : Maybe(mem.Allocator),
	}

	Server_logger_allocator :: struct {
		server : ^Server,
		logger : Maybe(log.Logger),
		allocator : Maybe(mem.Allocator),
	}

	if server.endpoint.port == 0 {
		panic("Endpoint is not setup");
	}

	if true { //TODO make multiple interfaces
		err : net.Network_Error;
		server.accpector_interface, err = net.listen_tcp(server.endpoint);
		
		if err != nil {
			panic("Failed setup_acceptor");
		}
	}
	
	log.infof("Succesfully setup acceptor"); 

	//This loops while the client is connected
	server_side_client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		
		sac := cast(^Server_and_client)t.data;
		
		this_logger := context.logger;
		this_allocator := context.allocator;

		if l, ok := sac.logger.?; ok {
			this_logger = l;
		}

		if a, ok := sac.allocator.?; ok {
			this_allocator = a;
		}

		context.logger = this_logger;
		context.allocator = this_allocator;
		
		client : ^Server_side_client = sac.c;
		server : ^Server = sac.s;
		assert(client.client_id == t.user_index);

		free(sac);

		switch &base in client.interface {
			case Client_tcp_base: {
				recv_tcp_parse_loop(&base, server.params);
			}
			case: {
				unreachable();
			}
		}

		log.debugf("disconnected socket server side");
	}
	
	//This loops forever in another thread.
	acceptor_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		
		sla : ^Server_logger_allocator = cast(^Server_logger_allocator)t.data;
		server : ^Server = sla.server;
		
		this_logger := context.logger;
		this_allocator := context.allocator;
		
		if l, ok := sla.logger.?; ok {
			this_logger = l;
		}
		
		if a, ok := sla.allocator.?; ok {
			this_allocator = a;
		}
		
		context.logger = this_logger;
		context.allocator = this_allocator;
		
		defer free(sla); //need later when creting clients

		log.debugf("server.should_close : %v", server.should_close);

		assert(server.should_close == false, "server has not opened but it should already close?")
		assert(server.is_open == false, "server already open")

		///////////////////////////////////////////////////////

		log.debugf("Thread acceptor running");
		
		server.is_open = true;
		
		for !server.should_close {
			new_client : ^Server_side_client = new(Server_side_client);
			
			switch accpector in server.accpector_interface {
				
				case net.TCP_Socket: {
					err : net.Network_Error;
					
					base := init_tcp_base(new_client);
					
					//blocks until a client has connected
					base.sock, new_client.endpoint, err = net.accept_tcp(accpector);
					base.events = &server.events;
					base.event_mutex = &server.mutex;

					if true && server.should_close { //something here instead of true
						free(new_client);
						continue
					}
					else if err != nil {
						log.errorf("Failed accept_tcp, err : %v", err);
						free(new_client);
						continue;
					}
					
					/////////// get an index for the client ///////////
					sync.lock(&server.mutex);
					client_index := server.current_client_index;
					server.current_client_index += 1;
					
					log.infof("A new client connected, serving with id : %v", client_index);
					
					/////////// setup client thread ///////////
					assert(net.set_blocking(base.sock, true) == nil); //We want it to be blocking, since we have 1 thread per client.
					//assert(net.set_option(base.sock, .Keep_Alive, true) == nil);
					//TODO a timeout is needed (and maybe keep alive settings?)
					
					sac := new(Server_and_client);
					sac.c = new_client;
					sac.s = server;
					sac.logger = sla.logger;
					sac.allocator = sla.allocator;
					
					new_client.recive_thread = thread.create(server_side_client_recive_loop);
					new_client.client_id = client_index;
					new_client.recive_thread.data = sac;
					new_client.recive_thread.user_index = client_index;
					new_client.interface = base;
					new_client.id = client_index;

					queue.init(&base.current_bytes_recv);
					base.events = &server.events;
					base.event_mutex = &server.mutex;
					
					/////////// add the clients ///////////
					server.clients[client_index] = new_client;
					queue.append(&server.events, Event{new_client, time.now(), Event_connected{}});
					
					///////////////////////////////////////
					
					//start the client thread
					sync.unlock(&server.mutex);
					
					log.debugf("starting server side client recive thread");
					thread.start(new_client.recive_thread);
				} 
			}

			free_all(context.temp_allocator);
		}
		
		switch accpector in server.accpector_interface {
			
			case net.TCP_Socket: {
				net.close(accpector);
			}
		}
		
		log.debugf("Thread acceptor stopped and closed");
		
		free_all(context.temp_allocator);
	}

	///////////////////////////////

	sla := new(Server_logger_allocator);
	sla^ = Server_logger_allocator {
		server,
		thread_logger,
		thread_allocator,
	}

	server.acceptor_thread = thread.create(acceptor_loop);
	server.acceptor_thread.data = sla;
	
	log.infof("Starting thread acceptor");
	thread.start(server.acceptor_thread);
}

//Stop accepecting and recving new clients and messages from clients (disconnects all clients), there might still be unhandeled messages, which can be handled before server_destroy.
@(require_results)
server_close :: proc(server : ^Server) -> Error{
	
	server_begin_handle_events(server);
	for id, c in server.clients {
		server_disconnect_client(server, id); //this will NOT join the client thread
	}
	server_end_handle_events(server);
	
	server.should_close = true;
	
	switch interface in server.accpector_interface {
		case net.TCP_Socket: {
			net.shutdown(interface, .Both);
			net.close(interface);
		}
	}

	thread.destroy(server.acceptor_thread); //also joins

	return nil
}

//Free allocations
server_destroy :: proc(server : ^Server) {

	switch acceptor in server.accpector_interface {
		case net.TCP_Socket: {
			//TODO
		}
	}
	
	queue.destroy(&server.events);
	clean_up_events(&server.to_clean, _server_destroy_client);
	delete(server.to_clean);

	assert(len(server.clients) == 0);
	delete(server.clients);

	delete_commands(&server.params);

	free(server);
}

server_begin_handle_events :: proc (server : ^Server, loc := #caller_location) {
	assert(server.handeling_events == false, "you must call server_end_handle_commands before calling server_begin_handle_commands twice", loc);
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

	clean_up_events(&server.to_clean, _server_destroy_client);
}

@(require_results)
server_send :: proc (server : ^Server, client : ^Server_side_client, value : any, loc := #caller_location) -> (err : Error) {
	
	switch base in client.interface {
		case Client_tcp_base: {
			return send_tcp_message_commands(base.sock, server.params, value, loc);
		}
		case: {
			unreachable()
		}
	}
	
	unreachable();
}

//send to all clients
send_broadcast :: proc (server : ^Server, value : any, loc := #caller_location) {
	for _, client  in server.clients {
		_ = server_send(server, client, value, loc);
	}
}

//Will disconnect and allow one to handle the remaining messages
server_disconnect_client :: proc (server : ^Server, client_id : client_id_type, loc := #caller_location) {
	
	assert(server.handeling_events == true, "you must call begin_handle_commands first", loc)
	fmt.assertf(client_id in server.clients, "Not a valid client id : %v", client_id, loc = loc);
	
	client := server.clients[client_id];
	
	switch &base in client.interface {
		case Client_tcp_base: {
			log.warn("closing socket server side");
			base.should_close = true;
			net.shutdown(base.sock, .Both);
			net.close(base.sock);
			log.error("shutting down the server side client");
		}
		case: {
			unreachable();
		}
	}
	
	delete_key(&server.clients, client_id);
}

@(private)
_server_destroy_client :: proc(client : rawptr) {
	client : ^Server_side_client = auto_cast client;
	
	thread.destroy(client.recive_thread); //also joins
	
	switch &base in client.interface {
		case Client_tcp_base: {
			destroy_tcp_base(&base);
		}
		case: {
			unreachable();
		}
	}

	free(client);
}
