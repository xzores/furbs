package render;

import "core:fmt"
import "core:runtime"
import "core:slice"
import "core:sync"
import "core:container/queue"
import "core:c"

import "vendor:glfw"

import "gl"

Mouse_mode :: enum {
	locked = glfw.CURSOR_DISABLED,
	hidden = glfw.CURSOR_HIDDEN,
	normal = glfw.CURSOR_NORMAL,
}

key_callback : glfw.KeyProc : proc "c" (glfw_window : glfw.WindowHandle, key : i32, scancode : i32, action : i32, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
	
	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

	context = runtime.default_context();

	event : Key_input_event = {
		window = window,
		key = auto_cast key,
		scancode = auto_cast scancode,
		action = auto_cast action,
		mods = transmute(Input_modifier) mods,
	}

	queue.append(&state.key_input_events, event);
}

button_callback : glfw.MouseButtonProc : proc "c" (glfw_window : glfw.WindowHandle, button, action, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);

	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

	context = runtime.default_context();

	event : Mouse_input_event = {
		window = window,
		button = auto_cast button,
		action = auto_cast action,
		mods = transmute(Input_modifier) mods,
	}
	
	queue.append(&state.button_input_events, event);
}

scroll_callback : glfw.ScrollProc : proc "c" (glfw_window : glfw.WindowHandle, xoffset, yoffset: f64) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
	
	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

	context = runtime.default_context();

	queue.append(&state.scroll_input_event, [2]f32{auto_cast xoffset, auto_cast yoffset});
}

input_callback : glfw.CharModsProc : proc "c" (glfw_window : glfw.WindowHandle, codepoint: rune, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);

	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

	context = runtime.default_context();
	
	queue.append(&state.char_input_buffer, codepoint);
}

window_focus_callback : glfw.WindowFocusProc : proc "c" (glfw_window : glfw.WindowHandle, focused : c.int) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
	
	context = runtime.default_context();

	focused : bool = focused == 1;

    if (focused) {
        // The window gained input focus
		state.window_in_focus = window;
    }
    else if state.window_in_focus == window {
        // The window lost input focus
		state.window_in_focus = nil;
    }
}

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
	//scale_backbuffer, //This stopped working for some reason
}

//TODO this should include, RGA8 vs RGBA8 vs RGB16F vs ....
//TODO This should also include the depth component, so like 16, 24 or 32 bits.
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
	
	//To handle the gl stategl_states
	gl_states : gl.GL_states_comb,

	//Just to handle fullscreen
	is_fullscreen : bool,
	fullscreen_target_state : bool,
	old_windowed_rect : [4]i32,
	target_windowed_rect : [4]i32,
	target_monitor : glfw.MonitorHandle,
	target_refresh : i32,
}

make_window :: proc(width, height : i32, title : string, resize_behavior : Resize_behavior = .resize_backbuffer, antialiasing : Antialiasing = .none, loc := #caller_location) -> (window : ^Window){
	
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
	
	/*if desc.resize_behavior == .scale_backbuffer {
		assert(desc.antialiasing == .none, "it is not possiable to do multisampling (MSAA) while having a scaling backbuffer.", loc);
	}*/

	window = new(Window);
	window.gl_states = gl.init_state();
	setup_window_no_backbuffer(desc, window);
	
	//Make a framebuffer in each context shareing the underlaying buffers.
	init_frame_buffer_render_buffers(&window.framebuffer, 1, desc.width, desc.height, auto_cast desc.antialiasing, .RGBA8, .depth_component24);
	assert(window.framebuffer.id != 0, "something went wrong");
	assert(window.framebuffer.color_format != nil, "something went wrong, color format is nil");
	assert(window.framebuffer.depth_format != nil, "something went wrong, depth format is nil");
	
	_make_context_current(window);
	
	recreate_frame_buffer(&window.context_framebuffer, window.framebuffer);
	assert(window.context_framebuffer.id != 0, "something went wrong");		
	assert(window.context_framebuffer.color_format != nil, "something went wrong, color format is nil");
	assert(window.context_framebuffer.depth_format != nil, "something went wrong, depth format is nil");

	_make_context_current(nil);

	append(&state.active_windows, window);

	return;
}

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

	glfw.SetKeyCallback(window.glfw_window, key_callback);
	glfw.SetMouseButtonCallback(window.glfw_window, button_callback);
	glfw.SetScrollCallback(window.glfw_window, scroll_callback);
	glfw.SetCharModsCallback(window.glfw_window, input_callback);
	glfw.SetInputMode(window.glfw_window, glfw.STICKY_KEYS, 1);
	glfw.SetWindowFocusCallback(window.glfw_window, window_focus_callback);

	glfw.SetWindowUserPointer(window.glfw_window, window);

	state.window_in_focus = window;
}

destroy_window :: proc (window : ^Window, loc := #caller_location) {
	
	if window.glfw_window == state.owner_context {
		panic("You should not delete the window if it is created with init. It is destroyed when calling destroy.", loc);
	}

	_make_context_current(window);
	gl.delete_frame_buffer(window.context_framebuffer.id);
	
	_make_context_current(nil);
	destroy_frame_buffer(window.framebuffer);

	index, found := slice.linear_search(state.active_windows[:], window);
	if !found {
		panic("the window you are trying to destroy is not in active windows.")
	}
	unordered_remove(&state.active_windows, index);

	glfw.DestroyWindow(window.glfw_window);
	gl.destroy_state(window.gl_states);

	free(window);
}

//pass nil to bind the owner context, if there is no main window.
_make_context_current ::proc(window : ^Window, loc := #caller_location) {
	
	helper :: proc(window : glfw.WindowHandle, from_loc : runtime.Source_Code_Location, loc := #caller_location) {
		gl.record_call(from_loc, nil, {window}, loc);
	}

	bind_context :: proc (con : glfw.WindowHandle, loc := #caller_location) {
		if con == state.current_context {
			return;
		}
		helper(con, loc, loc);
		glfw.MakeContextCurrent(con);
		state.current_context = con;
	}

	prev_window : ^Window = nil;

	if w, ok := state.bound_window.?; ok {
		if w == window {
			return;
		}
		prev_window = w;
	}

	old_states : ^gl.GL_states_comb;
	
	if prev_window == nil {
		old_states = &state.owner_gl_states;
	}
	else {
		old_states = &prev_window.gl_states;
	}

	if window == nil {
		//We must bind the owner context.
		bind_context(state.owner_context);
		if prev_window != nil {
			gl.swap_states(&state.owner_gl_states, old_states);
		}
	}
	else {
		bind_context(window.glfw_window);
		gl.swap_states(&window.gl_states, old_states);
	}
	
	state.bound_window = window;
}

enable_vsync :: proc(enable : bool, loc := #caller_location) {
	//assert(state.bound_window == nil || state.bound_window.glfw_window == state.owner_context, "enable_vsync must only be called when the owner_context is active", loc);
	state.vsync = enable;
	glfw.SwapInterval(auto_cast enable);
}

enable_fullscreen :: proc(window : ^Window, enable : bool, loc := #caller_location) {
	assert(window != nil, "window is nil", loc);
	
	if enable && !window.is_fullscreen {
		// Get the position of the window
		xpos, ypos := glfw.GetWindowPos(window.glfw_window);

		// Get the list of monitors
		monitors := glfw.GetMonitors();

		monitor : glfw.MonitorHandle;

		// Iterate through each monitor to find out which monitor the window is on
		for mon in monitors {
			mx, my := glfw.GetMonitorPos(mon);

			video_mode := glfw.GetVideoMode(mon);
			if xpos >= mx && xpos < mx + video_mode.width && ypos >= my && ypos < my + video_mode.height {
				monitor = mon;
			}
		}
		
		assert(monitor != nil);
		mode := glfw.GetVideoMode(monitor);
		assert(mode != nil);
		window.fullscreen_target_state = true;
		window.old_windowed_rect = {xpos, ypos, window.width, window.height};
		window.target_windowed_rect = {0, 0, mode.width, mode.height};
		window.target_monitor = monitor;
		window.target_refresh = mode.refresh_rate;
	}
	else if !enable && window.is_fullscreen {
		window.fullscreen_target_state = false;
		window.old_windowed_rect, window.target_windowed_rect = window.target_windowed_rect, window.old_windowed_rect;
		window.target_monitor = nil;
	}
}

should_close :: proc(window : ^Window, loc := #caller_location) -> bool {
	return auto_cast glfw.WindowShouldClose(window.glfw_window);
}

get_screen_size :: proc(window : ^Window, loc := #caller_location) -> (w, h : i32) {
	
	w, h = glfw.GetFramebufferSize(window.glfw_window);
	
	if w == 0 {
		w = window.width;
	}
	if h == 0 {
		h = window.height;
	}

	return;
}

mouse_mode :: proc(window : ^Window, mouse_mode : Mouse_mode, loc := #caller_location) {
	glfw.SetInputMode(window.glfw_window, glfw.CURSOR, auto_cast mouse_mode);
}



/*
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