package render;

import "core:fmt"
import "core:sync"
import "core:container/queue"

import "vendor:glfw"

////////// Common //////////

Input_modifier_enum :: enum i32 {
	none = 0,
	
	shift     = 1,
	control   = 2,
	alt       = 4,
	super     = 8,
	caps_lock = 16,
	//num_lock  = 32, //TODO this does not fit
}

Input_state :: enum {
	release = glfw.RELEASE,
	press 	= glfw.PRESS,
	repeat 	= glfw.REPEAT,
}

Input_modifier :: bit_set[Input_modifier_enum; i32];

////////// Keys //////////

Key_code :: enum i32 {

	/* The unknown glfw.KEY */
	invlaid = glfw.KEY_UNKNOWN,

	/** Printable glfw.KEYs **/

	/* Named printable glfw.KEYs */
	space = glfw.KEY_SPACE,
	apostrophe = glfw.KEY_APOSTROPHE,  /* ' */
	comma = glfw.KEY_COMMA,  /* , */
	minus = glfw.KEY_MINUS,  /* - */
	period = glfw.KEY_PERIOD,  /* . */
	slash = glfw.KEY_SLASH,  /* / */
	semicolon = glfw.KEY_SEMICOLON,  /* ; */
	equal = glfw.KEY_EQUAL,  /* :: */
	bracket_left = glfw.KEY_LEFT_BRACKET,  /* [ */
	backslash = glfw.KEY_BACKSLASH,  /* \ */
	bracket_right = glfw.KEY_RIGHT_BRACKET,  /* ] */
	grave_accent = glfw.KEY_GRAVE_ACCENT,  /* ` */
	world_1 = glfw.KEY_WORLD_1, /* non-US #1 */
	world_2 = glfw.KEY_WORLD_2, /* non-US #2 */

	/* Alphanumeric characters */
	zero = glfw.KEY_0,
	one = glfw.KEY_1,
	two = glfw.KEY_2,
	tree = glfw.KEY_3,
	four = glfw.KEY_4,
	five = glfw.KEY_5,
	six = glfw.KEY_6,
	seven = glfw.KEY_7,
	eight = glfw.KEY_8,
	nine = glfw.KEY_9,

	a = glfw.KEY_A,
	b = glfw.KEY_B,
	c = glfw.KEY_C,
	d = glfw.KEY_D,
	e = glfw.KEY_E,
	f = glfw.KEY_F,
	g = glfw.KEY_G,
	h = glfw.KEY_H,
	i = glfw.KEY_I,
	j = glfw.KEY_J,
	k = glfw.KEY_K,
	l = glfw.KEY_L,
	m = glfw.KEY_M,
	n = glfw.KEY_N,
	o = glfw.KEY_O,
	p = glfw.KEY_P,
	q = glfw.KEY_Q,
	r = glfw.KEY_R,
	s = glfw.KEY_S,
	t = glfw.KEY_T,
	u = glfw.KEY_U,
	v = glfw.KEY_V,
	w = glfw.KEY_W,
	x = glfw.KEY_X,
	y = glfw.KEY_Y,
	z = glfw.KEY_Z,

	/* Named non-printable glfw.KEYs */
	escape = glfw.KEY_ESCAPE,
	enter = glfw.KEY_ENTER,
	tab = glfw.KEY_TAB,
	backspace = glfw.KEY_BACKSPACE,
	insert = glfw.KEY_INSERT,
	delete = glfw.KEY_DELETE,
	right = glfw.KEY_RIGHT,
	left = glfw.KEY_LEFT,
	down = glfw.KEY_DOWN,
	up = glfw.KEY_UP,
	page_up = glfw.KEY_PAGE_UP,
	page_down = glfw.KEY_PAGE_DOWN,
	home = glfw.KEY_HOME,
	end = glfw.KEY_END,
	caps_lock = glfw.KEY_CAPS_LOCK,
	scroll_lock = glfw.KEY_SCROLL_LOCK,
	num_lock = glfw.KEY_NUM_LOCK,
	print_screen = glfw.KEY_PRINT_SCREEN,
	pause = glfw.KEY_PAUSE,

	/* Function glfw.KEYs */
	f1 = glfw.KEY_F1,
	f2 = glfw.KEY_F2,
	f3 = glfw.KEY_F3,
	f4 = glfw.KEY_F4,
	f5 = glfw.KEY_F5,
	f6 = glfw.KEY_F6,
	f7 = glfw.KEY_F7,
	f8 = glfw.KEY_F8,
	f9 = glfw.KEY_F9,
	f10 = glfw.KEY_F10,
	f11 = glfw.KEY_F11,
	f12 = glfw.KEY_F12,
	f13 = glfw.KEY_F13,
	f14 = glfw.KEY_F14,
	f15 = glfw.KEY_F15,
	f16 = glfw.KEY_F16,
	f17 = glfw.KEY_F17,
	f18 = glfw.KEY_F18,
	f19 = glfw.KEY_F19,
	f20 = glfw.KEY_F20,
	f21 = glfw.KEY_F21,
	f22 = glfw.KEY_F22,
	f23 = glfw.KEY_F23,
	f24 = glfw.KEY_F24,
	f25 = glfw.KEY_F25,

	/* glfw.KEYpad numbers */
	kp_0 = glfw.KEY_KP_0,
	kp_1 = glfw.KEY_KP_1,
	kp_2 = glfw.KEY_KP_2,
	kp_3 = glfw.KEY_KP_3,
	kp_4 = glfw.KEY_KP_4,
	kp_5 = glfw.KEY_KP_5,
	kp_6 = glfw.KEY_KP_6,
	kp_7 = glfw.KEY_KP_7,
	kp_8 = glfw.KEY_KP_8,
	kp_9 = glfw.KEY_KP_9,

	/* glfw.KEYpad named function glfw.KEYs */
	kp_decimal = glfw.KEY_KP_DECIMAL,
	kp_divide = glfw.KEY_KP_DIVIDE,
	kp_multiply = glfw.KEY_KP_MULTIPLY,
	kp_subtract = glfw.KEY_KP_SUBTRACT,
	kp_add = glfw.KEY_KP_ADD,
	kp_enter = glfw.KEY_KP_ENTER,
	kp_equal = glfw.KEY_KP_EQUAL,

	/* Modifier glfw.KEYs */
	shift_left = glfw.KEY_LEFT_SHIFT,
	control_left = glfw.KEY_LEFT_CONTROL,
	alt_left = glfw.KEY_LEFT_ALT,
	super_left = glfw.KEY_LEFT_SUPER,
	shift_right = glfw.KEY_RIGHT_SHIFT,
	control_right = glfw.KEY_RIGHT_CONTROL,
	alt_right = glfw.KEY_RIGHT_ALT,
	super_right = glfw.KEY_RIGHT_SUPER,
	menu = glfw.KEY_MENU,

	max_keys = glfw.KEY_LAST,
}

Key_input_event :: struct {
	glfw_handle : glfw.WindowHandle,
	key : Key_code,
	scancode : i32,
	action : Input_state,
	mods : Input_modifier,
}

@(require_results)
recive_next_input :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) -> (char : rune, done : bool) {

	check_window(s, window);

	done = queue.len(window.char_input) != 0;
	if done {
		char = queue.pop_front(&window.char_input);
	}
	
	return;
}

get_clipboard_string :: proc(using s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) -> string {
	return glfw.GetClipboardString(window.glfw_window);
}

//constantly down
is_key_down :: proc(using s : ^Render_state($U,$A), window : ^Window, key : Key_code, loc := #caller_location) -> bool {
	return window.keys_down[key];
}

//trigger on pressed key
is_key_pressed :: proc(using s : ^Render_state($U,$A), window : ^Window, key : Key_code, loc := #caller_location) -> bool {
	return window.keys_released[key];
}

//trigger on release key
is_key_released :: proc(using s : ^Render_state($U,$A), window : ^Window, key : Key_code, loc := #caller_location) -> bool {
	return window.keys_pressed[key];
}

//triggers when press and repeat signals
is_key_triggered :: proc(using s : ^Render_state($U,$A), window : ^Window, key : Key_code, loc := #caller_location) -> bool {
	return window.keys_triggered[key];
}

////////// Mouse //////////

Mouse_code :: enum i32 {
	
	/* Mouse buttons */
	mouse_button_1 = 0,
	mouse_button_2 = 1,
	mouse_button_3 = 2,
	mouse_button_4 = 3,
	mouse_button_5 = 4,
	mouse_button_6 = 5,
	mouse_button_7 = 6,
	mouse_button_8 = 7,

	/* Mousebutton aliases */
	left = 0,
	right = 1,
	middel = 2,
}

Mouse_input_event :: struct {
	glfw_handle : glfw.WindowHandle,
	button : Mouse_code, 
	action : Input_state, 
	mods : Input_modifier,
}

//constantly down, button means mouse
is_button_down :: proc(using s : ^Render_state($U,$A), button : Mouse_code, loc := #caller_location) -> bool {
	return window.button_down[button];
}

//trigger on pressed key
is_button_pressed :: proc(using s : ^Render_state($U,$A), button : Mouse_code, loc := #caller_location) -> bool {
	return window.button_pressed[button];
}

//trigger on release key
is_button_released :: proc(using s : ^Render_state($U,$A), button : Mouse_code, loc := #caller_location) -> bool {
	return window.button_released[button];
}

get_mouse_pos :: proc(using s : ^Render_state($U,$A), loc := #caller_location) -> [2]f32 {
	return window.mouse_pos;
}

get_mouse_delta :: proc(using s : ^Render_state($U,$A), loc := #caller_location) -> [2]f32 {
	return window.mouse_delta;
}

get_scroll_delta :: proc(using s : ^Render_state($U,$A), loc := #caller_location) -> [2]f32 {
	return window.scroll_delta;
}

///////////////////////

//Called by begin_frame
@(private)
begin_inputs :: proc(s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) {

	check_window(s, window);

	assert(queue.len(window.key_release_input_events) == 0, "key_release_input_events is not zero, did  you forget to call end_inputs?", loc = loc);

	sync.lock(&window.input_events_mutex);
	defer sync.unlock(&window.input_events_mutex);
	
	mx, my := glfw.GetCursorPos(window.glfw_window);
	new_mouse_pos := [2]f32{auto_cast mx, auto_cast my};
	
	window.mouse_delta = new_mouse_pos - window.mouse_pos;
	window.mouse_pos = new_mouse_pos;

	for queue.len(window.char_input_buffer) != 0 {
		queue.append(&window.char_input, queue.pop_front(&window.char_input_buffer));
	}

	for queue.len(window.scroll_input_event) != 0 {
		window.scroll_delta += queue.pop_front(&window.scroll_input_event);
	}

	for queue.len(window.button_input_events) != 0 {
		event := queue.pop_front(&window.button_input_events);
		
		switch event.action {
			case .press:
				window.button_pressed[event.button] = true;
				window.button_down[event.button] = true;
			case .release:
				window.button_released[event.button] = true;
				queue.append(&window.button_release_input_events, event);
			case .repeat:
				panic("unimplemented");
		}
	}

	for queue.len(window.key_input_events) != 0 {
		event := queue.pop_front(&window.key_input_events);
		
		switch event.action {
			case .press:
				window.keys_pressed[event.key] = true;
				window.keys_triggered[event.key] = true;
				window.keys_down[event.key] = true;
			case .release:
				window.keys_released[event.key] = true;
				queue.append(&window.key_release_input_events, event);
			case .repeat:
				window.keys_triggered[event.key] = true;
		}
	}
}

@(private)
end_inputs :: proc(s : ^Render_state($U,$A), window : ^Window, loc := #caller_location) {

	when ODIN_DEBUG {
		assert(s.bound_window != nil, "A window must be bound", loc = loc);
	}

	sync.lock(&window.input_events_mutex);
	defer sync.unlock(&window.input_events_mutex);
	
	window.scroll_delta = [2]f32{0,0};

	for queue.len(window.button_release_input_events) != 0 {
		event := queue.pop_front(&window.button_release_input_events);

		if event.action == .release {
			window.button_down[event.button] = false;
		}
		else {
			panic("Only release buttons in button_release_input_events");
		}
	}

	for queue.len(window.key_release_input_events) != 0 {
		event := queue.pop_front(&window.key_release_input_events);

		if event.action == .release {
			window.keys_down[event.key] = false;
		}
		else {
			panic("Only release keys in key_release_input_events");
		}
	}

	for &button in window.button_released {
		button = false;
	}

	for &button in window.button_pressed {
		button = false;
	}

	for &key in window.keys_released {
		key = false;
	}

	for &key in window.keys_pressed {
		key = false;
	}

	for &key in window.keys_triggered {
		key = false;
	}

	queue.clear(&window.char_input);

}

//TODO is_cursor_on_screen