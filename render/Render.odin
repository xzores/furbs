package render;

import glfw "vendor:glfw"
import gl "vendor:OpenGL"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"
import fs "vendor:fontstash"
import "core:intrinsics"
import "core:reflect"
import "core:strconv"
import "core:strings"
import "core:fmt"
import "core:runtime"
import "core:sync"
import "core:container/queue"
import "core:time"

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

	///////////// STATE of init ////////////
	render_has_been_init : bool,
	
	///////////// shader stuff ////////////
	default_shader : Shader(U, A),
	
	prj_mat 		: matrix[4,4]f32,
	inv_prj_mat 	: matrix[4,4]f32,

	view_mat 		: matrix[4,4]f32,
	inv_view_mat	: matrix[4,4]f32,

	shader_folder_location : string,

	texture_locations : map[U]Texture_slot,

	///////////// render target size ////////////
	current_render_target_width : f32,
	current_render_target_height : f32,

	///////////// OPENGL stuff ////////////
	opengl_version : GL_version,

	/////////// Texture/font stuff ////////////	
	font_context : fs.FontContext,
	font_texture : Texture2D,
	
	white_texture : Texture2D, //Use get_white_texture to get it as it will init it if it is not.

	//TODO make this a single mesh buffer (for preformance)
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

////////////////////////////////////////////////////////////////////

required_uniforms 	:: 	map[string]Uniform_info {};
required_attributes :: 	map[string]Attribute_info {};

init_render :: proc(s : ^Render_state($U,$A), uniform_spec : [U]Uniform_info, attribute_spec : [A]Attribute_info, texture_locations : map[U]Texture_slot, shader_defines : map[string]string, shader_folder : string, 
						required_gl_verion : GL_version = nil, window_title : string = "furbs window", #any_int window_width : i32 = 600, #any_int window_height : i32 = 600, loc := #caller_location) where intrinsics.type_is_enum(U) && intrinsics.type_is_enum(A) {
	
	assert(s.render_has_been_init == false, "renderer already initiazied");

	/////////////////////
	
	//Copy the map
	s.texture_locations = make(map[U]Texture_slot);
	for k,v in texture_locations {s.texture_locations[k]=v};

	required_uniforms := required_uniforms;
	required_attributes := required_attributes;
	defer delete(required_uniforms);
	defer delete(required_attributes);

	for enum_val in reflect.enum_fields_zipped(U) {
		if enum_val.name in required_uniforms {
			v : Uniform_info = required_uniforms[enum_val.name];
			value : Uniform_info = uniform_spec[auto_cast enum_val.value];
			
			fmt.assertf(v.location == value.location || v.location == -1, "The location of uniform %v does not match, required location %v, given location : %v", enum_val.name, v.location, value.location, loc = loc);
			fmt.assertf(v.uniform_type == value.uniform_type || v.uniform_type == .invalid, "The uniform type of uniform %v does not match, required type %v, given type : %v", enum_val.name, v.uniform_type, value.uniform_type, loc = loc);
			fmt.assertf(v.array_size == value.array_size || v.array_size == -1, "The array size of uniform %v does not match, required array size %v, given array size : %v", enum_val.name, v.array_size, value.array_size, loc = loc);

			delete_key(&required_uniforms, enum_val.name);
		}
	}

	for enum_val in reflect.enum_fields_zipped(A) {
		if enum_val.name in required_attributes {
			v : Attribute_info = required_attributes[enum_val.name];
			value : Attribute_info = attribute_spec[auto_cast enum_val.value];
			
			fmt.assertf(v.attribute_type == value.attribute_type || v.attribute_type == .invalid, "The attribute type of uniform %v does not match, required type %v, given type : %v", enum_val.name, v.attribute_type, value.attribute_type, loc = loc);

			delete_key(&required_attributes, enum_val.name);
		}
	}
	
	if len(required_uniforms) != 0 {
		fmt.panicf("The following uniforms are required but not included : \n %v \n", required_uniforms);
	}

	if len(required_attributes) != 0 {
		fmt.panicf("The following attributes are required but not included : \n %v \n", required_attributes);
	}

	if shader_defines != nil {
		for e, v in shader_defines {
			set_shader_define(s,e,v);
		}
	}

	if shader_folder == "" {
		panic("Unimplemented, todo, you must have a shader folder!");
	}

	s.shader_folder_location = strings.clone(shader_folder);

	//////////////////////////////// glfw CODE BELOW ////////////////////////////////

	if(!cast(bool)glfw.Init()){
		panic("Failed to init glfw");
	}
	glfw.SetErrorCallback(error_callback);
	fmt.printf("inited glfw\n");


	/*
	time.stopwatch_start(&s.window.startup_timer);

	if required_gl_verion >= GL_version.opengl_3_2 {
		glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
	}
	if required_gl_verion != nil {
		glfw.WindowHint_int(glfw.CONTEXT_VERSION_MAJOR, auto_cast get_gl_major(required_gl_verion));
		glfw.WindowHint_int(glfw.CONTEXT_VERSION_MINOR, auto_cast get_gl_minor(required_gl_verion));
	}

    // Create render window.
    glfw_window := glfw.CreateWindow(window_width, window_height, fmt.ctprintf("%s", window_title), nil, nil);
    fmt.assertf(glfw_window != nil, "Window or OpenGL context creation failed, glfw_window is : %v", glfw_window);
	s.window.glfw_window = glfw_window;

	glfw.MakeContextCurrent(s.window.glfw_window);
	
	glfw.SetKeyCallback(s.window.glfw_window, key_callback);
	glfw.SetMouseButtonCallback(s.window.glfw_window, button_callback);
	glfw.SetScrollCallback(s.window.glfw_window, scroll_callback);
	glfw.SetCharModsCallback(s.window.glfw_window, input_callback);
	glfw.SetInputMode(s.window.glfw_window, glfw.STICKY_KEYS, 1);

	//Load 1.0 to get access to the "get_gl_version" function and then load the actual verison afterwards.
	gl.load_up_to(1, 0, glfw.gl_set_proc_address);
	version := get_gl_version(s);

	//TODO, enum cannot be below 3.3 //assert(version >= .opengl_3_3, "This library only supports OpenGL 3.0 or higher")
	if required_gl_verion != nil {
		//load the specified
		assert(version >= required_gl_verion, "OpenGL version is not new enough for the required version");
		gl.load_up_to(get_gl_major(required_gl_verion), get_gl_major(required_gl_verion), glfw.gl_set_proc_address);
		s.opengl_version = required_gl_verion;
	}
	else {
		//load the newest
		gl.load_up_to(get_gl_major(version), get_gl_major(version), glfw.gl_set_proc_address);
		s.opengl_version = version;
	}

	s.window.window_context = context;
	fmt.printf("Loaded opengl version : %v\n", s.opengl_version);

	//TODO check that we dont exceed max textures assert(get_max_supported_active_textures() >= auto_cast len(texture_locations));
	init_shaders(s);
	glfw.MakeContextCurrent(nil);
	
	bind_window(s);

	//TODO 1,1 for w and h is might not be the best idea, what should we do instead?
	fs.Init(&s.font_context, 1, 1, .BOTTOMLEFT);

	glfw.SetWindowUserPointer(s.window.glfw_window, &s.window); // :: proc(window.glfw_window, window) //TODO this window and then pointer
	*/

	s.render_has_been_init = true;
}

destroy_render :: proc(using s : ^Render_state($U,$A), loc := #caller_location) {
	
	//assert(bound_window == &s.window, "The window must be bound when calling destroy_render", loc = loc);

	unload_shader(s, &s.default_shader);
	delete(shader_folder_location);
	
	delete_map(s.texture_locations);

	unbind_window(s);

	/////////// Texture/font stuff ////////////	
	/*
	if font_context != nil {
		fs.destroy_font(font_context);
	}
	
	if is_texture_real(font_texture) {
		destroy_texture(font_texture);
	}
	
	if is_texture_real(white_texture) {
		destroy_texture(white_texture);
	}

	//TODO make this a single mesh buffer (for preformance)
	destroy_mesh(shape_quad);
	destroy_mesh(shape_circle);
	
	/////////// Shaders ///////////
	destroy_shaders(s);

	//TODO check that all things has been destroyed in debug mode.
	*/
	
	glfw.Terminate();
	fmt.printf("terminated glfw\n");
	
}

set_shader_define :: proc (s : ^Render_state($U,$A), k : string, v : string) {
	panic("TODO");
}


