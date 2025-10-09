package whirl_web

import "core:reflect"
import "core:fmt"
import "core:c"
import "core:log"
import "core:mem"

import "base:intrinsics"
import "base:runtime"

import cef "CEF_bindings"

@private
Super :: struct(T : typeid) {
	obj : T,
	ref_cnt : i32,
	user_data : rawptr,
	on_free : proc "contextless" (self: ^cef.base_ref_counted, user_data : rawptr, alloc_location : runtime.Source_Code_Location),
	alloc_location : runtime.Source_Code_Location,
}

//Must be called when creating a cef object.
@(require_results)
alloc_cef_object_outplace :: proc ($T : typeid, user_data : rawptr, on_free : proc "contextless" (self: ^cef.base_ref_counted, user_data : rawptr, alloc_location : runtime.Source_Code_Location) = nil, loc := #caller_location) -> ^T where intrinsics.type_has_field(T, "base") {
	assert(cef_allocator != {}, "You must call set_cef_allocator first", loc);

	//log.debugf("allocating %v", type_info_of(T), location = loc);
	
	base : cef.base_ref_counted = {
		size_of(T), //size
		proc "system" (self: ^cef.base_ref_counted) { //add_ref 
			context = restore_context();
			super := cast(^Super(T))self;
			old_val := intrinsics.atomic_add(&super.ref_cnt, 1);
		},
		proc "system" (self: ^cef.base_ref_counted) -> b32 { //release
			context = restore_context();
			super := cast(^Super(T))self;
			old_val := intrinsics.atomic_sub(&super.ref_cnt, 1);
			freed := old_val == 1

			//free the object
			if freed {
				assert(super.ref_cnt == 0);

				if super.on_free != nil {
					super.on_free(self, super.user_data, super.alloc_location);
				}

				//log.debugf("freeing %v", type_info_of(T), location = super.alloc_location);
				mem.free(super, cef_allocator, loc = super.alloc_location);
				super = {};
			}
			else {
				fmt.assertf(super.ref_cnt > 0, "%v was freed one to many times, ref_cnt is %v", type_info_of(T), super.ref_cnt, loc = super.alloc_location);
			}
			
			return auto_cast freed;
		},
		proc "system" (self: ^cef.base_ref_counted) -> b32 { //has_one_ref
			super := cast(^Super(T))self;
			return super.ref_cnt == 1;
		},
		proc "system" (self: ^cef.base_ref_counted) -> b32 { //has_at_least_one_ref
			super := cast(^Super(T))self;
			return super.ref_cnt >= 1;
		}
	}

	ptr, err := mem.alloc(size = size_of(Super(T)), allocator = cef_allocator, loc = loc);
	super := cast(^Super(T))ptr;
	assert(err == nil, "Failed to allocate memory for CEF object");
	super.obj.base = base;
	super.ref_cnt = 1;
	super.alloc_location = loc;
	super.user_data = user_data;
	
	return &super.obj;
}

alloc_cef_object_inplace :: proc (obj : ^^$T, user_data : rawptr, on_free : proc "contextless" (self: ^cef.base_ref_counted, user_data : rawptr, alloc_location : runtime.Source_Code_Location) = nil, loc := #caller_location) where intrinsics.type_has_field(T, "base") {
	obj^ = alloc_cef_object_outplace(T, user_data, on_free, loc);
}

alloc_cef_object :: proc {alloc_cef_object_outplace, alloc_cef_object_inplace}

cef_object_get_user_data :: proc "contextless" (obj : ^$T) -> rawptr where intrinsics.type_has_field(T, "base") {
	super := cast(^Super(T))obj;
	return super.user_data;
}

release :: proc "contextless" (t : ^$T) where intrinsics.type_has_field(T, "base") {
	t.base.release(&t.base);
}

increment :: proc "contextless" (t : ^$T) where intrinsics.type_has_field(T, "base") {
	t.base.add_ref(&t.base);
}

//helper
@private
change_all_base_on_struct :: proc (parent : ^$T, add : bool) {
	
	for field in reflect.struct_fields_zipped(T) {

		if tip, ok := field.type.variant.(runtime.Type_Info_Pointer); ok {
			base_field := reflect.struct_field_by_name(tip.elem.id, "base");
			if base_field == {} {
				continue;
			}
			if base_field.type.id == cef.base_ref_counted {
				assert(base_field.offset == 0);
				
				base_ptr := cast(^^cef.base_ref_counted)(cast(uintptr)parent + field.offset);

				if add {
					base_ptr^.add_ref(base_ptr^);
				}
				else {
					base_ptr^.release(base_ptr^);
				}
			}
		}
	}
}

//increment all the sub objects with a base_ref_counted struct.
increment_all :: proc (parent : ^$T) {
	change_all_base_on_struct(parent, true);
}

//increment all the sub objects with a base_ref_counted struct.
release_all :: proc (parent : ^$T) {
	change_all_base_on_struct(parent, false);
}