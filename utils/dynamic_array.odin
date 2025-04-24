package utils;

import "base:runtime"

Dynamic_array :: struct {
	element_size : int,	//what is the size of each element
	
	element_cnt : int,	//how many elements are currently there
	element_cap : int,	//What is the current capacity
	data : rawptr,		//the data on the heap
	
	allocator : runtime.Allocator,
}

dynamic_array_make :: proc(element_size : int, capacity := 8, allocator := context.allocator) -> Dynamic_array {
	
}

dynamic_array_get :: proc(arr : ^Dynamic_array, index : int) -> rawptr {
	
}

dynamic_array_add_element :: proc (arr : ^Dynamic_array, elem : rawptr) -> (index : int) {
	
}

dynamic_array_len :: proc (arr : Dynamic_array) -> (len : int) {
	
}

dynamic_array_unordered_remove :: proc (arr : ^Dynamic_array, index : int) {
	
}