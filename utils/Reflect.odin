package utils;

import "core:runtime"
import "core:reflect"
import "core:intrinsics"

@(require_results)
is_enum_valid :: proc(a : any, loc := #caller_location) -> bool {

	if a == nil { return false; }
	
	ti := runtime.type_info_base(type_info_of(a.id))
	
	if e, ok := ti.variant.(runtime.Type_Info_Enum); ok {
		v, _ := reflect.as_i64(a)
		
		for value, i in e.values {
			if value == reflect.Type_Info_Enum_Value(v) {
				return true;
			}
		}
	} 
	else {
		panic("Expected an enum", loc);
	}

	return false;
}

@(require_results)
is_type_name_in_union :: proc ($u : typeid, type_name : string) -> (bool) where intrinsics.type_is_union(u) {
	return type_name_in_union_to_typeid(u, type_name) != nil;
}

@(require_results)
type_name_in_union_to_typeid :: proc ($u : typeid, type_name : string) -> typeid where intrinsics.type_is_union(u) {
	using runtime;

	ti := type_info_of(u);

	//Strip the name
	if named, ok := ti.variant.(Type_Info_Named); ok {
		ti = named.base;
	}

	if union_type_info, ok := ti.variant.(Type_Info_Union); ok {
		for v in union_type_info.variants {
			if n, ok := v.variant.(Type_Info_Named); ok {
				if n.name == type_name {
					return v.id; //or n.id??
				}
			}
			else {
				panic("Unamed union member, should we ignore?");
			}
		}
	}
	else {
		panic("Not a union");
	}

	return nil;
}