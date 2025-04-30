package utils;

import "core:mem"
import "base:runtime"

Dynamic_array :: struct {
	element_size : int,	//what is the size of each element
	
	element_cnt : int,	//how many elements are currently there
	element_cap : int,	//What is the current capacity
	data : rawptr,		//the data on the heap
	
	allocator : runtime.Allocator,
}

@require_results
dynamic_array_make :: proc(element_size : int, capacity := 8, allocator := context.allocator, loc := #caller_location) -> Dynamic_array {
	
	ptr, err := mem.alloc(element_size * capacity, allocator = allocator, loc = loc);
	
	assert(err == nil, "failed to allocate");
	
	return Dynamic_array{
		element_size,
		0,
		capacity,
		ptr,
		allocator
	};
}

dynamic_array_destroy :: proc (arr : Dynamic_array) {
	free(arr.data, arr.allocator);
}

@require_results
dynamic_array_get :: proc(arr : ^Dynamic_array, index : int, loc := #caller_location) -> rawptr {
	
	ptr := cast(uintptr)arr.data;
	
	if index < 0 || index >= arr.element_cnt {
		panic("out of bounds", loc);
	}
	
	return cast(rawptr)(ptr + uintptr(index * arr.element_size));
}

@require_results
dynamic_array_add_element :: proc (arr : ^Dynamic_array, elem : rawptr) -> (index : int) {
	
	if arr.element_cnt >= arr.element_cap {
		//There is not enough space, resize
		new_data, err := mem.alloc(arr.element_size * 2 * arr.element_cap, allocator = arr.allocator);
		assert(err == nil, "failed to allocate");
		
		mem.copy(new_data, arr.data, arr.element_size * arr.element_cap)
		mem.free(arr.data, arr.allocator);
		arr.data = new_data;
		
		arr.element_cap *= 2;
	}
	
	mem.copy(arr.data, elem, arr.element_size * 1);
	
	return arr.element_cnt - 1;
}

@require_results
dynamic_array_len :: proc (arr : Dynamic_array) -> (len : int) {
	return arr.element_cnt;
}

dynamic_array_unordered_remove :: proc (arr : ^Dynamic_array, index : int, loc := #caller_location) {
	assert(arr.element_cnt > 0, "array is empty", loc);
	
	last := dynamic_array_get(arr, arr.element_cnt - 1);
	to_remove := dynamic_array_get(arr, index);
	
	mem.copy(to_remove, last, arr.element_size * 1);
	mem.zero(last, arr.element_size * 1);
	arr.element_size -= 1;
	
}
