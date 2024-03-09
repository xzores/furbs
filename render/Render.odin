package render;


import "core:runtime"
import "core:fmt"
import "core:mem"
import "core:strings"
import "core:reflect"
import "core:log"
import "core:container/queue"

import "vendor:glfw"
import fs "vendor:fontstash"

import ex_defs "../../user_defs"
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

init :: proc(uniform_spec : [Uniform_location]Uniform_info, attribute_spec : [Attribute_location]Attribute_info, shader_defines : map[string]string, 
			window_desc : Maybe(Window_desc) = nil, required_gl_verion : Maybe(GL_version) = nil, render_context := context, loc := #caller_location) -> ^Window {
	
	using gl;

	window : ^Window = nil;

	fmt.assertf(mem.check_zero_ptr(&state, size_of(state)), "it looks like the state is not cleared correctly, did you forget to close the last state correctly, or did you already call init_render?\nThe state : %v", state, loc = loc);
	state.render_context = render_context;
	
	// Initialize GLFW
    if !glfw.Init() {
		panic("Could not init glfw\n");
    }
	
	state.shader_defines = make(map[string]string);
	if shader_defines != nil {
		for e, v in shader_defines {
			set_shader_define(e,v);
		}
	}

	state.is_init = true;

    // Set GLFW error callback
    glfw.SetErrorCallback(glfw_error_callback);

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
		assert(desc.resize_behavior == .resize_backbuffer || desc.resize_behavior == .dont_allow, "when calling init with a window descriptor, the resize_behavior must be .resize_backbuffer or .dont_allow", loc);

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

	init_shaders();
	//fs.Init(&state.font_context, 1, 1, .BOTTOMLEFT);	//TODO 1,1 for w and h is might not be the best idea, what should we do instead?

	return window;
}

destroy :: proc (loc := #caller_location) {

	//Check we inited before destroy 
	assert(state.is_init == true, "Cannot destroy renderer as the state is not initialized. Call init first.", loc);
	state.is_init = false;
	state.opengl_version = nil;

	//Reset button and key state
	state.button_down 		= {};
	state.button_released 	= {};
	state.button_pressed 	= {};

	state.keys_down 		= {};
	state.keys_released 	= {};
	state.keys_pressed 		= {};
	state.keys_triggered 	= {};

	state.mouse_pos 		= {};
	state.mouse_delta 		= {};
	state.scroll_delta 		= {};


	//Destroy shaders defines
	for e, v in state.shader_defines {
		delete_key(&state.shader_defines, e);
		delete(e);
		delete(v);
	}

	delete(state.shader_defines); state.shader_defines = {};

	destroy_shaders();
	
	//Check that all sub windows have been destroyed.
	if len(state.active_windows) != 0 {
		panic("You must close all window before calling destroy");
	}
	
	//Destoy active windows
	delete(state.active_windows);
	state.active_windows = {};

	//font context
	fs.Destroy(&state.font_context);
	state.font_context = {};

	//destroy gl
	log.infof("Destroying gl_wrappers");
	gl.destroy();

	//Destroy main window
	fmt.printf("Destorying main window\n");
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
	
	glfw.Terminate();

	//TODO make this so it prints the field that are not mem zero.
	if mem.check_zero_ptr(&state, size_of(State)) {
		for field in reflect.struct_fields_zipped(State) {
			
			ptr : uintptr = cast(uintptr)&state + field.offset;
			val := any{data = auto_cast ptr, id = field.type.id};
			fmt.assertf(mem.check_zero_ptr(val.data, reflect.size_of_typeid(val.id)), "State must be reset before closing (internal error). The field %s is : %#v", field.name, val);
		}
		fmt.panicf("state is not zero : %v", state);
	}

	//state.render_context = {};
}

begin_frame :: proc() {
	
	begin_inputs();
	
	for w in state.active_windows {
		
		if w.is_fullscreen != w.fullscreen_target_state {
			r := w.target_windowed_rect;
			glfw.SetWindowMonitor(w.glfw_window, w.target_monitor, r.x, r.y, r.z, r.w, w.target_refresh); //TODO should we allow setting a refresh rate?
			w.is_fullscreen = !w.is_fullscreen;
		}
		
		if w.resize_behavior == .resize_backbuffer {
			sw, sh := get_screen_size(w);

			if w.framebuffer.width == sw && w.framebuffer.height == sh {
				//do nothing, everything is ok
			}
			else {
				//resize both the framebuffer and the context_framebuffer.
				destroy_frame_buffer(w.framebuffer);
				assert(w.framebuffer.color_format != nil, "w.framebuffer.color_format is nil");
				init_frame_buffer_render_buffers(&w.framebuffer, 1, sw, sh, w.framebuffer.samples, w.framebuffer.color_format, w.framebuffer.depth_format);
				w.width, w.height = sw, sh;

				_make_context_current(w);
				gl.delete_frame_buffer(w.context_framebuffer.id);
				w.context_framebuffer = {}; //set it to zero, before recreation, not required attom.
				recreate_frame_buffer(&w.context_framebuffer, w.framebuffer);
				_make_context_current(nil);
			}
		}
	}
	
	//back to main window//
	_make_context_current(nil);
	gl.bind_frame_buffer(0);
	if state.main_window != nil {
		w := state.main_window;
		
		if w.is_fullscreen != w.fullscreen_target_state {
			r := w.target_windowed_rect;
			glfw.SetWindowMonitor(w.glfw_window, w.target_monitor, r.x, r.y, r.z, r.w, w.target_refresh); //TODO should we allow setting a refresh rate?
			w.is_fullscreen = !w.is_fullscreen;
		}
		state.main_window.width, state.main_window.height = get_screen_size(state.main_window);
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

		dst_width, dst_height = get_screen_size(w);
		gl.blit_fbo_to_screen(w.context_framebuffer.id, 0, 0, w.framebuffer.width, w.framebuffer.height, 0, 0, dst_width, dst_height, true);

		_swap_buffers(loc, w.glfw_window);
	}
	
	_make_context_current(nil);	
	_swap_buffers(loc, state.owner_context);
	glfw.PollEvents();

	end_inputs();
}

set_shader_define :: proc (entry : string, value : string) {
	using strings;

	state.shader_defines[clone(entry)] = clone(value);
}