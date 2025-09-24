package furbs_network

import "base:runtime"

import vmem "core:mem/virtual"

import "../utils"
import "../serialize"

Message_id :: u32;
Header_size :: i64;

//You can use this if you have a protocol that allows ones to send bytes, but needs more.

any_to_array :: proc (msg_types : map[typeid]Message_id, value : any, loc := #caller_location) -> ([]u8, serialize.Serialization_error) {
	assert(value.id in msg_types, "the message you are passing is not in the message map", loc);

	data := make([dynamic]u8);

	serialize.append_type_to_data(msg_types[value.id], &data)
	header := cast(^Header_size)&data[len(data)];
	resize(&data, len(data) + size_of(Header_size))

	err := serialize.serialize_to_bytes_append(value, &data);
	header^ = auto_cast len(data);

	if err != nil {
		delete(data);
		return nil, err;
	}

	return data[:], .ok;
}

//if not valid we need more data
array_to_any :: proc (msg_types : map[Message_id]typeid, array : []u8) -> (valid : bool, read_bytes : int, value : any, free_func : proc (any, rawptr), data : rawptr) {
	msg_id := serialize.to_type(array, Message_id);
	header := serialize.to_type(array[size_of(Message_id):], Header_size);

	if cast(i64)len(array) < header {
		return false, 0, nil, nil, nil;
	}

	valid = true;
	read_bytes = auto_cast header;
	
	arena_alloc := new(vmem.Arena);
	aerr := vmem.arena_init_growing(arena_alloc);
	assert(aerr == nil);
	
	v, err := serialize.deserialize_from_bytes_any(msg_types[msg_id], array[size_of(Message_id) + size_of(Header_size):], vmem.arena_allocator(arena_alloc));
	value = v;
	
	assert(err == nil, "failed to deserialize")

	free_func = proc (v : any, data : rawptr) {
		data := cast(^vmem.Arena)data;
		
		vmem.arena_destroy(data);
		free(data);
	}
	
	data = arena_alloc;

	return 
}