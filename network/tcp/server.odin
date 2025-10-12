package furbs_network_tcp_interface

import "base:runtime"

import "core:net"
import "core:thread"
import "core:fmt"
import "core:log"

import network ".."

@(private="file")
Data :: struct {
	//Data required to connect
	target : net.Endpoint,
	use_binary : bool,

	//message conversion
	from_type : map[typeid]network.Message_id,
	to_type : map[network.Message_id]typeid,

	//Network side
	server : ^network.Server,
	interface_handle : network.Interface_handle,

	//TCP side
	acceptor_socket : net.TCP_Socket,
	acceptor_thread : ^thread.Thread,
	should_close : bool, 
}

//per connection data
@(private="file")
Data_client :: struct {
	name : net.Endpoint,
	socket : net.TCP_Socket,
	recive_thread : ^thread.Thread,
	should_close : bool, //stops the listening thread.
}

@(require_results)
server_interface :: proc "contextless" (commands_map : map[network.Message_id]typeid, endpoint : union{string, net.Host_Or_Endpoint}, use_binary := true, loc := #caller_location) -> (network.Server_interface) {
	assert_contextless(tcp_allocator != {}, "you must init the library first", loc);
	context = restore_context();

	on_send :: proc "contextless" (server : ^network.Server, client : ^network.Server_side_client, user_data : rawptr, client_user_data : rawptr, data : any) -> network.Error {
		user_data := cast(^Data)user_data;
		client_user_data := cast(^Data_client)client_user_data;
		context = restore_context();

		tcp_send(client_user_data.socket, user_data.from_type, data, user_data.use_binary);

		return .ok;
	}

	on_disconnect :: proc "contextless" (server : ^network.Server, client : ^network.Server_side_client, user_data : rawptr, client_user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		client_user_data := cast(^Data_client)client_user_data;
		context = restore_context();
		
		log.infof("closing socket server side");
		client_user_data.should_close = true;
		net.shutdown(client_user_data.socket, .Both);

		return .ok;
	}

	on_destroy_client :: proc "contextless" (server : ^network.Server, client : ^network.Server_side_client, user_data : rawptr, client_user_data : rawptr) {
		user_data := cast(^Data)user_data;
		client_user_data := cast(^Data_client)client_user_data;
		context = restore_context();

		thread.destroy(client_user_data.recive_thread);
		free(client_user_data);
	}

	on_close :: proc "contextless" (server : ^network.Server, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		server.should_close = true;

		context = restore_context();
		net.close(user_data.acceptor_socket);
		thread.destroy(user_data.acceptor_thread); //also joins

		return nil
	}

	on_destroy :: proc "contextless" (server : ^network.Server, user_data : rawptr) {
		user_data := cast(^Data)user_data;
		context = restore_context();

		delete(user_data.from_type);
		delete(user_data.to_type);

		free(user_data);
	}

	ep : net.Endpoint;
	err : net.Network_Error;

	switch endpoint in endpoint {
		case string: {
			ep, err = net.resolve_ip4(endpoint);
			if err != nil {
				ep, err = net.resolve_ip6(endpoint);
			}
		}
		case net.Host_Or_Endpoint: {
			switch endpoint in endpoint {
				case net.Host: {
					endpoint := fmt.tprintf("%v:%v", endpoint.hostname, endpoint.port);
					ep, err = net.resolve_ip4(endpoint);
					if err != nil {
						ep, err = net.resolve_ip6(endpoint);
					}
				}
				case net.Endpoint:{
					ep = endpoint;
				}
			}
		}
	}
	
	if err != nil {
		log.errorf("Could not resolve %v, got error: %v", endpoint, err);
		//because we dont bind yet, we cannot yet throw the error, happens later.
	}
	else {
		log.infof("resolved host ip to %v", ep);
	}

	rm := reverse_map(commands_map);

	data := new(Data);
	data^ = {
		ep,
		use_binary,

		//message conversion
		rm,
		reverse_map(rm),

		//Network side
		nil, //server : ^network.Server,
		-1, //interface_handle : network.Interface_handle,

		//TCP side
		{}, //acceptor_socket : net.TCP_Socket,
		nil, //acceptor_thread : ^thread.Thread,
		false, //should_close : bool, 
	}

	interface : network.Server_interface = {
		data,

		on_listen, //listen data is given by the user who starts it.
		on_send,
		on_disconnect, //disconnect the client forcefully (cannot fail)
		on_destroy_client,
		on_close, //Must stop accecpting and close all connections
		on_destroy, //removes the interface, the interface must free all its internal data.
	}
	
	return interface;
}

@(private="file")
destroy_client_user_data :: proc (client_user_data : ^Data_client) {

	free(client_user_data);
}

@(private="file")
on_listen :: proc "contextless" (server : ^network.Server, interface_handle : network.Interface_handle, user_data : rawptr) -> network.Error {
	user_data := cast(^Data)user_data;
	context = restore_context();

	user_data.interface_handle = interface_handle;

	if user_data.target == {} {
		panic("Endpoint is not setup");
	}
	
	err : net.Network_Error;
	user_data.acceptor_socket, err = net.listen_tcp(user_data.target);
	
	if err != nil {
		log.errorf("Failed setup_acceptor, error : %v", err);
		return .already_open;
	}
	
	log.infof("Succesfully setup acceptor"); 

	//This loops while the client is connected
	//A thread per client for listening, this could be done better, but it is OS dependent, for future work.
	//TODO overlapping IO
	server_side_client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		context = restore_context();

		server := cast(^network.Server)t.user_args[0];
		client := cast(^network.Server_side_client)t.user_args[1];
		user_data := cast(^Data)t.user_args[2];
		client_user_data := cast(^Data_client)t.user_args[3];
		
		recv_tcp_parse_loop(C{server, client}, client_user_data.socket, user_data.to_type, &user_data.should_close, user_data.use_binary);
		
		net.close(client_user_data.socket);
		log.debugf("disconnected tcp socket %v server side", client_user_data.name);
		network.push_disconnect_server(server, client);
	}
	
	//This loops forever in another thread.
	acceptor_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
		context = restore_context();
		
		server := cast(^network.Server) t.user_args[0];
		user_data := cast(^Data) t.user_args[1];

		///////////////////////////////////////////////////////

		log.debugf("Thread acceptor running");
		
		for !server.should_close {
			
			client_user_data := new(Data_client);
			
			err : net.Network_Error;
			
			//blocks until a client has connected
			client_user_data.socket, client_user_data.name, err = net.accept_tcp(user_data.acceptor_socket);

			if err != nil {
				if !server.should_close || err != net.Accept_Error.Interrupted {
					log.errorf("Failed accept_tcp, err : %v", err);
				}
				
				free(client_user_data);
				continue;
			}
			
			/////////// get an index for the client ///////////
			log.infof("A new client connected, serving on : %v", client_user_data.name);
			
			/////////// setup client thread ///////////
			assert(net.set_blocking(client_user_data.socket, true) == nil); //We want it to be blocking, since we have 1 thread per client.
			//assert(net.set_option(base.sock, .Keep_Alive, true) == nil);
			//TODO a timeout is needed (and maybe keep alive settings?)
			
			ssc := network.push_connect_server(server, user_data.interface_handle, client_user_data);

			client_user_data.recive_thread = thread.create(server_side_client_recive_loop);
			client_user_data.recive_thread.user_args[0] = server
			client_user_data.recive_thread.user_args[1] = ssc
			client_user_data.recive_thread.user_args[2] = user_data
			client_user_data.recive_thread.user_args[3] = client_user_data
			
			//start the client thread
			log.debugf("starting server side client recive thread");
			thread.start(client_user_data.recive_thread);

			free_all(context.temp_allocator);
		}
		
		log.debugf("Thread acceptor stopped and closed");
		
		free_all(context.temp_allocator);
	}

	///////////////////////////////
	
	user_data.acceptor_thread = thread.create(acceptor_loop);
	user_data.acceptor_thread.user_args[0] = server;
	user_data.acceptor_thread.user_args[1] = user_data;
	
	log.infof("Starting thread acceptor");
	thread.start(user_data.acceptor_thread);

	return .ok;
}

