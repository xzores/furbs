package render;

import "core:container/queue"

import "vendor:glfw"
import fs "vendor:fontstash"

import "gl"

//This contains high-level state, go to wrappers to see the opengl client side state.

state : State;

State :: struct {
	
	//Input stuff
	button_down 	: [Mouse_code]bool,
	button_released : [Mouse_code]bool,
	button_pressed 	: [Mouse_code]bool,
	
	keys_down 		: #sparse [Key_code]bool,
	keys_released 	: #sparse [Key_code]bool,
	keys_pressed 	: #sparse [Key_code]bool,
	keys_triggered 	: #sparse [Key_code]bool,

	key_input_events : queue.Queue(Key_input_event),
	key_release_input_events : queue.Queue(Key_input_event),
	
	char_input_buffer : queue.Queue(rune),
	char_input : queue.Queue(rune),

	button_input_events : queue.Queue(Mouse_input_event),
	button_release_input_events : queue.Queue(Mouse_input_event),

	scroll_input_event : queue.Queue([2]f32),

	mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,

	//Render init variable
	is_init : bool,
	
	//Window stuff
	owner_context : glfw.WindowHandle,
	owner_gl_states : gl.GL_states_comb,
	opengl_version : GL_version,
	active_windows : [dynamic]^Window,
	vsync : bool,
	
	bound_window : Maybe(^Window),
	window_in_focus : ^Window,

	main_window : ^Window,

	target_pixel_width, target_pixel_height : f32,

	//Text stuff
	font_context : fs.FontContext,
	
	//Shader stuff
	is_init_shader : bool,
	default_shader : ^Shader,
	shader_defines : map[string]string,

	loaded_shaders : [dynamic]^Shader,
	
	bound_shader : ^Shader,

	//Camera projection stuff
	using camera : struct {
		prj_mat 		: matrix[4,4]f32,
		inv_prj_mat 	: matrix[4,4]f32,
		view_mat 		: matrix[4,4]f32,
		inv_view_mat	: matrix[4,4]f32,
	},

	
}





