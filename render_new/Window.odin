package render;

import "core:fmt"
import "core:runtime"
import "core:slice"

import "vendor:glfw"

import "gl"

Antialiasing :: enum {
	none = 1,
	msaa2 = 2,
	msaa4 = 4,
	msaa8 = 8,
	msaa16 = 16,
	msaa32 = 32,
}

Resize_behavior :: enum {
	dont_allow,
	resize_backbuffer,
	scale_backbuffer,
}

Window_desc :: struct {
	width, height : i32,
	title : string,
	resize_behavior : Resize_behavior,
	antialiasing : Antialiasing,
}

Window :: struct {
	glfw_window : glfw.WindowHandle, //dont touch
	framebuffer : Frame_buffer,			//This and context_framebuffer makes up the "fake" backbuffer.
	context_framebuffer : Frame_buffer,

	resize_behavior : Resize_behavior,
	width, height : i32,
}

make_window_parameterized :: proc(width, height : i32, title : string, resize_behavior : Resize_behavior = .resize_backbuffer, antialiasing : Antialiasing = .none, loc := #caller_location) -> (window : ^Window){

	desc : Window_desc = {
		width = width,
		height = height,
		title = title,
		resize_behavior = resize_behavior,
		antialiasing = antialiasing,
	}

	return make_window_desc(desc, loc);
}

make_window_desc :: proc(desc : Window_desc, loc := #caller_location) -> (window : ^Window) {
	
	assert(state.is_init == true, "You must call init_render", loc = loc)
	
	if desc.resize_behavior == .scale_backbuffer {
		assert(desc.antialiasing == .none, "it is not possiable to do multisampling (MSAA) while having a scaling backbuffer.", loc);
	}

	window = new(Window);
	
	setup_window_no_backbuffer(desc, window);
	
	//Make a framebuffer in each context shareing the underlaying buffers.
	window.framebuffer = make_frame_buffer(1, desc.width, desc.height, auto_cast desc.antialiasing, true, .rgba8, .depth_component24);
	assert(window.framebuffer.id != 0, "something went wrong");
	_make_context_current(window.glfw_window);
	recreate_frame_buffer(&window.context_framebuffer, window.framebuffer);
	assert(window.context_framebuffer.id != 0, "something went wrong");
	_make_context_current(state.owner_context);

	append(&state.active_windows, window);

	return;
}

make_window :: proc {make_window_desc, make_window_parameterized};

@(private)
setup_window_no_backbuffer :: proc(desc : Window_desc, window : ^Window) {

	window.width = desc.width;
	window.height = desc.height;
	window.resize_behavior = desc.resize_behavior;

	if desc.resize_behavior == .dont_allow {
		glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE);
	}
	else {
		glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE);
	}

    // Create render window.
    window.glfw_window = glfw.CreateWindow(desc.width, desc.height, fmt.ctprintf("%s", desc.title), nil, state.owner_context);
    assert(window.glfw_window != nil, "Window or OpenGL context creation failed");
	
	/*
	glfw.SetKeyCallback(window.glfw_window, key_callback);
	glfw.SetMouseButtonCallback(window.glfw_window, button_callback);
	glfw.SetScrollCallback(window.glfw_window, scroll_callback);
	glfw.SetCharModsCallback(window.glfw_window, input_callback);
	glfw.SetInputMode(window.glfw_window, glfw.STICKY_KEYS, 1);
	*/
	
	glfw.SetWindowUserPointer(window.glfw_window, window);
} 

destroy_window :: proc (window : ^Window, loc := #caller_location) {
	
	if window.glfw_window == state.owner_context {
		panic("You should not delete the window if it is created with init. It is destroyed when calling destroy.", loc);
	}

	_make_context_current(window.glfw_window);
	gl.delete_frame_buffer(window.context_framebuffer.id);
	_make_context_current(state.owner_context);
	destroy_frame_buffer(window.framebuffer);

	index, found := slice.linear_search(state.active_windows[:], window);
	if !found {
		panic("the window you are trying to destroy is not in active windows.")
	}
	unordered_remove(&state.active_windows, index);

	glfw.DestroyWindow(window.glfw_window);
	
	free(window);
}

_make_context_current ::proc(window : glfw.WindowHandle, loc := #caller_location) {

	if state.current_context == window {
		return;
	}

	helper :: proc(window : glfw.WindowHandle, from_loc : runtime.Source_Code_Location, loc := #caller_location) {
		gl.record_call(from_loc, nil, {window}, loc);
	}
	
	helper(window, loc);
	glfw.MakeContextCurrent(window);

	state.current_context = window;
} 

@(deprecated="enable_vsync does not take new windows into account")
enable_vsync :: proc(enable : bool) {
	
	for w in state.active_windows {
		_make_context_current(w.glfw_window);
		glfw.SwapInterval(auto_cast enable);
	}

	_make_context_current(state.owner_context);
	glfw.SwapInterval(auto_cast enable);
}

should_close :: proc(window : ^Window, loc := #caller_location) -> bool {
	return auto_cast glfw.WindowShouldClose(window.glfw_window);
}


get_screen_size :: proc(window : ^Window, loc := #caller_location) -> (w, h : i32) {
	
	w, h = glfw.GetFramebufferSize(window.glfw_window);
	return;
}

/*
mouse_mode :: proc(using s : ^Render_state($U,$A), mouse_mode : Mouse_mode, loc := #caller_location) {
	
	glfw.SetInputMode(v.glfw_window, glfw.CURSOR, auto_cast mouse_mode);
}

//The image data is 32-bit, little-endian, non-premultiplied RGBA, i.e. eight bits per channel. The pixels are arranged canonically as sequential rows, starting from the top-left corner.
set_cursor :: proc(using s : ^Render_state($U,$A), cursor : []u8, size : i32, loc := #caller_location) {
	
	fmt.assertf(len(cursor) == auto_cast(size * size * 4), "Size does not match array data. Data length : %v, expected : %v\n", len(cursor), size * size * 4, loc = loc)

	image : glfw.Image;
	image.width = size;
	image.height = size;
	image.pixels = raw_data(cursor);
	
	cursor : glfw.CursorHandle = glfw.CreateCursor(&image, 0, 0); //TODO this is leaked, i belive.
	glfw.SetCursor(window.glfw_window, cursor);
	//glfw.DestroyCursor(cursor);
}
*/