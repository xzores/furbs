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

import "libws"
import "libwebsockets"
import network ".."

import "../../serialize"

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
				network.push_connect_client(user_data.client);
				user_data.ws_client = client;
			}
			case .LIBWS_EVENT_CONNECTION_ERROR: {
				network.push_error_client(user_data.client, .network_error);
			}
			case .LIBWS_EVENT_SENT: {
				//Do we need to do anything?
			}
			case .LIBWS_EVENT_RECEIVED: {

				wsi := libws.get_websocket(client);
				
				if libwebsockets.is_first_fragment(wsi) {
					clear(&user_data.message_buffer);
				}

				length := libwebsockets.remaining_packet_payload(wsi);
				pre_msg_length := len(user_data.message_buffer);
				resize(&user_data.message_buffer, pre_msg_length + auto_cast length);
				read_bytes := libws.receive(client, raw_data(user_data.message_buffer[pre_msg_length:]), length);
				assert(read_bytes == length, "something went wrong, length of recived and payload does not match");
				
				if libwebsockets.is_final_fragment(wsi) {

					is_binary : bool = auto_cast libwebsockets.frame_is_binary(wsi);

					if is_binary {
						valid, _, value, free_proc, backing_data := network.array_to_any(user_data.to_type, user_data.message_buffer[:]);
						
						if valid {
							network.push_msg_client(user_data.client, value, free_proc, backing_data);
						}
						else {
							network.push_error_client(user_data.client, .corrupted_stream);
						}
					}
					else {
						//text read as json
						str_data := string(user_data.message_buffer[:]);
						first_bracket := -1;
						for c in str_data {
							if c == '{' {
								break;
							}
						}
						
						cmd, ok := strconv.parse_u64(str_data[:first_bracket]);
						if !ok {
							network.push_error_client(user_data.client, .data_error);
						}

						command_id : network.Message_id = auto_cast cmd;
						
						if !(command_id in user_data.to_type) {
							network.push_error_client(user_data.client, .data_error);
						}
						
						if first_bracket != -1 {
							
							arena_alloc := new(vmem.Arena);
							aerr := vmem.arena_init_growing(arena_alloc);
							assert(aerr == nil);

							context.allocator = vmem.arena_allocator(arena_alloc);
							
							type := user_data.to_type[command_id];

							//we must allocate the any
							v_data, a_err := mem.alloc(reflect.size_of_typeid(type));
							assert(a_err == nil, "failed to allocate");
							value : any = transmute(any)runtime.Raw_Any{v_data, type};

							json.unmarshal_any(user_data.message_buffer[first_bracket:], value);

							free_proc :: proc (value : any, data : rawptr) {
								data := cast(^vmem.Arena)data;
								vmem.arena_destroy(data);
								free(data);
							}

							network.push_msg_client(user_data.client, value, free_proc, arena_alloc);
						}
						else {
							network.push_error_client(user_data.client, .corrupted_stream);
						}
					}
				}

			}
			case .LIBWS_EVENT_CLOSED: {
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
		0,								/* listen port, or CONTEXT_PORT_NO_LISTEN */
		nil,							/* NULL = any */
		nil,				/* your protocols array (NULL-terminated) */
		"default",						/* eg "default" */
		nil, 								/* ctx user pointer (optional) */
		0, 							/* 0 unless you need special flags */
		0, 0, 							/* 0 */
		0, 0, 0,	/* 0 (keepalive off) */
		/* leave all TLS / fileops / mounts / fops fields at 0 / NULL */
	}
	
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
