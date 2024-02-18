package render;

import "vendor:glfw"
import fs "vendor:fontstash"

//This contains high-level state, go to wrappers to see the opengl client side state.

state : State;

State :: struct {
	is_init : bool,
	
	owner_context : glfw.WindowHandle,
	opengl_version : GL_version,
	active_windows : [dynamic]^Window,

	current_context : glfw.WindowHandle,

	main_window : ^Window,

	font_context : fs.FontContext,
	
	is_init_shader : bool,
	default_shader : ^Shader,
	shader_defines : map[string]string,

	loaded_shaders : [dynamic]^Shader,
}





