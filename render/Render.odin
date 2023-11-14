package render;

import glfw "vendor:glfw"
import gl "vendor:OpenGL"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"
import "core:intrinsics"
import "core:reflect"
import "core:strconv"
import "core:fmt"
import "core:runtime"

import c "core:c/libc"



/* 
		NOTES ON INTERFACE

A common vulkan/opengl interface, calling a wrapper should abscract away vulkan/opengl. Wrappers are not called by the user.
Intead a high level interface is used, optimized for vulkan/opengl 4.6. Calling these functions will append the work to another thread.
This thread is the render thread. We should properly allow one to construct some render queue thingy, but maybe just have a default for simplicity....

Start with a default and see what happens, the thread should be optionally passed by the user.
So we have 1 big queue of commands, all commands specify if the underlying resource is owned by the render thread or the logic thread, this is specified by the user when the thing is passed.

It cannot be a virtual thing because that would require memory fraqmentation (lookup might not be true).


*/


////////////////////////////////////////////////////////////////////

error_callback : glfw.ErrorProc : proc "c" (error: i32, description: cstring) {
	context = runtime.default_context();
	fmt.panicf("Recvied GLFW error : %v, text : %s", error, description);
}

begin_render :: proc(uniform_spec : [$U]Uniform_info, attribute_spec : [$A]Attribute_info, shader_defines : map[string]string, shader_folder : string,
						loc := #caller_location) where intrinsics.type_is_enum(U) && intrinsics.type_is_enum(A) {

	
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

	if(!cast(bool)glfw.Init()){
		panic("Failed to init glfw");
	}
	
	glfw.SetErrorCallback(error_callback);

	/////////////////////

	uniform_enum_type = U;
	attribute_enum_type = A;
	
	allowed_uniforms = make([dynamic]Uniform_info, len(U));
	allowed_attributes = make([dynamic]Attribute_info, len(U));

	requied_uniforms : map[string]Uniform_info = get_requied_uniforms();
	requied_attributes : map[string]Attribute_info = get_requied_attributes();
	defer delete(requied_uniforms);
	defer delete(requied_attributes);
	
	for enum_val in reflect.enum_fields_zipped(U) {
		if enum_val.name in requied_uniforms {
			v : Uniform_info = requied_uniforms[enum_val.name];
			value : Uniform_info = uniform_spec[auto_cast enum_val.value];
			
			fmt.assertf(v.location == value.location || v.location == -1, "The location of uniform %v does not match, required location %v, given location : %v", enum_val.name, v.location, value.location, loc = loc);
			fmt.assertf(v.uniform_type == value.uniform_type || v.uniform_type == .invalid, "The uniform type of uniform %v does not match, required type %v, given type : %v", enum_val.name, v.uniform_type, value.uniform_type, loc = loc);
			fmt.assertf(v.array_size == value.array_size || v.array_size == -1, "The array size of uniform %v does not match, required array size %v, given array size : %v", enum_val.name, v.array_size, value.array_size, loc = loc);

			delete_key(&requied_uniforms, enum_val.name);
		}
		
		allowed_uniforms[auto_cast enum_val.value] = uniform_spec[auto_cast enum_val.value];
	}

	for enum_val in reflect.enum_fields_zipped(A) {
		if enum_val.name in requied_attributes {
			v : Attribute_info = requied_attributes[enum_val.name];
			value : Attribute_info = attribute_spec[auto_cast enum_val.value];
			
			fmt.assertf(v.attribute_type == value.attribute_type || v.attribute_type == .invalid, "The attribute type of uniform %v does not match, required type %v, given type : %v", enum_val.name, v.attribute_type, value.attribute_type, loc = loc);

			delete_key(&requied_attributes, enum_val.name);
		}

		allowed_attributes[auto_cast enum_val.value] = attribute_spec[auto_cast enum_val.value];
	}
	
	if len(requied_uniforms) != 0 {
		fmt.panicf("The following uniforms are required but not included : \n %v \n", requied_uniforms);
	}

	if len(requied_attributes) != 0 {
		fmt.panicf("The following attributes are required but not included : \n %v \n", requied_attributes);
	}

	if shader_defines != nil {

		for e, v in shader_defines {
			add_shader_defines(e,v);
		}
	}

	if shader_folder == "" {
		panic("Unimplemented, todo");
	}	
	//shader_folder_location = strings.clone(shader_folder);
}

end_render :: proc() {
	delete(allowed_uniforms);
	delete(allowed_attributes);
}

add_shader_defines :: proc (k : string, v : string) {
	panic("TODO");
}

get_requied_uniforms :: proc() -> (res : map[string]Uniform_info) {

	fields := reflect.struct_fields_zipped(Builtin_uniforms);
	
	for field in fields {
		
		req_type : Uniform_info;

		if req_type_str, ok := reflect.struct_tag_lookup(field.tag, "type"); ok {
			val, type_spes := reflect.enum_from_name(Uniform_type, auto_cast req_type_str);
			fmt.assertf(type_spes, "the name %v is not part of the Uniform_type enum, furbs interal error...", req_type_str);
			req_type.uniform_type = auto_cast val;
		}
		else {
			panic("Type must be specified, furbs interal error...")
		}
		
		if req_arr_size_str, ok := reflect.struct_tag_lookup(field.tag, "array_size"); ok {
			val, is_int_ok := strconv.parse_int(auto_cast req_arr_size_str);
			assert(is_int_ok, "Builtin_uniforms has an invalid int for array_size");
			
			req_type.array_size = auto_cast val;
		}
		else {
			req_type.array_size = -1;
		}

		res[field.name] = req_type;
	}

	return;
}

get_requied_attributes :: proc() -> map[string]Attribute_info {

	fields := reflect.struct_fields_zipped(Builtin_uniforms);

	for field in fields {
		
		req_type : Attribute_info;

		if req_type_str, ok := reflect.struct_tag_lookup(field.tag, "type"); ok {
			val, type_spes := reflect.enum_from_name(Attribute_type, auto_cast req_type_str);
			fmt.assertf(type_spes, "the name %v is not part of the Attribute_type enum, furbs interal error...", req_type_str);
			req_type.attribute_type = auto_cast val;
		}
		else {
			panic("Type must be specified, furbs interal error...")
		}

		res[field.name] = req_type;
	}

	return;
}
