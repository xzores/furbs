package furbs_network_tcp_interface

import "core:strconv"
import "core:debug/pe"
import "core:math"
import "base:runtime"

import "core:net"
import "core:time"
import "core:container/queue"
import "core:thread"
import "core:mem"
import vmem "core:mem/virtual"
import "core:fmt"
import "core:log"
import "core:reflect"
import "core:sync"
import "core:unicode/utf8"
import "core:encoding/json"
import "core:strings"
import "core:slice"

import "../../serialize"
import network ".."

//////////////////////////////////////////////////////////////////////
// 				This is only meant for internal use					//
//////////////////////////////////////////////////////////////////////

@private
json_spec :: json.Marshal_Options{.JSON5, false, false, 0, false, true, false, false, true, {}, {}, {}}

//////////////////////////////////// SEND ////////////////////////////////////

tcp_send :: proc (socket : net.TCP_Socket, from_type : map[typeid]network.Message_id, data : any, binary : bool) -> network.Error {
	assert(reflect.is_struct(type_info_of(data.id)), "the message must be a struct")

	arr : []u8;
	defer delete(arr);

	if binary {
		err : serialize.Serialization_error;
		arr, err = network.any_to_array(from_type, data);
		
		if err != nil {
			return .serialize_error;
		}
	}
	else {
		json_arr, json_err := json.marshal(data, json_spec);
		
		if json_err != nil {
			return .serialize_error;
		}

		b : strings.Builder;
		strings.builder_init(&b);

		ti := type_info_of(data.id);
		
		//we prefer to write the name, but if we can't we write the msg_id instead
		if named, ok := ti.variant.(runtime.Type_Info_Named); ok {
			strings.write_string(&b, named.name);
		}
		else {
			strings.write_i64(&b, cast(i64)from_type[data.id]);
		}
		
		strings.write_bytes(&b, json_arr);

		arr = b.buf[:]
	}
	
	log.debugf("sending json:\n%v", string(arr));
	bw, e := net.send_tcp(socket, arr);
	
	if e != nil {
		log.errorf("failed to send TCP message, got error : %v", e);
		return .network_error;
	}
	if bw != len(arr) {
		log.errorf("failed to send entire TCP message, tried to send %v, but only send : %v", len(arr), bw);
		return .corrupted_stream;
	}

	return .ok;
}



//////////////////////////////////// RECV ////////////////////////////////////

@(private)
C :: struct {
	server : ^network.Server,
	client : ^network.Server_side_client
}

@(private)
U :: union {
	^network.Client,
	C,
}

@(private)
recv_tcp_parse_loop :: proc (client : U, socket : net.TCP_Socket, to_type : map[network.Message_id]typeid, should_close : ^bool, parse_binary : bool, init_buffer_size := 1024 * 1024, loc := #caller_location) {
	assert(client != nil);
	new_data_buffer := make([]u8, init_buffer_size); //The max number of bytes that can be recived at a time (you can still recive messages larger then this)
	defer delete(new_data_buffer);

	current_bytes_recv : queue.Queue(u8);
	queue.init(&current_bytes_recv);
	defer queue.destroy(&current_bytes_recv);
	
	for !should_close^ {
		bytes_recv, err := net.recv(socket, new_data_buffer[:]);

		if bytes_recv == 0 {
			break;
		}
		if (err == net.TCP_Recv_Error.Connection_Closed || err == net.TCP_Recv_Error.Interrupted) && should_close^ {
			log.warnf("Breakout of recv : %v", loc);
			continue;
		}
		else if (err == net.TCP_Recv_Error.Connection_Closed || err == net.TCP_Recv_Error.Interrupted) {
			log.warnf("Warning : a connection was close without should_close being set true. Automagicly closing now\n Caller : %v", loc);
			should_close^ = true;
			continue;
		}
		else if err != nil {
			log.errorf("failed recv, err : %v called from : %v", err, loc);
			switch c in client {
				case ^network.Client:
					network.push_error_client(c, .network_error);
				case C:
					network.push_error_server(c.server, c.client, .network_error);
			}
			break;
		}
		
		queue.append_elems(&current_bytes_recv, ..new_data_buffer[:bytes_recv]);
		
		status, value, free_func, data := parse_message(&current_bytes_recv, to_type, parse_binary, loc);
		for status == .finished {
			switch c in client {
				case ^network.Client: {
					assert(c != nil, "you passed a nil client", loc);
					network.push_msg_client(c, value, free_func, data);
				}
				case C: {
					network.push_msg_server(c.server, c.client, value, free_func, data);
				}
			}

			//maybe there are more messages:
			status, value, free_func, data = parse_message(&current_bytes_recv, to_type, parse_binary, loc);
			//log.debugf("status is finished there might be more messages");
		}; //Parses all messages, if one finishes then do the next...

		if status == .failed {
			panic("TODO corrupt message disconnect client");
		}
		
		free_all(context.temp_allocator);
	}
	
	free_all(context.temp_allocator);
}

//returns true if it did parse something
@(private, require_results)
parse_message :: proc (current_bytes_recv : ^queue.Queue(u8), to_type : map[network.Message_id]typeid, parse_binary : bool, loc := #caller_location) -> (status : network.Msg_pass_result, value : any, free_func : proc (any, rawptr), data : rawptr) {

	free_func = proc (v : any, data : rawptr) {
		data := cast(^vmem.Arena)data;
		context = restore_context()
		
		vmem.arena_destroy(data);
		free(data);
	}

	message_data := current_bytes_recv.data[current_bytes_recv.offset:current_bytes_recv.offset + current_bytes_recv.len]

	if parse_binary {
		
		//We want enough bytes to know the message_id, otherwise we know nothing.
		if queue.len(current_bytes_recv^) < size_of(network.Message_id) + size_of(network.Header_size) {
			return .not_done, nil, nil, nil;
		}
		
		{
			//log.debugf("offset : %v, len : %v", current_bytes_recv.offset, current_bytes_recv.len);
			message_id : network.Message_id = serialize.to_type(message_data[:], network.Message_id);
			
			if message_id in to_type {
				//Yes, a valid message
				status, read_bytes, value, _, data := network.array_to_any(to_type, message_data[:], loc);
				queue.consume_front(current_bytes_recv, read_bytes);
				if queue.len(current_bytes_recv^) == 0 {
					queue.clear(current_bytes_recv);
				}
				//log.debugf("offset : %v, len : %v", current_bytes_recv.offset, current_bytes_recv.len);

				if status == .finished {
					return .finished, value, free_func, data;
				}
				
				if status == .failed {
					log.errorf("failed to parse message");
					return .failed, nil, nil, nil;
				}

				return .not_done, nil, nil, nil;
			}
			else {
				log.errorf("A none valid message %v was passed.\n params are : %#v.\n", message_id);
				return .failed, nil, nil, nil;
			}
		}
	}
	else{

		if !utf8.valid_string(string(message_data)) {
			log.errorf("recvied invalid string : %v string(%v)", message_data, string(message_data));
			return .failed, nil, nil, nil;
		}
		
		//read until the first {
		//Check if the pre-{ is a number, if yes, lookup by message_id, if not then lookup by name.
		msg_start := -1;
		for c, i in message_data {
			if c == '{' {
				//we have found the message 
				msg_start = i;
				break;
			}
		}

		if msg_start == -1 {
			return .not_done, nil, nil, nil;  //we need more of the message
		}

		//count the { vs } and find the last }
		count := 0;
		last_bracket := -1;
		for c, i in message_data {
			if c == '{' {
				count += 1;
			}
			else if c == '}' {
				count -= 1;
				if count == 0 {
					last_bracket = i+1;
					break; //we found the entire message
				}
			}
		}

		//if there is too many { then we are not done yet
		if count != 0 {
			return .not_done, nil, nil, nil;  //we need more of the message
		}

		if last_bracket == -1 {
			panic("this should never be hit");
		}

		pre_msg := string(message_data[:msg_start]);
		num, valid := strconv.parse_i64(pre_msg);
		
		res_type : typeid = nil;

		if valid {
			if !(auto_cast num in to_type) {
				return .failed, nil, nil, nil
			}

			res_type = to_type[auto_cast num]
		}
		else {
			//try to find by name instead
			for _, t in to_type {
				ti := type_info_of(t)
				if named, ok := ti.variant.(runtime.Type_Info_Named); ok {
					if named.name == pre_msg {
						//we found the match
						res_type = t;
						break;
					}
					//log.debugf("searched '%v' (%v)", named.name, transmute([]u8)named.name);
				}
			}
		}
		
		if res_type == nil {
			log.errorf("could not find a match for message type '%v' (%v)", pre_msg, transmute([]u8)pre_msg);
			return .failed, nil, nil, nil;
		}

		arena_alloc := new(vmem.Arena, loc = loc);
		aerr := vmem.arena_init_growing(arena_alloc);
		assert(aerr == nil);

		pt := runtime.Type_Info_Pointer{type_info_of(res_type)};

		res_ptr, err := mem.alloc(reflect.size_of_typeid(res_type), allocator = vmem.arena_allocator(arena_alloc));
		assert(err == nil)
		
		value = any{res_ptr, res_type};
		json_err := json.unmarshal_any(message_data[msg_start:last_bracket], value, json.Specification.JSON5, vmem.arena_allocator(arena_alloc));
		if json_err != nil {
			log.errorf("failed to parse json, got err: %v for recvie message : %v", json_err, string(message_data[msg_start:last_bracket]));
			return .failed, nil, nil, nil;
		}

		queue.consume_front(current_bytes_recv, last_bracket);
		if queue.len(current_bytes_recv^) == 0 {
			queue.clear(current_bytes_recv);
		}

		return .finished, value, free_func, arena_alloc;
	}

	unreachable();
}
