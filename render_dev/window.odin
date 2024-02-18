package render;

import "core:strings"
import "core:runtime"
import "core:fmt"
import "core:container/queue"
import "core:sync"
import "core:mem"
import "core:time"

import "vendor:glfw"
import gl "vendor:OpenGL"

import fs "vendor:fontstash"

Mouse_mode :: enum {
	locked = glfw.CURSOR_DISABLED,
	hidden = glfw.CURSOR_HIDDEN,
	normal = glfw.CURSOR_NORMAL,
}

check_window :: proc(s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) {
	when ODIN_DEBUG {
		if s.bound_window != nil {
			assert(s.bound_window == window, "The window that was passes in not the bound window", loc = loc);
		} else {
			panic("No window is bound", loc = loc);
		}
	}
}

key_callback : glfw.KeyProc : proc "c" (glfw_window : glfw.WindowHandle, key : i32, scancode : i32, action : i32, mods : i32) {	
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);

	context = window.window_context;
	
	sync.lock(&window.input_events_mutex);
	defer sync.unlock(&window.input_events_mutex);

	assert(window != nil, "window is nil");

	event : Key_input_event = {
		glfw_handle = window.glfw_window,
		key = auto_cast key,
		scancode = auto_cast scancode,
		action = auto_cast action,
		mods = transmute(Input_modifier) mods,
	}
	
	queue.append(&window.key_input_events, event);
}

button_callback : glfw.MouseButtonProc : proc "c" (glfw_window : glfw.WindowHandle, button, action, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
		
	context = window.window_context;
	
	sync.lock(&window.input_events_mutex);
	defer sync.unlock(&window.input_events_mutex);
	
	assert(window != nil, "window is nil");

	event : Mouse_input_event = {
		glfw_handle = window.glfw_window,
		button = auto_cast button,
		action = auto_cast action,
		mods = transmute(Input_modifier) mods,
	}
	
	queue.append(&window.button_input_events, event);
}

scroll_callback : glfw.ScrollProc : proc "c" (glfw_window : glfw.WindowHandle, xoffset, yoffset: f64) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);
	
	context = window.window_context;

	sync.lock(&window.input_events_mutex);
	defer sync.unlock(&window.input_events_mutex);

	assert(window != nil, "window is nil");

	queue.append(&window.scroll_input_event, [2]f32{auto_cast xoffset, auto_cast yoffset});
}

error_callback : glfw.ErrorProc : proc "c" (error: i32, description: cstring) {
	context = runtime.default_context();
	fmt.panicf("Recvied GLFW error : %v, text : %s", error, description);
}

/*
input_callback : glfw.CharProc : proc "c" (window : glfw.WindowHandle, codepoint: rune) {
	sync.lock(&input_events_mutex);
	defer sync.unlock(&input_events_mutex);

	context = window_context;
	
	queue.append(&char_input_buffer, codepoint);
}
*/

input_callback : glfw.CharModsProc : proc "c" (glfw_window : glfw.WindowHandle, codepoint: rune, mods : i32) {
	window : ^Window = cast(^Window)glfw.GetWindowUserPointer(glfw_window);

	context = window.window_context;

	sync.lock(&window.input_events_mutex);
	defer sync.unlock(&window.input_events_mutex);

	assert(window != nil, "window is nil");

	queue.append(&window.char_input_buffer, codepoint);
}

Window :: struct {
	
	glfw_window : glfw.WindowHandle, //dont touch
	startup_timer : time.Stopwatch,
	frame_timer : time.Stopwatch,

	window_context : runtime.Context,

	//Current key state
	keys_down 		: #sparse [Key_code]bool,
	keys_released 	: #sparse [Key_code]bool,
	keys_pressed 	: #sparse [Key_code]bool,
	keys_triggered 	: #sparse [Key_code]bool,

	button_input_events : queue.Queue(Mouse_input_event),
	button_release_input_events : queue.Queue(Mouse_input_event),

	scroll_input_event : queue.Queue([2]f32),
	
	//Current key state
	button_down 	: [Mouse_code]bool,
	button_released : [Mouse_code]bool,
	button_pressed 	: [Mouse_code]bool,

	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,

	//Locks
	input_events_mutex : sync.Mutex,
	key_input_events : queue.Queue(Key_input_event),
	key_release_input_events : queue.Queue(Key_input_event),
	char_input_buffer : queue.Queue(rune),
	char_input : queue.Queue(rune),
}

init_window :: proc(s : ^Render_state($U,$A), width, height : i32, title : string, shader_folder : string, required_gl_verion : Maybe(GL_version) = nil, loc := #caller_location) -> (window : ^Window) {
	assert(s.render_has_been_init == true, "You must call init_render", loc = loc)
	
	window = new(Window);

	window.window_context = context;

	s.shader_folder_location = strings.clone(shader_folder);
	
	time.stopwatch_start(&window.startup_timer);

	if required_verion, ok := required_gl_verion.?; ok {
		if required_verion >= GL_version.opengl_3_2 {
			glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE);
		}
		if required_verion != nil {
			glfw.WindowHint_int(glfw.CONTEXT_VERSION_MAJOR, auto_cast get_gl_major(required_verion));
			glfw.WindowHint_int(glfw.CONTEXT_VERSION_MINOR, auto_cast get_gl_minor(required_verion));
		}
	}

    // Create render window.
    window.glfw_window = glfw.CreateWindow(width, height, fmt.ctprintf("%s", title), nil, nil)
    assert(window.glfw_window != nil, "Window or OpenGL context creation failed");

	glfw.MakeContextCurrent(window.glfw_window);
	
	glfw.SetKeyCallback(window.glfw_window, key_callback);
	glfw.SetMouseButtonCallback(window.glfw_window, button_callback);
	glfw.SetScrollCallback(window.glfw_window, scroll_callback);
	glfw.SetCharModsCallback(window.glfw_window, input_callback);
	glfw.SetInputMode(window.glfw_window, glfw.STICKY_KEYS, 1);

	//Load 1.0 to get access to the "get_gl_version" function and then load the actual verison afterwards.
	gl.load_up_to(1, 0, glfw.gl_set_proc_address);
	version := get_gl_version(s);

	//TODO, enum cannot be below 3.3 //assert(version >= .opengl_3_3, "This library only supports OpenGL 3.0 or higher")
	if required_verion, ok := required_gl_verion.?; ok {
		//load the specified
		assert(version >= required_verion, "OpenGL version is not new enough for the required version");
		gl.load_up_to(get_gl_major(required_verion), get_gl_major(required_verion), glfw.gl_set_proc_address);
	}
	else {
		//load the newest
		gl.load_up_to(get_gl_major(version), get_gl_major(version), glfw.gl_set_proc_address);
	}
	s.opengl_version = version;

	fmt.printf("Loaded opengl version : %v\n", s.opengl_version);

	//TODO only for the first window...
	//TODO assert(get_max_supported_active_textures() >= auto_cast len(texture_locations));
	init_shaders(s);
	//TODO 1,1 for w and h is might not be the best idea, what should we do instead?
	fs.Init(&s.font_context, 1, 1, .BOTTOMLEFT); //TODO try TOPLEFT and BOTTOMLEFT
	
	glfw.SetWindowUserPointer(window.glfw_window, window);

	glfw.MakeContextCurrent(nil);

	return;
}

destroy_window :: proc(using s : ^Render_state($U,$A), window : ^Window, loc :=  #caller_location) {
	
	/*
	TODO what here
	unbind_window(s, window);

	if v, ok :=s.bound_window.?; ok {
		assert(v != window^, "The window must be unbound before it can be delelted", loc = loc);
	}
	*/
	
	fs.Destroy(&font_context);

	glfw.DestroyWindow(window.glfw_window);
	window.glfw_window = nil;
	//TODO //window_context = {};
	free(window);
}

bind_window :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) {
	
	when ODIN_DEBUG {
		if s.bound_window != nil {
			panic("Another window is already bound", loc = loc);
		}
		s.bound_window = window;
	}

	glfw.MakeContextCurrent(window.glfw_window);

}

unbind_window :: proc(using s : ^Render_state($U,$A), loc := #caller_location) {

	when ODIN_DEBUG {
		assert(s.bound_window != nil, "There is no window bound in the first place", loc);
		s.bound_window = nil;
	}

	glfw.MakeContextCurrent(nil);
}

begin_frame :: proc(using s : ^Render_state($U,$A), window : ^Window, clear_color : [4]f32 = {0,0,0,1}, loc := #caller_location) {

	check_window(s, window, loc);

	when ODIN_DEBUG {
		assert(s.is_begin_render == false, "begin render has already been called this frame.", loc = loc);
		s.is_begin_render = true;
	}

	time.stopwatch_start(&window.frame_timer);
	
	glfw.PollEvents();
	clear_color_depth(s, clear_color);

	begin_inputs(s, window);

} 

end_frame :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) {
	check_window(s, window, loc);
	when ODIN_DEBUG {
		assert(s.is_begin_render == true, "begin render has not been called this frame.", loc = loc);
		s.is_begin_render = false;
	}

	end_inputs(s, window);

	glfw.SwapBuffers(window.glfw_window);
	
	time.stopwatch_stop(&window.frame_timer);
	ms := time.duration_seconds(time.stopwatch_duration(window.frame_timer));
	glfw.SetWindowTitle(window.glfw_window, fmt.ctprintf("%s (%iFPS)", "my window : ", i32(1.0/(ms))));
	time.stopwatch_reset(&window.frame_timer);
}

should_close :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) -> bool {
	return auto_cast glfw.WindowShouldClose(window.glfw_window);
}

enable_vsync :: proc(using s : ^Render_state($U,$A), enable : bool) {
	glfw.SwapInterval(auto_cast enable);
}

get_screen_width :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) -> i32{
	
	w, h := glfw.GetFramebufferSize(window.glfw_window);
	return w;
}

get_screen_height :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) -> i32 {
	
	w, h := glfw.GetFramebufferSize(window.glfw_window);
	return h;
}

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

delta_time :: proc(using s : ^Render_state($U,$A)) -> f32 {
	return 1.0/120;
}

time_since_window_creation :: proc(using s : ^Render_state($U,$A)) -> f64 {
	
	return time.duration_seconds(time.stopwatch_duration(v.startup_timer));
}