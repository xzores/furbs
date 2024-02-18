package render;

import fs "vendor:fontstash"

////////////// TYPES ////////////

Vertex_buffer_targets :: enum {
	array_buffer,
}

///////////// STATE ////////////

font_texture : Texture2D;
font_context : fs.FontContext;
text_shader : Shader;

prj_mat 		: matrix[4,4]f32;
inv_prj_mat 	: matrix[4,4]f32;

view_mat 		: matrix[4,4]f32;
inv_view_mat	: matrix[4,4]f32;

shader_folder_location : string;

current_render_target_width : f32;
current_render_target_height : f32;
current_render_target_unit : f32; //TODO

bound_window : Maybe(Window);

opengl_version : GL_version;

/////////// Optional helpers stuff ////////////

//TODO shapes_buffer : Mesh_buffer; //TODO unused
gui_shader : Shader;
white_texture : Texture2D; //Use get_white_texture to get it as it will init it if it is not.

//TODO make this a single mesh buffer
shape_quad : Mesh;
shape_circle : Mesh;

///////////// DEBUG STATE ////////////

render_has_been_init : bool = false;

////////////////

when ODIN_DEBUG {

	//What is alive
	//not it map = not created,
	//false = deleted,
	//true = alive,
	shader_program_alive : map[Shader_program_id]bool; //All array_buffers alive
	shader_vertex_alive : map[Shader_vertex_id]bool; //All array_buffers alive
	shader_fragment_alive : map[Shader_fragment_id]bool; //All array_buffers alive

	textures_alive : map[Texture_id]bool; //All array_buffers alive
	render_buffer_alive : map[Render_buffer_id]bool; //All array_buffers alive
	frame_buffer_alive : map[Frame_buffer_id]bool; //All array_buffers alive
	
	vertex_buffers_alive : map[Vbo_ID]bool; //All array_buffers alive
	array_buffers_alive : map[Vao_ID]struct{
		is_alive : bool,
		vertex_attrib_enabled : [8]bool,
	}; //All array_buffers alive

	texture_slots_binds : map[Texture_slot]Texture_id;

	//What is bound
	bound_shader_program : Shader_program_id;
	bound_array_buffer : Vao_ID;
	bound_element_buffer : Vbo_ID;
	//TODO check bound_texture2D 	: Texture_id;
	vertex_buffer_targets : [Vertex_buffer_targets]Vbo_ID;

	bound_frame_buffer_id : Frame_buffer_id;
	bound_read_frame_buffer_id : Frame_buffer_id;
	bound_write_frame_buffer_id : Frame_buffer_id;

}

///////// camera /////////
bound_camera : union {
	Camera_pixel,
	Camera2D,
	Camera3D,
};