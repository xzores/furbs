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
	//client : ^network.Client,

	//TCP side
	socket : net.TCP_Socket,
	recive_thread : ^thread.Thread,
	should_close : bool,
}

Ip_mode :: enum  {
	ipv4_only,
	ipv6_only,
	prefer_ipv4, //tries ipv4 and then ipv6
	prefer_ipv6, //tries ipv6 then ipv4
	//TODO maybe implement later: auto, //infer from endpoint, or try both and pick the fastest
}

//endpoint could be 1.2.3.4:9000 or localhost:2345 or www.google.com
@(require_results)
client_interface :: proc "contextless" (commands_map : map[network.Message_id]typeid, endpoint : union{string, net.Host_Or_Endpoint}, mode : Ip_mode, use_binary := true) -> network.Client_interface {
	assert_contextless(tcp_allocator != {}, "you must init the library first");
	context = restore_context();

	on_connect :: proc "contextless" (client : ^network.Client, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();

		sock, s_err := net.dial_tcp_from_host_or_endpoint(user_data.target);
		user_data.socket = sock;
		
		if s_err != nil {
			err : network.Error = .unknown;

			#partial switch v in s_err {
				case net.Create_Socket_Error:
					err = .unknown
				case net.Dial_Error:
					err = .refused
				case net.Bind_Error:
					err = .refused
				case net.Socket_Option_Error:
					err = .invalid_parameter
				case net.Parse_Endpoint_Error:
					err = .endpoint_error
				case net.Resolve_Error:
					err = .endpoint_error
				case net.DNS_Error:
					err = .dns_error
				case:
			}

			log.errorf("Failed to connect to server got error : %v", s_err);
			return err;
		}

		network.push_connect_client(client);
		log.infof("Client connected to server : %v", user_data.target);

		assert(net.set_blocking(sock, true) == nil); //We want it to be blocking
		//assert(net.set_option(base.sock, .Linger, time.Second) == nil);
		//assert(net.set_option(base.sock, .Keep_Alive, true) == nil);
		//TODO a timeout is needed (and maybe keep alive settings?)

		client_recive_loop : thread.Thread_Proc : proc(t : ^thread.Thread) {
			context = restore_context();

			client := cast(^network.Client) t.user_args[0]
			user_data := cast(^Data) t.user_args[1]

			log.debugf("begining client tcp parse loop")
			
			recv_tcp_parse_loop(client, user_data.socket, user_data.to_type, &user_data.should_close, user_data.use_binary);

			net.close(user_data.socket);
			log.debugf("disconnected tcp socket client side");
			network.push_disconnect_client(client);
		}

		user_data.recive_thread = thread.create(client_recive_loop);
		user_data.recive_thread.user_args[0] = client;
		user_data.recive_thread.user_args[1] = user_data;

		thread.start(user_data.recive_thread);

		return .ok;
	}

	on_send :: proc "contextless" (client : ^network.Client, user_data : rawptr, data : any) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();
		
		return tcp_send(user_data.socket, user_data.from_type, data, user_data.use_binary);
	}

	on_disconnect :: proc "contextless" (client : ^network.Client, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();

		user_data.should_close = true;
		
		err := net.shutdown(user_data.socket, .Send)  // disable send/recv

		if err != nil {
			return .network_error;
		}

		return nil;
	}

	on_destroy :: proc "contextless" (client : ^network.Client, user_data : rawptr) {
		user_data := cast(^Data)user_data;
		context = restore_context();

		delete(user_data.from_type);
		delete(user_data.to_type);

		thread.destroy(user_data.recive_thread);

		free(user_data);
	}

	ep : net.Endpoint;
	err : net.Network_Error = nil;

	resolve :: proc (endpoint : string, mode : Ip_mode) -> (ep : net.Endpoint, err : net.Network_Error){
		ep4, ep6, port := net.resolve(endpoint);
		ep = ep4;

		switch mode {
			case .ipv4_only:
				ep, err = net.resolve_ip4(endpoint);
			case .ipv6_only:
				ep, err = net.resolve_ip6(endpoint)
			case .prefer_ipv4:
				ep4, ep6, port := net.resolve(endpoint);
				ep = ep4;
				if ep4 == {} {
					ep = ep6;
				}
			case .prefer_ipv6:
				ep4, ep6, err := net.resolve(endpoint);
				ep = ep6;
				if ep6 == {} {
					ep = ep4;
				}
			
		}
		
		return;
	}

	switch endpoint in endpoint {
		case string: {
			ep, err = resolve(endpoint, mode);
		}
		case net.Host_Or_Endpoint: {
			switch endpoint in endpoint {
				case net.Host: {
					ep, err = resolve(fmt.tprintf("%v:%v", endpoint.hostname, endpoint.port), mode);
				}
				case net.Endpoint:{
					ep = endpoint;
				}
			}
		}
	}

	if err != nil {
		log.errorf("invalid endpoint %v, got err : %v", endpoint, err);
	}

	rm := reverse_map(commands_map);

	data := new(Data);
	data^ = {
		ep,
		use_binary,
		rm,
		reverse_map(rm), // a sneaky way to clone the map
		//nil, //client
		{}, //socket
		nil, //thread
		false, //should_close
	}

	interface : network.Client_interface = {
		data,

		on_connect,
		on_send,
		on_disconnect,
		on_destroy,
	}
	
	return interface;
}
