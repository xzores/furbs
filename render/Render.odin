package render;

import glfw "vendor:glfw"
import gl "vendor:OpenGL"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"
import fs "vendor:fontstash"
import "core:intrinsics"
import "core:reflect"
import "core:strconv"
import "core:fmt"
import "core:runtime"
import "core:sync"
import "core:container/queue"

import c "core:c/libc"


/* 
		NOTES ON INTERFACE

A common vulkan/opengl interface, calling a wrapper should abscract away vulkan/opengl. Wrappers are not called by the user.
Intead a high level interface is used, optimized for vulkan/opengl 4.6. Calling these functions will append the work to another thread.
This thread is the render thread. We should properly allow one to construct some render queue thingy, but maybe just have a default for simplicity....

Start with a default and see what happens, the thread should be optionally passed by the user.
So we have 1 big queue of commands, all commands specify if the underlying resource is owned by the render thread or the logic thread, this is specified by the user when the thing is passed.

It cannot be a virtual thing because that would require memory fraqmentation (lookup might not be true).
Vulkan might not be added.
*/

////////////// TYPES ////////////

Vertex_buffer_targets :: enum {
	array_buffer,
}

///////////// STATE ////////////
Render_state :: struct(U, A : typeid) where intrinsics.type_is_enum(U) && intrinsics.type_is_enum(A) {

	default_shader : Shader(U, A),

	font_texture : Texture2D,
	font_context : fs.FontContext,
	//text_shader : Shader, renamed default_shader
	//gui_shader : Shader, renamed default_shader

	prj_mat 		: matrix[4,4]f32,
	inv_prj_mat 	: matrix[4,4]f32,

	view_mat 		: matrix[4,4]f32,
	inv_view_mat	: matrix[4,4]f32,

	shader_folder_location : string,

	current_render_target_width : f32,
	current_render_target_height : f32,
	current_render_target_unit : f32, //TODO

	opengl_version : GL_version,

	//Window stuff
	bound_window : Maybe(^Window),
	
	/////////// Optional helpers stuff ////////////
	shapes_buffer : Mesh_buffer(A), //TODO unused
	white_texture : Texture2D, //Use get_white_texture to get it as it will init it if it is not.

	//TODO make this a single mesh buffer
	shape_quad : Mesh(A),
	shape_circle : Mesh(A),

	/////////// Camera ///////////
	bound_camera : union {
		Camera2D,
		Camera3D,
	},

	/////////// Shaders ///////////
	loaded_vertex_shaders : map[string]Shader_vertex_id,
	loaded_fragment_shaders : map[string]Shader_fragment_id,

	/////////// Debug state, only used when compiled with "-debug" ///////////
	using debug_state : Debug_state,

}

///////////// DEBUG STATE ////////////

when ODIN_DEBUG {
	Debug_state :: struct {

		render_has_been_init : bool,

		////////////////

		//What is alive
		//not it map = not created,
		//false = deleted,
		//true = alive,
		shader_program_alive : map[Shader_program_id]bool, //All array_buffers alive
		shader_vertex_alive : map[Shader_vertex_id]bool, //All array_buffers alive
		shader_fragment_alive : map[Shader_fragment_id]bool, //All array_buffers alive

		textures_alive : map[Texture_id]bool, //All array_buffers alive
		render_buffer_alive : map[Render_buffer_id]bool, //All array_buffers alive
		frame_buffer_alive : map[Frame_buffer_id]bool, //All array_buffers alive

		vertex_buffers_alive : map[Vbo_ID]bool, //All array_buffers alive
		array_buffers_alive : map[Vao_ID]struct{
			is_alive : bool,
			vertex_attrib_enabled : [8]bool,
		}, //All array_buffers alive

		texture_slots_binds : map[Texture_slot]Texture_id,

		//What is bound
		bound_shader_program : Shader_program_id,
		bound_array_buffer : Vao_ID,
		bound_element_buffer : Vbo_ID,
		//TODO check bound_texture2D 	: Texture_id;
		vertex_buffer_targets : [Vertex_buffer_targets]Vbo_ID,

		bound_frame_buffer_id : Frame_buffer_id,
		bound_read_frame_buffer_id : Frame_buffer_id,
		bound_write_frame_buffer_id : Frame_buffer_id,
	};
}
else {
	Debug_state :: struct {};
}

////////////////////////////////////////////////////////////////////

error_callback : glfw.ErrorProc : proc "c" (error: i32, description: cstring) {
	context = runtime.default_context();
	fmt.panicf("Recvied GLFW error : %v, text : %s", error, description);
}

init_render :: proc(s : ^Render_state($U,$A), uniform_spec : [U]Uniform_info, attribute_spec : [A]Attribute_info, shader_defines : map[string]string, shader_folder : string,
						loc := #caller_location) where intrinsics.type_is_enum(U) && intrinsics.type_is_enum(A) {

	
	glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);

	if(!cast(bool)glfw.Init()){
		panic("Failed to init glfw");
	}
	
	glfw.SetErrorCallback(error_callback);

	/////////////////////
	/*

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
	*/
	
	if shader_folder == "" {
		panic("Unimplemented, todo");
	}	

	//shader_folder_location = strings.clone(shader_folder);
}

destroy_render :: proc(s : ^Render_state($U,$A)) {
	//delete(allowed_uniforms);
	//delete(allowed_attributes);
}

add_shader_defines :: proc (s : Render_state($U,$A), k : string, v : string) {
	panic("TODO");
}

get_requied_uniforms :: proc() -> (s : Render_state($U,$A), res : map[string]Uniform_info) {

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

get_requied_attributes :: proc(s : Render_state($U,$A)) -> map[string]Attribute_info {

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

