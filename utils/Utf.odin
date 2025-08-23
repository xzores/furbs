package utils;

import "core:unicode/utf16"


string_to_utf16_slice :: proc (str : string, alloc := context.allocator) -> []u16 {
	
	res := make([dynamic]u16, len(str), alloc)

	for r in str {
		
	}

	return res[:];
}