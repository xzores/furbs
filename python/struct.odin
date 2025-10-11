package furbs_python_helper_package;

import "core:strings"
import "base:runtime"
import "base:intrinsics"

import "core:reflect"
import "core:fmt"
import "core:slice"

/// THIS ALLOWS YOU TO CONVERT A ODIN STRUCT DEFINITION TO A PYTHON STRUCT DEFINITION ///

//internal use
//do not free these, they are temp allocated
@(require_results)
to_python_type :: proc (t: ^runtime.Type_Info, dependencies: ^[dynamic]^runtime.Type_Info, comment : ^strings.Builder) -> (res: string) {
	base := reflect.type_info_base(t)

	#partial switch &type in base.variant {
		case runtime.Type_Info_Array: {
			// Python has no fixed-size array type; use list[Elem]
			elem_s := to_python_type(type.elem, dependencies, comment)

			builder : strings.Builder;
			strings.builder_init(&builder, context.temp_allocator);

			strings.write_string(&builder, "tuple[");
			for i in 0..<type.count {
				strings.write_string(&builder, elem_s);
				if i != type.count-1 {
					strings.write_string(&builder, ", ");
				}
			}
			strings.write_string(&builder, "]");

			res = strings.to_string(builder);
		}
		case runtime.Type_Info_Boolean: {
			res = "bool"
		}
		case runtime.Type_Info_Complex: {
			res = "complex"
		}
		case runtime.Type_Info_Dynamic_Array, runtime.Type_Info_Slice: {
			sa : ^runtime.Type_Info;
			
			#partial switch &type in base.variant {
				case runtime.Type_Info_Dynamic_Array: {
					sa = type.elem;
				}
				case runtime.Type_Info_Slice: {
					sa = type.elem;
				}
			}
			
			elem_s := to_python_type(sa, dependencies, comment)
			res = fmt.tprintf("list[%s]", elem_s)
		}
		case runtime.Type_Info_Enum: {
			// Map enums to string (Python doesn't have built-in enum type name)
			strings.write_string(comment, " #options are ");
			for n in type.names {
				strings.write_string(comment, n);
				strings.write_string(comment, ", ");
			}
			strings.write_string(comment, " ");

			res = "str"
		}
		case runtime.Type_Info_Float: {
			res = "float"
		}
		case runtime.Type_Info_Integer: {
			res = "int"
		}
		case runtime.Type_Info_Map: {
			m := base.variant.(runtime.Type_Info_Map)
			k_s := to_python_type(m.key, dependencies, comment)
			v_s := to_python_type(m.value, dependencies, comment)
			res = fmt.tprintf("dict[%s, %s]", k_s, v_s)
		}
		case runtime.Type_Info_String: {
			res = "str"
		}
		case runtime.Type_Info_Quaternion: {
			// 4-tuple of floats
			res = "tuple[float, float, float, float]"
		}
		/*case runtime.Type_Info_Rune: {
			// Unicode code point → represent as 1-char string in Python
			res = "str"
		}
		case runtime.Type_Info_Named: {
			//this must be a struct
			s, ok := type.base.variant.(runtime.Type_Info_Struct)
			assert(ok);
			dependencies[base] = {};
		}*/
		case runtime.Type_Info_Struct: {
			//this must be a struct
			named, ok := t.variant.(runtime.Type_Info_Named);
			assert(ok);
			if !slice.contains(dependencies[:], t) {
				append(dependencies, t);
			}
			res = named.name
		}
		case runtime.Type_Info_Union: {

			builder : strings.Builder;
			strings.builder_init(&builder, context.temp_allocator);

			py_types := make([dynamic]string);
			for v, i in type.variants {
				// If your reflect API stores pointers, adjust to v.type or ^runtime.Type_Info accordingly.
				member_s := to_python_type(v, dependencies, comment);
				if i != 0 {
					strings.write_string(&builder, " | ");
				}
				strings.write_string(&builder, member_s);
			}

			if len(type.variants) == 1 {
				strings.write_string(&builder, " | None");
			}

			res = strings.to_string(builder);
		}
		case: {
			fmt.panicf("type %v not supported to be translated to python", base)
		}
    }

    return res;
}

//internal use
//everything is temp allocated
@(require_results)
convert_struct_definition :: proc (t : ^runtime.Type_Info, dependencies : ^[dynamic]^runtime.Type_Info, loc := #caller_location) -> (res : string) {
	base := reflect.type_info_base(t);
	ti_struct, ok := base.variant.(runtime.Type_Info_Struct);
	assert(ok, "must be a struct", loc)

	builder : strings.Builder;
	strings.builder_init(&builder, context.temp_allocator);

	strings.write_string(&builder, "class ");
	strings.write_string(&builder, t.variant.(runtime.Type_Info_Named).name);
	strings.write_string(&builder, ":\n");

	for field in reflect.struct_fields_zipped(t.id) {
		strings.write_string(&builder, "\t");
		strings.write_string(&builder, field.name);
		strings.write_string(&builder, ": ");

		comment : strings.Builder;
		strings.builder_init(&comment, context.temp_allocator);

		strings.write_string(&builder,  to_python_type(field.type, dependencies, &comment));
		if len(comment.buf) != 0 {
			strings.write_string(&builder, strings.to_string(comment));
		}	
		strings.write_string(&builder, "\n");
	}
	if len(reflect.struct_fields_zipped(t.id)) == 0 {
		strings.write_string(&builder, "\tpass\n");
	}

	return strings.to_string(builder);
}


//this string must be freed by the user
@(require_results)
convert_to_python :: proc (ts : []^runtime.Type_Info, loc := #caller_location) -> (res : string) {

	dependencies := make([dynamic]^runtime.Type_Info, context.temp_allocator)
	converted := make(map[^runtime.Type_Info]string, context.temp_allocator);

	for t in ts {
		append(&dependencies, t);
	}

	is_done := false;

	for !is_done {
		is_done = true;
		
		for dep, _ in dependencies {
			if !(dep in converted) {
				is_done = false;
				converted[dep] = convert_struct_definition(dep, &dependencies, loc)
			}
		}
	}

	builder : strings.Builder;
	strings.builder_init(&builder);

	#reverse for dep in dependencies {
		strings.write_string(&builder, converted[dep]);
		strings.write_string(&builder, "\n");
	}
	
	return strings.to_string(builder);
}