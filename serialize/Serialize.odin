#+feature dynamic-literals
package serialize;

import "core:fmt"
import "core:reflect"
import "core:mem"
import "base:runtime"
import "core:log"



//////////////////////////// TODO ////////////////////////
//Currently we use 4 bytes for the entire message and 8 for sub elements (arrays and such)
//that is not great we get the worst of both worlds, so we could swap so the entire is 8 and sub is 4 or both are 8.
//TODO!!! Implement this

Header_size_type :: u32;


Serialization_error :: enum {
	ok,
	uknown,
	type_not_supported,
	value_too_big,
	custom_type_invalid_data,
	allocation_error,
}

@(require_results)
serialize_to_bytes_res :: proc(value : any, loc := #caller_location) -> ([]u8, Serialization_error) { //The header includes itself, and is the size type of Header_size_type
	using runtime;
	
	data := make([dynamic]u8);
	
	err := serialize_to_bytes_append(value, &data, loc);
	
	if err != nil {
		delete(data);
		return nil, err;
	}
	
	return data[:], .ok;
}

@(require_results)
serialize_to_bytes_append :: proc(value : any, data : ^[dynamic]u8, loc := #caller_location) -> (Serialization_error) { //The header includes itself, and is the size type of Header_size_type
	using runtime;
	
	header_index := len(data);
	resize(data, len(data) + size_of(Header_size_type));
	
	res := _serialize_to_bytes(value, data, loc);
	if res != .ok {
		return res;
	}

	//Set the header size in the begining.
	message_size : i64 = i64(len(data)) - i64(header_index); //The message_size size includes the header
	if message_size >= cast(i64)max(Header_size_type) {
		return .value_too_big;
	}
	header : ^Header_size_type = cast(^Header_size_type)&data[header_index];
	header^ = cast(Header_size_type)message_size;

	return .ok;
}

serialize_to_bytes :: proc {serialize_to_bytes_res, serialize_to_bytes_append}

@(private, require_results)
_serialize_to_bytes :: proc(value : any, data : ^[dynamic]u8, loc := #caller_location) -> Serialization_error { //The header includes itself, and is the size type of Header_size_type
	using runtime;
	
	//If it is just a simple copy, then we simply copy it.
	if is_trivial_copied(value.id) {
		append_type_to_data(value, data, loc);
	}
	else {
		ti : ^Type_Info = type_info_of(value.id);
		//strip the named
		if named_type_info, ok := ti.variant.(Type_Info_Named); ok {
			ti = named_type_info.base;
		}
		
		#partial switch info in ti.variant {
			case Type_Info_Struct: {
				
				fields := reflect.struct_fields_zipped(ti.id);

				for f in fields {
					
					id : typeid = f.type.id;
					member_ptr : rawptr = cast(rawptr)(cast(uintptr)value.data + f.offset)
					member : any = {data = member_ptr, id = id};

					res := _serialize_to_bytes(member, data, loc);
					if res != .ok {
						return res;
					}
				}
			}
			case runtime.Type_Info_String: {
				if info.is_cstring {
					//log.errorf("TODO cstring not supported yet");
					return .type_not_supported; //I think it is ok for serilzation, but it failes at deserizlize
				}

				length : i64 = cast(i64)reflect.length(value);
				append_type_to_data(length, data, loc); //write the length (header of the string)
				
				if length == 0 {
					return .ok;
				}
				
				//Allocate size for data
				old_len := len(data);
				resize(data, len(data) + auto_cast length, loc = loc);
				dst : rawptr = &data[old_len];

				//Copy the data.
				string_raw_ptr, valid := reflect.as_raw_data(value);
				assert(valid);
				mem.copy(dst, string_raw_ptr, auto_cast length); //follow by the raw data
			}
			case Type_Info_Dynamic_Array, runtime.Type_Info_Slice: {

				elem_id : typeid;
				elem_size : i64;

				if dyn_info, ok := info.(Type_Info_Dynamic_Array); ok {
					elem_id = dyn_info.elem.id
					elem_size = auto_cast dyn_info.elem_size
				}
				else if slice_info, ok := info.(Type_Info_Slice); ok {
					elem_id = slice_info.elem.id
					elem_size = auto_cast slice_info.elem_size
				}
				else {
					unreachable();
				}
				
				//fmt.printfln("value : %p, %v", value.data, value.id);
				length : i64 = auto_cast reflect.length(value);
				//fmt.printfln("did value : %p, %v", value.data, value.id);
				append_type_to_data(length, data, loc);

				if length == 0 {
					return .ok;
				}

				begin_ptr, valid := reflect.as_raw_data(value);
				assert(valid);
				for i in 0..<length {
					elem_ptr := cast(rawptr)(cast(uintptr)begin_ptr + cast(uintptr)(i * elem_size));
					element : any = {data = elem_ptr, id = elem_id};
					
					seri_err := _serialize_to_bytes(element, data, loc);
					
					if seri_err != .ok {
						return seri_err;
					}
				}
			}
			case:
				log.errorf("type_not_supported : %v", ti);
				return .type_not_supported;
		}
	}
	
	return .ok;
}








///////////////////////////////////////////// private helpers /////////////////////////////////////////////

is_trivial_copied :: proc(t : typeid, loc := #caller_location) -> bool {
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
			log.errorf("Unhandled type for ti.varient! type info was %v", info, location = loc);
			fmt.panicf("Unhandled type for ti.varient! type info was %v", info, loc = loc);
	}
};

//One would have to free the memory with free(...) if one does not use a temp allocator.
@(require_results)
deserialize_from_bytes_static :: proc($To_type : typeid, data : []u8, alloc : mem.Allocator, loc := #caller_location) -> (value : To_type, err : Serialization_error) {
	using runtime;
	
	context.allocator = mem.panic_allocator();
	
	assert(len(data) >= size_of(Header_size_type), "not enough data for header");
	header : Header_size_type = (cast(^Header_size_type)raw_data(data))^;
	assert(len(data) == auto_cast header, "length of data does not match header size");
	used_bytes : Header_size_type = size_of(Header_size_type);

	value_data : To_type;
	
	err = _deserialize_from_bytes(To_type, data, &used_bytes, &value_data, alloc);
	if err != nil {
		return {}, err;
	}

	return value_data, nil;
}

//One would have to free the memory with free(...) if one does not use a temp allocator.
@(require_results)
deserialize_from_bytes_any :: proc(as_type : typeid, data : []u8, alloc : mem.Allocator, loc := #caller_location) -> (value : any, err : Serialization_error) {
	using runtime;
	
	context.allocator = mem.panic_allocator();
	
	assert(len(data) >= size_of(Header_size_type), "not enough data for header");
	header : Header_size_type = (cast(^Header_size_type)raw_data(data))^;
	assert(len(data) == auto_cast header, "length of data does not match header size");
	used_bytes : Header_size_type = size_of(Header_size_type);
	
	if reflect.size_of_typeid(as_type) != 0 {
		ptr, alloc_err := mem.alloc(reflect.size_of_typeid(as_type), mem.DEFAULT_ALIGNMENT, alloc, loc);
		fmt.assertf(alloc_err == nil, "failed to allocate : %v", alloc_err);
		log.debugf("the pointer was : %p for %v", ptr, type_info_of(as_type));
		err = _deserialize_from_bytes(as_type, data, &used_bytes, ptr, alloc, loc);
		if err != nil {
			return {}, err;
		}
		
		return any{ptr, as_type}, nil;
	}

	return any{nil, as_type}, nil;
}

deserialize_from_bytes :: proc {deserialize_from_bytes_static, deserialize_from_bytes_any};

@(private, require_results)
_deserialize_from_bytes :: proc(as_type : typeid, data : []u8, used_bytes : ^Header_size_type, value_data : rawptr, alloc : mem.Allocator, loc := #caller_location) -> Serialization_error {
	fmt.assertf(value_data != nil, "value_data for type %v is nil", as_type, loc = loc);
	using runtime;

	if is_trivial_copied(as_type) { //First see if we can just copy the memory, if yes then we do that.
		to_type_at(value_data, data[used_bytes^:], as_type, "trivial_copy", loc);
		used_bytes^ += cast(u32)reflect.size_of_typeid(as_type);
	}
	else {
		
		ti : ^Type_Info = type_info_of(as_type);
		
		//strip the named
		if named_type_info, ok := ti.variant.(Type_Info_Named); ok {
			ti = named_type_info.base;
		}

		#partial switch info in ti.variant {
			case Type_Info_Struct: {
				
				fields := reflect.struct_fields_zipped(ti.id);

				for f in fields {
					id : typeid = f.type.id;
					member_ptr : rawptr = cast(rawptr)(cast(uintptr)value_data + f.offset)
					member : any = {data = member_ptr, id = id};

					res := _deserialize_from_bytes(id, data, used_bytes, member_ptr, alloc);
					if res != .ok {
						return res;
					}
				}
			}
			case runtime.Type_Info_String: {
				if info.is_cstring {
					log.errorf("TODO cstring not supported yet");
					return .type_not_supported; //I think it is ok for serilzation, but it failes at deserizlize
				}

				str_len := to_type(data[used_bytes^:], i64, "string_length");
				used_bytes^ += size_of(i64);
				if str_len == 0 {
					return .ok;
				}

				context.allocator = alloc;
				buf, err := mem.alloc(auto_cast str_len); //return a rawptr
				mem.copy(buf, &data[used_bytes^], auto_cast str_len); //we copy out the data into our memory as the other data will be deleted.

				raw_string := runtime.Raw_String {cast(^u8)buf, auto_cast str_len};
				used_bytes^ += auto_cast str_len; //consume the length of the string from the bytes.
				
				assert(size_of(raw_string) == size_of(string));
				mem.copy(value_data, &raw_string, size_of(string)); //copy the string value in place (this is not the data but the ptr and len of the string)
			}
			case Type_Info_Dynamic_Array, runtime.Type_Info_Slice: {
				elem_id  : typeid;
				elem_size: i64;
				is_dyn   : bool = false;

				if dinfo, ok := info.(Type_Info_Dynamic_Array); ok {
					elem_id   = dinfo.elem.id;
					elem_size = auto_cast dinfo.elem_size;
					is_dyn    = true;
				} else if sinfo, ok := info.(Type_Info_Slice); ok {
					elem_id   = sinfo.elem.id;
					elem_size = auto_cast sinfo.elem_size;
				} else {
					unreachable();
				}
				
				length : i64 = to_type(data[used_bytes^:], i64, "slice_length"); // in elements
				used_bytes^ += size_of(i64);

				if length == 0 {
					return .ok;
				}
				
				// allocate backing storage
				length_bytes : int = auto_cast (length * elem_size); // in bytesa
				buf, err := mem.alloc(length_bytes, allocator = alloc);
				if err != nil {
					//can we allocate a smaller array?
					_, err2 := mem.alloc(60000, allocator = alloc);
					log.infof("err2 : %v", err2); //This is fine
				}
				fmt.assertf(err == nil, "failed to allocate, err : %v, length in bytes : %v", err, length_bytes);
				
				// element-wise deserialize (handles string / non-POD via recursion)
				for i in 0..<length {
					elem_place := cast(rawptr)(cast(uintptr)buf + cast(uintptr)(i * elem_size));
					err := _deserialize_from_bytes(elem_id, data, used_bytes, elem_place, alloc);
					if err != .ok { return err; }
				}

				if is_dyn {
					//Raw_Dynamic_Array is ptr, length, cap, allocator
					arr := runtime.Raw_Dynamic_Array {buf, cast(int)length, cast(int)length, alloc};
					assert(reflect.size_of_typeid(as_type) == size_of(arr));
					mem.copy(value_data, &arr, reflect.size_of_typeid(as_type));
				} else {
					arr := runtime.Raw_Slice{buf, cast(int)length};
					fmt.assertf(reflect.size_of_typeid(as_type) == size_of(arr), "deserialize sizes for slice did not match %v vs %v bytes", reflect.size_of_typeid(as_type), size_of(arr));
					mem.copy(value_data, &arr, reflect.size_of_typeid(as_type));
				}

			}

			//TODO case : union
			case:
				return .type_not_supported;
		}
	}
	
	return .ok;
}

@(require_results)
to_type :: proc(data : []u8, $new_type : typeid, debug_str := "", loc := #caller_location) -> new_type {
	
	fmt.assertf(len(data) >= size_of(new_type), "We cannot convert %v a slice to type that is longer then the slice, length was %v type was %v with length (%v), \ndata: %v", debug_str, len(data), typeid_of(new_type), size_of(new_type), data, loc = loc);
	if len(data) < size_of(new_type){
		panic("We cannot convert a slice to type that is longer then the slice");
	}
	
	data_ptr : ^new_type = transmute(^new_type)&data[0];
	
	return data_ptr^;

}

@(private)
to_type_at :: proc(dst : rawptr, data : []u8, new_type : typeid, debug_str := "", loc := #caller_location) {
	
	if len(data) < reflect.size_of_typeid(new_type) {
		fmt.panicf("We cannot convert %v a slice to type that is longer then the slice, the size of the data array is %v, the size if the type is %v for data: %v", debug_str, len(data), reflect.size_of_typeid(new_type), data, loc = loc);
	}

	if reflect.size_of_typeid(new_type) == 0 {
		return;
	}

	fmt.assertf(dst != nil, "dst is nil for type %v for %v, with data length : %v", type_info_of(new_type), debug_str, len(data), loc = loc)
	data_ptr : rawptr = &data[0];
	mem.copy(dst, data_ptr, reflect.size_of_typeid(new_type));
}

//Only works for trivial copies.
@(require_results, private)
from_type :: proc(field : any, alloc := context.allocator) -> []u8 {
	
	assert(is_trivial_copied(field.id));
	
	size := reflect.size_of_typeid(field.id);
	data : []u8 = make([]u8, size, alloc);

	mem.copy(&data[0], field.data, size);
	
	return data;
}

@(private)
append_type_to_data :: proc (field : any, append_to : ^[dynamic]u8, loc := #caller_location) {

	assert(is_trivial_copied(field.id));

	size := reflect.size_of_typeid(field.id);
	if size == 0 {
		return;
	}
	
	old_len := len(append_to);

	//Allocate size for data
	resize(append_to, len(append_to) + size, loc);
	dst : rawptr = &append_to[old_len];

	//Copy the data.
	mem.copy(dst, field.data, size);
}