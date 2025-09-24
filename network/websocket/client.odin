package furbs_network_websocket_interface;

import "core:strconv"
import "core:reflect"
import "core:encoding/json"
import "base:runtime"
import "core:c"
import "core:strings"
import "core:log"
import "core:mem"
import "core:thread"
import vmem"core:mem/virtual"

import "../../libws"
import "../../libwebsockets"
import "../../serialize"
import network ".."

//Shallow copy
reverse_map :: proc (to_reverse : map[$A]$B) -> map[B]A {

	reversed := make(map[B]A);

	for k, v in to_reverse {
		reversed[v] = k
	}

	return reversed;
}

// example client_interface("localhost", 80, "/websocket/1234")
@(require_results)
client_interface :: proc (commands : map[u32]typeid, address : string, #any_int port : c.int, path : string, send_binary := true, loc := #caller_location) -> network.Client_interface {
	assert_contextless(websocket_allocator != {}, "you must init the library first", loc);
	context = restore_context();
	
	Data :: struct {
		//Data required to connect
		address : cstring,
		port : c.int,
		path : cstring,
		send_binary : bool,

		//message conversion
		from_type : map[typeid]network.Message_id,
		to_type : map[network.Message_id]typeid,

		//Network side
		client : ^network.Client,

		//Libws side
		ctx : libwebsockets.Lws_context,
		socket : libws.Ws,
		ws_client : libws.Ws_client,
		
		message_buffer : [dynamic]u8,
	}
	
	callback : libws.Callback : proc "c" (client: libws.Ws_client, event: libws.Event, user_data : rawptr) -> c.int {
		user_data := cast(^Data)user_data;
		context = restore_context();

		switch event {
			case .LIBWS_EVENT_CONNECTED: {
				log.debugf("Client recived connected event");
				network.push_connect_client(user_data.client);
				user_data.ws_client = client;
			}
			case .LIBWS_EVENT_CONNECTION_ERROR: {
				log.errorf("Client recived error event");
				network.push_error_client(user_data.client, .network_error);
			}
			case .LIBWS_EVENT_SENT: {
				//Do we need to do anything?
			}
			case .LIBWS_EVENT_RECEIVED: {
				done, value, free_proc, backing_data, was_binary, error := recive_fragment(user_data.from_type, user_data.to_type, client, &user_data.message_buffer);
				if done {
					if error != nil {
						network.push_error_client(user_data.client, error);
					}
					else {
						user_data.send_binary = was_binary; //resond to the client the same protocol as the the client asked, json vs binary
						network.push_msg_client(user_data.client, value, free_proc, backing_data);
					}
				}
			}
			case .LIBWS_EVENT_CLOSED: {
				log.debugf("Client recvied closed event");
				network.push_disconnect_client(user_data.client);
			}
		}

		return 0;
	}
	
	on_connect :: proc (client : ^network.Client, user_data : rawptr) -> (network.Error) {
		user_data := cast(^Data)user_data;
		context = restore_context();

		connect_options := libws.Connect_options{
			auto_cast user_data.ctx,
			user_data.address,
			user_data.port,
			user_data.path,
			callback,
			0, //per_client_data_size = size_of(Data),
		}

		user_data.client = client;
		user_data.socket = libws.connect(&connect_options);

		if user_data.socket == nil {
			return .invalid_parameter;
		}
		
		return .ok;
	}

	on_send :: proc (client : ^network.Client, user_data : rawptr, data : any) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();

		arr, err := network.any_to_array(user_data.from_type, data);

		if err != nil {
			return .serialize_error;
		}
		
		assert(user_data.ws_client != nil, "ws_client not ready");
		libws.send(user_data.ws_client, raw_data(arr), len(arr));

		return .ok;
	}

	on_disconnect :: proc (client : ^network.Client, user_data : rawptr) -> network.Error {
		user_data := cast(^Data)user_data;
		context = restore_context();

		libws.delete(user_data.socket);
		return .ok;
	}

	on_destroy :: proc (client : ^network.Client, user_data : rawptr) {
		context = restore_context();
		//todo clean up
	}

	ctx_info := libwebsockets.lws_context_creation_info {
		//I dont think we need to set anything here 
	};
	
	ctx : libwebsockets.Lws_context = libwebsockets.create_context(&ctx_info);

	data := new(Data);
	data^ = {
		strings.clone_to_cstring(address),
		port,
		strings.clone_to_cstring(path),
		send_binary,
		reverse_map(commands),
		reverse_map(reverse_map(commands)),
		nil,
		ctx,
		nil,
		nil,
		make([dynamic]u8),
	}

	return network.Client_interface {
		data,
		on_connect,
		on_send,
		on_disconnect,
		on_destroy,
	}
}
