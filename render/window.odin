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
	locked 	= glfw.CURSOR_DISABLED,
	hidden 	= glfw.CURSOR_HIDDEN,
	normal 	= glfw.CURSOR_NORMAL,
	bound,	//The cursor will not be able to exit the window.
}

/*
mouse_pos_callback : glfw.CursorPosProc : proc "c" (glfw_window : glfw.WindowHandle, xpos,  ypos: f64) {

	xpos, ypos := xpos, ypos;

	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
	
	context = runtime.default_context(); //TODO, should this no be another context...

	if window_is_focus(window) {
		
		width_i, height_i := window_get_size(window);
		width, height := cast(f64)width_i, cast(f64)height_i;
		
		// Clamp the cursor position to stay within the window boundaries
		if (xpos < 0.0) {
			xpos = 0.0;
		} else if (xpos > width) {
			xpos = width;
		}
		
		if (ypos < 0.0) {
			ypos = 0.0;
		} else if (ypos > height) {
			ypos = height;
		}
		
		// Set the cursor position
		window_set_cursor_position(window, xpos, ypos);
	}

	fmt.printf("xpos, ypos : %v, %v", xpos, ypos);
}
*/

key_callback : glfw.KeyProc : proc "c" (glfw_window : glfw.WindowHandle, key : i32, scancode : i32, action : i32, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
	
	context = runtime.default_context(); //TODO, should this no be another context...

	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

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

	context = runtime.default_context();

	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

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
	
	context = runtime.default_context();

	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

	queue.append(&state.scroll_input_event, [2]f32{auto_cast xoffset, auto_cast yoffset});
}

input_callback : glfw.CharModsProc : proc "c" (glfw_window : glfw.WindowHandle, codepoint: rune, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);

	context = runtime.default_context();

	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);
	
	queue.append(&state.char_input_buffer, codepoint);
}

window_focus_callback : glfw.WindowFocusProc : proc "c" (glfw_window : glfw.WindowHandle, focused : c.int) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);

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

Monitor :: glfw.MonitorHandle;

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
	framebuffer : Frame_buffer,				//This and context_framebuffer makes up the "fake" backbuffer.
	context_framebuffer : Frame_buffer,		//This is the same framebuffer, but it lives in the other (non-main) context.

	resize_behavior : Resize_behavior,
	width, height : i32,
	
	cursor : glfw.CursorHandle, //optional

	//To handle the gl stategl_states
	gl_states : gl.GL_states_comb,
	
	decorated : bool,
	mouse_bound : bool,  // TODO 
	
	//Just to handle fullscreen
	current_fullscreen : Fullscreen_mode,
	old_windowed_rect : [4]i32,

	//
}

Fullscreen_mode :: enum {
	fullscreen,
	borderless_fullscreen,
	windowed,
}

window_make :: proc(width, height : i32, title : string, resize_behavior : Resize_behavior = .resize_backbuffer, antialiasing : Antialiasing = .none, loc := #caller_location) -> (window : ^Window){
	
	desc : Window_desc = {
		width = width,
		height = height,
		title = title,
		resize_behavior = resize_behavior,
		antialiasing = antialiasing,
	}

	return window_make_desc(desc, loc);
}

window_make_desc :: proc(desc : Window_desc, loc := #caller_location) -> (window : ^Window) {
	
	assert(state.is_init == true, "You must call init_render", loc = loc)
	
	/*if desc.resize_behavior == .scale_backbuffer {
		assert(desc.antialiasing == .none, "it is not possiable to do multisampling (MSAA) while having a scaling backbuffer.", loc);
	}*/

	window = new(Window);
	window.gl_states = gl.init_state();
	setup_window_no_backbuffer(desc, window);
	
	//Make a framebuffer in each context shareing the underlaying buffers.
	window.framebuffer = frame_buffer_make_render_buffers(1, desc.width, desc.height, auto_cast desc.antialiasing, .RGBA8, .depth_component24);
	assert(window.framebuffer.id != 0, "something went wrong");
	assert(window.framebuffer.color_format != nil, "something went wrong, color format is nil");
	assert(window.framebuffer.depth_format != nil, "something went wrong, depth format is nil");
	
	_make_context_current(window);
	
	frame_buffer_recreate(&window.context_framebuffer, window.framebuffer);
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
	window.current_fullscreen = .windowed;
	window.decorated = true;

	if desc.resize_behavior == .dont_allow {
		glfw.WindowHint(glfw.RESIZABLE, glfw.FALSE);
	}
	else {
		glfw.WindowHint(glfw.RESIZABLE, glfw.TRUE);
	}

    // Create render window.
    window.glfw_window = glfw.CreateWindow(desc.width, desc.height, fmt.ctprintf("%s", desc.title), nil, state.owner_context);
    assert(window.glfw_window != nil, "Window or OpenGL context creation failed");

	//glfw.SetCursorPosCallback(window.glfw_window, mouse_pos_callback);
	glfw.SetKeyCallback(window.glfw_window, key_callback);
	glfw.SetMouseButtonCallback(window.glfw_window, button_callback);
	glfw.SetScrollCallback(window.glfw_window, scroll_callback);
	glfw.SetCharModsCallback(window.glfw_window, input_callback);
	glfw.SetInputMode(window.glfw_window, glfw.STICKY_KEYS, 1);
	glfw.SetWindowFocusCallback(window.glfw_window, window_focus_callback);

	glfw.SetWindowUserPointer(window.glfw_window, window);

	state.window_in_focus = window;
}

window_destroy :: proc (window : ^Window, loc := #caller_location) {
	
	if window.glfw_window == state.owner_context {
		panic("You should not delete the window if it is created with init. It is destroyed when calling destroy.", loc);
	}

	_make_context_current(window);
	gl.delete_frame_buffer(window.context_framebuffer.id);
	
	_make_context_current(nil);
	frame_buffer_destroy(window.framebuffer);

	index, found := slice.linear_search(state.active_windows[:], window);
	if !found {
		panic("the window you are trying to destroy is not in active windows.")
	}
	unordered_remove(&state.active_windows, index);
	
	if window.cursor != nil {
		glfw.DestroyCursor(window.cursor);
	}

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
		if gl._gl_context != {} {
			helper(con, loc, loc);
		}
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

//Return the monitor in which the window currently resides.
window_get_monitor :: proc (window : ^Window) -> Monitor {

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

	return monitor;
}

window_set_vsync :: proc(enable : bool, loc := #caller_location) {
	assert(state.bound_window == nil || state.bound_window.(^Window).glfw_window == state.owner_context, "window_set_vsync must only be called when the owner_context is active", loc);
	
	state.vsync = enable;
	
	if enable {
		glfw.SwapInterval(1);
	}
	else {
		glfw.SwapInterval(0);
	}
}

//By default the monitor that the screen resides on is used, if monitor parameter is set then that monitor is used.
window_set_fullscreen :: proc(window : ^Window, mode : Fullscreen_mode, monitor : Maybe(Monitor) = nil, width : Maybe(i32) = nil, height : Maybe(i32) = nil, loc := #caller_location) {
	assert(window != nil, "window is nil", loc);
	assert(!state.is_begin_frame, "window_set_fullscreen must be called outside frame_begin/_end, as the window cannot resize while drawing.", loc);
	
	// Get the position of the window
	xpos, ypos := glfw.GetWindowPos(window.glfw_window);
	ww, wh := window_get_size(window);

	monitor := window_get_monitor(window);
	
	mon_mode := glfw.GetVideoMode(monitor);
	assert(mon_mode != nil);

	if mode != .fullscreen {
		assert(width == nil, "width is only allowed to be non-nil if mode is .fullscreen");
		assert(height == nil, "height is only allowed to be non-nil if mode is .fullscreen");
	}

	if mode != window.current_fullscreen {
		
		switch mode {
			case .fullscreen:
				window.old_windowed_rect = {xpos, xpos, ww, wh};
				glfw.SetWindowMonitor(window.glfw_window, monitor, 0, 0, mon_mode.width, mon_mode.height, mon_mode.refresh_rate);

			case .borderless_fullscreen:
				//HAHA, windows does fun stuff, it ignores the SetWindowPos and SetWindowAttrib if the size is set to the same as the window.
				//So on windows this looks like it goes fullscreen, but idk, it might be different of other OS's.
				window.old_windowed_rect = {xpos, xpos, ww, wh};
				glfw.SetWindowAttrib(window.glfw_window, glfw.DECORATED, 0);
				glfw.SetWindowSize(window.glfw_window, mon_mode.width, mon_mode.height);
				glfw.SetWindowPos(window.glfw_window, 0, 0);

			case .windowed:
				r := window.old_windowed_rect;
				glfw.SetWindowMonitor(window.glfw_window, nil, r.x, r.y, r.z, r.w, glfw.DONT_CARE);

				if window.decorated {
					glfw.SetWindowAttrib(window.glfw_window, glfw.DECORATED, 1);
				}
				else {
					glfw.SetWindowAttrib(window.glfw_window, glfw.DECORATED, 0);
				}
		}
	}

	window_set_vsync(state.vsync);
	window.current_fullscreen = mode;
}

window_set_decorations :: proc "contextless" (window : ^Window, decorations : bool) {
	
	window.decorated = decorations;

	if window.decorated {
		glfw.SetWindowAttrib(window.glfw_window, glfw.DECORATED, 1);
	}
	else {
		glfw.SetWindowAttrib(window.glfw_window, glfw.DECORATED, 0);
	}
}

window_should_close :: proc "contextless" (window : ^Window, loc := #caller_location) -> bool {
	return auto_cast glfw.WindowShouldClose(window.glfw_window);
}

window_maximize :: proc "contextless" (window : ^Window) {
	glfw.MaximizeWindow(window.glfw_window);
}

window_focus :: proc "contextless" (window : ^Window) {
	glfw.FocusWindow(window.glfw_window);
}

window_request_attention :: proc "contextless" (window : ^Window) {
	glfw.RequestWindowAttention(window.glfw_window);
}

window_is_focus :: proc "contextless" (window : ^Window) -> bool {
	return state.window_in_focus == window;
}

window_set_position :: proc "contextless" (window : ^Window, x, y : i32) {
	glfw.SetWindowPos(window.glfw_window, x, y);
}

window_get_position :: proc "contextless" (window : ^Window) -> (x, y : i32) {
	return glfw.GetWindowPos(window.glfw_window);
}

window_set_size :: proc "contextless" (window : ^Window, w, h : i32) {
	glfw.SetWindowSize(window.glfw_window, w, h);
}

window_get_size :: proc "contextless" (window : ^Window, loc := #caller_location) -> (w, h : i32) {

	w, h = glfw.GetFramebufferSize(window.glfw_window);
	
	if w == 0 {
		w = window.width;
	}
	if h == 0 {
		h = window.height;
	}

	return;
}

window_set_mouse_mode :: proc "contextless" (window : ^Window, mouse_mode : Mouse_mode, loc := #caller_location) {
	if mouse_mode == .bound {
		window.mouse_bound = true; // TODO 
		glfw.SetInputMode(window.glfw_window, glfw.CURSOR, glfw.CURSOR_NORMAL);
	}
	else {
		window.mouse_bound = false;  // TODO 
		glfw.SetInputMode(window.glfw_window, glfw.CURSOR, auto_cast mouse_mode);
	}
}

//The image data is 32-bit, little-endian, non-premultiplied RGBA, i.e. eight bits per channel. The pixels are arranged canonically as sequential rows, starting from the top-left corner.
//Cleanup happens when window closes or cursor is replaced.
window_set_cursor_icon :: proc (window : ^Window, #any_int width, height : i32, cursor : []u8, loc := #caller_location) {
	
	fmt.assertf(len(cursor) == auto_cast(width * height * 4), "Size does not match array data. Data length : %v, expected : %v\n", len(cursor), width * height * 4, loc = loc)

	if window.cursor != nil {
		glfw.DestroyCursor(window.cursor);
	}

	image : glfw.Image;
	image.width = width;
	image.height = height;
	image.pixels = raw_data(cursor);
	
	window.cursor = glfw.CreateCursor(&image, 0, 0); //TODO this is leaked, i belive.
	glfw.SetCursor(window.glfw_window, window.cursor);
}

window_set_cursor_position :: proc "contextless" (window : ^Window, width, height : f64) {
	glfw.SetCursorPos(window.glfw_window, width, height);
}

//Unlike mouse_pos, this will return the mouse position relative to a window.
window_get_cursor_position :: proc "contextless" (window : ^Window) -> (w, h : f64) {
	return glfw.GetCursorPos(window.glfw_window);
}

/////////////////// Monitor stuff ///////////////////

//This contains everything you might want to know about a monitor, delete with monitor_destroy_infos.
Monitor_info :: struct {
	handle 					: Monitor,
	
	name 					: string,
	is_primary_monitor		: bool,

	pixel_size        		: [2]i32,
	physical_width 			: Maybe([2]i32), // in milimeters

	virtual_position 		: [2]f32,
	work_area 				: [2]f32,

	red_bits				: i32,
	green_bits				: i32,
	blue_bits 				: i32,

	refresh_rate			: i32,
}

monitor_get_infos :: proc () -> []Monitor_info {

	monitors := glfw.GetMonitors();
	
	//glfwGetPrimaryMonitor();

	//GLFWvidmode* modes = glfwGetVideoModes(monitor, &count);

	//const char* name = glfwGetMonitorName(monitor);

	//glfw.GetMonitorPhysicalSize

	//glfwGetMonitorPos(monitor, &xpos, &ypos);

	return {};
}

monitor_destroy_infos :: proc ([]Monitor_info) {

}


/////////////////// OS stuff ///////////////////


//handle os error pop-up messages

//Do os explorerer pop-up







