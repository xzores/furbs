#+feature dynamic-literals
package utils;

import "core:fmt"
import "core:reflect"
import "core:mem"
import "base:runtime"

Header_size_type :: u32;

Serialize_proc :: #type proc(value : any, append_to : ^[dynamic]u8);
Deserialize_proc :: #type proc(dst : any, data : []byte) -> (bytes_used : Header_size_type, err : bool);

Seri_info :: struct {
	serialize : Serialize_proc,
	deserialize : Deserialize_proc, 
};

serializen_table : map[typeid]Seri_info = {
	string = {string_seri, string_deseri}
};

is_trivial_copied :: proc(t : typeid) -> bool {
	using runtime;
	
	ti : ^Type_Info = type_info_of(t);

	//strip the named
	if named_type_info, ok := ti.variant.(Type_Info_Named); ok {
		ti = named_type_info.base;
	}
	
	switch info in ti.variant {
		case Type_Info_Named:
			unreachable();
		case Type_Info_Integer:
			return true;
		case Type_Info_Rune:
			return true;
		case Type_Info_Float:
			return true;
		case Type_Info_Complex:
			return true;
		case Type_Info_Quaternion:
			return true;
		case Type_Info_Boolean:
			return true;
		case Type_Info_Array:
			return true;
		case Type_Info_Enumerated_Array:
			return true;
		case Type_Info_Matrix:
			return true;
		case Type_Info_Enum:
			return true;
		case Type_Info_Parameters:
			//TODO this might not allways be false, but I see no usecase for checking
			return false;
		case Type_Info_Bit_Set:
			return false; //IDK IS it?
		case Type_Info_Bit_Field:
			return false; //IDK IS it?
		case Type_Info_Simd_Vector:
			return false; //IDK IS it?
		case Type_Info_Type_Id:
			return false; //I think this is, check later 
		case Type_Info_String:
			return false;
		case Type_Info_Any:
			return false;
		case Type_Info_Pointer:
			return false;
		//case Type_Info_Relative_Slice:
		//	return false;
		//case Type_Info_Relative_Multi_Pointer:
		//	return false;
		case Type_Info_Multi_Pointer:
			return false;
		case Type_Info_Procedure:
			return false;
		case Type_Info_Dynamic_Array:
			return false;
		case Type_Info_Slice:
			return false;
		case Type_Info_Map:
			return false;
		//case Type_Info_Relative_Pointer:
		//	return false;
		case Type_Info_Soa_Pointer:
			return false;
		case Type_Info_Struct:
			res : bool = true;
			for t in info.types[:info.field_count] {
				if !is_trivial_copied(t.id) {
					res = false;
				}
			}
			return res;
		case Type_Info_Union:
			res : bool = true;
			for t in info.variants {
				if !is_trivial_copied(t.id) {
					res = false;
				}
			}
			return res;
		case:
			panic("Unhandled type!");
	}
};

Serialization_error :: enum {
	uknown,
	ok,
	type_not_supported,
	value_too_big,
	custom_type_invalid_data,
	allocation_error,
}

//Handels trivial, structs and unions, but does include the size as a u32, so only use for non-trivial structs or unions.
serialize_to_bytes :: proc(value : any, data : ^[dynamic]u8, loc := #caller_location) -> Serialization_error { //The header includes itself, and is the size type of Header_size_type
	using runtime;
	
	header_index := len(data);
	resize(data, len(data) + size_of(Header_size_type));

	res := _serialize_to_bytes(value, data, loc);
	if res != .ok {
		return res;
	}

	//Set the header size in the begining.
	message_size : int = len(data) - header_index;
	if message_size >= cast(int)max(Header_size_type) {
		return .value_too_big;
	}
	header : ^u32 = cast(^u32)&data[header_index];
	header^ = cast(u32)message_size;

	return .ok;
}

_serialize_to_bytes :: proc(value : any, data : ^[dynamic]u8, loc := #caller_location) -> Serialization_error { //The header includes itself, and is the size type of Header_size_type
	using runtime;
	
	//If it is just a simple copy, then we simply copy it.
	if is_trivial_copied(value.id) {
		append_type_to_data(value, data);
	}
	else {
		ti : ^Type_Info = type_info_of(value.id);
		//strip the named
		if named_type_info, ok := ti.variant.(Type_Info_Named); ok {
			ti = named_type_info.base;
		}

		#partial switch info in ti.variant {
			case Type_Info_Struct:
				
				fields := reflect.struct_fields_zipped(ti.id);

				for f in fields {
					
					id : typeid = f.type.id;
					member_ptr : rawptr = cast(rawptr)(cast(uintptr)value.data + f.offset)
					member : any = {data = member_ptr, id = id};

					if id in serializen_table {
						serializen_table[id].serialize(member, data);
					}
					else {
						res := _serialize_to_bytes(member, data);
						if res != .ok {
							return res;
						}
					}
				}
			//TODO case : union
			case Type_Info_Dynamic_Array:
				length : int = reflect.length(value);
				length_bytes := length * ti.variant.(Type_Info_Dynamic_Array).elem_size;
				append_type_to_data(length, data);

				//fmt.printf("length_bytes : %v\n", length_bytes);
				
				data_len := len(data);

				runtime.resize(data, data_len + length_bytes);
				//fmt.printf("data_len : %v, length_bytes : %v\n data : %v\n", data_len, length_bytes, len(data));
				value_raw_data, valid := reflect.as_raw_data(value);
				assert(valid);
				
				if length_bytes != 0 {
					mem.copy(&data[data_len], value_raw_data, length_bytes);
				}

			case:
				return .type_not_supported;
		}
	}
	
	return .ok;
}

//One would have to free the memory with free(...) if one does not use a temp allocator.
deserialize_from_bytes :: proc(to_type : typeid, data : []u8, alloc : mem.Allocator, loc := #caller_location) -> (value : any, err : Serialization_error) {
	using runtime;

	context.allocator = mem.nil_allocator();

	used_bytes : u32 = size_of(Header_size_type);

	value_data : rawptr;
	a_err : runtime.Allocator_Error;
	value_data, a_err = mem.alloc(reflect.size_of_typeid(to_type), DEFAULT_ALIGNMENT, alloc, loc);
	if a_err != nil {
		err = .allocation_error;
		return;
	}

	err = _deserialize_from_bytes(to_type, data, &used_bytes, value_data, alloc, loc);
	value = {data = value_data, id = to_type};

	return;
}

_deserialize_from_bytes :: proc(as_type : typeid, data : []u8, used_bytes : ^Header_size_type, value_data : rawptr, alloc : mem.Allocator, loc := #caller_location) -> Serialization_error {
	using runtime;

	if is_trivial_copied(as_type) {
		to_type_at(value_data, data[used_bytes^:], as_type);
		used_bytes^ += cast(u32)reflect.size_of_typeid(as_type);
	}
	else {
		
		ti : ^Type_Info = type_info_of(as_type);
		
		//strip the named
		if named_type_info, ok := ti.variant.(Type_Info_Named); ok {
			ti = named_type_info.base;
		}

		#partial switch info in ti.variant {
			case Type_Info_Struct:
				
				fields := reflect.struct_fields_zipped(ti.id);

				for f in fields {
					
					id : typeid = f.type.id;
					member_ptr : rawptr = cast(rawptr)(cast(uintptr)value_data + f.offset)
					member : any = {data = member_ptr, id = id};

					if id in serializen_table {
						context.allocator = alloc;
						used, s_err := serializen_table[id].deserialize(member, data[used_bytes^:]);
						used_bytes^ += used;
						if s_err {
							return .custom_type_invalid_data;
						}
					}
					else {
						res := _deserialize_from_bytes(id, data, used_bytes, member_ptr, alloc, loc);
						if res != .ok {
							return res;
						}
					}
				}
			case Type_Info_Dynamic_Array:
				length : int = to_type(data[used_bytes^:], int);
				used_bytes^ += size_of(int);
				elem_size := ti.variant.(Type_Info_Dynamic_Array).elem_size;
				length_bytes := length * elem_size;

				context.allocator = alloc;
				runtime.__dynamic_array_make(value_data, elem_size, elem_size, length, length, loc);
				arr := cast(^runtime.Raw_Dynamic_Array)value_data;

				if length != 0 {
					mem.copy(arr.data, &data[used_bytes^], length_bytes);
				}
				used_bytes^ += u32(length_bytes);

			//TODO case : union
			case:
				return .type_not_supported;
		}
	}

	return .ok;
}

to_type :: proc(data : []u8, $new_type : typeid) -> new_type {
	
	if len(data) < size_of(new_type){
		panic("We cannot convert a slice to type that is longer then the slice");
	}
	
	data_ptr : ^new_type = transmute(^new_type)&data[0];
	
	return data_ptr^;
}

to_type_at :: proc(dst : rawptr, data : []u8, new_type : typeid) {
	
	if len(data) < reflect.size_of_typeid(new_type){
		panic("We cannot convert a slice to type that is longer then the slice");
	}
	
	data_ptr : rawptr = &data[0];
	mem.copy(dst, data_ptr, reflect.size_of_typeid(new_type));
}

//Only works for trivial copies.
from_type :: proc(field : any, alloc := context.allocator) -> []u8 {
	
	assert(is_trivial_copied(field.id));
	
	size := reflect.size_of_typeid(field.id);
	data : []u8 = make([]u8, size, alloc);

	mem.copy(&data[0], field.data, size);
	
	return data;
}

append_type_to_data :: proc (field : any, append_to : ^[dynamic]u8) -> rawptr {

	assert(is_trivial_copied(field.id));

	size := reflect.size_of_typeid(field.id);
	old_len := len(append_to);

	//Allocate size for data
	resize(append_to, len(append_to) + size);
	dst : rawptr = &append_to[old_len];

	//Copy the data.
	mem.copy(dst, field.data, size);

	return dst;
}