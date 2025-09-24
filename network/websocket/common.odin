package furbs_network_websocket_interface;

import "core:net"
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



@(private, require_results)
recive_fragment :: proc (from_type : map[typeid]network.Message_id, to_type : map[network.Message_id]typeid, lws_client : libwebsockets.Lws_client, message_buffer : ^[dynamic]u8) -> (done : bool, value : any, free_proc : proc (any, rawptr), backing_data : rawptr, error : network.Error) {

	wsi := libws.get_websocket(lws_client);

	if libwebsockets.is_first_fragment(wsi) {
		clear(message_buffer);
	}
	
	length := libwebsockets.remaining_packet_payload(wsi);
	pre_msg_length := len(message_buffer);
	resize(message_buffer, pre_msg_length + auto_cast length);
	read_bytes := libws.receive(lws_client, raw_data(message_buffer[pre_msg_length:]), length);
	assert(read_bytes == length, "something went wrong, length of recived and payload does not match");
	
	if libwebsockets.is_final_fragment(wsi) {

		is_binary : bool = auto_cast libwebsockets.frame_is_binary(wsi);

		if is_binary {
			valid, _, value, free_proc, backing_data := network.array_to_any(to_type, message_buffer[:]);
			
			if valid {
				return true, value, free_proc, backing_data, nil;
			}
			else {
				return true, nil, nil, nil, .corrupted_stream;
			}
		}
		else {
			//text read as json
			str_data := string(message_buffer[:]);
			first_bracket := -1;
			for c in str_data {
				if c == '{' {
					break;
				}
			}
			
			cmd, ok := strconv.parse_u64(str_data[:first_bracket]);
			if !ok {
				return true, nil, nil, nil, .data_error;
			}

			command_id : network.Message_id = auto_cast cmd;
			
			if !(command_id in to_type) {
				return true, nil, nil, nil, .data_error;
			}
			
			if first_bracket != -1 {
				
				arena_alloc := new(vmem.Arena);
				aerr := vmem.arena_init_growing(arena_alloc);
				assert(aerr == nil);

				context.allocator = vmem.arena_allocator(arena_alloc);
				
				type := to_type[command_id];

				//we must allocate the any
				v_data, a_err := mem.alloc(reflect.size_of_typeid(type));
				assert(a_err == nil, "failed to allocate");
				value : any = transmute(any)runtime.Raw_Any{v_data, type};

				json.unmarshal_any(message_buffer[first_bracket:], value);

				free_proc :: proc (value : any, data : rawptr) {
					data := cast(^vmem.Arena)data;
					vmem.arena_destroy(data);
					free(data);
				}

				return true, value, free_proc, arena_alloc, nil;
			}
			else {
				return true, nil, nil, nil, .corrupted_stream;
			}
		}
	}

	return false, nil, nil, nil, nil;
}