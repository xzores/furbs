package render;

import glfw "vendor:glfw"
import gl "vendor:OpenGL"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

import c "core:c/libc"

////////////////////////////////////////////////////////////////////

		// THESE DEFINES WHAT CANE BE IN A SHADER // 

//locations may overlap as long as there is only of the overlapping in use at a time.

//////////////////////////////////////////////////////////

Shader_program_id :: distinct u32;
Shader_vertex_id :: distinct u32;
Shader_fragment_id :: distinct u32;

Texture_id :: distinct u32;
Render_buffer_id :: distinct u32;
Frame_buffer_id :: distinct u32;

Attribute_id :: distinct i32;
Uniform_id :: distinct i32;

Vao_ID :: distinct i32; //TODO small ID
Vbo_ID :: distinct i32; //TODO

//Not an opengl thing
Texture_slot :: distinct i32;

Shader_type :: enum {
	vertex_shader,
	fragment_shader,
}

Uniform_type :: enum u32 {
	invalid 		= 0,
	float 			= gl.FLOAT,
	vec2 			= gl.FLOAT_VEC2,
	vec3 			= gl.FLOAT_VEC3,
	vec4 			= gl.FLOAT_VEC4,
	int 			= gl.INT,
	ivec2 			= gl.INT_VEC2,
	ivec3 			= gl.INT_VEC3,
	ivec4 			= gl.INT_VEC4,
	uint 			= gl.UNSIGNED_INT,
	uvec2 			= gl.UNSIGNED_INT_VEC2,
	uvec3 			= gl.UNSIGNED_INT_VEC3,
	uvec4 			= gl.UNSIGNED_INT_VEC4,
	bool 			= gl.BOOL,
	mat2 			= gl.FLOAT_MAT2,
	mat3 			= gl.FLOAT_MAT3,
	mat4 			= gl.FLOAT_MAT4,
	sampler_1d 		= gl.SAMPLER_1D,
	sampler_2d 		= gl.SAMPLER_2D,
	sampler_3d 		= gl.SAMPLER_3D,
	sampler_cube	= gl.SAMPLER_CUBE,
	isampler_1d 	= gl.INT_SAMPLER_1D,
	isampler_2d 	= gl.INT_SAMPLER_2D,
	isampler_3d 	= gl.INT_SAMPLER_3D,
	isampler_cube 	= gl.INT_SAMPLER_CUBE,
	isampler_buffer = gl.INT_SAMPLER_BUFFER,
	//TODO should we support more? : https://registry.khronos.org/OpenGL-Refpages/gl4/html/glGetActiveUniform.xhtml
}

is_sampler :: proc (u : Uniform_type) -> bool {
	#partial switch u {
		case .sampler_1d:
			return true;
		case .sampler_2d:
			return true;
		case .sampler_3d:
			return true;
		case .sampler_cube:
			return true;
		case .isampler_1d:
			return true;
		case .isampler_2d:
			return true;
		case .isampler_3d:
			return true;
		case .isampler_cube:
			return true;
		case .isampler_buffer:
			return true;
		case:
			return false;
	}

	return false;
}

Attribute_type :: enum u32 {
	invalid 		= 0,
	float 			= gl.FLOAT,
	vec2 			= gl.FLOAT_VEC2,
	vec3 			= gl.FLOAT_VEC3,
	vec4 			= gl.FLOAT_VEC4,
	int 			= gl.INT,		//32 bits, not 64
	ivec2 			= gl.INT_VEC2,
	ivec3 			= gl.INT_VEC3,
	ivec4 			= gl.INT_VEC4,
	uint 			= gl.UNSIGNED_INT,
	uvec2 			= gl.UNSIGNED_INT_VEC2,
	uvec3 			= gl.UNSIGNED_INT_VEC3,
	uvec4 			= gl.UNSIGNED_INT_VEC4,
	//mat2 			= gl.FLOAT_MAT2,
	//mat3 			= gl.FLOAT_MAT3,
	//mat4 			= gl.FLOAT_MAT4,
}

odin_type_to_attribute_type :: proc (odin_type : typeid) -> Attribute_type{
	switch odin_type {
		case f32:
			return .float;
		case [2]f32:
			return .vec2;
		case [3]f32:
			return .vec3;
		case [4]f32:
			return .vec4;
		case i32:
			return .int; 
		case [2]i32:
			return .ivec2; 
		case [3]i32:
			return .ivec3; 
		case [4]i32:
			return .ivec4;
		case u32:
			return .uint;
		case [2]u32:
			return .uint;
		case [3]u32:
			return .uint;
		case [4]u32:
			return .uint;
		case:
			return .invalid;
	}

	return .invalid;
}

//return the "entries" or number of dimensions. numbers are between 0 and 4.
get_attribute_type_dimensions :: proc (at : Attribute_type) -> int {
	switch at {
		case .invalid:
			return 0;
		case .float, .int, .uint:
			return 1;
		case .vec2, .ivec2, .uvec2:
			return 2; 
		case .vec3, .ivec3, .uvec3:
			return 3;
		case .vec4, .ivec4, .uvec4:
			return 4;
	}

	return 0;
}

get_attribute_primary_type :: proc (at : Attribute_type) -> Attribute_primary_type {
	switch at {
		case .invalid:
			return .invalid;
		case .float, .vec2, .vec3, .vec4: 
			return .float;
		case .int, .ivec2, .ivec3, .ivec4:
			return .int; 
		case .uint, .uvec2, .uvec3, .uvec4:
			return .uint;
	}

	return .invalid;
}

Attribute_primary_type :: enum u32 {
	invalid 		= 0,
	float 			= gl.FLOAT,
	int 			= gl.INT,
	uint 			= gl.UNSIGNED_INT,
}

get_attribute_primary_byte_len :: proc (at : Attribute_primary_type) -> int {
	switch at {
		case .invalid:
			return 0;
		case .float: 
			return size_of(f32);
		case .int:
			return size_of(i32); 
		case .uint:
			return size_of(u32); 
	}

	return 0;
}

Uniform_info :: struct {
	location : Uniform_id,
	uniform_type : Uniform_type,
	array_size : i32,
}

Attribute_info :: struct {
	location : Attribute_id,
	attribute_type : Attribute_type,
}

// Shader attribute data types
Shader_attribute_data_type :: enum c.int {
	float = 0,         // Shader attribute type: float
	vector2,              // Shader attribute type: vec2 (2 float)
	vector3,              // Shader attribute type: vec3 (3 float)
	vector4,              // Shader attribute type: vec4 (4 float)
}

Depth_format :: enum {
	bits_auto = gl.DEPTH_COMPONENT,
	bits_16 = gl.DEPTH_COMPONENT16,
	bits_24 = gl.DEPTH_COMPONENT24,
	bits_32 = gl.DEPTH_COMPONENT32,
}

format_info :: proc(format : Pixel_format) -> (gl_name : c.uint, channels : c.int) {
	
	if format == .uncompressed_R8 {
		return gl.RED, 1;
	}
	else if format == .uncompressed_RG8 {
		return gl.RG, 2;
	}
	else if format == .uncompressed_RGB8 {
		return gl.RGB, 3;
	}
	else if format == .uncompressed_RGBA8 {
		return gl.RGBA, 4;
	}
	else {
		panic("Unsupported pixel format");
	}
}

// Pixel formats
// NOTE: Support depends on OpenGL version and platform
Pixel_format :: enum c.int {
	invalid = 0,
	uncompressed_R8 = gl.R8,
	uncompressed_RG8 = gl.RG8,
	uncompressed_RGB8 = gl.RGB8,
	uncompressed_RGBA8 = gl.RGBA8,
}

GL_version :: enum {
	invalid = 0,
	opengl_3_0,
	opengl_3_1,
	opengl_3_2,
	opengl_3_3,
	opengl_4_0,
	opengl_4_1,
	opengl_4_2,
	opengl_4_3,
	opengl_4_4,
	opengl_4_5,
	opengl_4_6,
}

get_gl_major :: proc(version : GL_version) -> int {
	
	if version >= .opengl_4_0 {
		return 4;
	}
	
	if version >= .opengl_3_0 {
		return 3;
	}

	return 0;
} 

get_gl_minor :: proc(version : GL_version) -> int {
	
	switch version {
		case .opengl_3_0, .opengl_4_0:
			return 0;
		case .opengl_3_1, .opengl_4_1:
			return 1;
		case .opengl_3_2, .opengl_4_2:
			return 2;
		case .opengl_3_3, .opengl_4_3:
			return 3;
		case .opengl_4_4:
			return 4;
		case .opengl_4_5:
			return 5;
		case .opengl_4_6:
			return 6;
		case .invalid:
			return 0;
		case:
			return 0;
	}

	return 0;
}

Cull_method :: enum {
	no_cull,
	front_cull,
	back_cull,
}

Render_target :: union {
	Render_texture,
	^Window,
}

Polygon_mode :: enum {
	points 			= gl.POINTS,
	lines 			= gl.LINES,
	fill 			= gl.FILL,
}

Primitive :: enum {
	points 			= gl.POINTS,
	line_strip 		= gl.LINE_STRIP,
	lines 			= gl.LINES,
	triangle_strip 	= gl.TRIANGLE_STRIP,
	triangles 		= gl.TRIANGLES,
}

Blend_mode :: enum {
	no_blend,
	one_minus_src_alpha = gl.ONE_MINUS_SRC_ALPHA,
}

//////////////////
Anchor_point :: enum {
    top_left,
    top_center,
    top_right,
    center_left,
    center_center,
    center_right,
    bottom_left,
    bottom_center,
    bottom_right,
}



///////////// DEBUG STATE ////////////

when ODIN_DEBUG {
	Debug_state :: struct {

		//Window stuff
		bound_window : ^Window,

		////////////////

		//What is alive
		//not it map = not created,
		//false = deleted,
		//true = alive,
		shader_program_alive : map[Shader_program_id]bool, //All array_buffers alive
		shader_vertex_alive : map[Shader_vertex_id]bool, //All array_buffers alive
		shader_fragment_alive : map[Shader_fragment_id]bool, //All array_buffers alive

		textures_alive : map[Texture_id]bool, //All array_buffers alive
		render_buffer_alive : map[Render_buffer_id]bool, //All array_buffers alive
		frame_buffer_alive : map[Frame_buffer_id]bool, //All array_buffers alive

		vertex_buffers_alive : map[Vbo_ID]bool, //All array_buffers alive
		array_buffers_alive : map[Vao_ID]struct{
			is_alive : bool,
			vertex_attrib_enabled : [8]bool,
		}, //All array_buffers alive

		texture_slots_binds : map[Texture_slot]Texture_id,

		//What is bound
		bound_shader_program : Shader_program_id,
		bound_array_buffer : Vao_ID,
		bound_element_buffer : Vbo_ID,
		//TODO check bound_texture2D 	: Texture_id;
		vertex_buffer_targets : [Vertex_buffer_targets]Vbo_ID,

		//TODO these are unused
		//bound_frame_buffer_id : Frame_buffer_id,
		//bound_read_frame_buffer_id : Frame_buffer_id,
		//bound_write_frame_buffer_id : Frame_buffer_id,

		is_begin_render : bool,
	};
}
else when !ODIN_DEBUG {
	Debug_state :: struct {};
}