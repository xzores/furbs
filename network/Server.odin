package furbs_network

import "core:net"
import "core:container/queue"
import "core:thread"
import "core:sync"
import "core:mem"
import "core:log"

import "../utils"

//All members are private
Server_side_client :: struct {
    
	interface : union {
		Client_tcp_base,
	},
	
	//For TCP client
	endpoint : net.Endpoint,

	//user_data : rawprt, //TODO should we?

    client_id : client_id_type,
    recive_thread : ^thread.Thread,
}

//All members are private
Server :: struct {

    recv_commands       : queue.Queue(Command),     //This should be handle in the main thread
	recv_mutex 			: sync.Mutex,

    //TCP stuff
    endpoint : net.Endpoint,
    
	accpector_interface : union {
		net.TCP_Socket,
	},

	Make a function (user_space) which retrives "endpoint", "user_data", "client_id" and "is_dead"
	TODO make something which is sure that when a client is dead. The "is_dead" should be have a race condition.

    //clients
    clients : map[int]^Server_side_client,
    clients_mutex : utils.Mutex,
    current_client_index : client_id_type,              //increases whenever a new client connects.
	new_clients : queue.Queue(int),

    //Dead clients
	dead_clients : queue.Queue(int),
    clients_to_clean : queue.Queue(utils.Pair(int, ^Server_side_client)),    //TODO acctually clean them
    clean_mutex : utils.Mutex,

    //threading stuff
    is_open : bool,
    should_close : bool,
    acceptor_thread : ^thread.Thread,
 
    params : Network_commands,
}

server_create :: proc(commands_map : map[Message_id_type]typeid, endpoint : Endpoint, loc := #caller_location) -> (server : ^Server) {
	
    server = new(Server);
    server^ = Server{
        endpoint = endpoint,
        params = make_commands(commands_map),
    }
	
	queue.init(&server.dead_clients);
	queue.init(&server.clients_to_clean);
	queue.init(&server.new_clients);
	queue.init(&server.recv_commands);

	return server;
}

//Start reciving clients
server_start_accepting :: proc (server : ^Server, loc := #caller_location) {

	Server_and_client :: struct {
		c : ^Server_side_client,
		s : ^Server,
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
	
    log.debugf("Succesfully setup acceptor\n"); 

    //This loops while the client is connected
    server_side_client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {

		sac := cast(^Server_and_client)t.data;

		client : ^Server_side_client = sac.c;
        server : ^Server = sac.s;
        assert(client.client_id == t.user_index);

		free(sac);

        log.debugf("Starting client_loop %v\n", t.user_index);
        log.debugf("Listing for client data with client index %v\n", t.user_index);
		
		switch &base in client.interface {
			case Client_tcp_base:
 		       	recv_tcp_parse_loop(&base, server.params);
		}

		sync.lock(&server.clean_mutex);
		queue.append(&server.clients_to_clean, utils.Pair(int, ^Server_side_client){t.user_index, client});
		sync.unlock(&server.clean_mutex);
    }
    
    //This loops forever in another thread.
    acceptor_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {

       	server : ^Server = cast(^Server)t.data;

		///////////////////////////////////////////////////////

        log.debugf("Thread acceptor running\n");
		
        server.is_open = true;

        for !server.should_close {
            new_client : ^Server_side_client = new(Server_side_client);
			
			switch accpector in server.accpector_interface {
				
				case net.TCP_Socket: {
					err : net.Network_Error;
					
					base := init_tcp_base();
					
					//blocks until a client has connected
					base.sock, new_client.endpoint, err = net.accept_tcp(accpector);
					
					if true && server.should_close { //something here instead of true
						free(new_client);
						continue
					}
					else if err != nil {
						log.errorf("Failed accept_tcp, err : %v\n", err);
						free(new_client);
						continue;
					}
					
					/////////// get an index for the client ///////////
					sync.lock(&server.clients_mutex);
					//fmt.printf("acceptor_loop locked clients_mutex %v\n", clients_mutex);
					client_index := server.current_client_index;
					server.current_client_index += 1;
					
					/////////// setup client thread ///////////
					assert(net.set_blocking(base.sock, false) == nil); //We want it to be blocking, since we have 1 thread per client.
					//TODO a timeout is needed (and maybe keep alive settings?)
					
					sac := new(Server_and_client);
					sac.c = new_client;
					sac.s = server;
					
					new_client.recive_thread = thread.create(server_side_client_recive_loop);
					new_client.client_id = client_index;
					new_client.recive_thread.data = sac;
					new_client.recive_thread.user_index = client_index;
					
					queue.init(&base.current_bytes_recv);
					base.recv_commands = &server.recv_commands;
					base.recv_mutex = &server.recv_mutex;
					
					/////////// add the clients ///////////
					server.clients[client_index] = new_client;
					queue.append(&server.new_clients, new_client.client_id);

					///////////////////////////////////////
					
					//start the client thread
					sync.unlock(&server.clients_mutex);
					log.debugf("acceptor_loop unlocked clients_mutex %v\n", server.clients_mutex);
					
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

		free_all(context.temp_allocator);
    }

    ///////////////////////////////

    server.acceptor_thread = thread.create(acceptor_loop);
	server.acceptor_thread.data = server;
    
    log.debugf("Starting thread acceptor\n");
    thread.start(server.acceptor_thread);
}

//Stop accepecting and recving new clients and messages from clients (disconnects all clients), there might still be unhandeled messages, which can be handled before server_destroy.
server_close :: proc(using server : ^Server) {

}

//Free allocations
server_destroy :: proc(using server : ^Server) {

}

server_begin_handle_commands :: proc () {

}

server_get_next_command :: proc () {

}

server_end_handle_commands :: proc () {

}

server_send :: proc (server : ^Server, client : ^Server_side_client, value : any, loc := #caller_location) -> (err : Error) {
	
	switch base in client.interface {
		case Client_tcp_base: {
			return send_tcp_message_commands(base.sock, client.params, value, loc);
		}
	}
	
	unreachable();
}

//send to all clients
send_broadcast :: proc (server : ^Server, value : any, loc := #caller_location) {
	for _, client  in server.clients {
        server_send(server, client, value, loc);
    }
}

//Will disconnect and allow one to handle the remaining messages
server_disconnect_client :: proc (using server : ^Server, client : client_id_type, loc := #caller_location) {

}

//Removes the client permently, associeted resources are freed
//This also disconnects before removing
server_remove_client :: proc(server : ^Server, client : int) {

}
