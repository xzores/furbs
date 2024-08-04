package utils;

import "core:mem"
import "core:strings"
import "core:fmt"

string_seri : Serialize_proc : proc(value : any, append_to : ^[dynamic]u8) {
	
	s := value.(string);

	header : u32 = cast(u32)len(s);
	append_type_to_data(header, append_to);

	for i in 0..<len(s) { //TODO this is slow
		append(append_to, s[i]);
	}

}

string_deseri : Deserialize_proc : proc(dst : any, data : []byte) -> (bytes_used : Header_size_type, err : bool) {
	using strings;

	s : ^string = &dst.(string);

	header : ^u32 = cast(^u32)&data[0];
	s^ = strings.clone(string(data[size_of(u32):size_of(u32)+header^]));
	
	return header^ + size_of(u32), false;
}


