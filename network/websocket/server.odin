package furbs_network_websocket_interface;

import "core:net"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:log"
import "core:mem"
import "core:thread"

import "libws"
import "libwebsockets"
import network ".."

import "../../serialize"

// example client_interface("localhost", 80, "/websocket/1234")¨
//iface = nil means listen on everything, localhost can be "localhost" or "127.0.0.1"
@(require_results)
server_interface :: proc (commands : map[u32]typeid, iface : string, port : c.int, send_binary := true, loc := #caller_location) -> network.Server_interface {
	assert_contextless(websocket_allocator != {}, "you must init the library first");
	context = restore_context();

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

		client_map : map[libws.Ws_client]struct{client : ^network.Server_side_client, message_buffer : [dynamic]u8},

		//Libws side
		ctx : libwebsockets.Lws_context,
		socket : libws.Ws,
	}
	
	callback : libws.Callback : proc "c" (client: libws.Ws_client, event: libws.Event, user_data : rawptr) -> c.int {
		user_data := cast(^Data)user_data;
		context = restore_context();

		switch event {
			case .LIBWS_EVENT_CONNECTED: {
				//create a new client on the server
				new_client := network.push_connect_server(user_data.server, user_data.interface_handle, user_data);
				user_data.client_map[client] = {new_client, make([dynamic]u8)};
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
				done, value, free_proc, backing_data, error := recive_fragment(user_data.from_type, user_data.to_type, client, &v.message_buffer);
				if done {
					if error != nil {
						network.push_error_server(user_data.server, v.client, error);
					}
					else {
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
		
		listion_options := libws.Listen_options {
			auto_cast user_data.ctx,
			user_data.port,
			callback,         	// int (*)(ws_client*, ws_event, void*)
			0, 					//per_client_data_size = size_of(Data),
		}

		user_data.socket = libws.listen(&listion_options);
		user_data.server = server;
		user_data.interface_handle = interface_handle;

		return .ok;
	}

	on_send :: proc (server : ^network.Server, user_data : rawptr, ws_client : rawptr, data : any) -> network.Error {
		user_data := cast(^Data)user_data;
		ws_client := cast(libws.Ws_client)ws_client;
		context = restore_context();

		arr, err := network.any_to_array(user_data.from_type, data);

		if err != nil {
			return .serialize_error;
		}
		
		assert(user_data.socket != nil, "ws_client not ready");
		libws.send(ws_client, raw_data(arr), len(arr));

		return .ok;
	}

	on_disconnect :: proc (server : ^network.Server, user_data : rawptr, ws_client : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		ws_client := cast(libws.Ws_client)ws_client;
		context = restore_context();

		libws.delete(libws.get_websocket(ws_client));

		return .ok;
	}

	on_close :: proc (server : ^network.Server, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		libws.delete(user_data.socket);
		context = restore_context();
		
		return .ok;
	}

	on_destroy :: proc (server : ^network.Server, user_data : rawptr) {
		context = restore_context();
		//TODO
	}

	iface := strings.clone_to_cstring(iface, context.temp_allocator);

	ctx_info := libwebsockets.lws_context_creation_info {
		0,															/* listen port, or CONTEXT_PORT_NO_LISTEN */
		iface,	/* NULL = any */
		nil,														/* your protocols array (NULL-terminated) */
		"default",													/* eg "default" */
		nil, 														/* ctx user pointer (optional) */
		0, 															/* 0 unless you need special flags */
		0, 0, 														/* 0 */
		0, 0, 0,													/* 0 (keepalive off) */
		/* leave all TLS / fileops / mounts / fops fields at 0 / NULL */
	}
	
	ctx : libwebsockets.Lws_context = libwebsockets.create_context(&ctx_info);

	data := new(Data);
	data^ = {
		iface,
		port,
		true,
		
		//message conversion
		reverse_map(commands),
		reverse_map(reverse_map(commands)),
		
		//Network side
		nil,
		-1,

		make(map[libws.Ws_client]struct{client : ^network.Server_side_client, message_buffer : [dynamic]u8}),

		//Libws side
		ctx,
		nil,
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
