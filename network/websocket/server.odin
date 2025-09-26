package furbs_network_websocket_interface;

import "core:container/queue"
import "core:net"
import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"
import "core:reflect"
import "core:log"
import "core:mem"
import "core:sync"
import "core:thread"

import lws "../../libwebsockets"
import "../../libws"
import "../../serialize"

import network ".."

@(private="file")
context_to_data : map[libws.Ws]^Data;

@(private="file")
Data :: struct {
	//Data required to connect
	iface : cstring,
	port : c.int,
	send_binary : bool,
	
	//message conversion
	from_type : map[typeid]network.Message_id,
	to_type : map[network.Message_id]typeid,
	
	//Network side
	server : ^network.Server,
	interface_handle : network.Interface_handle,

	client_map : map[libws.Ws_client]struct{client : ^network.Server_side_client, in_message_buffer : [dynamic]u8, outgoing : [dynamic][]u8},
	
	//Libws side
	ctx : lws.Context,
	socket : libws.Ws,

	//Threading
	service_thread : ^thread.Thread,
	mutex : sync.Mutex,
	should_run : bool,
}

// example client_interface("localhost", 80, "/websocket/1234")¨
//iface = nil means listen on everything, localhost can be "localhost" or "127.0.0.1"
@(require_results)
server_interface :: proc (commands : map[u32]typeid, iface : string, #any_int port : c.int, default_binary := true, loc := #caller_location) -> network.Server_interface {
	assert_contextless(websocket_allocator != {}, "you must init the library first");
	context = restore_context();
	
	callback : libws.Callback : proc "c" (client: libws.Ws_client, event: libws.Event, _user_data : rawptr) -> c.int {
		context = restore_context();
		_user_data : ^^Data = cast(^^Data)_user_data;
		
		if _user_data^ == nil {
			ws := libws.get_websocket(client);
			assert(ws in context_to_data);
			_user_data^ = context_to_data[ws];

			log.debugf("websocket server init user_data");

			delete_key(&context_to_data, ws);
			if len(context_to_data) == 0 {
				delete(context_to_data);
			}
		}
		
		user_data : ^Data = _user_data^;
		
		assert(user_data != nil, "user_data is nil");

		switch event {
			case .LIBWS_EVENT_CONNECTED: {
				//create a new client on the server
				log.debugf("websocket pushing connection on interface id : %v", user_data.interface_handle);
				new_client := network.push_connect_server(user_data.server, user_data.interface_handle, user_data);
				user_data.client_map[client] = {new_client, make([dynamic]u8), make([dynamic][]u8)};
			}
			case .LIBWS_EVENT_CONNECTION_ERROR: {
				assert(client in user_data.client_map, "not a valid client");
				network.push_error_server(user_data.server, user_data.client_map[client].client, .network_error);
			}
			case .LIBWS_EVENT_SENT: {
				//Do we need to do anything?
			}
			case .LIBWS_EVENT_RECEIVED: {
				k, v, ji, e := map_entry(&user_data.client_map, client);
				assert(ji == false);
				done, value, free_proc, backing_data, was_binary, error := recive_fragment(user_data.from_type, user_data.to_type, client, &v.in_message_buffer);
				if done {
					if error != nil {
						network.push_error_server(user_data.server, v.client, error);
					}
					else {
						user_data.send_binary = was_binary; //resond to the client the same protocol as the the client asked, json vs binary
						network.push_msg_server(user_data.server, v.client, value, free_proc, backing_data);
					}
				}
			}
			case .LIBWS_EVENT_CLOSED: {
				assert(client in user_data.client_map, "not a valid client");
				k, v, ji, e := map_entry(&user_data.client_map, client);
				assert(ji == false);
				network.push_disconnect_server(user_data.server, v.client);
			}
		}

		return 0;
	}

	on_listen :: proc (server : ^network.Server, interface_handle : network.Interface_handle, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();
		sync.guard(&user_data.mutex);

		user_data.server = server;
		log.debugf("websocket got interface id : %v", interface_handle);
		user_data.interface_handle = interface_handle;

		service_proc :: proc (t : ^thread.Thread) {
			user_data := cast(^Data)t.user_args[0];
			
			protocols := [?]lws.Protocols {
				lws.Protocols{
					name                  = "websocket",
					callback              = nil,
					per_session_data_size = 0,
					rx_buffer_size        = 128,
				},
				lws.Protocols{}, // terminator
			}

			ctx_info : lws.Context_creation_info = {
				port = user_data.port,
				iface = user_data.iface,
				protocols = raw_data(protocols[:]),
			}

			user_data.ctx = lws.create_context(&ctx_info);

			listion_options := libws.Listen_options {
				user_data.ctx,
				user_data.port,
				callback,         					// int (*)(ws_client*, ws_event, void*)
				size_of(^Data), 					//per_client_data_size = size_of(Data),
			}
			
			user_data.socket = libws.listen(&listion_options);
			
			log.debugf("adding server ctx : %v", user_data.socket);
			context_to_data[user_data.socket] = user_data;

			for user_data.should_run {
				res := lws.service(user_data.ctx, 0);
				fmt.assertf(res == 0, "failed to service, code was : %v", res);
				
				sync.lock(&user_data.mutex);
				for ws_client, &con in user_data.client_map {
					for msg in con.outgoing {
						assert(user_data.socket != nil, "ws_client not ready");
						libws.send(ws_client, raw_data(msg), len(msg));
						delete(msg);
					}
					clear(&con.outgoing)
				}
				sync.unlock(&user_data.mutex);
			}

			//shutdown (just close)
			log.errorf("TODO shutdown");
			//libws.delete(user_data.socket);
		}

		service_thread := thread.create(service_proc);
		service_thread.user_args[0] = user_data;
		
		user_data.service_thread = service_thread;
		
		thread.start(service_thread);

		return .ok;
	}

	on_send :: proc (server : ^network.Server, user_data : rawptr, ws_client : rawptr, data : any) -> network.Error {
		user_data := cast(^Data)user_data;
		ws_client := cast(libws.Ws_client)ws_client;
		context = restore_context();
		sync.guard(&user_data.mutex);

		arr, err := network.any_to_array(user_data.from_type, data);

		if err != nil {
			return .serialize_error;
		}

		k, v, ji, _ := map_entry(&user_data.client_map, ws_client);
		append(&v.outgoing, arr); //this takes ownership, do not delete

		return .ok;
	}

	on_disconnect :: proc (server : ^network.Server, user_data : rawptr, ws_client : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		ws_client := cast(libws.Ws_client)ws_client;
		context = restore_context();
		sync.guard(&user_data.mutex);

		libws.delete(libws.get_websocket(ws_client));

		return .ok;
	}

	on_close :: proc (server : ^network.Server, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();
		sync.guard(&user_data.mutex);

		user_data.should_run = false;
		
		return .ok;
	}

	on_destroy :: proc (server : ^network.Server, user_data : rawptr) {
		user_data := cast(^Data)user_data;
		context = restore_context();
		sync.guard(&user_data.mutex);
		//TODO
	}
	
	iface := strings.clone_to_cstring(iface, context.temp_allocator);
	
	data := new(Data);
	data^ = {
		iface,
		port,
		default_binary,
		
		//message conversion
		reverse_map(commands),
		reverse_map(reverse_map(commands)),
		
		//Network side
		nil,
		-1,

		make(map[libws.Ws_client]struct{client : ^network.Server_side_client, in_message_buffer : [dynamic]u8, outgoing : [dynamic][]u8}),

		//Libws side
		nil,
		nil,
		//nil,
		//make([dynamic][]u8),

		//Threading
		nil,
		{},
		true,
	}

	return network.Server_interface {
		data,

		on_listen, //listen data is given by the user who starts it.
		on_send,
		on_disconnect, //disconnect the client forcefully (cannot fail)
		on_close, //Must stop accecpting and close all connections
		on_destroy, //removes the interface, the interface must free all its internal data.
	}
}


