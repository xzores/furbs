package render;

import glfw "vendor:glfw"
import gl "vendor:OpenGL"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

import c "core:c/libc"

////////////////////////////////////////////////////////////////////

Uniform_client_index :: distinct i32;
Attribute_client_index :: distinct i32;

builtin_uniforms : Builtin_uniforms;
builtin_attributes : Builtin_attributes;

//These are required for the renderer to function.
Builtin_uniforms :: struct {
	mvp : Uniform_client_index 				`type:"mat4" array_size:"1"`,
	inv_mvp : Uniform_client_index			`type:"mat4" array_size:"1"`,

	prj_mat : Uniform_client_index			`type:"mat4" array_size:"1"`,
	inv_prj_mat : Uniform_client_index		`type:"mat4" array_size:"1"`,

	model_mat : Uniform_client_index		`type:"mat4" array_size:"1"`,
	inv_model_mat : Uniform_client_index	`type:"mat4" array_size:"1"`,

	col_diffuse : Uniform_client_index		`type:"vec4" array_size:"1"`,

	texture_diffuse : Uniform_client_index	`type:"sampler_2d" array_size:"1"`,
}

//These are required for the renderer to function.
Builtin_attributes :: struct {
	position : Attribute_client_index 		`type:"vec3"`,					
	texcoord : Attribute_client_index		`type:"vec2"`,
	normal : Attribute_client_index			`type:"vec3"`,
}

//////////////////////////////////////////////////////////

Shader_program_id :: distinct u32;
Shader_vertex_id :: distinct u32;
Shader_fragment_id :: distinct u32;

Texture_id :: distinct u32;
Render_buffer_id :: distinct u32;
Frame_buffer_id :: distinct u32;

Attribute_id :: distinct i32;
Uniform_id :: distinct i32;

Vao_id :: distinct i32; //TODO small ID
Vbo_id :: distinct i32; //TODO

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

Attribute_type :: enum u32 {
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

	//TODO these are not valid? right?
	//mat2 			= gl.FLOAT_MAT2,
	//mat3 			= gl.FLOAT_MAT3,
	//mat4 			= gl.FLOAT_MAT4,
}

Attribute_data_type :: enum u32 {
	invalid 		= 0,
	float 			= gl.FLOAT,
	int 			= gl.INT,
	uint 			= gl.UNSIGNED_INT,
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


get_attribute_data_type :: proc(a : Attribute_type) -> Attribute_data_type {
	
	switch a {
		case .invalid:
			return .invalid;
		case .float, .vec2, .vec3, .vec4:
			return .float;
		case .int, .ivec2, .ivec3, .ivec4:
			return .int;
		case .uint, .uvec2, .uvec3, .uvec4:
			return .uint;
		case:
			return .invalid;
	}
}

get_attribute_typeid :: proc(a : Attribute_type) -> typeid {
	return get_attribute_data_typeid(get_attribute_data_type(a));
}

get_attribute_data_typeid :: proc(a : Attribute_data_type) -> typeid {
	
	switch a {
		case .invalid:
			return nil;
		case .float:
			return f32;
		case .int:
			return int;
		case .uint:
			return uint;
		case:
			return nil;
	}
}

get_attribute_data_size :: proc(a : Attribute_type) -> int {

	switch a {
		case .invalid:
			return 0;
		case .float, .int, .uint, vec4:
			return 1;
		case .vec2, .ivec2, .uvec2:
			return 2;
		case .vec3, .ivec3, .uvec3:
			return 3;
		case .vec4, .ivec4, .uvec4:
			return 4;
		case:
			return 0;
	}
}

attribute_type_from_typeid :: proc(t : [$N]$T) -> Attribute_type where intrinsics.type_is_integer(N) && intrinsics.type_is_typeid(T) {
	attrib_data_type := attribute_data_type_from_typeid();
	return attribute_type_from_type_and_length(attrib_data_type, N);
}

attribute_data_type_from_typeid :: proc(t : typeid) -> Attribute_data_type {
	
	switch t {
		case f32:
			return .float;
		case i32:
			return .int;
		case u32:
			return .uint;
		case:
			return .invalid;
	}
}

attribute_type_from_type_and_length :: proc (a : Attribute_data_type, #any_int n : int) -> Attribute_type{
	
	switch a {
		case .float:
			switch n {
				case 1:
					return .float;
				case 2:
					return .vec2;
				case 3:
					return .vec3;
				case 4:
					return .vec4;
				case:
					return .invalid;
			}
		case .int:
			switch n {
				case 1:
					return .int;
				case 2:
					return .ivec2;
				case 3:
					return .ivec3;
				case 4:
					return .ivec4;
				case:
					return .invalid;
			}
		case .uint:
			switch n {
				case 1:
					return .uint;
				case 2:
					return .uvec2;
				case 3:
					return .uvec3;
				case 4:
					return .uvec4;
				case:
					return .invalid;
			}
		case:
			return .invalid;
	}
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
