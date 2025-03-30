package render;


import "base:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:reflect"
import "core:log"
import "core:container/queue"

import "core:os"
import "core:time"

import "vendor:glfw"
import fs "vendor:fontstash"

import ex_defs "../../furbs_defs"
import "gl"

////////////////////////////// Defines //////////////////////////////

Uniform_location :: ex_defs.Uniform_location;
Attribute_location :: ex_defs.Attribute_location;
Texture_location :: ex_defs.Texture_location;

Shader_program_id :: gl.Shader_program_id;
//Shader_vertex_id :: gl.Shader_vertex_id;
//Shader_fragment_id :: gl.Shader_fragment_id;

Texture_id :: gl.Texture_id;

Attribute_id :: gl.Attribute_id;
Uniform_id :: gl.Uniform_id;

Vao_id :: gl.Vao_id;
Fbo_id :: gl.Fbo_id;
Rbo_id :: gl.Rbo_id;
Buffer_id :: gl.Buffer_id;

Uniform_type :: gl.Uniform_type;
Attribute_type :: gl.Attribute_type;
Attribute_primary_type :: gl.Attribute_primary_type;

//return the "entries" or number of dimensions. numbers are between 0 and 4.
get_attribute_type_dimensions :: gl.get_attribute_type_dimensions;

get_attribute_primary_type :: gl.get_attribute_primary_type;
get_attribute_primary_byte_len :: gl.get_attribute_primary_byte_len;

Cull_method :: gl.Cull_method;
Polygon_mode :: gl.Polygon_mode;
Primitive :: gl.Primitive;
Blend_mode :: gl.Blend_mode;

GL_version :: gl.GL_version;

Fence :: gl.Fence;

MAX_COLOR_ATTACH :: gl.MAX_COLOR_ATTACH;

////////////////////////////// structs //////////////////////////////

Render_target :: union {
	^Window,
	^Frame_buffer,
}

Uniform_info :: gl.Uniform_info;
Attribute_info :: gl.Attribute_info;

////////////////////////////// FUNCTIONS //////////////////////////////

glfw_error_callback : glfw.ErrorProc : proc "c" (error: i32, description: cstring) {
	context = runtime.default_context();
	fmt.panicf("Recvied GLFW error : %v, text : %s", error, description);
}

//uniform_spec : [Uniform_location]Uniform_info, attribute_spec : [Attribute_location]Attribute_info,
init :: proc(shader_defines : map[string]string, window_desc : Maybe(Window_desc) = nil, required_gl_verion : Maybe(GL_version) = nil, render_context := context, pref_warn := true, loc := #caller_location) -> ^Window {
	
	using gl;

	window : ^Window = nil;
	
	when ODIN_BUILD_MODE == .Executable {
		state_ptr := &state;
	}
	else when ODIN_BUILD_MODE == .Dynamic {
		state_ptr := state;
	}
	else {
		#panic("What here?");
	}
	
	fmt.assertf(mem.check_zero_ptr(state_ptr, size_of(state)), "it looks like the state is not cleared correctly, did you forget to close the last state correctly, or did you already call init_render?\nThe state : %v", state, loc = loc);
	state.render_context = render_context;
	state.time_start = time.now();
	state.time_last = time.now();

	// Initialize GLFW
	if !glfw.Init() {
		panic("Could not init glfw\n");
	}
	
	state.shader_defines = make(map[string]string, loc = loc);
	if shader_defines != nil {
		for e, v in shader_defines {
			set_shader_define(e,v);
		}
	}

	state.is_init = true;
	enable_preformence_warnings(pref_warn);

	// Set GLFW error callback
	glfw.SetErrorCallback(glfw_error_callback);

	//SHOULD THIS BE A THING? glfw.WindowHint(glfw.REFRESH_RATE, glfw.DONT_CARE);

	if required_verion, ok := required_gl_verion.?; ok {
		if required_verion != nil {
			glfw.WindowHint_int(glfw.CONTEXT_VERSION_MAJOR, auto_cast get_major(required_verion));
			glfw.WindowHint_int(glfw.CONTEXT_VERSION_MINOR, auto_cast get_minor(required_verion));
		}
	}
	
	when ODIN_OS == .Windows {
		glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
		glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6);
	}
	else when ODIN_OS == .Darwin { //Mac_os, idk something that is needed (I think)
		glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
		glfw.WindowHint(glfw.OPENGL_FORWARD_COMPAT, glfw.TRUE);
		glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
		glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 1);
	}
	else when ODIN_OS == .Linux {
		glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 4);
		glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 6);
	}
	else {
		panic("TODO");
	}

	//when in debug, do the thing
	when ODIN_DEBUG {
		glfw.WindowHint(glfw.OPENGL_DEBUG_CONTEXT, glfw.TRUE);
	}
	
	if desc, ok := window_desc.?; ok {
		assert(desc.resize_behavior == .allow_resize || desc.resize_behavior == .dont_allow_resize, "when calling init with a window descriptor, the resize_behavior must be .resize_backbuffer or .dont_allow", loc);

		if desc.antialiasing != .none {
			glfw.WindowHint_int(glfw.SAMPLES, auto_cast desc.antialiasing);
		}
		
		window = new(Window);
		window.gl_states = gl.init_state();
		setup_window_no_backbuffer(desc, window);
		
		state.owner_context = window.glfw_window;
		state.owner_gl_states = window.gl_states
		state.main_window = window;
	}
	else {
		// Create a dummy window for context sharing
		glfw.WindowHint(glfw.VISIBLE, glfw.FALSE);  // Make the window invisible
		state.owner_context = glfw.CreateWindow(1, 1, "you should not see this window", nil, nil);
		state.owner_gl_states = gl.init_state();
		glfw.WindowHint(glfw.VISIBLE, glfw.TRUE);
	}

	if state.owner_context == nil {
		fmt.printf("Failed to open window");
		glfw.Terminate();
	}

	_make_context_current(nil);

	load_up_to(.opengl_3_0, glfw.gl_set_proc_address);
	version := get_version();
	
	if required_verion, ok := required_gl_verion.?; ok {
		//load the specified
		assert(version >= required_verion, "OpenGL version is not new enough for the requied version");
		load_up_to(required_verion, glfw.gl_set_proc_address);
		state.opengl_version = required_verion;
	}
	else {
		//load the newest
		load_up_to(version, glfw.gl_set_proc_address);
		state.opengl_version = version;
	}

	gl.init(); //call after load_up_to

	/*
	supported_attribs := get_max_supported_attributes();
	assert(supported_attribs <= len(static_attrib_info) + len(dynamic_attrib_info), "The GPU does not support the amount of attributes needed", loc);
	*/
	
	state.default_copy_fbo = gl.gen_frame_buffer("default_copy_FBO", loc);
	
	shaders_init(loc = loc);
	text_init(loc = loc);
	
	return window;
}

destroy :: proc (loc := #caller_location) {

	when ODIN_BUILD_MODE == .Executable {
		state_ptr := &state;
	}
	else when ODIN_BUILD_MODE == .Dynamic {
		state_ptr := state;
	}
	else {
		#panic("What here?");
	}

	//Check we inited before destroy 
	assert(state.is_init == true, "Cannot destroy renderer as the state is not initialized. Call init first.", loc);
	state.is_init = false;
	state.opengl_version = nil;

	//Reset button and key state
	state.button_down		= {};
	state.button_released	= {};
	state.button_pressed	= {};

	state.keys_down		= {};
	state.keys_released	= {};
	state.keys_pressed		= {};
	state.keys_triggered	= {};
	
	state.old_mouse_pos	= {};
	state.mouse_delta		= {};
	state.scroll_delta		= {};

	//Extras
	state.fps_measurement	= {};
	if state.overlay_init {
		frame_buffer_destroy(state.arrow_fbo);			state.arrow_fbo = {};
		pipeline_destroy(state.shapes_pipeline);		state.shapes_pipeline = {};
		pipeline_destroy(state.overlay_pipeline);		state.overlay_pipeline = {};
	}
	state.overlay_init = false;
	
	gl.delete_frame_buffer(state.default_copy_fbo); state.default_copy_fbo = 0;
	
	//Destroy shaders defines
	for e, v in state.shader_defines {
		delete_key(&state.shader_defines, e);
		delete(e);
		delete(v);
	}

	delete(state.shader_defines); state.shader_defines = {};

	if state.white_texture != {} {
		texture2D_destroy(state.white_texture);
		state.white_texture = {};
	}

	if state.black_texture != {} {
		texture2D_destroy(state.black_texture);
		state.black_texture = {};
	}
	
	text_destroy();
	shapes_destroy();
	shaders_destroy();
	
	//Check that all sub windows have been destroyed.
	if len(state.active_windows) != 0 {
		log.errorf("You must close all window before calling destroy (except for the window created with init)");
	}
	
	//Destoy active windows
	delete(state.active_windows);
	state.active_windows = {};

	//destroy gl
	log.infof("Destroying gl_wrappers");
	gl.destroy();

	//Destroy main window
	log.infof("Destorying main window");
	glfw.DestroyWindow(state.owner_context);
	state.owner_context = nil;
	state.bound_window = nil;

	if state.main_window != nil {
		free(state.main_window);
		state.main_window = nil;
	}

	queue.destroy(&state.key_input_events);
	queue.destroy(&state.key_release_input_events);
	queue.destroy(&state.char_input_buffer);
	queue.destroy(&state.char_input);
	queue.destroy(&state.button_input_events);
	queue.destroy(&state.button_release_input_events);
	queue.destroy(&state.scroll_input_event);

	state.key_input_events				= {};
	state.key_release_input_events		= {};
	state.char_input_buffer			= {};
	state.char_input					= {};
	state.button_input_events			= {};
	state.button_release_input_events	= {};
	state.scroll_input_event			= {};
	
	state.current_context	= nil;
	state.vsync			= false;
	state.window_in_focus	= nil;
	state.render_context	= {};
	
	state.time_start	= {};
	state.time_last	= {};
	state.delta_time	= {};
	state.time_elapsed	= {};

	state.pref_warn = false;

	glfw.Terminate();
	
	if !mem.check_zero_ptr(state_ptr, size_of(State)) {
		for field in reflect.struct_fields_zipped(State) {
			ptr : uintptr = cast(uintptr)state_ptr + field.offset;
			val := any{data = cast(rawptr)ptr, id = field.type.id};

			if !mem.check_zero_ptr(val.data, reflect.size_of_typeid(val.id)) {
				fmt.printf("field.name, val : %v\n", field.name);
			}
			
			fmt.assertf(mem.check_zero_ptr(val.data, reflect.size_of_typeid(val.id)), "\033[31mState must be reset before closing (internal error). The field %s is : %#v\n\033[0m", field.name, val);
		}
		//panic("state is not zero");
	}
}

begin_frame :: proc() {
	
	now := time.now();
	state.time_elapsed = cast(f32)time.duration_seconds(time.diff(state.time_start, now));
	state.delta_time = cast(f32)time.duration_seconds(time.diff(state.time_last, now));
	state.time_last = now;
	
	state.is_begin_frame = true;

	for w in &state.active_windows {
		
		sw, sh := window_get_size(w);
		
		if w.framebuffer.width != sw || w.framebuffer.height != sh {
			frame_buffer_destroy(w.framebuffer);
			render_buffer, ok := w.framebuffer.color_attachments[0].(Color_render_buffer);
			assert(ok == true, "window.framebuffer.color_format is nil");
			w.framebuffer = frame_buffer_make_render_buffers({render_buffer.format}, sw, sh, w.framebuffer.samples, w.framebuffer.depth_format);
			w.width, w.height = sw, sh;
			
			_make_context_current(w);
			gl.delete_frame_buffer(w.context_framebuffer.id);
			w.context_framebuffer = {}; //set it to zero, before recreation, not required atm.
			frame_buffer_recreate(&w.context_framebuffer, w.framebuffer);
			_make_context_current(nil);
		}
	}
	
	if state.main_window != nil {
		state.main_window.width, state.main_window.height = window_get_size(state.main_window);
	}

	input_begin();
	
	_make_context_current(nil);
	gl.bind_frame_buffer(0);
	
	//auto reload shaders
	if true {
		for shader in state.loaded_shaders {
			if load, ok := shader.loaded.?; ok {
				
				file, err := os.stat(load.path);
				defer os.file_info_delete(file);
				
				if time.duration_seconds(time.diff(file.modification_time, load.time_stamp)) <= 0 {
					shader_reload(shader);
				}

			}
		}
	}
}

end_frame :: proc(loc := #caller_location) {
	
	_swap_buffers :: proc (from_loc : runtime.Source_Code_Location, w : glfw.WindowHandle, loc := #caller_location) {
		glfw.SwapBuffers(w);
		gl.record_call(from_loc, nil, {w});
	}

	for w in state.active_windows {
		_make_context_current(w);
		
		dst_width, dst_height : i32;

		dst_width, dst_height = window_get_size(w);
		gl.blit_fbo_color_to_screen(w.context_framebuffer.id, 0, 0, 0, w.framebuffer.width, w.framebuffer.height, 0, 0, dst_width, dst_height, true);

		_swap_buffers(loc, w.glfw_window);
	}
	
	_make_context_current(nil);	
	_swap_buffers(loc, state.owner_context);
	glfw.PollEvents();
	
	input_end();

	state.is_begin_frame = false;
}

Stored_target :: struct {
	target : Render_target,
	pipeline : Stored_pipeline,
}

store_target :: proc(loc := #caller_location) -> Stored_target {
	old_target := state.current_target;
	pipe := store_pipeline();
	target_end(loc);
	return { old_target, pipe };
}

restore_target :: proc(stored : Stored_target, loc := #caller_location) {
	target_begin(stored.target, nil, nil, loc);
	restore_pipeline(stored.pipeline, loc);
}

Stored_pipeline :: struct {
	pipeline : Pipeline,
	camera : Camera_matrices,
}

store_pipeline :: proc(loc := #caller_location) -> Stored_pipeline {
	old_pipeline, old_cam := state.current_pipeline, state.camera;
	pipeline_end(loc);
	
	return {old_pipeline, old_cam};
}

restore_pipeline :: proc(state : Stored_pipeline, loc := #caller_location) {
	pipeline_begin(state.pipeline, state.camera, loc);
}

set_shader_define :: proc (entry : string, value : string) {
	using strings;

	state.shader_defines[clone(entry)] = clone(value);
}

delta_time :: proc () -> f32 {
	return state.delta_time;
}

elapsed_time :: proc () -> f32 {
	return state.time_elapsed;
}

get_render_target_size :: proc (target : Render_target) -> (w, h : i32){

	switch v in target {
		case ^Frame_buffer:
			return v.width, v.height;
		case ^Window:
			return v.width, v.height;
	}

	unreachable();
}
