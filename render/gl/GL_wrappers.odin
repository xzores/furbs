package wrappers;

import "base:runtime"
import "core:mem"
import "core:os"
import "core:strconv"
import "core:reflect"
import "core:strings"
import "core:fmt"
import "core:math"
import "core:time"
import "core:slice"
import "core:log"

import "core:thread"
import "core:sync"
import "core:container/queue"

import gl "OpenGL"
import utils "../../utils"

_ :: gl.GLenum;

RENDER_DEBUG	:: #config(RENDER_DEBUG, ODIN_DEBUG);
RECORD_DEBUG 	:: #config(RECORD_DEBUG, false);
UNBIND_DEBUG 	:: #config(UNBIND_DEBUG, true);

/////////// Opengl handles ///////////
Shader_program_id :: distinct u32;

Texture_id :: distinct u32;

Attribute_id :: distinct i32;
Uniform_id :: distinct i32;

Vao_id :: distinct i32;
Fbo_id :: distinct u32;
Tex1d_id :: distinct u32;
Tex2d_id :: distinct u32;
Tex3d_id :: distinct u32;
Texg_id :: distinct u32; //generic for all textures 
Rbo_id :: distinct u32;
Buffer_id :: distinct i32; //used for generic buffers, like VBO's and EBO's

Fence :: struct {
	sync : gl.GLsync,
}

MAX_COLOR_ATTACH :: 8; //If we use opengl 3.0 we can only have 4 color attachements here.

Uniform_type :: enum u64 {
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
	//mat2 			= gl.FLOAT_MAT2,
	//mat3 			= gl.FLOAT_MAT3,
	//mat4 			= gl.FLOAT_MAT4,
}

Attribute_primary_type :: enum u32 {
	invalid 		= 0,
	float 			= gl.FLOAT,
	int 			= gl.INT,
	uint 			= gl.UNSIGNED_INT,
}

Uniform_info :: struct {
	location : i32, 				//this is a per shader thing
	uniform_type : Uniform_type,
	active : bool,
	array_size : i32,
}

Attribute_info :: struct {
	location : Attribute_id,
	attribute_type : Attribute_type,
}

Attribute_info_ex :: struct {
	offset : uintptr,
	stride : i32,
	normalized : bool,
	using _ : Attribute_info,
}

@(require_results)
odin_type_to_uniform_type :: proc (odin_type : typeid) -> Uniform_type {
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
		case bool:
			return .bool;
		case matrix[2,2]f32:
			return .mat2;
		case matrix[3,3]f32:	
			return .mat3;
		case matrix[4,4]f32:	
			return .mat4;
		case:
			return .invalid;
	}

	return .invalid;
}

@(require_results)
odin_type_to_attribute_type :: proc (odin_type : typeid) -> Attribute_type {
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
		case quaternion128: //should this be here?
			return .vec4;
		case:
			return .invalid;
	}

	return .invalid;
}

//return the "entries" or number of dimensions. numbers are between 0 and 4.
@(require_results)
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

@(require_results)
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

@(require_results)
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

Cull_method :: enum u32 {
	no_cull,
	front_cull = gl.FRONT,
	back_cull = gl.BACK,
}

Polygon_mode :: enum u32 {
	point 			= gl.POINT,
	line 			= gl.LINE,
	fill 			= gl.FILL,
}

Primitive :: enum u32 {
	points 			= gl.POINTS,
	line_strip 		= gl.LINE_STRIP,
	lines 			= gl.LINES,
	triangle_strip 	= gl.TRIANGLE_STRIP,
	triangles 		= gl.TRIANGLES,
}

//TODO how to make proper blend functions?
/*
Blend_factor :: enum {
	zero,
	one,
	alpha,
	one_minus_alpha,
}

//TODO blend mode is 2 blend factors, and they should
//TODO make a per channel blend mode, (4x2 blend mode)

Blend_mode :: union {
	[2]Blend_factor,
	[4][2]Blend_factor,
}
*/
//TODO how to make proper blend functions?

Blend_mode :: enum {
	no_blend,
	blend,
}

Clear_flags_enum :: enum {
	color_bit,
	depth_bit,
	stencil_bit,
	accum_bit,
}

Clear_flags :: bit_set[Clear_flags_enum];

/////// Resources ///////

Resource_usage :: enum {
	
	stream_read,
	stream_write,
	stream_read_write,
	stream_host_only,

	dynamic_read,
	dynamic_write,
	dynamic_read_write,
	dynamic_host_only,
	
	static_read,
	static_write,
	static_read_write,
	static_host_only,
}

Resource_usage_3_3 :: enum u32 {
	stream_write =	gl.STREAM_DRAW,
	stream_read =	gl.STREAM_READ,
	stream_copy = 	gl.STREAM_COPY,

	static_write =	gl.STATIC_DRAW,
	static_read =	gl.STATIC_READ,
	static_copy = 	gl.STATIC_COPY,
	
	//These are static because the memory other would live in heap memory. NOT GPU memory.
	//But we likely want to to be GPU memory.
	dynamic_write = gl.DYNAMIC_DRAW,
	dynamic_read = 	gl.DYNAMIC_READ,
	dynamic_copy =  gl.DYNAMIC_COPY,
}

Index_buffer_type :: enum u32 {
	no_index_buffer,
	unsigned_short = gl.UNSIGNED_SHORT,
	unsigned_int = gl.UNSIGNED_INT,
}

/*
Resource_direction :: enum {
	read,
		//This should use glBufferData flags "GL_STREAM_READ", "GL_STATIC_READ" or "GL_DYNAMIC_READ" for opengl 3.3
		//This should use glStorageBuffer  flags "GL_MAP_READ_BIT"
			//This should use glMapBufferRange flags "GL_MAP_READ_BIT"
	
	write,
		//This should use glBufferData     flags "GL_STREAM_WRITE", "GL_STATIC_WRITE" or "GL_DYNAMIC_WRITE" for opengl 3.3
		//This should use glStorageBuffer  flags "GL_MAP_WRITE_BIT"
			//This should use glMapBufferRange flags "GL_MAP_WRITE_BIT | GL_MAP_INVALIDATE_RANGE_BIT"
	
	read_write,		//This requires mapping, so that is why there is both glBufferData and glMapBuffer.
		//This should use glBufferData     flags "GL_STREAM_WRITE", "GL_STATIC_WRITE" or "GL_DYNAMIC_WRITE" for opengl 3.3 (I don't think we can do better)
		//This should use glStorageBuffer  flags "GL_MAP_WRITE_BIT | GL_MAP_READ_BIT" if stream_usage.
			//This should use glMapBufferRange flags "GL_MAP_WRITE_BIT | GL_MAP_READ_BIT"

	host_only,		//host_only is for transfers that are from GPU buffer to another GPU buffer, where the data does not go though the GPU.
		//This should use glBufferData     flags "GL_STREAM_COPY", "GL_STATIC_COPY" or "GL_DYNAMIC_COPY" for opengl 3.3
		//This should use glBufferStorage  flags "" (no flags) as we only want to data on the host.

}

Resource_usage :: enum {
	
	stream_usage,		//Stream data every frame
		//This will translate to "GL_MAP_PERSISTENT_BIT | GL_MAP_COHERENT_BIT" in both glBufferStorage and glMapBuffer/Range for opengl 4.4 and above.
		//This will translate to "GL_STREAM_DRAW", "GL_STREAM_COPY" and "GL_STREAM_READ" in glBufferData for opengl 3.3
	
	dynamic_usage,	//Update somewhat freqently
		//This will translate to "GL_DYNAMIC_STORAGE_BIT" in glBufferStorage for opengl 4.4 and above
		//This will translate to "GL_DYNAMIC_DRAW", "GL_DYNAMIC_COPY" or "GL_DYNAMIC_READ" in glBufferData for opengl 3.3
	
	static_usage,		//Upload once or at max a few times.
		//This will not apply any flags to glBufferStorage and glMapBuffer/Range for opengl 4.4 and above.
		//This will translate to "GL_STATIC_DRAW", "GL_STATIC_COPY" or "GL_STATIC_READ" in glBufferData for opengl 3.3
}
//The GL_MAP_PERSISTENT_BIT and GL_MAP_COHERENT_BIT flags are available only if the GL version is 4.4 or greater. 

Resource_usage_4_4 :: enum u32 {
	dynamic_bit = gl.DYNAMIC_STORAGE_BIT,
	persistent_bit = gl.MAP_PERSISTENT_BIT,
	coherent_bit = gl.MAP_COHERENT_BIT,
}
*/


@(require_results)
translate_resource_usage_3_3 :: proc(usage : Resource_usage) -> (buffer_flags : Resource_usage_3_3, map_flags : u32) {

	//buffer_flags 	are for glBufferData
	//map_flags 	are for glMapBufferRange

	switch usage {

		//STREAM//
		case .stream_read:
			buffer_flags 	= .stream_read;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT;
		
		case .stream_write:
			buffer_flags 	= .stream_write;
			map_flags 		= gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT | gl.MAP_UNSYNCHRONIZED_BIT;
		
		case .stream_read_write:
			buffer_flags 	= .stream_write;	//THERE is no good hint, here default to write
			map_flags 		= gl.MAP_WRITE_BIT | gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .stream_host_only:
			buffer_flags 	= .stream_copy;	//THERE is no good hint, here default to write
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a host only buffer

		//DYNAMIC//
		case .dynamic_read:
			buffer_flags 	= .dynamic_read;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .dynamic_write:
			buffer_flags 	= .dynamic_write;
			map_flags 		= gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .dynamic_read_write:
			buffer_flags 	= .dynamic_write;
			map_flags 		= gl.MAP_WRITE_BIT | gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .dynamic_host_only:
			buffer_flags 	= .dynamic_copy;
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a host only buffer

		//STATIC//
		case .static_read:
			buffer_flags 	= .static_read;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT; //This should be ok

		case .static_write:
			buffer_flags 	= .static_write;
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a static buffer

		case .static_read_write:
			buffer_flags 	= .static_write;
			map_flags 		= 0 //THIS IS NOT VALID, you should not map a static buffer

		case .static_host_only:
			buffer_flags 	= .static_copy;
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a host only buffer
	}

	return;
}

@(require_results)
translate_resource_usage_4_4 :: proc(usage : Resource_usage) -> (buffer_flags : u32, map_flags : u32) {

	//buffer_flags 	are for glStorageBuffer
	//map_flags 	are for glMapBufferRange
	
	//THE MAP_UNSYNCHRONIZED_BIT flag only makes sense for double or trible buffering.
	//This is because it affects glUnmapBuffer, so a fence should be placed after glUnmapBuffer.
	//The fence should then be sync with before drawing, since glUnmapBuffer will not nessearily be done uploading before the drawing happens.
	//If MAP_UNSYNCHRONIZED_BIT is not used, then the entire buffer will be synced. 
	//But if you are not going to use the newly uploaded data before next frame (like with double buffering) then you can skip that sync point.
	//Also some amount of work can be skipped by the driver, and if the buffer is mapped often then we handle sync ourselfs.

	switch usage {
		//STREAM//
		case .stream_read:
			buffer_flags 	= gl.MAP_READ_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT | gl.MAP_UNSYNCHRONIZED_BIT;
		
		case .stream_write:
			buffer_flags 	= gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
			map_flags 		= gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT | gl.MAP_UNSYNCHRONIZED_BIT;
		
		case .stream_read_write:
			buffer_flags 	= gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .stream_host_only:
			buffer_flags 	= 0; //THERE is no good hint, here default to write
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a host only buffer
		
		//DYNAMIC//
		case .dynamic_read:
			buffer_flags 	= gl.MAP_READ_BIT;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .dynamic_write:
			buffer_flags 	= gl.MAP_WRITE_BIT | gl.DYNAMIC_STORAGE_BIT;
			map_flags 		= gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .dynamic_read_write:
			buffer_flags 	= gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.DYNAMIC_STORAGE_BIT;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_WRITE_BIT | gl.MAP_UNSYNCHRONIZED_BIT;

		case .dynamic_host_only:
			buffer_flags 	= 0; //This is valid, there are just no flags.
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a host only buffer

		//STATIC// (these are the same as dynamic for opengl 4.4)
		//For static models we recreate the glStorageBuffer with the data. This mean we cannot write at all because we are not using the gl.DYNAMIC_STORAGE_BIT flag.
		case .static_read:
			buffer_flags 	= gl.MAP_READ_BIT;
			map_flags 		= gl.MAP_READ_BIT | gl.MAP_UNSYNCHRONIZED_BIT; //THIS IS NOT VALID, you should not map a static buffer

		case .static_write:
			buffer_flags 	= gl.MAP_WRITE_BIT;
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a static buffer

		case .static_read_write:
			buffer_flags 	= gl.MAP_READ_BIT | gl.MAP_WRITE_BIT;
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a static buffer

		case .static_host_only:
			buffer_flags 	= 0; //This is valid, there are just no flags.
			map_flags 		= 0; //THIS IS NOT VALID, you should not map a host only buffer
	}

	return;
}

Buffer_type :: enum u32 {
	array_buffer = gl.ARRAY_BUFFER,								//Version GL 1.5	//Used as attribute data, yeah pretty normal stuff
	//would anyone use this? = gl.ATOMIC_COUNTER_BUFFER,		//Version GL 3.1 	//I don't know when I would use this, seems like a way to slow down shaders
	//dispatch_indirect_buffer= gl.DISPATCH_INDIRECT_BUFFER,	//Version GL 4.3	//something with computes shaders, we will likely not use this, We wont support compute shaders... (use fraqment or vertex)
	draw_indirect_buffer = gl.DRAW_INDIRECT_BUFFER,				//Version GL 4.0	//Used for GL_MULTI_DRAW_INDIRECT, we will use this when advaliable
	element_array_buffer = gl.ELEMENT_ARRAY_BUFFER,				//Version GL 1.5	//Used to hold indicies... yeah big surprise
	pixel_pack_buffer = gl.PIXEL_PACK_BUFFER,					//Version GL 2.1	//Used to download (from GPU to CPU) pixels, it is optimized for this.
	pixel_unpack_buffer = gl.PIXEL_UNPACK_BUFFER,				//Version GL 2.1	//Used to upload (from CPU to GPU) pixels, it is optimized for this.
	//??? = gl.QUERY_BUFFER,									//Version GL 4.4 	//???
	//shader_storage_buffer = gl.SHADER_STORAGE_BUFFER,			//Version GL 4.3 	//We will not use this (too new), it allows fast read/writes from the shader.
	texture_buffer = gl.TEXTURE_BUFFER,							//Version GL 3.1 	//Use to store access large amount of memory from the shader (it is not a real texture, it is a hacky way to access data).
	transform_feedback_buffer = gl.TRANSFORM_FEEDBACK_BUFFER,	//Version GL 3.0 	//This is a way to process data in a vertex shader without rasterizing or fragment shader. Use for partical systems and such.
	uniform_buffer = gl.UNIFORM_BUFFER,							//Version GL 3.1	//We will not use this...

	read_copy_buffer = gl.COPY_READ_BUFFER,						
	write_copy_buffer = gl.COPY_WRITE_BUFFER,							
}


/*
There are 2 ways to redo the Resource
	1: A resource should not own the Buffer_id itself, instead a resource is a sync point and a pointer to a buffer and a range.
	2: A resource implements double/triple and auto buffering. This means it will own the Buffer_id.

	The downside to 1 is that it means more comlicated setup, but more flexiable.
	
	The downside to 2 is that what happens at a resize? A new buffer must be created, 
		and then data must be copied from the old buffer to the new buffer.
		But we cannot copy the data before the copy is done, so we must sync. The hole idea was to not sync.
		
		We could maybe make it so a Resource implements single/double or triple buffering, but it will not do auto.
		So auto should be handled at a higher level that allocates new resources. 
		You might ask, why not just always handle all the double/triple or auto buffering at a higher level.
		The docs says 
			GL_MAP_UNSYNCHRONIZED_BIT indicates that the GL should not attempt to synchronize pending operations on the buffer prior to returning
			from glMapBufferRange or glMapNamedBufferRange. No GL error is generated if pending operations which source or modify the buffer
			overlap the mapped region, but the result of such previous and any subsequent operations is undefined.
		This means that there must also be some level of synchronization when calling GL_MAP_UNSYNCHRONIZED_BIT.
		
*/

Resource_desc :: struct {
	usage : Resource_usage,
	buffer_type : Buffer_type,
	bytes_count : int,
}

Resource :: struct {

	buffer 			: Buffer_id, //Vertex buffer or somthing
	
	persistent_mapped_data : []u8,

	using desc 		: Resource_desc,
}


/////// Textures ///////

// Pixel formats
Pixel_format_internal :: enum i32 {
	invalid = 0,

	//the ussual float formats
	RGB4 = gl.RGB4,
	RGBA4 = gl.RGBA4,

	R8 = gl.R8,
	RG8 = gl.RG8,
	RGB8 = gl.RGB8,
	RGBA8 = gl.RGBA8,

	R16 = gl.R16,
	RG16 = gl.RG16,
	RGB16 = gl.RGB16,
	RGBA16 = gl.RGBA16,

	compressed_R8 = gl.COMPRESSED_RED,
	compressed_RG8 = gl.COMPRESSED_RG,
	compressed_RGB8 = gl.COMPRESSED_RGB,
	compressed_RGBA8 = gl.COMPRESSED_RGBA,

	//Some weirder formats
	S_RGB8 = gl.SRGB8,
	S_RGBA8 = gl.SRGB8_ALPHA8,

	RGB5_A1 = gl.RGB5_A1, //float format, use when you need an on off alpha.
	
	//Depth formats (only used with framebuffers)
	depth_component16 = gl.DEPTH_COMPONENT16,
	depth_component24 = gl.DEPTH_COMPONENT24,
	depth_component32 = gl.DEPTH_COMPONENT32,
	
	//Some int formats
	R8_int = gl.R8I,
	RG8_int = gl.RG8I,
	RGB8_int = gl.RGB8I,
	RGBA8_int = gl.RGBA8I,

	R16_int = gl.R16I,
	RG16_int = gl.RG16I,
	RGB16_int = gl.RGB16I,
	RGBA16_int = gl.RGBA16I,

	R32_int = gl.R32I,
	RG32_int = gl.RG32I,
	RGB32_int = gl.RGB32I,
	RGBA32_int = gl.RGBA32I,

	//Some unsigned int formats
	R8_uint = gl.R8UI,
	RG8_uint = gl.RG8UI,
	RGB8_uint = gl.RGB8UI,
	RGBA8_uint = gl.RGBA8UI,

	R16_uint = gl.R16UI,
	RG16_uint = gl.RG16UI,
	RGB16_uint = gl.RGB16UI,
	RGBA16_uint = gl.RGBA16UI,

	R32_uint = gl.R32UI,
	RG32_uint = gl.RG32UI,
	RGB32_uint = gl.RGB32UI,
	RGBA32_uint = gl.RGBA32UI,

	//Some float formats
	R16_float = gl.R16F,
	RG16_float = gl.RG16F,
	RGB16_float = gl.RGB16F,
	RGBA16_float = gl.RGBA16F,

	R32_float = gl.R32F,
	RG32_float = gl.RG32F,
	RGB32_float = gl.RGB32F,
	RGBA32_float = gl.RGBA32F,
}

Pixel_format_upload :: enum i32 {
	no_upload,

	R8,
	RG8,
	RGB8,
	RGBA8,

	R16,
	RG16,
	RGB16,
	RGBA16,
	
	R32,
	RG32,
	RGB32,
	RGBA32,

	RGBA32_float,
}


@(require_results)
upload_format_channel_cnt :: proc (f : Pixel_format_upload) -> (channels : int) {

	switch f {
		case .R8, .R16, .R32:
			return 1;
		case .RG8, .RG16, .RG32:
			return 2;
		case .RGB8, .RGB16, .RGB32:
			return 3;
		case .RGBA8, .RGBA16, .RGBA32, .RGBA32_float:
			return 4;
		case .no_upload:
			return 0;
		case:
			panic("Invalid format");
	}

	unreachable();
}

@(require_results)
upload_format_gl_channel_format :: proc (f : Pixel_format_upload) -> (components : gl.GLenum) {

	switch f {
		case .R8, .R16, .R32:
			return .RED;
		case .RG8, .RG16, .RG32:
			return .RG;
		case .RGB8, .RGB16, .RGB32:
			return .RGB;
		case .RGBA8, .RGBA16, .RGBA32, .RGBA32_float:
			return .RGBA;
		case .no_upload:
			return nil;
		case:
			panic("Invalid format");
	}

	unreachable();
}

@(require_results)
upload_format_gl_type :: proc (f : Pixel_format_upload) -> (size : gl.GLenum) {

	switch f {
		case .R8, .RG8, .RGB8, .RGBA8:
			return .UNSIGNED_BYTE;
		case .R16, .RG16, .RGB16, .RGBA16:
			return .UNSIGNED_SHORT;
		case .R32, .RG32, .RGB32, .RGBA32:
			return .UNSIGNED_INT;
		case .RGBA32_float:
			return .FLOAT;
		case .no_upload:
			return nil;
		case:
			panic("Invalid format");
	}

	unreachable();
}

//Size in bytes
@(require_results)
upload_format_component_size :: proc (f : Pixel_format_upload) -> (size_in_bytes_per_component : int) {

	switch f {
		case .R8, .RG8, .RGB8, .RGBA8:
			return 1;
		case .R16, .RG16, .RGB16, .RGBA16:
			return 2;
		case .R32, .RG32, .RGB32, .RGBA32, .RGBA32_float:
			return 4;
		case .no_upload:
			return 0;
		case:
			panic("Invalid format");
	}

	unreachable();
}

Wrapmode :: enum i32 {
	repeat = gl.REPEAT,
	clamp_to_edge = gl.CLAMP_TO_EDGE,
	clamp_to_border = gl.CLAMP_TO_BORDER,
	mirrored_repeat = gl.MIRRORED_REPEAT,
	//mirrored_clamp_to_edge = gl.MIRROR_CLAMP_TO_EDGE, //opengl 4.4 only
}

Filtermode :: enum {
	nearest,
	linear,
}

/////////// Helper funcs ///////////

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

@(require_results)
get_major :: proc(version : GL_version) -> int {
	
	if version >= .opengl_4_0 {
		return 4;
	}
	
	if version >= .opengl_3_0 {
		return 3;
	}

	return 0;
} 

@(require_results)
get_minor :: proc(version : GL_version) -> int {
	
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

/////////// Debugging ///////////

Source_Code_Location :: runtime.Source_Code_Location;

when RENDER_DEBUG {

	Buffer_access :: struct {
		location : runtime.Source_Code_Location,
		offset_length : [2]int
	}

	Living_state :: struct {
		programs 	: map[Shader_program_id]Source_Code_Location,
		buffers 	: map[Buffer_id]Source_Code_Location,
		vaos 		: map[Vao_id]Source_Code_Location,
		fbos 		: map[Fbo_id]Source_Code_Location,
		tex1ds 		: map[Tex1d_id]Source_Code_Location,
		tex2ds 		: map[Tex2d_id]Source_Code_Location,
		tex3ds 		: map[Tex3d_id]Source_Code_Location,
		rbos 		: map[Rbo_id]Source_Code_Location,
		syncs 		: map[gl.sync_t]Source_Code_Location,
	}

	GL_debug_state :: struct {
		using living : Living_state,
		accessed_buffers : map[Buffer_id][dynamic]^Buffer_access, //what range of the buffer is accessed
	}
	
	debug_state : GL_debug_state;

	/*
	live_shaders : map[Shader_program_id]struct{},
	live_framebuffers : map[Fbo_id]struct{},
	live_buffers : map[Buffer_id]struct{},
	live_vaos : map[Vao_id]struct{},
	*/

	@(private)
	init_debug_state :: proc() -> (s : GL_debug_state) {
		log.infof("init_debug_state");
		return;
	}

	@(private)
	destroy_debug_state :: proc(s : GL_debug_state) {
		log.infof("destroy_debug_state");
		delete(s.programs);
		delete(s.buffers);
		delete(s.vaos);
		delete(s.fbos);
		delete(s.tex1ds);
		delete(s.tex2ds);
		delete(s.tex3ds);
		delete(s.rbos);
		delete(s.syncs);
		delete(s.accessed_buffers);
	}
}

gpu_state : GL_state;
cpu_state : GL_state_ex;
info : GL_info;			//fecthed in the begining and can be read from to get system information.

GL_state :: struct {

	bound_shader 	: Shader_program_id,
	bound_target 	: Maybe(Fbo_id),
	bound_draw_fbo 	: Maybe(Fbo_id),
	bound_read_fbo 	: Maybe(Fbo_id),
	bound_rbo 		: Rbo_id,

	//Textures have a 16 slots, so there are 16 textures in play at once. texture_slot denotes the texture currently being changed.
	//The other textures are still there and still bound in the shader.
	texture_slot 	: i32, //0-15 (specifies what bound_texture is currently changing).
	bound_texture 	: [16]Texg_id,

	//There are a single bound VAO, it keeps track of all the bound buffers, and attributes. It also keeps track on how the attriute data is sourced from the buffers.
	//When binding a buffer you are really binding a buffer to a VAO, even if you think a VAO is unbind, it acctually just means that the default VAO is active.
	//So there is always an VAO. 
	bound_vao 		: Vao_id,
	bound_buffer 	: map[Buffer_type]Buffer_id,
}

GL_state_ex :: struct {
	
	gl_version : GL_version,

	blend_mode : Blend_mode,
	depth_write : bool,
	depth_test : bool,
	polygon_mode : Polygon_mode,
	culling : Cull_method,
	depth_clamp : bool,
	depth_clamp_range : [2]f64,
	viewport : [4]i32,
	clear_color : [4]f32,

	using gl_state : GL_state,
}

GL_info :: struct {
	MAX_SAMPLES : i32,
	MAX_INTEGER_SAMPLES : i32,
	MAX_VERTEX_ATTRIB_BINDINGS : i32,
	MAX_VERTEX_ATTRIBS : i32,
	MAX_VERTEX_ATTRIB_STRIDE : i32,
	MAX_VERTEX_ATTRIB_RELATIVE_OFFSET : i32,
	MAX_TEXTURE_SIZE : i32,
	MAX_3D_TEXTURE_SIZE : i32,
	MAX_CUBE_MAP_TEXTURE_SIZE : i32,
	MAX_TEXTURE_UNITS : i32,
	MAX_TEXTURE_IMAGE_UNITS : i32,
	MAX_VERTEX_TEXTURE_IMAGE_UNITS : i32,
	MAX_GEOMETRY_TEXTURE_IMAGE_UNITS : i32,
	MAX_COMBINED_TEXTURE_IMAGE_UNITS : i32,
	MAX_TEXTURE_COORDS : i32,
	MAX_ARRAY_TEXTURE_LAYERS : i32,
}

init_state :: proc () -> GL_states_comb {

	log.infof("initializing gl_states");

	state : GL_states_comb;

	when RENDER_DEBUG {
		state.debug_state = init_debug_state();
	}

	return state;
}

destroy_state :: proc (state : GL_states_comb) {

	log.infof("destorying gl_states");

	delete(state.cpu_state.bound_buffer);
	delete(state.gpu_state.bound_buffer);

	when RENDER_DEBUG {
		destroy_debug_state(state.debug_state);
	}
}

debug_callback : gl.debug_proc_t : proc "c" (source: gl.GLenum, type: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, message: cstring, user_param : rawptr) {
	context = _gl_context;
    // Print or handle the debug message here

	#partial switch severity {
		case .DEBUG_SEVERITY_NOTIFICATION:
			log.debugf("From %v, OpenGL Debug Message: %.*s", source, length, message);
	 	case .DEBUG_SEVERITY_LOW:
    		log.infof("From %v, OpenGL Debug Message: %.*s", source, length, message);
		case .DEBUG_SEVERITY_MEDIUM:
			log.warnf("From %v, OpenGL Debug Message: %.*s", source, length, message);
		case .DEBUG_SEVERITY_HIGH:
			log.errorf("From %v, OpenGL Debug Message: %.*s", source, length, message);
		case:
			fmt.panicf("Unhandled severity : %v", severity);
	}
}

swap_states :: proc (new_states : ^GL_states_comb, old_states : ^GL_states_comb, loc := #caller_location) {
	assert(new_states != old_states, "states are the same!", loc);
	new_states^, old_states^ = old_states^, new_states^;
}

when RENDER_DEBUG {
	GL_states_comb :: struct {
		cpu_state 	: GL_state_ex,
		gpu_state 	: GL_state,
		debug_state : GL_debug_state,
	}
}
else {
	GL_states_comb :: struct {
		cpu_state 	: GL_state_ex,
		gpu_state 	: GL_state,
	}
}

_gl_context : runtime.Context;

init :: proc(gl_context := context) {

	_gl_context = gl_context;

	when RECORD_DEBUG {
		setup_call_recorder(); 
		gl.capture_gl_callback = record_call;
	}
	
	when gl.GL_DEBUG {
		if cpu_state.gl_version >= .opengl_4_3 {
			// Enable debug messages
			log.infof("Enable opengl debug messages");
			gl.Enable(.DEBUG_OUTPUT);
			gl.Enable(.DEBUG_OUTPUT_SYNCHRONOUS);

			// Set up debug callback function
			gl.DebugMessageCallback(debug_callback, nil);

		}
	}

	gl.capture_error_callback = record_err;

	info = fetch_gl_info();
	log.debugf("System info : %#v", info);
}

destroy :: proc(loc := #caller_location) -> (leaks : int) {
	
	leaks = 0;

	when RENDER_DEBUG {
		
		for field in reflect.struct_fields_zipped(Living_state) {
			
			key_size : int;

			if map_type_info, ok := field.type.variant.(runtime.Type_Info_Map); ok {
				key_size = map_type_info.key.size;
				
				if value_info, ok := map_type_info.value.variant.(runtime.Type_Info_Named); ok {
					fmt.assertf(value_info.name == "Source_Code_Location", "Map must hold Source_Code_Location, found : %s", value_info.name)
				}
				//assert(map_type_info.value.varient.(Type_Info_Named));
			}
			else {
				panic("This must be a map");
			}

			if key_size == 4 {
				s := cast(^map[u32]Source_Code_Location)(cast(uintptr)&debug_state.living + field.offset);
				for id, loc in s {
					log.errorf("Leak detected! %v with id %i has not been deleted, but allocated at location : %v", field.name, id, loc);
					leaks += 1;
				}
			}
			else if key_size == 8 {
				s := cast(^map[u64]Source_Code_Location)(cast(uintptr)&debug_state.living + field.offset);
				for id, loc in s {
					log.errorf("Leak detected! %v with id %i has not been deleted, but allocated at location : %v", field.name, id, loc);
					leaks += 1;
				}
			}
			else {
				panic("handle this case");
			}
		}

		if leaks == 0 {
			log.infof("No OpenGL object(s) leaks detected");
		}
		else {
			log.errorf("%v OpenGL object(s) has not been destroyed\n", leaks);
		}
	}
	
	when RENDER_DEBUG {
		s : GL_states_comb = {cpu_state, gpu_state, debug_state};
		destroy_state(s);
	}
	else {
		s : GL_states_comb = {cpu_state, gpu_state};
		destroy_state(s);
	}

	when RECORD_DEBUG {
		destroy_call_recorder();
	}

	_gl_context = {};

	return;
}


/////////// recording ///////////

Error_Enum :: gl.Error_Enum;

when RECORD_DEBUG {
	
	//This got a little complicated, there is a alot of step to make it work for a non-thread-safe allocator.
	//It does make debug builds way faster so I will keep it for now.

	//Internal use only
	record_output : os.Handle;
	time_being : time.Time;

	//Internal use only
	record_thread : ^thread.Thread;
	record_mutex : sync.Mutex;
	record_queue : queue.Queue(strings.Builder);
	record_queue_2 : queue.Queue(strings.Builder);
	record_should_close : bool;
	record_mutex_clean : sync.Mutex;
	record_filename : string;

	//This is unlike the others owned by the recoder thread (the one that writes to the file).
	record_queue_clean : queue.Queue(strings.Builder); //This to clean up by the main thread. We dont want to force users to use a multithreaded allocator.
	record_mutex_showdown : sync.Mutex;
	record_should_close_completly : bool;
	
	setup_call_recorder :: proc (filename : string = "gl_calls.txt") {
		when RECORD_DEBUG {
			time_being = time.now();
			record_filename = strings.clone(filename);
			
			record_should_close = false;
			record_should_close_completly = false;
			//record_mutex does not need initialization
			queue.init(&record_queue);
			queue.init(&record_queue_2);
			record_thread = thread.create_and_start(record_thread_loop, self_cleanup = true);
		}
	}
	
	destroy_call_recorder :: proc () {
		when RECORD_DEBUG {
			
			record_should_close = true;
			sync.lock(&record_mutex_showdown);
			for queue.len(record_queue_clean) != 0 {
				c := queue.pop_front(&record_queue_clean);
				strings.builder_destroy(&c);
			}
			sync.unlock(&record_mutex_showdown);
			record_should_close_completly = true;
			thread.join(record_thread); record_thread = {};
			queue.destroy(&record_queue);
			queue.destroy(&record_queue_2);
			delete(record_filename);
		}
	}
	
	@(private)
	record_thread_loop :: proc () {

		do_thing :: proc () {
			did_something := false;

			sync.lock(&record_mutex);
			for queue.len(record_queue) != 0 {
				record_queue, record_queue_2 = record_queue_2, record_queue; //Swap queues
				did_something = true;
			}
			sync.unlock(&record_mutex);
			
			if !did_something {
				time.sleep(100 * time.Microsecond);
			}

			for queue.len(record_queue_2) != 0 {
				
				to_write := queue.pop_front(&record_queue_2);
				os.write_string(record_output, strings.to_string(to_write)); //Write the thing

				//The builer must be cleaned by the main thread. Not all allocators are threaded.
				sync.lock(&record_mutex_clean);
				queue.append(&record_queue_clean, to_write);
				sync.unlock(&record_mutex_clean);
			}
		}
		
		sync.lock(&record_mutex_showdown);
		queue.init(&record_queue_clean);
		defer queue.destroy(&record_queue_clean);

		err : os.Errno;
		record_output, err = os.open(record_filename, os.O_CREATE|os.O_TRUNC);
		if err != 0 {
			panic("Could not open record file");
		}
		else {
			log.infof("recording calles to %v", record_filename);
		}
		defer {
			err = os.close(record_output);
			if err != 0 {
				fmt.panicf("Could not close record file, %v", err);
			}
		}

		for !record_should_close {
			do_thing();
			mem.free_all(context.temp_allocator);
		}
		
		do_thing(); //To make sure we got them all
		do_thing(); //To make sure we got them all
		mem.free_all(context.temp_allocator);

		sync.unlock(&record_mutex_showdown);

		for !record_should_close_completly {
			time.sleep(time.Microsecond);
		}
	}
	
	record_call :: proc (from_loc : runtime.Source_Code_Location, ret_val : any, args : []any, loc := #caller_location) {
		
		context = _gl_context;
		assert(_gl_context != {}, "_gl_context is nil", loc); //This wont do anthing as the _gl_context is required to do something with the context...
		
		b := strings.builder_make_len_cap(0, 125);
		
		call_time_mil_sec : f64 = time.duration_seconds(time.since(time_being));
		strings.write_string(&b, fmt.tprintf("%.7f : gl%s(", call_time_mil_sec, loc.procedure));
		
		for arg, i in args {
			
			if i > 0 { strings.write_string(&b, ", ") }
			
			if v, ok := arg.(gl.GLenum); ok {
				strings.write_string(&b, fmt.tprintf("GL_%v", v));
			} 
			else if v, ok := arg.(gl.GLbitfield); ok {
				strings.write_string(&b, fmt.tprintf("GL_%v", v));
			} 
			else if v, ok := arg.(u32); ok {
				strings.write_string(&b, fmt.tprintf("%v", v));
			}
			else if v, ok := arg.(i32); ok {
				strings.write_string(&b, fmt.tprintf("%v", v));
			}
			else if v, ok := arg.(f32); ok {
				strings.write_string(&b, fmt.tprintf("%v", v));
			}
			else {
				strings.write_string(&b, fmt.tprintf("(%v)%v", arg.id, arg));
			}
		}
		
		if ret_val != nil {
			strings.write_string(&b, fmt.tprintf(") -> %v", ret_val));
		}
		else {
			strings.write_string(&b, ")");
		}
		
		strings.write_string(&b, "\n");

		sync.lock(&record_mutex);
		queue.append(&record_queue, b);
		sync.unlock(&record_mutex);

		sync.lock(&record_mutex_clean);
		for queue.len(record_queue_clean) != 0 {
			c := queue.pop_front(&record_queue_clean);
			strings.builder_destroy(&c);
		}
		sync.unlock(&record_mutex_clean);
	}
}
else {
	record_call :: proc (from_loc : runtime.Source_Code_Location, ret_val : any, args : []any, loc := #caller_location) {}; //Do nothing
	setup_call_recorder :: proc (filename : string) {}; //Do nothing
	destroy_call_recorder :: proc (filename : string) {}; //Do nothing
}

record_err :: proc (from_loc: runtime.Source_Code_Location, err_val: any, err : Error_Enum, args : []any, loc : runtime.Source_Code_Location) {

	context = _gl_context;
	assert(_gl_context != {}, "_gl_context is nil", loc);

	{

		log.errorf("glGetError() returned GL_%v\n\tfrom:\tgl%s(%v)\n\tin:\t%v(%v:%v)\n", err, loc.procedure, args, from_loc.file_path, from_loc.line, from_loc.column);

		// add location
		//log.errorf("	in:   %s(%d:%d)\n", from_loc.file_path, from_loc.line, from_loc.column)

		if cpu_state.gl_version >= .opengl_4_3 {
			
			mes_cnt : gl.GLint;
			gl.GetIntegerv(.DEBUG_LOGGED_MESSAGES, &mes_cnt)
			
			for mes_cnt != 0 {
				
				l : gl.GLint;
				gl.GetIntegerv(.DEBUG_NEXT_LOGGED_MESSAGE_LENGTH, &l);
				
				err_str := make([]u8, l+2);

				message_sources : []gl.GLenum = {
					.DEBUG_SOURCE_API,
					.DEBUG_SOURCE_WINDOW_SYSTEM,
					.DEBUG_SOURCE_SHADER_COMPILER,
					.DEBUG_SOURCE_THIRD_PARTY,
					.DEBUG_SOURCE_APPLICATION,
					.DEBUG_SOURCE_OTHER,
				}

				message_types : []gl.GLenum = {
					.DEBUG_TYPE_ERROR,
					.DEBUG_TYPE_DEPRECATED_BEHAVIOR,
					.DEBUG_TYPE_UNDEFINED_BEHAVIOR,
					.DEBUG_TYPE_PORTABILITY,
					//.DEBUG_TYPE_PERFORMANCE,
					//.DEBUG_TYPE_MARKER,
					//.DEBUG_TYPE_PUSH_GROUP,
					//.DEBUG_TYPE_POP_GROUP,
					//.DEBUG_TYPE_OTHER,
				}
				
				message_severities : []gl.GLenum = {
					.DEBUG_SEVERITY_HIGH,
					.DEBUG_SEVERITY_MEDIUM,
					.DEBUG_SEVERITY_LOW,
					.DEBUG_SEVERITY_NOTIFICATION,
				}

				gl.GetDebugMessageLog(1, l, raw_data(message_sources[:]), raw_data(message_types[:]), nil, raw_data(message_severities[:]), &l, raw_data(err_str));
				//(count : GLuint, bufSize : GLsizei, sources : ^GLenum, types : ^GLenum, ids : ^GLuint, severities : ^GLenum, lengths : ^GLsizei, messageLog : GLoutstring
				
				log.errorf("recive debug message : %v", string(err_str));
				gl.GetIntegerv(.DEBUG_LOGGED_MESSAGES, &mes_cnt)
			}
		}
		
		log.errorf("Current cpu state : %#v", cpu_state);
		log.errorf("Current gpu state : %#v", gpu_state);
	}

	panic("Caught opengl error!", from_loc);
}

/////////// Getters/GLFW  ///////////

@(require_results)
fetch_gl_info :: proc () -> (info : GL_info) {
	
	fields := reflect.struct_fields_zipped(GL_info);

	for field in fields {
		to_fetch, ok := reflect.enum_from_name(gl.GLenum, field.name);
		field_pointer : rawptr = cast(rawptr)(cast(uintptr)&info + field.offset);
		gl.GetIntegerv(to_fetch, cast(^i32) field_pointer);
	}

	return;
}

@(require_results)
get_version :: proc() -> GL_version {
	
	v := gl.GetString(auto_cast gl.VERSION); //This must not be deleted.
	version := strings.clone_from(v);

	Major : int = strconv.atoi(version[0:1]);
	Minor : int = strconv.atoi(version[2:3]);
	
	delete(version);

	if Major < 3 {
		panic("A higher version of opengl is required");
	}
	
	if Major == 3 && Minor == 0 {
		return .opengl_3_0;
	}
	else if Major == 3 && Minor == 1 {
		return .opengl_3_1;
	}
	else if Major == 3 && Minor == 2 {
		return .opengl_3_2;
	}
	else if Major == 3 && Minor == 3 {
		return .opengl_3_3;
	}
	else if Major == 3 {
		return .opengl_3_3; //if 3.4 or 3.5 releases at some point.
	}
	
	if Major == 4 && Minor == 0 {
		return .opengl_4_0;
	}
	else if Major == 4 && Minor == 1 {
		return .opengl_4_1;
	}
	else if Major == 4 && Minor == 2 {
		return .opengl_4_2;
	}
	else if Major == 4 && Minor == 3 {
		return .opengl_4_3;
	}
	else if Major == 4 && Minor == 4 {
		return .opengl_4_4;
	}
	else if Major == 4 && Minor == 5 {
		return .opengl_4_5;
	}
	else if Major == 4 && Minor == 6 {
		return .opengl_4_6;
	}
	else if  Major == 4 {
		return .opengl_4_6; //if 4.7 or 4.8 releases at some point.
	}

	if Major > 4 {
		return .opengl_4_6;
	}

	unreachable();
}

load_up_to :: proc (version : GL_version, set_proc : proc(p: rawptr, name: cstring)) {

	cpu_state.gl_version = version;

	major : int = get_major(version);
	minor : int = get_minor(version);
	
	gl.load_up_to(major, minor, set_proc);
}

//////////////////////////////////////////// Functions ////////////////////////////////////////////

/////////// pipeline ///////////

set_blend_mode :: proc(blend_mode : Blend_mode) {
	//TODO how to make proper blend functions?

	/* 
	to_gl_factor :: proc (b : Blend_factor, is_src : bool) -> u32 {
		switch b {
			case .one:
				return gl.ONE;
			case .zero:
				return gl.ZERO;
			case .alpha:
				if is_src {
					return gl.SRC_ALPHA;
				}
				else {

				}
		}
	}

	if b, ok := blend_mode.([2]Blend_factor); ok {
		gl.BlendFunc(to_gl_factor(b[0], true), to_gl_factor(b[1], false));
	}
	else {
		panic("TODO");
	}
	*/

	if cpu_state.blend_mode == blend_mode {
		return;
	}

	if blend_mode == .blend {
		gl.Enable(.BLEND);
		gl.BlendFunc(.SRC_ALPHA, .ONE_MINUS_SRC_ALPHA);
	}
	else {
		gl.Disable(.BLEND);
		//gl.BlendFunc(gl.SRC_ALPHA, gl.ONE_MINUS_SRC_ALPHA);
	}

	cpu_state.blend_mode = blend_mode;
}

set_depth_write :: proc(depth_write : bool) {
		
	if cpu_state.depth_write == depth_write {
		return;
	}

	if depth_write {
		gl.DepthMask(gl.TRUE);
	}
	else {
		gl.DepthMask(gl.FALSE);
	}

	cpu_state.depth_write = depth_write;
}

set_depth_test :: proc(depth_test : bool) {
	
	if cpu_state.depth_test == depth_test {
		return;
	}

	if depth_test {
		gl.Enable(.DEPTH_TEST);
	}
	else {
		gl.Disable(.DEPTH_TEST);
	}

	cpu_state.depth_test = depth_test;

}

set_depth_clamp :: proc(depth_clamp : bool) {
	
	if cpu_state.depth_clamp == depth_clamp {
		return;
	}
	
	if depth_clamp {
		gl.Enable(.DEPTH_CLAMP);
	}
	else {
		gl.Disable(.DEPTH_CLAMP);
	}

	cpu_state.depth_clamp = depth_clamp;
}

set_depth_clamp_range :: proc(range : [2]f64) {
	
	if cpu_state.depth_clamp_range == range {
		return;
	}

	gl.DepthRange(range.x, range.y);

	cpu_state.depth_clamp_range = range;
}

set_polygon_mode :: proc(polygon_mode : Polygon_mode) {
	
	if cpu_state.polygon_mode == polygon_mode {
		return;
	}

	gl.PolygonMode(.FRONT_AND_BACK, auto_cast polygon_mode);
	
	cpu_state.polygon_mode = polygon_mode;
}

set_culling :: proc(method : Cull_method) {
	
	if cpu_state.culling == method {
		return;
	}

	if method == .no_cull {
		gl.Disable(.CULL_FACE);
	}
	else {
		gl.Enable(.CULL_FACE);
		gl.CullFace(auto_cast method);
	}

	cpu_state.culling = method;
}

set_viewport :: proc(#any_int x, y, width, height : i32) {
	
	vp := [4]i32{x, y, width, height};

	if cpu_state.viewport == vp {
		return;
	}

	gl.Viewport(x, y, width, height);
	
	cpu_state.viewport = vp;
}

set_clear_color :: proc(clear_color : [4]f32) {
	
	if cpu_state.clear_color == clear_color {
		return;
	}
	
	gl.ClearColor(clear_color.x, clear_color.y, clear_color.z, clear_color.w);

	cpu_state.clear_color = clear_color;
}

clear :: proc(clear_color : [4]f32, flags : Clear_flags = {.color_bit, .depth_bit}, loc := #caller_location) {
	flag : u32;
	
	if .color_bit in flags {
		set_clear_color(clear_color);
		flag = flag | gl.COLOR_BUFFER_BIT;
	}
	if .depth_bit in flags {
		flag = flag | gl.DEPTH_BUFFER_BIT;
	}
	if .stencil_bit in flags {
		flag = flag | gl.STENCIL_BUFFER_BIT;
	}
	if .accum_bit in flags {
		flag = flag | gl.ACCUM_BUFFER_BIT;
	}

	gl.Clear(auto_cast flag);
}

/////////// shaders ///////////

Compilation_error :: struct {
	msg : string,
	type : enum {vertex, fragment, link},
}

//return true if error
@(require_results)
load_shader_program :: proc(name : string, vertex_src : string, fragment_src : string, loc := #caller_location) -> (Shader_program_id, Maybe(Compilation_error)) {
	
	compile_shader :: proc (shader_id : u32) -> (err : bool, msg : string) {
		gl.CompileShader(auto_cast shader_id);

		success : i32;
		gl.GetShaderiv(shader_id, .COMPILE_STATUS, &success);

		if success == 0 {
			log_length  : i32;
			gl.GetShaderiv(shader_id, .INFO_LOG_LENGTH, &log_length);

			err_info : []u8 = make([]u8, log_length + 1);
			gl.GetShaderInfoLog(shader_id, log_length, nil, auto_cast raw_data(err_info));

			return true, string(err_info);
		}

		return false, "";
	}
	
	link_shader_program :: proc (shader_id : u32) -> (err : string) {
		gl.LinkProgram(shader_id);
		
		success : i32;
		
		gl.GetProgramiv(auto_cast shader_id, .LINK_STATUS, &success);

		if success == 0 {
			log_length  : i32;
			gl.GetProgramiv(shader_id, .INFO_LOG_LENGTH, &log_length);

			err_info : []u8 = make_slice([]u8, log_length + 1);
			gl.GetProgramInfoLog(shader_id, log_length, nil, auto_cast raw_data(err_info));

			return {};
		}

		return {};
	}

	shader_id_vertex := gl.CreateShader(.VERTEX_SHADER);
	shader_id_fragment := gl.CreateShader(.FRAGMENT_SHADER);

	log.debugf("Sending the vertex shader code to openGL : \n%s", vertex_src);
	shader_sources_vertex : [1]cstring = { strings.clone_to_cstring(vertex_src) }
	defer delete(shader_sources_vertex[0]);
	gl.ShaderSource(shader_id_vertex, 1, auto_cast &shader_sources_vertex, nil);

	if err, msg := compile_shader(auto_cast shader_id_vertex); err {
		log.errorf("Failed to compile vertex shader %v, ERROR : '%s'", name, msg);
		gl.DeleteShader(shader_id_vertex);
		gl.DeleteShader(shader_id_fragment);
		return 0, Compilation_error{msg, .vertex};
	}

	log.debugf("Sending the fragment shader code to openGL : \n%s", fragment_src);
	shader_sources_fragment : [1]cstring = { strings.clone_to_cstring(fragment_src) }
	defer delete(shader_sources_fragment[0]);
	gl.ShaderSource(shader_id_fragment, 1, auto_cast &shader_sources_fragment, nil);

	if err, msg := compile_shader(auto_cast shader_id_fragment); err {
		log.errorf("Failed to compile fragment shader %v, ERROR : %s", name, msg);
		gl.DeleteShader(shader_id_vertex);
		gl.DeleteShader(shader_id_fragment);
		return 0, Compilation_error{msg, .fragment};
	}

	shader_program : Shader_program_id = auto_cast gl.CreateProgram();
	gl.AttachShader(auto_cast shader_program, auto_cast shader_id_vertex);
	gl.AttachShader(auto_cast shader_program, auto_cast shader_id_fragment);
	
	if err := link_shader_program(auto_cast shader_program); err != {} {
		log.errorf("Failed to link shader program %v, ERROR : %s", name, err);
		gl.DeleteShader(shader_id_vertex);
		gl.DeleteShader(shader_id_fragment);
		gl.DeleteProgram(auto_cast shader_program);
		return 0, Compilation_error{err, .link};
	}

	//These are ok to delete because they are still referenced by the shader program. So their acctual deletion will happen when the shader program is deleted.
	gl.DeleteShader(shader_id_vertex);
	gl.DeleteShader(shader_id_fragment);

	when RENDER_DEBUG {
		debug_state.programs[shader_program] = loc;
	}

	return shader_program, nil;
}

unload_shader_program :: proc(shader : Shader_program_id) {
	assert(cpu_state.bound_shader != shader);
	
	if cpu_state.bound_shader == 0 {
		if gpu_state.bound_shader == shader {
			gl.UseProgram(0);
			gpu_state.bound_shader = 0;
		}
	}

	gl.DeleteProgram(auto_cast shader);
	
	when RENDER_DEBUG {
		delete_key(&debug_state.programs, shader);
	}
}

bind_shader_program :: proc(id : Shader_program_id) {
	
	cpu_state.bound_shader = id;

	if gpu_state.bound_shader == id {
		return;
	}

	gpu_state.bound_shader = id;
	
	gl.UseProgram(auto_cast id);
	
}

unbind_shader_program :: proc() {
	
	when UNBIND_DEBUG {
		cpu_state.bound_shader = 0;
		gpu_state.bound_shader = 0;
		gl.UseProgram(0);
	}
	else {
		cpu_state.bound_shader = 0;
	}
}

/////////// Vertex array stuff ///////////

gen_vertex_arrays :: proc(vaos : []Vao_id, loc := #caller_location) {

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateVertexArrays(auto_cast len(vaos), cast([^]u32) raw_data(vaos));
	}
	else {
		gl.GenVertexArrays(auto_cast len(vaos), cast([^]u32) raw_data(vaos));
	}
	
	when RENDER_DEBUG {
		for vao in vaos {
			debug_state.vaos[vao] = loc;
		}
	}
}

gen_vertex_array :: proc(loc := #caller_location) -> Vao_id {

	vao : Vao_id;

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateVertexArrays(1, cast([^]u32) &vao);
	}
	else {
		gl.GenVertexArrays(1, cast([^]u32) &vao);
	}

	when RENDER_DEBUG {
		debug_state.vaos[vao] = loc;
	}

	return vao;
}

bind_vertex_array :: proc (vao : Vao_id, loc := #caller_location) {
	
	when RENDER_DEBUG {
		if vao != 0 {
			assert(gpu_state.bound_buffer[.element_array_buffer] == 0, "another index buffer is bound while calling bind_vertex_array", loc);
		}
	}

	cpu_state.bound_vao = vao;

	if gpu_state.bound_vao == vao {
		return
	}

	gpu_state.bound_vao = vao;

	gl.BindVertexArray(auto_cast vao);

}

unbind_vertex_array :: proc () {

	when UNBIND_DEBUG {
		cpu_state.bound_vao = 0;
		gpu_state.bound_vao = 0;
		gl.BindVertexArray(0);
	}
	else {
		cpu_state.bound_vao = 0;
	}
}

delete_vertex_arrays :: proc (vaos : []Vao_id) {
	
	if cpu_state.bound_vao == 0 {
		for vao in vaos {
			if gpu_state.bound_vao == vao {
				gl.BindVertexArray(0);
				cpu_state.bound_vao = 0;
				gpu_state.bound_vao = 0;
			}
		}
	}
	
	gl.DeleteVertexArrays(auto_cast len(vaos), cast([^]u32) raw_data(vaos));

	when RENDER_DEBUG {
		for vao in vaos {
			delete_key(&debug_state.vaos, vao);
		}
	}
}

delete_vertex_array :: proc (vao : Vao_id) {
	vao := vao;

	if cpu_state.bound_vao == 0 {
		if gpu_state.bound_vao == vao {
			gl.BindVertexArray(0);
			gpu_state.bound_vao = 0;
		}
	}
	
	gl.DeleteVertexArrays(1, cast([^]u32)&vao);

	when RENDER_DEBUG {
		delete_key(&debug_state.vaos, vao);
	}

}

//This assumes only one buffer per VAO
associate_buffer_with_vao :: proc (vao : Vao_id, buffer : Buffer_id, attributes : []Attribute_info_ex, #any_int divisor : u32 = 0, loc := #caller_location) {

	bind_vertex_array(auto_cast vao);
	bind_buffer(.array_buffer, auto_cast buffer);
	
	for attrib, i in attributes {
		fmt.assertf(attrib.attribute_type != nil, "The type : %v is not valid. The attrib is : %v\n", attrib.attribute_type, attrib, loc = loc);
		//log.infof("setting up VertexAttribPointer : %v, %v, %v, %v, %v, %v\n", attrib.location, get_attribute_type_dimensions(attrib.attribute_type), get_attribute_primary_type(attrib.attribute_type), attrib.normalized, attrib.stride, attrib.offset);
		gl.VertexAttribPointer(auto_cast attrib.location, auto_cast get_attribute_type_dimensions(attrib.attribute_type), auto_cast get_attribute_primary_type(attrib.attribute_type), attrib.normalized, attrib.stride, attrib.offset);
		gl.EnableVertexAttribArray(auto_cast attrib.location);
		if divisor != 0 {
			gl.VertexAttribDivisor(auto_cast attrib.location, divisor);
		}
		//VertexAttribPointer      :: proc "c" (index: u32, size: i32, type: u32, normalized: bool, stride: i32, pointer: uintptr)
	}
	
	bind_buffer(.array_buffer, 0);
	bind_vertex_array(0);
}

associate_index_buffer_with_vao :: proc(vao : Vao_id, buffer : Buffer_id) {

	bind_vertex_array(auto_cast vao);
	bind_buffer(.element_array_buffer, buffer);
	bind_vertex_array(0);
	bind_buffer(.element_array_buffer, 0);
}

draw_arrays :: proc (vao : Vao_id, primitive : Primitive, #any_int first, count : i32) {
	bind_vertex_array(auto_cast vao);
    gl.DrawArrays(auto_cast primitive, first, count);
   	unbind_vertex_array();
}

draw_elements :: proc (vao : Vao_id, primitive : Primitive, #any_int first, count : i32, index_type : Index_buffer_type, index_buf : Buffer_id, loc := #caller_location) {
	when ODIN_DEBUG {
		assert(index_type != .no_index_buffer, "What are you trying to do -.-", loc);
		assert(vao != 0, "vao may not be 0");
		assert(first >= 0, "first must be more then zero", loc);
		assert(count > 0, "count must be larger then 0", loc);
		assert(index_buf != 0, "index_buf is required", loc);
		assert(gpu_state.bound_buffer[.element_array_buffer] == 0, "another index buffer is bound while calling draw elements", loc);
	}

	index_size : i32 = 0;
	switch index_type {
		case .no_index_buffer:
			panic("Draw elements require indices", loc);
		case .unsigned_short:
			index_size = 2;
		case .unsigned_int:
			index_size = 4;
	}

	bind_vertex_array(auto_cast vao);
    gl.DrawElements(auto_cast primitive, count, auto_cast index_type, cast(rawptr)cast(uintptr)(first * index_size));
	unbind_vertex_array();
}

draw_arrays_instanced :: proc (vao : Vao_id, primitive : Primitive, #any_int first, count, instance_count : i32) {
	bind_vertex_array(auto_cast vao);
    gl.DrawArraysInstanced(auto_cast primitive, first, count, instance_count);
   	unbind_vertex_array();
}

draw_elements_instanced :: proc (vao : Vao_id, primitive : Primitive, #any_int first, count : i32, index_type : Index_buffer_type, index_buf : Buffer_id, instance_count : i32) {
	assert(index_type != .no_index_buffer, "What are you trying to do -.-");
	
	index_size : i32 = 0;
	switch index_type {
		case .no_index_buffer:
			index_size = 0;
		case .unsigned_short:
			index_size = 2;
		case .unsigned_int:
			index_size = 4;
	}

	bind_vertex_array(auto_cast vao);
    gl.DrawElementsInstanced(auto_cast primitive, count, auto_cast index_type, cast(rawptr)cast(uintptr)(first * index_size), instance_count);
   	unbind_vertex_array();
}

/////////// Buffer stuff ///////////

//TODO should we even use Buffer_type? we keep it, it is easier to remove then add.
gen_buffers :: proc(_ : Buffer_type, buffers : []Buffer_id, loc := #caller_location) {

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateBuffers(auto_cast len(buffers), cast([^]u32) raw_data(buffers));
	}
	else {
		gl.GenBuffers(auto_cast len(buffers), cast([^]u32) raw_data(buffers));
	}

	when RENDER_DEBUG {
		for b in buffers {
			debug_state.buffers[b] = loc;
		}
	}
}

gen_buffer :: proc(_ : Buffer_type, loc := #caller_location) -> (buf : Buffer_id) {

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateBuffers(1, auto_cast &buf);
	}
	else {
		gl.GenBuffers(1, auto_cast &buf);
	}

	when RENDER_DEBUG {
		debug_state.buffers[buf] = loc;
	}

	return;
}

delete_buffers :: proc(location : Buffer_type, buffers : []Buffer_id) {

	if cpu_state.bound_buffer[location] == 0 {
		for b in buffers {
			if gpu_state.bound_buffer[location] == b {
				gl.BindBuffer(auto_cast location, 0);
				gpu_state.bound_buffer[location] = 0;
			}
		}
	}
	
	gl.DeleteBuffers(auto_cast len(buffers), cast([^]u32) raw_data(buffers));

	when RENDER_DEBUG {
		for b in buffers {
			delete_key(&debug_state.buffers, b);
		}
	}
}

delete_buffer :: proc(location : Buffer_type, buffer : Buffer_id) {
	
	if cpu_state.bound_buffer[location] == 0 && gpu_state.bound_buffer[location] == buffer {
		gl.BindBuffer(auto_cast location, 0);
		gpu_state.bound_buffer[location] = 0;
	}

	buffer := buffer;
	gl.DeleteBuffers(1, auto_cast &buffer);

	when RENDER_DEBUG {
		delete_key(&debug_state.buffers, buffer);
	}
}

bind_buffer :: proc(location : Buffer_type, buffer : Buffer_id) {
	
	cpu_state.bound_buffer[location] = buffer;
	
	if gpu_state.bound_buffer[location] == buffer {
		return
	}

	gpu_state.bound_buffer[location] = buffer;

	gl.BindBuffer(auto_cast location, auto_cast buffer);
}

unbind_buffer :: proc(location : Buffer_type) {
	
	when UNBIND_DEBUG {
		cpu_state.bound_buffer[location] = 0;
		gpu_state.bound_buffer[location] = 0;
		gl.BindBuffer(auto_cast location, 0);
	}
	else {
		//This seems hacky could we do something better?
		#partial switch location {
			case .element_array_buffer, .array_buffer:
				cpu_state.bound_buffer[location] = 0;
				gpu_state.bound_buffer[location] = 0;
				gl.BindBuffer(auto_cast location, 0);
			case:
				cpu_state.bound_buffer[location] = 0;
		}
	}
}

buffer_sub_data :: proc (buffer : Buffer_id, buffer_type : Buffer_type, #any_int offset_bytes : int, data : []u8) {
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.NamedBufferSubData(auto_cast buffer, offset_bytes, len(data), raw_data(data));
	}
	else {
		bind_buffer(buffer_type, buffer);
		gl.BufferSubData(auto_cast buffer_type, offset_bytes, len(data), raw_data(data));
		unbind_buffer(buffer_type);
	}
}

//Setup the buffer (with optional data, data = nil. No data)
buffer_data :: proc(buffer : Buffer_id, target : Buffer_type, size : int, data : rawptr, usage : Resource_usage) {	
	assert(size > 0, "size must be larger then 0");

	if cpu_state.gl_version >= .opengl_4_5 {
		buffer_falgs, _ := translate_resource_usage_4_4(usage);
		gl.NamedBufferStorage(auto_cast buffer, size, data, auto_cast buffer_falgs);
	}
	else if cpu_state.gl_version >= .opengl_4_4 {
		buffer_falgs, _ := translate_resource_usage_4_4(usage);
		bind_buffer(target, buffer);
		gl.BufferStorage(auto_cast target, size, data, auto_cast buffer_falgs);
		unbind_buffer(target);
	}
	else {
		buffer_falgs, _ := translate_resource_usage_3_3(usage);
		bind_buffer(target, buffer);
		gl.BufferData(auto_cast target, size, data, auto_cast buffer_falgs);
		unbind_buffer(target);
	}
}

copy_buffer_sub_data :: proc(read : Buffer_id, write : Buffer_id, read_offset : int, write_offset : int, size : int) {

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CopyNamedBufferSubData(auto_cast read, auto_cast write, read_offset, write_offset, size);
	}
	else {
		bind_buffer(.read_copy_buffer, read);
		bind_buffer(.write_copy_buffer, write);
		gl.CopyBufferSubData(.COPY_READ_BUFFER, .COPY_WRITE_BUFFER, read_offset, write_offset, size);
		unbind_buffer(.write_copy_buffer);
		unbind_buffer(.read_copy_buffer);
	}
}

place_fence :: proc (loc := #caller_location) -> Fence {
	fence_id := gl.FenceSync(auto_cast gl.SYNC_GPU_COMMANDS_COMPLETE, auto_cast 0);

	when RENDER_DEBUG {
		debug_state.syncs[fence_id] = loc;
	}

	if fence_id == nil {
		panic("failed to create sync object");
	}

	return Fence{fence_id};
}

//non-blocking, return if the fence is ready to be synced. Returns true if sync_fence will be non-blocking.
is_fence_ready :: proc (fence : Fence) -> bool {
	
	if fence.sync == nil {
		return true;
	}
	
	waitResult := gl.ClientWaitSync(fence.sync, auto_cast gl.SYNC_FLUSH_COMMANDS_BIT, 1); // 1 nano second timeout
	return waitResult == auto_cast gl.ALREADY_SIGNALED || waitResult == auto_cast gl.CONDITION_SATISFIED;
}

sync_fence :: proc (fence : ^Fence) {
	
	if fence.sync == nil {
		return;
	}

	waitResult : gl.GLenum;
	
	for true {
		waitResult = gl.ClientWaitSync(fence.sync, auto_cast gl.SYNC_FLUSH_COMMANDS_BIT, 1000000000); // 1 second timeout
		
        if waitResult == auto_cast gl.ALREADY_SIGNALED || waitResult == auto_cast gl.CONDITION_SATISFIED {
            break;
        } 
		else if waitResult == auto_cast gl.TIMEOUT_EXPIRED {
        	log.warnf("Timeout waiting for fence sync object, trying again\n");
        }
		else if waitResult == auto_cast gl.WAIT_FAILED {
            panic("Wait for fence sync object failed\n");
        }
		else {
			panic("What now?");
		}
	}
	
	discard_fence(fence);
}

discard_fence :: proc(fence : ^Fence, loc := #caller_location){
	
	when RENDER_DEBUG {
		delete_key(&debug_state.syncs, fence.sync);
	}

	if fence.sync != nil {
		gl.DeleteSync(fence.sync);
	}
	fence^ = {};
}

map_buffer_range :: proc (buffer : Buffer_id, buffer_type : Buffer_type,  #any_int offset, length : int, usage : Resource_usage, loc := #caller_location) -> (p : rawptr) {

	if cpu_state.gl_version >= .opengl_4_5 {
		_, map_flags := translate_resource_usage_4_4(usage);
		p = gl.MapNamedBufferRange(auto_cast buffer, offset, length, auto_cast map_flags);
	}
	else if cpu_state.gl_version >= .opengl_4_4 {
		_, map_flags := translate_resource_usage_4_4(usage);
		bind_buffer(buffer_type, buffer);
		p = gl.MapBufferRange(auto_cast buffer_type, offset, length, auto_cast map_flags);
		unbind_buffer(buffer_type);
	}
	else {
		_, map_flags := translate_resource_usage_3_3(usage);
		bind_buffer(buffer_type, buffer);
		p = gl.MapBufferRange(auto_cast buffer_type, offset, length, auto_cast map_flags);
		unbind_buffer(buffer_type);
	}

	return;
}

unmap_buffer :: proc (buffer : Buffer_id, buffer_type : Buffer_type, loc := #caller_location) {

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.UnmapNamedBuffer(auto_cast buffer);
	}
	else {
		bind_buffer(buffer_type, buffer);
		gl.UnmapBuffer(auto_cast buffer_type);
		unbind_buffer(buffer_type);
	}
}

/////////// Resource stuff ///////////

@(require_results)
make_resource :: proc(bytes_count : int, buffer_type : Buffer_type, resource_usage : Resource_usage, data : []u8, loc :=#caller_location) -> Resource {
	
	resource_desc : Resource_desc = {
		resource_usage,
		buffer_type,
		bytes_count,
	}
	
	return make_resource_desc(resource_desc, data, loc);
}

@(require_results)
make_resource_desc :: proc(desc : Resource_desc, data : []u8, loc := #caller_location) -> Resource {

	resource : Resource;
	resource.desc = desc;
	
	assert(data == nil || len(data) == desc.bytes_count, "data must be nil or have the same length as the resource bytes_count", loc = loc);

	#partial switch desc.usage {
		case .static_read, .static_write, .static_read_write, .static_host_only:
			assert(data != nil, "a static buffer cannot be written to after first initilized, so it makes no sense for the data to be nil.\nData must not be nil.", loc = loc);
		case:
			//nil is fine in other cases.
	}

	resource.buffer = gen_buffer(resource.buffer_type, loc);
	buffer_data(resource.buffer, resource.buffer_type, resource.bytes_count, raw_data(data), resource.usage);

	return resource;
}

destroy_resource :: proc(resource : Resource, loc := #caller_location) {

	needs_unmapping : bool;

	#partial switch resource.usage {
		case .stream_read, .stream_write, .stream_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				needs_unmapping = true;
			}
			else {
				needs_unmapping = false;
			}
		case:
			needs_unmapping = false;
	}
	
	if needs_unmapping {
		unmap_buffer(resource.buffer, resource.buffer_type, loc);
	}

	delete_buffer(resource.buffer_type, resource.buffer);
}

buffer_upload_sub_data :: proc (resource : ^Resource, #any_int offset_bytes : int, data : []u8) {
	buffer_sub_data(resource.buffer, resource.buffer_type, offset_bytes, data);
}

//if range == nil then the entire buffer is returned. Range is {being, end}
//You must sync, so that you do not write to any data currently being used.
//This is unsyncronized mapped buffer or presistent mapped buffer.
@(require_results)
begin_buffer_write :: proc(resource : ^Resource, begin : int = 0, length : Maybe(int) = nil, loc := #caller_location) -> (data : []u8) {
	
	byte_len : int = resource.bytes_count - begin;
	p : rawptr = nil;

	if l, ok := length.?; ok {
		byte_len = l;
	}

	switch resource.usage {

		case .stream_write, .stream_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				//If this is the first time it gets mapped persistently, then acctually map it.
				if resource.persistent_mapped_data == nil {
					//map the entire buffer
					p_p := map_buffer_range(resource.buffer, resource.buffer_type, 0, resource.bytes_count, resource.usage, loc);
					raw : runtime.Raw_Slice = {data = p_p, len = byte_len};
					resource.persistent_mapped_data = transmute([]u8)raw;
				}
				
				//It still need to be offset correctly. We offset by begin.
				p = &resource.persistent_mapped_data[begin];
			
			}
			else {
				p = map_buffer_range(resource.buffer, resource.buffer_type, begin, byte_len, resource.usage, loc);
			}
		
		case .dynamic_write, .dynamic_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				p = map_buffer_range(resource.buffer, resource.buffer_type, begin, byte_len, resource.usage, loc); //TODO this is the same as below
			}
			else {
				p = map_buffer_range(resource.buffer, resource.buffer_type, begin, byte_len, resource.usage, loc); //TODO same as above
			}
		
		case .static_write, .static_read_write:
			panic("Cannot write to a static buffer", loc);
		
		case .stream_read, .dynamic_read, .static_read:
			panic("Cannot write to a read only buffer", loc);

		case .stream_host_only, .dynamic_host_only, .static_host_only:
			panic("Cannot write to a host only buffer", loc);
		
		case:
			panic("Cannot write to a this buffer", loc);
	}
	
	assert(p != nil, "No mapped data", loc);
	raw : runtime.Raw_Slice = {data = p, len = byte_len}

	return transmute([]u8)raw;
}

//after calling this you may not change the buffer data (or even keep a refernce to it)
end_buffer_writes :: proc(using resource : ^Resource, loc := #caller_location) {

	switch resource.usage {
		
		case .stream_write, .stream_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				//We don't need to do anything here.
			}
			else {
				unmap_buffer(buffer, buffer_type);
			}
		
		case .dynamic_write, .dynamic_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				unmap_buffer(buffer, buffer_type);
			}
			else {
				unmap_buffer(buffer, buffer_type);
			}

		case .static_write, .static_read_write:
			panic("Cannot write to a static buffer", loc);
		
		case .stream_read, .dynamic_read, .static_read:
			panic("Cannot write to a read only buffer", loc);

		case .stream_host_only, .dynamic_host_only, .static_host_only:
			panic("Cannot write to a host only buffer", loc);
		
		case:
			panic("Cannot write to a this buffer", loc);
	}
	
}

//////////// Render Buffers ////////////

gen_render_buffers :: proc (rbos : []Rbo_id, loc := #caller_location) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateRenderbuffers(auto_cast len(rbos), auto_cast raw_data(rbos));
	}
	else {
		gl.GenRenderbuffers(auto_cast len(rbos), auto_cast raw_data(rbos));
	}

	when RENDER_DEBUG {
		for r in rbos {
			debug_state.rbos[r] = loc;
		}
	}
} 

@(require_results)
gen_render_buffer :: proc (loc := #caller_location) -> Rbo_id {

	// Create renderbuffer object
	buffer : Rbo_id;
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateRenderbuffers(1, auto_cast &buffer);
	}
	else {
		gl.GenRenderbuffers(1, auto_cast &buffer);
	}
	
	when RENDER_DEBUG {
		debug_state.rbos[buffer] = loc;
	}

	return buffer;
}

delete_render_buffers :: proc(rbos : []Rbo_id) {

	for rbo in rbos {
		if gpu_state.bound_rbo == rbo {
			gl.BindRenderbuffer(.RENDERBUFFER, 0);
			gpu_state.bound_rbo = 0;
		}
	}

	gl.DeleteRenderbuffers(auto_cast len(rbos), auto_cast raw_data(rbos));
	
	when RENDER_DEBUG {
		for r in rbos {
			delete_key(&debug_state.rbos, r);
		}
	}
}

delete_render_buffer :: proc(rbo : Rbo_id) {
	
	if gpu_state.bound_rbo == rbo {
		gl.BindRenderbuffer(.RENDERBUFFER, 0);
		gpu_state.bound_rbo = 0;
	}

	rbo := rbo;
	gl.DeleteRenderbuffers(1, auto_cast &rbo);

	when RENDER_DEBUG {
		delete_key(&debug_state.rbos, rbo);
	}
}

gen_frame_buffer :: proc (loc := #caller_location) -> Fbo_id {

	// Create a framebuffer object (FBO)
	framebuffer_id : Fbo_id;
	
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateFramebuffers(1, auto_cast &framebuffer_id);
	}
	else {
		gl.GenFramebuffers(1, auto_cast &framebuffer_id);
	}

	when RENDER_DEBUG {
		debug_state.fbos[framebuffer_id] = loc;
	}

	return framebuffer_id;
}

delete_frame_buffer :: proc(fbo : Fbo_id, loc := #caller_location) {
	
	//To ensure it is not still bound somehow.
	gpu_state.bound_target = nil;
	gpu_state.bound_draw_fbo = nil;
	gpu_state.bound_read_fbo = nil;

	fbo := fbo;
	gl.DeleteFramebuffers(1, auto_cast &fbo);

	when RENDER_DEBUG {
		delete_key(&debug_state.fbos, fbo);
	}
}

bind_frame_buffer :: proc(fbo : Fbo_id, loc := #caller_location) {
	
	cpu_state.bound_target = fbo;

	if gpu_state.bound_target == fbo {
		return;
	}
	
	gpu_state.bound_target = fbo;

	gl.BindFramebuffer(.FRAMEBUFFER, auto_cast fbo);
	
}

unbind_frame_buffer  :: proc() {
	
	when UNBIND_DEBUG {
		cpu_state.bound_target = 0;
		gpu_state.bound_target = 0;
		gl.BindFramebuffer(.FRAMEBUFFER, 0);
	}
	else {
		cpu_state.bound_target = 0;
	}
}

bind_frame_buffer_read :: proc(fbo : Fbo_id, loc := #caller_location) {
	
	cpu_state.bound_read_fbo = fbo;

	if gpu_state.bound_read_fbo == fbo {
		return;
	}

	gpu_state.bound_read_fbo = fbo;
	
	gl.BindFramebuffer(.READ_FRAMEBUFFER, auto_cast fbo);
}

unbind_frame_buffer_read  :: proc() {

	when UNBIND_DEBUG {
		cpu_state.bound_read_fbo = 0;
		gpu_state.bound_read_fbo = 0;
		gl.BindFramebuffer(.READ_FRAMEBUFFER, 0);
	}
	else {
		cpu_state.bound_read_fbo = 0;
	}
}

bind_frame_buffer_draw :: proc(fbo : Fbo_id, loc := #caller_location) {
	
	cpu_state.bound_draw_fbo = fbo;
	
	if gpu_state.bound_draw_fbo == fbo {
		return;
	}

	gpu_state.bound_draw_fbo = fbo;

	gl.BindFramebuffer(.DRAW_FRAMEBUFFER, auto_cast fbo);
	
}

unbind_frame_buffer_draw  :: proc() {

	when UNBIND_DEBUG {
		cpu_state.bound_draw_fbo = 0;
		gpu_state.bound_draw_fbo = 0;
		gl.BindFramebuffer(.DRAW_FRAMEBUFFER, 0);
	}
	else {
		cpu_state.bound_draw_fbo = 0;
	}
}

bind_render_buffer :: proc(rbo : Rbo_id, loc := #caller_location) {
	
	cpu_state.bound_rbo = rbo;

	if gpu_state.bound_rbo == rbo {
		return;
	}

	gpu_state.bound_rbo = rbo;
	
	gl.BindRenderbuffer(.RENDERBUFFER, auto_cast rbo);
}

unbind_render_buffer :: proc() {	
	when UNBIND_DEBUG {
		cpu_state.bound_rbo = 0;
		gpu_state.bound_rbo = 0;
		gl.BindRenderbuffer(.RENDERBUFFER, 0);
	}
	else {
		cpu_state.bound_rbo = 0;
	}
}

associate_color_render_buffers_with_frame_buffer :: proc(fbo : Fbo_id, render_buffers : []Rbo_id, width, height, samples_hint : i32,
						start_index : int = 0, color_format : Pixel_format_internal = .RGBA8, loc := #caller_location) -> (samples : i32) {

	assert(len(render_buffers) + start_index <= MAX_COLOR_ATTACH, "you can only have up to 8 color attachments", loc);
	assert(color_format != nil, "color_format is nil", loc);

	#partial switch color_format {
		case .RGBA8, .RGBA16_float, .RGBA32_float:
			//everthing is ok
		case .RGB8, .RGB16_float, .RGB32_float:
			//everthing is ok
		case:
			fmt.panicf("The format %v is not valid, it must be RGBA8, float_RGBA16, float_RGBA32, RGB8, float_RGB16 or float_RGB32", color_format, loc = loc);
	}

	samples = math.min(samples_hint, info.MAX_SAMPLES, info.MAX_INTEGER_SAMPLES);
	//fmt.assertf(samples != 0, "something wrong, samples are : %v, %v, %v", samples_hint, info.MAX_SAMPLES, info.MAX_INTEGER_SAMPLES);

	if cpu_state.gl_version >= .opengl_4_5 {
		
		// Create a multisampled renderbuffer object for color attachment
		for i in 0 ..< len(render_buffers) {
			
			if samples == 1 {
				gl.NamedRenderbufferStorage(auto_cast render_buffers[i], auto_cast color_format, width, height);
			}
			else {
				gl.NamedRenderbufferStorageMultisample(auto_cast render_buffers[i], samples, auto_cast color_format, width, height);
			}
			
			gl.NamedFramebufferRenderbuffer(auto_cast fbo, auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast (i + start_index)), .RENDERBUFFER, auto_cast render_buffers[i]);
		}
	}
	else {
		
		//TODO move the generation out of this function so we can reuse more code. Have the function be like "attach_frame_buffer_render_attachmetns".
		bind_frame_buffer(fbo);
		
		// Create a (non-)multisampled renderbuffer object for color attachment
		for i in 0 ..< len(render_buffers) {

			bind_render_buffer(render_buffers[i]);

			if samples == 1 {
				gl.RenderbufferStorage(.RENDERBUFFER, auto_cast color_format, width, height);
			}
			else {
				gl.RenderbufferStorageMultisample(.RENDERBUFFER, samples, auto_cast color_format, width, height);
			}
			
			gl.FramebufferRenderbuffer(.FRAMEBUFFER, auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast (i + start_index)), .RENDERBUFFER, auto_cast render_buffers[i]);
		}
		
		unbind_render_buffer();
		bind_frame_buffer(0);
	}

	return;
}

//@(deprecated="This should be rethought to be like the one with textures, the same should happen for associate_color_render_buffers_with_frame_buffer")
associate_depth_render_buffer_with_frame_buffer :: proc(fbo : Fbo_id, render_buffer : Rbo_id, width, height, samples_hint : i32, depth_format : Pixel_format_internal = .depth_component24, loc := #caller_location) -> (samples : i32) {

	assert(depth_format != nil, "depth_format is nil", loc);
	
	#partial switch depth_format {
		case .depth_component16, .depth_component24, .depth_component32:
			//everthing is ok
		case:
			fmt.panicf("The format %v is not valid, it must be depth_component16, depth_component24 or depth_component32", depth_format, loc = loc);
	}
	
	samples = math.min(samples_hint, info.MAX_SAMPLES, info.MAX_INTEGER_SAMPLES);
	assert(samples != 0, "something wrong");

	if cpu_state.gl_version >= .opengl_4_5 {
		
		if samples == 1 {
			gl.NamedRenderbufferStorage(auto_cast render_buffer, auto_cast depth_format, width, height);
		}
		else {
			gl.NamedRenderbufferStorageMultisample(auto_cast render_buffer, samples, auto_cast depth_format, width, height);
		}

		gl.NamedFramebufferRenderbuffer(auto_cast fbo, .DEPTH_ATTACHMENT, .RENDERBUFFER, auto_cast render_buffer);
		
	}
	else {
		bind_frame_buffer(fbo);
		bind_render_buffer(render_buffer);
		
		if samples == 1 {
			gl.RenderbufferStorage(.RENDERBUFFER, auto_cast depth_format, width, height);
		}
		else {
			gl.RenderbufferStorageMultisample(.RENDERBUFFER, samples, auto_cast depth_format, width, height);
		}
		gl.FramebufferRenderbuffer(.FRAMEBUFFER, .DEPTH_ATTACHMENT, .RENDERBUFFER, auto_cast render_buffer);
		
		unbind_render_buffer();
		bind_frame_buffer(0);
	}

	return;
}

associate_depth_texture_with_frame_buffer :: proc(fbo : Fbo_id, texture : Tex2d_id, loc := #caller_location) {

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.NamedFramebufferTexture(auto_cast fbo, .DEPTH_ATTACHMENT, auto_cast texture, 0);
	}
	else {
		bind_frame_buffer(fbo);
		bind_texture2D(texture);
		gl.FramebufferTexture(.FRAMEBUFFER, .DEPTH_ATTACHMENT, auto_cast texture, 0);
		unbind_texture2D();
		bind_frame_buffer(0);
	}
}

associate_color_texture_with_frame_buffer :: proc(fbo : Fbo_id, textures : []Tex2d_id, start_index : int = 0, loc := #caller_location) {

	assert(len(textures) + start_index <= MAX_COLOR_ATTACH, "you can only have up to 8 color attachments", loc);
	if cpu_state.gl_version >= .opengl_4_5 {
		
		// Create a multisampled renderbuffer object for color attachment
		for i in 0 ..< len(textures) {
			gl.NamedFramebufferTexture(auto_cast fbo, auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast (i + start_index)), auto_cast textures[i], 0);
		}
	}
	else {
		
		//TODO move the generation out of this function so we can reuse more code. Have the function be like "attach_frame_buffer_render_attachmetns".
		bind_frame_buffer(fbo);
		
		// Create a (non-)multisampled renderbuffer object for color attachment
		for i in 0 ..< len(textures) {

			bind_texture2D(textures[i]);
			gl.FramebufferTexture(.FRAMEBUFFER, auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast (i + start_index)), auto_cast textures[i], 0);
		}
		
		unbind_texture2D();
		bind_frame_buffer(0);
	}

	return;
}


@(require_results)
validate_frame_buffer :: proc (fbo : Fbo_id, loc := #caller_location) -> (valid : bool) {
	// Check if framebuffer is complete
	
	status : gl.GLenum;
	
	if cpu_state.gl_version >= .opengl_4_5 {
		status = gl.CheckNamedFramebufferStatus(auto_cast fbo, .FRAMEBUFFER);
	} 
	else {
		bind_frame_buffer(fbo);
		status = gl.CheckFramebufferStatus(.FRAMEBUFFER);
		unbind_frame_buffer();
	}

	if (status != .FRAMEBUFFER_COMPLETE) {
		
		/* 
		TODO move the the associate functions
		for ca, i in color_attachements {
			if attachment, ok := ca.?; ok {
				
				attachment_type : gl.GLenum;
				attachemnt_id_enum : gl.GLenum = auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast i);
				gl.GetFramebufferAttachmentParameteriv(.FRAMEBUFFER, attachemfvt_id_enum, .FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, auto_cast &attachment_type);

				if (attachment_type == .NONE) {
					log.errorf("Framebuffer is missing a color attachment %v", i);
				}
				assert(attachment_type == .RENDERBUFFER, "attachment_type is not a renderbuffer!");
			}
		}

		depth_attachment_type : gl.GLenum;
		gl.GetFramebufferAttachmentParameteriv(.FRAMEBUFFER, .DEPTH_ATTACHMENT, .FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, auto_cast &depth_attachment_type);
		if (depth_attachment_type == .NONE) {
			log.errorf("Framebuffer is missing a depth attachment");
		}
		assert(depth_attachment_type == .RENDERBUFFER, "attachment_type is not a renderbuffer!");
		fmt.panicf("TODO move this. Framebuffer is not complete! Statues : %v", status, loc = loc);
		*/
		return false;
	}

	return true;
}

//Will blit the first color attachment to the screen.
blit_fbo_color_to_screen :: proc(fbo : Fbo_id, src_x, src_y, src_width, src_height, dst_x, dst_y, dst_width, dst_height : i32, use_linear_interpolation := false) {
	
	interpolation : gl.GLenum = .NEAREST;

	if use_linear_interpolation {
		interpolation = .LINEAR;
	}
	
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.BlitNamedFramebuffer(auto_cast fbo, 0, src_x, src_y, src_width, src_height, dst_x, dst_y, dst_width, dst_height, .COLOR_BUFFER_BIT, interpolation);
	}
	else {
		bind_frame_buffer_read(fbo);
		bind_frame_buffer_draw(0);
		gl.BlitFramebuffer(src_x, src_y, src_width, src_height, dst_x, dst_y, dst_width, dst_height, .COLOR_BUFFER_BIT, interpolation); 
		bind_frame_buffer_draw(0);
		bind_frame_buffer_read(0);
	}
}

//////////////////////////////////////////// Textures ////////////////////////////////////////////

//// 1D textures ////
gen_texture1Ds :: proc (textures : []Tex1d_id, loc := #caller_location) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateTextures(.TEXTURE_1D, cast(i32)len(textures), cast([^]u32)raw_data(textures));
	}
	else {
		gl.GenTextures(cast(i32)len(textures), cast([^]u32)raw_data(textures));
	}

	when RENDER_DEBUG {
		for t in textures {
			debug_state.tex1ds[t] = loc;
		}
	}
}

@(require_results)
gen_texture1D :: proc (loc := #caller_location) -> (tex : Tex1d_id) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateTextures(.TEXTURE_1D, 1, auto_cast &tex);
	}
	else {
		gl.GenTextures(1, auto_cast &tex);
	}

	when RENDER_DEBUG {
		debug_state.tex1ds[tex] = loc;
	}

	return tex;
}

delete_texture1Ds :: proc (textures : []Tex1d_id, loc := #caller_location) {

	if cpu_state.bound_texture[cpu_state.texture_slot] == 0 {
		for t in textures {
			if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id) t {
				gl.BindTexture(.TEXTURE_1D, 0);
				cpu_state.bound_texture[cpu_state.texture_slot] = 0;
			}
		}
	}

	gl.DeleteTextures(cast(i32)len(textures), cast([^]u32) raw_data(textures));

	when RENDER_DEBUG {
		for t in textures {
			delete_key(&debug_state.tex1ds, t);
		}
	}
}

delete_texture1D :: proc (texture : Tex1d_id, loc := #caller_location) {
	texture := texture;

	if cpu_state.bound_texture[cpu_state.texture_slot] == 0 {
		if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)texture {
				gl.BindTexture(.TEXTURE_1D, 0);
				cpu_state.bound_texture[cpu_state.texture_slot] = 0;
			}
	}

	gl.DeleteTextures(1, cast([^]u32)&texture);

	when RENDER_DEBUG {
		delete_key(&debug_state.tex1ds, texture);
	}
}

bind_texture1D :: proc(tex : Tex1d_id, loc := #caller_location) {
	
	cpu_state.bound_texture[cpu_state.texture_slot] = cast(Texg_id)tex;
	
	if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)tex {
		return;
	}
	
	gpu_state.bound_texture[cpu_state.texture_slot] = cast(Texg_id)tex;

	gl.BindTexture(.TEXTURE_1D, auto_cast tex);
	
}

unbind_texture1D  :: proc() {
	assert(cpu_state.texture_slot == gpu_state.texture_slot);

	when UNBIND_DEBUG {
		cpu_state.bound_texture[cpu_state.texture_slot] = 0;
		gpu_state.bound_texture[cpu_state.texture_slot] = 0;
		gl.BindTexture(.TEXTURE_1D, 0);
	}
	else {
		cpu_state.bound_texture[cpu_state.texture_slot] = 0;
	}
}

write_texure_data_1D :: proc (tex : Tex1d_id, level, offset : i32, width : gl.GLsizei, format : Pixel_format_upload, data : union {[]u8, Resource}, loc := #caller_location) {
	//type could be an option here, for now we only allow GL_UNSIGNED_BYTE as the type.

	data_ptr : rawptr;
	
	if d, ok := data.([]u8); ok {
		assert(d != nil, "Data is nil", loc);
		data_ptr = raw_data(d);
	}
	else if d, ok := data.(Resource); ok {
		panic("TODO pixel_unpack_buffer");
	}
	else {
		panic("???");
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureSubImage1D(cast(u32)tex, level, offset, width, upload_format_gl_channel_format(format), upload_format_gl_type(format), data_ptr);
	}
	else {
		bind_texture1D(tex);
		gl.TexSubImage1D(.TEXTURE_1D, level, offset, width, upload_format_gl_channel_format(format), upload_format_gl_type(format), data_ptr);
		unbind_texture1D();
	}
}

//This will for opengl 4.2 or below not generate mip maps, and they must be generated by generate_mip_maps_XD or the mipmap level must be set directly
setup_texure_1D :: proc (tex : Tex1d_id, mipmaps : bool, width : gl.GLsizei, format : Pixel_format_internal, loc := #caller_location) {
	//type could be an option here, for now we only allow GL_UNSIGNED_BYTE as the type.

	levels : i32 = 1;

	if mipmaps {
		levels = 1 + cast(i32)math.floor(math.log2(cast(f32)math.max(width)));
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureStorage1D(cast(u32)tex, levels, auto_cast format, width);
	}
	else if cpu_state.gl_version >= .opengl_4_3 { 
		bind_texture1D(tex);
		gl.TexStorage1D(.TEXTURE_1D, levels, auto_cast format, width);
		unbind_texture1D();
	}
	else {
		bind_texture1D(tex);
		gl.TexImage1D(.TEXTURE_1D, 0, auto_cast format, width, 0, .RGBA, .UNSIGNED_BYTE, nil);
		unbind_texture1D();
	}
}

generate_mip_maps_1D :: proc (tex_id : Tex1d_id) {

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.GenerateTextureMipmap(auto_cast tex_id);
	}
	else {
		bind_texture1D(tex_id);
		gl.GenerateMipmap(.TEXTURE_1D);
		unbind_texture1D();
	}
}

wrapmode_texture1D :: proc(tex_id : Tex1d_id, mode : Wrapmode) {

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_WRAP_S, cast(i32)mode);
	}
	else {
		bind_texture1D(tex_id);
		gl.TexParameteri(.TEXTURE_1D, .TEXTURE_WRAP_S, cast(i32)mode);
		unbind_texture1D();
	}
}

filtermode_texture1D :: proc(tex_id : Tex1d_id, mode : Filtermode, using_mipmaps : bool) {
	
	min_mode : gl.GLenum;
	mag_mode : gl.GLenum;

	switch mode {
		case .nearest:
			
			if using_mipmaps {
				min_mode = .NEAREST_MIPMAP_NEAREST;
			}
			else {
				min_mode = .NEAREST;
			}

			mag_mode = .NEAREST;
		case .linear:
			
			if using_mipmaps {
				min_mode = .LINEAR_MIPMAP_LINEAR;;
			}
			else {
				min_mode = .LINEAR;
			}

			mag_mode = .LINEAR;
	}
	
	
	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_MIN_FILTER, cast(i32)min_mode);
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_MAG_FILTER, cast(i32)mag_mode);
	}
	else {
		bind_texture1D(tex_id);
		gl.TexParameteri(.TEXTURE_1D, .TEXTURE_MIN_FILTER, cast(i32)min_mode);
		gl.TexParameteri(.TEXTURE_1D, .TEXTURE_MAG_FILTER, cast(i32)mag_mode);
		unbind_texture1D();
	}
}

//// 2D textures ////
gen_texture2Ds :: proc (textures : []Tex2d_id, loc := #caller_location) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateTextures(.TEXTURE_2D, cast(i32)len(textures), cast([^]u32)raw_data(textures));
	}
	else {
		gl.GenTextures(cast(i32)len(textures), cast([^]u32)raw_data(textures));
	}

	when RENDER_DEBUG {
		for t in textures {
			debug_state.tex2ds[t] = loc;
		}
	}
}

@(require_results)
gen_texture2D :: proc (loc := #caller_location) -> (tex : Tex2d_id) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateTextures(.TEXTURE_2D, 1, auto_cast &tex);
	}
	else {
		gl.GenTextures(1, auto_cast &tex);
	}

	when RENDER_DEBUG {
		debug_state.tex2ds[tex] = loc;
	}

	return tex;
}

delete_texture2Ds :: proc (textures : []Tex2d_id, loc := #caller_location) {

	if cpu_state.bound_texture[cpu_state.texture_slot] == 0 {
		for t in textures {
			if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)t {
				gl.BindTexture(.TEXTURE_2D, 0);
				gpu_state.bound_texture[cpu_state.texture_slot] = 0;
			}
		}
	}

	gl.DeleteTextures(auto_cast len(textures), cast([^]u32) raw_data(textures));

	when RENDER_DEBUG {
		for t in textures {
			delete_key(&debug_state.tex2ds, t);
		}
	}
}

delete_texture2D :: proc (texture : Tex2d_id, loc := #caller_location) {
	texture := texture;

	if cpu_state.bound_texture[cpu_state.texture_slot] == 0 {
		if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)texture {
			gl.BindTexture(.TEXTURE_2D, 0);
			gpu_state.bound_texture[cpu_state.texture_slot] = 0;
		}
	}

	gl.DeleteTextures(1, cast([^]u32)&texture);

	when RENDER_DEBUG {
		delete_key(&debug_state.tex2ds, texture);
	}
}

bind_texture2D :: proc(tex : Tex2d_id, loc := #caller_location) {

	cpu_state.bound_texture[cpu_state.texture_slot] = cast(Texg_id)tex;
	
	if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)tex {
		return;
	}
	
	gpu_state.bound_texture[cpu_state.texture_slot] = cast(Texg_id)tex;
	
	gl.BindTexture(.TEXTURE_2D, cast(gl.GLuint)tex);
	
}

unbind_texture2D  :: proc() {
	assert(cpu_state.texture_slot == gpu_state.texture_slot);
	
	when UNBIND_DEBUG {
		cpu_state.bound_texture[cpu_state.texture_slot] = 0;
		gpu_state.bound_texture[cpu_state.texture_slot] = 0;
		gl.BindTexture(.TEXTURE_2D, 0);
	}
	else {
		cpu_state.bound_texture[cpu_state.texture_slot] = 0;
	}
}

write_texure_data_2D :: proc (tex : Tex2d_id, level, xoffset, yoffset : i32, width, height : gl.GLsizei, format : Pixel_format_upload, data : union {[]u8, Resource}, loc := #caller_location) {
	//type could be an option here, for now we only allow GL_UNSIGNED_BYTE as the type.

	data_ptr : rawptr;
	
	if d, ok := data.([]u8); ok {
		assert(d != nil, "Data is nil", loc);
		data_ptr = raw_data(d);
	}
	else if d, ok := data.(Resource); ok {
		panic("TODO pixel_unpack_buffer");
	}
	else {
		panic("???");
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureSubImage2D(cast(u32)tex, level, xoffset, yoffset, width, height, upload_format_gl_channel_format(format), upload_format_gl_type(format), data_ptr);
	}
	else {
		bind_texture2D(tex);
		gl.TexSubImage2D(.TEXTURE_2D, level, xoffset, yoffset, width, height, upload_format_gl_channel_format(format), upload_format_gl_type(format), data_ptr);
		unbind_texture2D();
	}
}

//This will for opengl 4.2 or below not generate mip maps, and they must be generated by generate_mip_maps_XD or the mipmap level must be set directly
setup_texure_2D :: proc (tex : Tex2d_id, mipmaps : bool, width, height : gl.GLsizei, format : Pixel_format_internal, loc := #caller_location) {
	//type could be an option here, for now we only allow GL_UNSIGNED_BYTE as the type.

	levels : i32 = 1;

	if mipmaps {
		levels = 1 + cast(i32)math.floor(math.log2(cast(f32)math.max(width, height)));
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureStorage2D(cast(u32)tex, levels, auto_cast format, width, height);
	}
	else if cpu_state.gl_version >= .opengl_4_3 { 
		bind_texture2D(tex);
		gl.TexStorage2D(.TEXTURE_2D, levels, auto_cast format, width, height);
		unbind_texture2D();
	}
	else {
		bind_texture2D(tex);
		#partial switch format {
			case .depth_component16, .depth_component24, .depth_component32:
				gl.TexImage2D(.TEXTURE_2D, 0, auto_cast format, width, height, 0, .DEPTH_COMPONENT, .UNSIGNED_BYTE, nil);
			case:
				gl.TexImage2D(.TEXTURE_2D, 0, auto_cast format, width, height, 0, .RGBA, .UNSIGNED_BYTE, nil);
		}
		unbind_texture2D();
	}
}

generate_mip_maps_2D :: proc (tex_id : Tex2d_id) {

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.GenerateTextureMipmap(auto_cast tex_id);
	}
	else {
		bind_texture2D(tex_id);
		gl.GenerateMipmap(.TEXTURE_2D);
		unbind_texture2D();
	}
}

wrapmode_texture2D :: proc(tex_id : Tex2d_id, mode : Wrapmode) {
	
	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_WRAP_S, cast(i32)mode);
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_WRAP_T, cast(i32)mode);
	}
	else {
		bind_texture2D(tex_id);
		gl.TexParameteri(.TEXTURE_2D, .TEXTURE_WRAP_S, cast(i32)mode);
		gl.TexParameteri(.TEXTURE_2D, .TEXTURE_WRAP_T, cast(i32)mode);
		unbind_texture2D();
	}
}

filtermode_texture2D :: proc(tex_id : Tex2d_id, mode : Filtermode, using_mipmaps : bool) {
	
	min_mode : gl.GLenum;
	mag_mode : gl.GLenum;

	switch mode {
		case .nearest:
			
			if using_mipmaps {
				min_mode = .NEAREST_MIPMAP_NEAREST;
			}
			else {
				min_mode = .NEAREST;
			}

			mag_mode = .NEAREST;
		case .linear:
			
			if using_mipmaps {
				min_mode = .LINEAR_MIPMAP_LINEAR;;
			}
			else {
				min_mode = .LINEAR;
			}

			mag_mode = .LINEAR;
	}
	
	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_MIN_FILTER, cast(i32)min_mode);
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_MAG_FILTER, cast(i32)mag_mode);
	}
	else {
		bind_texture2D(tex_id);
		gl.TexParameteri(.TEXTURE_2D, .TEXTURE_MIN_FILTER, cast(i32)min_mode);
		gl.TexParameteri(.TEXTURE_2D, .TEXTURE_MAG_FILTER, cast(i32)mag_mode);
		unbind_texture2D();
	}
}

active_texture :: proc(slot : i32) {
	
	cpu_state.texture_slot = slot;
	
	if gpu_state.texture_slot == slot {
		return;
	}
	
	gpu_state.texture_slot = slot;


	gl.ActiveTexture(auto_cast (gl.TEXTURE0 + slot));

}

//activates a texture slot and binds a the texture to that slot.
active_bind_texture2D :: proc (tex : Tex2d_id, slot : i32) {
	active_texture(slot);
	bind_texture2D(tex);
}

//Clear mipmap level 0 of a texture
//TODO this does not support integer and GL_DEPTH_COMPONENT, GL_STENCIL_INDEX, or GL_DEPTH_STENCIL textures, see https://registry.khronos.org/OpenGL-Refpages/gl4/html/glClearTexImage.xhtml
clear_texture_2D :: proc (tex : Tex2d_id, clear_color : [$N]$T, format : Pixel_format_upload, loc := #caller_location) {
	bind_texture2D(tex); //TODO should we bind for the active texture? we could also always just use texture slot 0, but that might slower.
	//assert(cpu_state.bound_texture[cpu_state.texture_slot] == 0, "There cannot be a bound texture, while clearing a texture", loc);
	assert(N == upload_format_channel_cnt(format), "The clear_color does not have the same amount of channels as the format", loc);
	
	if cpu_state.gl_version >= .opengl_4_4 {
		clear_color := clear_color;
		t : gl.GLenum;

		when T == i8 {
			t = .BYTE;
		}
		else when T == u8 {
			t = .UNSIGNED_BYTE;
		}
		else when T == i16 {
			t = .SHORT;
		}
		else when T == u16 {
			t = .UNSIGNED_SHORT;
		}
		else when T == i32 {
			t = .INT;
		}
		else when T == u32 {
			t = .UNSIGNED_INT;
		}
		else when T == f32 {
			t = .FLOAT;
		}
		else {
			#panic("Unsupported type");
		}

		gl.ClearTexImage(auto_cast tex, 0, .RGBA, t, &clear_color[0]);
	}
	else {
		width, height : i32;
		gl.GetTexLevelParameteriv(.TEXTURE_2D, 0, .TEXTURE_WIDTH, &width);
		gl.GetTexLevelParameteriv(.TEXTURE_2D, 0, .TEXTURE_HEIGHT, &height);

		pixels := make([][N]T, width * height);
		defer delete(pixels);
		
		for &p in pixels {
			p = clear_color;
		}

		write_texure_data_2D(tex, 0, 0, 0, width, height, .RGBA32_float, slice.reinterpret([]u8, pixels), loc);
	}
}

//TODO move up to 1D stuff
clear_texture_1D :: proc (tex : Tex1d_id, clear_color : [$N]$T, format : Pixel_format_upload, loc := #caller_location) {
	panic("TODO");
}

//TODO move down to 3d stuff
clear_texture_3D :: proc (tex : Tex3d_id, clear_color : [$N]$T, format : Pixel_format_upload, loc := #caller_location) {
	panic("TODO");
}

/* TODO, allow binding many textures at a time
active_bind_texture2Ds :: proc (tex : []struct{Tex2d_id, slot : u32}) {
	panic("TODO");
}


//The copy_frame_buffer is used internally, it must exist only for the purpose of copying texture data.
copy_texture2D_sub_data :: proc (src_tex : Tex2d_id, dst_tex : int) {
	
	//TODO, it seems we need a framebuffer to copy texture data.
	//Make this take in a framebuffer, that is used to copy with

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_3 {
		gl.CopyImageSubData(src_tex, .TEXTURE_2D, src_level, src_x, src_y, src_z, 0, .TEXTURE_2D, dst_level, dst_x, dst_y, 0, width, height, 1);
	}
	else {
		bind_texture2D(src_tex);
		gl.CopyTexSubImage2D(.TEXTURE_2D, 0, );
		unbind_texture2D();
	}
}
*/

//// 3D textures ////
gen_texture3Ds :: proc (textures : []Tex3d_id, loc := #caller_location) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateTextures(.TEXTURE_3D, cast(i32)len(textures), cast([^]u32)raw_data(textures));
	}
	else {
		gl.GenTextures(cast(i32)len(textures), cast([^]u32)raw_data(textures));
	}

	when RENDER_DEBUG {
		for t in textures {
			debug_state.tex3ds[t] = loc;
		}
	}
}

@(require_results)
gen_texture3D :: proc (loc := #caller_location) -> (tex : Tex3d_id) {

	// Create renderbuffer objects
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.CreateTextures(.TEXTURE_3D, 1, auto_cast &tex);
	}
	else {
		gl.GenTextures(1, auto_cast &tex);
	}

	when RENDER_DEBUG {
		debug_state.tex3ds[tex] = loc;
	}

	return tex;
}

delete_texture3Ds :: proc (textures : []Tex3d_id, loc := #caller_location) {

	if cpu_state.bound_texture[cpu_state.texture_slot] == 0 {
		for t in textures {
			if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)t {
				gl.BindTexture(.TEXTURE_3D, 0);
				gpu_state.bound_texture[cpu_state.texture_slot] = 0;
			}
		}
	}
	
	gl.DeleteTextures(auto_cast len(textures), cast([^]u32) raw_data(textures));

	when RENDER_DEBUG {
		for t in textures {
			delete_key(&debug_state.tex3ds, t);
		}
	}
}

bind_texture3D :: proc(tex : Tex3d_id, loc := #caller_location) {
	
	cpu_state.bound_texture[cpu_state.texture_slot] = cast(Texg_id)tex;
	
	if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)tex {
		return;
	}
	
	gpu_state.bound_texture[cpu_state.texture_slot] = cast(Texg_id)tex;

	gl.BindTexture(.TEXTURE_3D, auto_cast tex);
}

unbind_texture3D  :: proc() {
	assert(cpu_state.texture_slot == gpu_state.texture_slot);
	
	when UNBIND_DEBUG {
		cpu_state.bound_texture[cpu_state.texture_slot] = 0;
		gpu_state.bound_texture[cpu_state.texture_slot] = 0;
		gl.BindTexture(.TEXTURE_3D, 0);
	}
	else {
		cpu_state.bound_texture[cpu_state.texture_slot] = 0;
	}
}

write_texure_data_3D :: proc (tex : Tex3d_id, level, xoffset, yoffset, zoffset : i32, width, height, depth : gl.GLsizei, format : Pixel_format_upload, data : union {[]u8, Resource}, loc := #caller_location) {
	//type could be an option here, for now we only allow GL_UNSIGNED_BYTE as the type.

	data_ptr : rawptr;
	
	if d, ok := data.([]u8); ok {
		assert(d != nil, "Data is nil", loc);
		data_ptr = raw_data(d);
	}
	else if d, ok := data.(Resource); ok {
		panic("TODO pixel_unpack_buffer");
	}
	else {
		panic("???");
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureSubImage3D(cast(u32)tex, level, xoffset, yoffset, zoffset, width, height, depth, upload_format_gl_channel_format(format), upload_format_gl_type(format), data_ptr);
	}
	else {
		bind_texture3D(tex);
		gl.TexSubImage3D(.TEXTURE_3D, level, xoffset, yoffset, zoffset, width, height, depth, upload_format_gl_channel_format(format), upload_format_gl_type(format), data_ptr);
		unbind_texture3D();
	}
}

//This will for opengl 4.2 or below not generate mip maps, and they must be generated by generate_mip_maps_XD or the mipmap level must be set directly
setup_texure_3D :: proc (tex : Tex3d_id, mipmaps : bool, width, height, depth : gl.GLsizei, format : Pixel_format_internal, loc := #caller_location) {
	//type could be an option here, for now we only allow GL_UNSIGNED_BYTE as the type.

	levels : i32 = 1;

	if mipmaps {
		levels = 1 + cast(i32)math.floor(math.log2(cast(f32)math.max(width, height, depth)));
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureStorage3D(cast(u32)tex, levels, auto_cast format, width, height, depth);
	}
	else if cpu_state.gl_version >= .opengl_4_3 { 
		bind_texture3D(tex);
		gl.TexStorage3D(.TEXTURE_3D, levels, auto_cast format, width, height, depth);
		unbind_texture3D();
	}
	else {
		bind_texture3D(tex);
		gl.TexImage3D(.TEXTURE_3D, 0, auto_cast format, width, height, depth, 0, .RGBA, .UNSIGNED_BYTE, nil);
		unbind_texture3D();
	}
}

generate_mip_maps_3D :: proc (tex_id : Tex3d_id) {

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.GenerateTextureMipmap(auto_cast tex_id);
	}
	else {
		bind_texture3D(tex_id);
		gl.GenerateMipmap(.TEXTURE_3D);
		unbind_texture3D();
	}
}

wrapmode_texture3D :: proc(tex_id : Tex3d_id, mode : Wrapmode) {

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_WRAP_S, cast(i32)mode);
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_WRAP_T, cast(i32)mode);
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_WRAP_R, cast(i32)mode);
	}
	else {
		bind_texture3D(tex_id);
		gl.TexParameteri(.TEXTURE_3D, .TEXTURE_WRAP_S, cast(i32)mode);
		gl.TexParameteri(.TEXTURE_3D, .TEXTURE_WRAP_T, cast(i32)mode);
		gl.TexParameteri(.TEXTURE_3D, .TEXTURE_WRAP_R, cast(i32)mode);
		unbind_texture3D();
	}
}

filtermode_texture3D :: proc(tex_id : Tex3d_id, mode : Filtermode, using_mipmaps : bool) {
	
	min_mode : gl.GLenum;
	mag_mode : gl.GLenum;

	switch mode {
		case .nearest:
			
			if using_mipmaps {
				min_mode = .NEAREST_MIPMAP_NEAREST;
			}
			else {
				min_mode = .NEAREST;
			}

			mag_mode = .NEAREST;
		case .linear:
			
			if using_mipmaps {
				min_mode = .LINEAR_MIPMAP_LINEAR;;
			}
			else {
				min_mode = .LINEAR;
			}

			mag_mode = .LINEAR;
	}

	if cpu_state.gl_version >= .opengl_4_5 { 
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_MIN_FILTER, cast(i32)min_mode);
		gl.TextureParameteri(auto_cast tex_id, .TEXTURE_MAG_FILTER, cast(i32)mag_mode);
	}
	else {
		bind_texture3D(tex_id);
		gl.TexParameteri(.TEXTURE_3D, .TEXTURE_MIN_FILTER, cast(i32)min_mode);
		gl.TexParameteri(.TEXTURE_3D, .TEXTURE_MAG_FILTER, cast(i32)mag_mode);
		unbind_texture3D();
	}
}

delete_texture3D :: proc (texture : Tex3d_id, loc := #caller_location) {
	texture := texture;

	if cpu_state.bound_texture[cpu_state.texture_slot] == 0 {
		if gpu_state.bound_texture[cpu_state.texture_slot] == cast(Texg_id)texture {
			gl.BindTexture(.TEXTURE_3D, 0);
			gpu_state.bound_texture[cpu_state.texture_slot]= 0;
		}
	}

	gl.DeleteTextures(1, cast([^]u32)&texture);

	when RENDER_DEBUG {
		delete_key(&debug_state.tex3ds, texture);
	}
}

//////////////////////////////////////////// Shader functions ////////////////////////////////////////////

@(require_results)
get_shader_attributes :: proc(program_id : Shader_program_id, alloc := context.allocator, loc := #caller_location) -> (res : map[string]Attribute_info) {

	context.allocator = alloc;

	count : i32;
	max_length : i32;
	gl.GetProgramiv(auto_cast program_id, .ACTIVE_ATTRIBUTES, &count);
	gl.GetProgramiv(auto_cast program_id, .ACTIVE_ATTRIBUTE_MAX_LENGTH, &max_length);

	res = make(map[string]Attribute_info);

	for i in 0..<count {
		
		name_buf : []u8 = make([]u8, max_length + 2);
		defer delete(name_buf);

		name_len : i32;
		size : i32; // size of the variable
		
		shader_type : Attribute_type;

		gl.GetActiveAttrib(auto_cast program_id, auto_cast i, auto_cast len(name_buf), &name_len, &size, auto_cast &shader_type, cast([^]u8)raw_data(name_buf));
		assert(size == 1, "size is not 1, I have missunderstood something...");

		name : string = strings.clone_from_bytes(name_buf[:name_len]);
		fmt.assertf(utils.is_enum_valid(shader_type), "uniform %s is not a supported type. OpenGL type : %v", name, cast(gl.GLenum)shader_type, loc = loc);
		res[name] = Attribute_info{location = get_attribute_location(program_id, name), attribute_type = auto_cast shader_type};
	}

	return;
}

@(require_results)
get_shader_uniforms :: proc(program_id : Shader_program_id, alloc := context.allocator, loc := #caller_location) -> (res : map[string]Uniform_info) {

	context.allocator = alloc;

	count : i32;
	max_length : i32;
	gl.GetProgramiv(auto_cast program_id, .ACTIVE_UNIFORMS, &count);
	gl.GetProgramiv(auto_cast program_id, .ACTIVE_UNIFORM_MAX_LENGTH, &max_length);

	res = make(map[string]Uniform_info);
	
	for i in 0..<count {

		name_buf : []u8 = make([]u8, max_length + 2);
		defer delete(name_buf);

		name_len : i32;
		size : i32; // size of the variable
		shader_type : Uniform_type;

		gl.GetActiveUniform(auto_cast program_id, auto_cast i, auto_cast len(name_buf), &name_len, &size, auto_cast &shader_type, cast([^]u8)raw_data(name_buf));

		name : string = strings.clone_from_bytes(name_buf[:name_len]);

		if strings.has_suffix(name, "[0]") {
			assert(size != 1, "It is an array with size 1?, so it is an array?");
			
			//strip [0]
			delete(name);
			name = strings.clone_from_bytes(name_buf[:name_len-3]);
		}
		else {
			assert(size == 1, "It is not an array?, but the size is not 1?");
		}

		fmt.assertf(utils.is_enum_valid(shader_type), "uniform %s is not a supported type. OpenGL type : %v", name, cast(gl.GLenum)shader_type, loc = loc);
		res[name] = Uniform_info{location = get_uniform_location(program_id, name), uniform_type = auto_cast shader_type, active = true, array_size = size};
	}

	return;
}

@(require_results)
get_attribute_location :: proc(shader_id : Shader_program_id, attrib_name : string) -> Attribute_id {
	return auto_cast gl.GetAttribLocation(auto_cast shader_id, fmt.ctprintf(attrib_name));
}

@(require_results)
get_uniform_location :: proc(shader_id : Shader_program_id, uniform_name : string) -> i32 {
	return gl.GetUniformLocation(auto_cast shader_id, fmt.ctprintf(uniform_name));
}
