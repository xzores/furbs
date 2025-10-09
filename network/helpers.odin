package furbs_network

import "base:runtime"

import vmem "core:mem/virtual"

import "core:log"

import "../utils"
import "../serialize"

Message_id :: i32;
Header_size :: u32;

//You can use this if you have a protocol that allows ones to send bytes, but needs more.
@(require_results)
any_to_array :: proc (msg_types : map[typeid]Message_id, value : any, loc := #caller_location) -> ([]u8, serialize.Serialization_error) {
	assert(value.id in msg_types, "the message you are passing is not in the message map", loc);

	data := make([dynamic]u8);
	
	msg_id : Message_id = msg_types[value.id];
	serialize.append_type_to_data(msg_id, &data);

	err := serialize.serialize_to_bytes_append(value, &data);

	if err != nil {
		delete(data);
		return nil, err;
	}

	return data[:], .ok;
}

Msg_pass_result :: enum {
	finished,
	not_done,
	failed,
}

//if not valid we need more data
@(require_results)
array_to_any :: proc (msg_types : map[Message_id]typeid, array : []u8, loc := #caller_location) -> (status : Msg_pass_result, read_bytes : int, value : any, free_func : proc (any, rawptr), data : rawptr) {
	if cast(i64)len(array) < size_of(Message_id) + size_of(Header_size) {
		return .not_done, 0, nil, nil, nil;
	}
	
	msg_id := serialize.to_type(array, Message_id);
	header := serialize.to_type(array[size_of(Message_id):], Header_size, "array_to_any", loc = loc);

	if cast(Header_size)len(array) < header {
		return .not_done, 0, nil, nil, nil;
	}

	status = .finished;
	read_bytes = size_of(Message_id) + auto_cast header;
	
	arena_alloc := new(vmem.Arena, loc = loc);
	aerr := vmem.arena_init_growing(arena_alloc);
	assert(aerr == nil);
	
	v, err := serialize.deserialize_from_bytes_any(msg_types[msg_id], array[size_of(Message_id):size_of(Message_id) + header], vmem.arena_allocator(arena_alloc));
	value = v;
	
	if err != nil {
		log.errorf("failed to deserialize"); 
		status = .failed;
	}

	free_func = proc (v : any, data : rawptr) {
		data := cast(^vmem.Arena)data;
		
		vmem.arena_destroy(data);
		log.debugf("deleting %p", data);
		free(data);
	}
	
	data = arena_alloc;

	return;
}