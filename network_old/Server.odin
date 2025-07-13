package network

import "base:builtin"

import "core:fmt"
import "core:net"
import "core:time"
import "core:mem"

import "core:container/queue"

import "../utils"
import thread "../utils" //TODO

import "../tracy"

Server_side_client :: struct {
    
    //Data
    user_data : any,                         //use the data from current_bytes_recv to fill this

    //Contains most needed data
    using _ : Client_base,

    //Network
    endpoint : net.Endpoint,

    //ID
    client_id : client_id_type
}

Server :: struct {
    
    //TCP stuff
    endpoint : net.Endpoint,
    acceptor_socket : net.TCP_Socket,
    
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
 
    params : Network_params,
}

@(private)
Server_and_client :: struct {
	c : ^Server_side_client,
	s : ^Server,
}

/////////////////////////////////////////////////////////////////////////////////////

Endpoint :: net.Endpoint;
IP4_Address :: net.IP4_Address;
IP6_Address :: net.IP6_Address;

create_server :: proc(params : Network_params, endpoint : net.Endpoint, loc := #caller_location) -> (server : ^Server) {
    tracy.Zone();

    assert(params.is_init, "network must be initialized before calling server_main", loc);

    server = new(Server);
    server^ = Server{
        endpoint = endpoint,
        params = params,
    }

	queue.init(&server.dead_clients);
	queue.init(&server.clients_to_clean);
	queue.init(&server.new_clients);
    
    start_accepting(server, loc);
    
    return server;
}

//Start reciving clients
start_accepting :: proc (using server : ^Server, loc := #caller_location) {
	tracy.Zone();

    assert(params.is_init, "Network must be initialized before calling start_accepting", loc);
    
    if endpoint.port == 0 {
        panic("Endpoint is not setup");
    }

    err : net.Network_Error;
    acceptor_socket, err = net.listen_tcp(endpoint);
    
    if err != nil {
        panic("Failed setup_acceptor");
    }

    fmt.printf("Succesfully setup acceptor\n"); 

    //This loops while the client is connected
    server_side_client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
        tracy.Zone();
		tracy.SetThreadName("Server side client recive thread");

		sac := cast(^Server_and_client)t.data;
		defer free(sac);

		client : ^Server_side_client = sac.c;
        server : ^Server = sac.s;
        assert(client.client_id == t.user_index);

        fmt.printf("Starting client_loop %v\n", t.user_index);
        fmt.printf("Listing for client data with client index %v\n", t.user_index);

        recv_parse_loop(client, server.params);

		lock(&server.clean_mutex);
		queue.append(&server.clients_to_clean, utils.Pair(int, ^Server_side_client){t.user_index, client});
		unlock(&server.clean_mutex);
    }
    
    //This loops forever in another thread.
    acceptor_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		tracy.Zone();
		tracy.SetThreadName("Acceptor thread");

       	server : ^Server = cast(^Server)t.data;
        using server;

		///////////////////////////////////////////////////////

        fmt.printf("Thread acceptor running\n");

        is_open = true;

        for !should_close {
			tracy.ZoneN("Waiting to accept");
            new_client : ^Server_side_client = new(Server_side_client);

            err : net.Network_Error;
            //blocks until a client has connected
            new_client.socket, new_client.endpoint, err = net.accept_tcp(acceptor_socket);
			tracy.Message("Recived new client");

            if err == net.Accept_Error.Not_Socket && should_close {
				free(new_client);
                continue
            }
            else if err != nil {
                fmt.printf("Failed accept_tcp, err : %v\n", err);
				free(new_client);
                continue;
            }

            /////////// get an index for the client ///////////
            lock(&clients_mutex);
            //fmt.printf("acceptor_loop locked clients_mutex %v\n", clients_mutex);
            client_index := current_client_index;
            current_client_index += 1;
            
            /////////// setup client thread ///////////
            assert(net.set_blocking(new_client.socket, true) == nil); //We want it to be blocking, since we have 1 thread per client.
            //TODO a timeout is needed (and maybe keep alive settings?)
			
			sac := new(Server_and_client);
           	sac.c = new_client;
			sac.s = server;

            new_client.recive_thread = thread.create(server_side_client_recive_loop, sac, client_index);
            new_client.client_id = client_index;

            queue.init(&new_client.current_bytes_recv);
            queue.init(&new_client.recv_commands);
            new_client.allowed_commands = make(typeid_set);
            for k, v in params.initial_allowed_commands {
                new_client.allowed_commands[k] = v;
            }
            
            /////////// add the clients ///////////
            clients[client_index] = new_client;
			queue.append(&new_clients, new_client.client_id);
            ///////////////////////////////////////

            //start the client thread
            unlock(&clients_mutex);
            fmt.printf("acceptor_loop unlocked clients_mutex %v\n", clients_mutex);

            thread.start(new_client.recive_thread); 

			free_all(context.temp_allocator);
        }

		net.close(acceptor_socket);
		free_all(context.temp_allocator);
    }

    ///////////////////////////////

    acceptor_thread = thread.create(acceptor_loop, server);
    
    //fmt.printf("Starting thread acceptor\n");
    thread.start(acceptor_thread);

	free_all(context.temp_allocator);
}

_clean_clients :: proc(using server : ^Server, loc := #caller_location) {

	lock(&server.clean_mutex);
    for queue.len(server.clients_to_clean) != 0 {
        c := queue.pop_front(&server.clients_to_clean);
        
		params.custem_user_data_cleanup_func(c.b.user_data);
		free(c.b, loc = loc); 

		queue.append(&dead_clients, c.a);
    }
    unlock(&server.clean_mutex);
}

update_server :: proc(using server : ^Server){
	tracy.Zone();

    //Try and lock the server mutex, and if yes then clean up.
    //TODO clean up
    //destroy thread
    //destroy mutex
    //free(c);
    
    _clean_clients(server);
}

//TODO return dead clients???
close_server :: proc(using server : ^Server) {
    tracy.Zone();

	fmt.printf("close_server called\n");

   // fmt.printf("waiting for server to open\n");
    should_close = true;
    for !is_open { fmt.printf("server is not open, so we wait before we can close it."); time.sleep(time.Millisecond) }
    is_open = false;
    //fmt.printf("Server is open, and we can now close it\n");

    //Stop accepting clients
    lock(&clients_mutex);
   	//fmt.printf("close_server locked clients_mutex %v\n", clients_mutex);
    net.close(server.acceptor_socket);
    unlock(&clients_mutex);
    //fmt.printf("close_server unlocked clients_mutex %v\n", clients_mutex);
    
    thread.destroy(acceptor_thread);
	free(acceptor_thread);
    
    lock(&clients_mutex);
    //fmt.printf("close_server 2 locked clients_mutex %v\n", clients_mutex);
    //Disconnect all clients
    for i, c in &clients {
        remove_client(server, i);
    }

    delete(clients);
	queue.destroy(&new_clients);
    unlock(&clients_mutex);
    //fmt.printf("close_server 2 unlocked clients_mutex %v\n", clients_mutex);

	_clean_clients(server);
	queue.destroy(&clients_to_clean);

	//TODO we want to handle the dead clients here???

	queue.destroy(&dead_clients);

    fmt.printf("All clients disconnected\n");
}

send_broadcast :: proc (server : ^Server, data : any, loc := #caller_location) {
	tracy.Zone();
    for _, client  in server.clients {
        send_message(client.socket, server.params, data, loc);
    }
}

//both Server and client shall be locked when calling this.
remove_client :: proc(server : ^Server, client : int) {
	tracy.Zone();

    disconnect_client_server_size(server, client);

    assert(client in server.clients);

    delete_key(&server.clients, client);
}

//both Server and client shall be locked when calling this.
disconnect_client_server_size :: proc (using server : ^Server, client_id : client_id_type, loc := #caller_location) {
    tracy.Zone();

    c, f := server.clients[client_id];
    
    //fmt.printf("waiting for client to open : %v\n", i);
    c.should_close = true;
    for !c.is_open {}
    c.is_open = false;
    //fmt.printf("client is open, and we can now close it : %v\n", i);
    
    fmt.printf("disconnecting index %v at endpoint %v\n", client_id, c.endpoint);
    net.close(c.socket);

    thread.destroy(c.recive_thread, loc);
	free(c.recive_thread);

    fmt.printf("Terminated client with index %v\n", client_id);
}
