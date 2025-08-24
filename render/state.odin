package render;

import "core:container/queue"
import "base:runtime"

import "vendor:glfw"
import fs "../fontstash"

import "core:time"
import "gl"

//This contains high-level state, go to wrappers to see the opengl client side state.

when ODIN_BUILD_MODE == .Executable {
	state : State;
}
else when ODIN_BUILD_MODE == .Dynamic {
	state : ^State;
}
else {
	#panic("What here?");
}

enable_preformence_warnings :: proc (warnings : bool) {
	state.pref_warn = warnings;
}

is_init :: proc () -> bool {
	return state.is_init;
}

Camera_matrices :: struct {
	prj_mat 		: matrix[4,4]f32,
	inv_prj_mat 	: matrix[4,4]f32,
	view_mat 		: matrix[4,4]f32,
	inv_view_mat	: matrix[4,4]f32,
	view_prj_mat 	: matrix[4,4]f32,
	inv_view_prj_mat: matrix[4,4]f32,
}

State :: struct {
	
	//Time stuff
	time_start : time.Time,
	time_last : time.Time,

	delta_time : f32, //TODO make f64
	time_elapsed : f32,
	
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
	key_input_buffer : [dynamic]Key_input_event,
	
	char_input_buffer : queue.Queue(Char_input_event),
	char_input : queue.Queue(Char_input_event),

	button_input_events : queue.Queue(Mouse_input_event),
	button_release_input_events : queue.Queue(Mouse_input_event),
	mouse_input_buffer : [dynamic]Mouse_input_event,
	
	scroll_input_event : queue.Queue([2]f32),

	old_mouse_pos : [2]f32,
	mouse_delta : [2]f32,
	scroll_delta : [2]f32,
		
	//Render init variable
	is_init : bool,
	pref_warn : bool,

	is_begin_frame : bool,
	
	//Shapes stuff
	shapes : Mesh_single,
	shapes_init : bool,
	
	shape_cube : [2]int,
	shape_circle : [2]int,
	shape_quad : [2]int,
	shape_char : [2]int,
	shape_cylinder : [2]int,
	shape_sphere : [2]int,
	shape_cone : [2]int,
	shape_arrow : [2]int,
	shape_right_triangle : [2]int,
	shape_equilateral_triangle : [2]int,
	
	//Extra stuff
	fps_measurement : f32,
	
	overlay_init 		: bool,
	shapes_pipeline 	: Pipeline,
	overlay_pipeline 	: Pipeline,
	arrow_fbo			: Frame_buffer,

	//Window stuff
	owner_context : glfw.WindowHandle,
	current_context : glfw.WindowHandle,
	owner_gl_states : gl.GL_states_comb,
	opengl_version : GL_version,
	active_windows : [dynamic]^Window,
	vsync : bool,
	
	bound_window : Maybe(^Window),
	window_in_focus : ^Window,

	main_window : ^Window,	//This will be nil if not created.

	target_pixel_width, target_pixel_height : f32,

	// Render target stuff
	current_pipeline : Pipeline,
	current_target : Render_target,

	//Text stuff
	font_context : fs.Font_context,
	
	char_mesh : Mesh_single,
	font_texture : Texture2D,

	default_fonts : Fonts,
	
	//Textures stuff
	white_texture : Texture2D,
	black_texture : Texture2D,
	
	default_copy_fbo : gl.Fbo_id,

	//Shader stuff
	is_init_shader : bool,
	default_shader : ^Shader,
	default_text_shader : ^Shader,
	default_instance_shader : ^Shader,
	shader_defines : map[string]string,

	loaded_shaders : [dynamic]^Shader,
	
	bound_shader : ^Shader,

	//Camera projection stuff
	using camera : Camera_matrices,

	render_context : runtime.Context,	
}





