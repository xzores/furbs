package wrappers;

import "core:mem"
import "core:runtime"
import "core:os"
import "core:strconv"
import "core:reflect"
import "core:strings"
import "core:fmt"
import "core:math"
import "core:time"

import gl "OpenGL"
import utils "../../utils"

_ :: gl.GLenum;

RENDER_DEBUG	:: #config(DEBUG_RENDER, ODIN_DEBUG)
RECORD_DEBUG 	:: #config(DEBUG_RECORD, ODIN_DEBUG)

//TODO glDebugMessageControl(GL_DONT_CARE, GL_DONT_CARE, GL_DONT_CARE, 0, nullptr, GL_FALSE);

/////////// Opengl handles ///////////
Shader_program_id :: distinct u32;

Texture_id :: distinct u32;

Attribute_id :: distinct i32;
Uniform_id :: distinct i32;

Vao_id :: distinct i32;
Fbo_id :: distinct u32;
Rbo_id :: distinct u32;
Buffer_id :: distinct i32; //used for generic buffers, like VBO's and EBO's

Fence_id :: distinct u32;

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
	location : Uniform_id,
	uniform_type : Uniform_type,
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
	points 			= gl.POINTS,
	lines 			= gl.LINES,
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
	
	dynamic_write = gl.DYNAMIC_DRAW,
	dynamic_read = 	gl.DYNAMIC_READ,
	dynamic_copy = gl.DYNAMIC_COPY,
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
			//TODO this will generate an error if used with glMapBufferRange.

}
//TODO when to use GL_MAP_UNSYNCHRONIZED_BIT and GL_MAP_FLUSH_EXPLICIT_BIT?
//glBufferSubData and glMapBufferRange does almost the same. I think we should only use mapping, is there a downside?

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

Resource_map_flags :: enum u32 {
	persistent_bit = gl.MAP_PERSISTENT_BIT,
	coherent_bit = gl.MAP_COHERENT_BIT,
}

@(require_results)
translate_resource_usage_3_3 :: proc(usage : Resource_usage, direction : Resource_direction) -> (buffer_flags : Resource_usage_3_3, map_flags : u32) {

	switch usage {
		case .stream_usage:
			switch direction {
				case read:
					buffer_flags = .stream_read;
				case write:
					buffer_flags = .stream_write;
				case read_write:
					buffer_flags = .stream_write;
				case host_only:
					buffer_flags = .stream_copy;
			}
		case .dynamic_usage:
			switch direction {
				case read:
					buffer_flags = .dynamic_read;
				case write:
					buffer_flags = .dynamic_write;
				case read_write:
					buffer_flags = .dynamic_write;
				case host_only:
					buffer_flags = .dynamic_copy;
			}
		case .static_usage:
			switch direction {
				case read:
					buffer_flags = .static_read;
				case write:
					buffer_flags = .static_write;
				case read_write:
					buffer_flags = .static_write;
				case host_only:
					buffer_flags = .static_copy;
			}
	}
	
	switch direction {
		case read:
			map_flags |= gl.MAP_READ_BIT;
		case write:
			map_flags |= gl.MAP_WRITE_BIT | gl.MAP_INVALIDATE_RANGE_BIT;
		case read_write:
			map_flags |= gl.MAP_WRITE_BIT | gl.MAP_READ_BIT;
		case host_only:
			map_flags |= 0; //You should NOT map a host_only buffer
	}

	return;
}

@(require_results)
translate_resource_usage_4_4 :: proc(usage : Resource_usage, direction : Resource_direction) -> (buffer_flags : u32, map_flags : u32) {

	switch usage {
		case .stream_usage:
			#partial switch direction {
				case host_only: 
					map_flags 		|= gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
					buffer_flags 	|= gl.MAP_PERSISTENT_BIT | gl.MAP_COHERENT_BIT;
				case: 
					map_flags 		|= 0;
					buffer_flags 	|= 0;
			}
		case .dynamic_usage:
			
			#partial switch direction {
				case write:
					map_flags 		|= gl.MAP_INVALIDATE_RANGE_BIT;
				case:
					map_flags 		|= 0;
			}

			buffer_flags 	|= gl.DYNAMIC_STORAGE_BIT
			
		case .static_usage:
			#partial switch direction {

				map_flags 		|= gl.MAP_INVALIDATE_RANGE_BIT;
				buffer_flags 	|= gl.DYNAMIC_STORAGE_BIT
			}
	}
	
	switch direction {
		case read:
			map_flags 		|= gl.MAP_READ_BIT;
			buffer_flags 	|= gl.MAP_READ_BIT;
		
		case write:
			map_flags 		|= gl.MAP_WRITE_BIT;
			buffer_flags 	|= gl.MAP_WRITE_BIT;
		
		case read_write:
			map_flags 		|= gl.MAP_WRITE_BIT | gl.MAP_READ_BIT;
			buffer_flags 	|= gl.MAP_WRITE_BIT | gl.MAP_READ_BIT;

		case host_only:
			buffer_flags 	|= 0; //TODO
			map_flags 		|= 0; //You should NOT map a host_only buffer
	}

	return;

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
			buffer_flags 	= gl.MAP_READ_BIT | gl.DYNAMIC_STORAGE_BIT; //TODO gl.DYNAMIC_STORAGE_BIT might not be neeeded here
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
}

Resource_desc :: struct {
	usage : Resource_usage,
	buffer_type : Buffer_type,
	bytes_count : int,
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

Resource :: struct {

	buffer 			: Buffer_id, //Vertex buffer or somthing

	using desc 		: Resource_desc,
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

	GL_debug_state :: struct {
		programs 	: map[Shader_program_id]Source_Code_Location,
		buffers 	: map[Buffer_id]Source_Code_Location,
		vaos 		: map[Vao_id]Source_Code_Location,
		fbos 		: map[Fbo_id]Source_Code_Location,
		rbos 		: map[Rbo_id]Source_Code_Location,
	
		write_accessed_buffers : map[Buffer_id][2]int, 	//what range of the buffer is accessed
		read_accessed_buffers : map[Buffer_id][2]int,	//what range of the buffer is accessed
	}

	debug_state : GL_debug_state;

	/*
	live_shaders : map[Shader_program_id]struct{},
	live_framebuffers : map[Fbo_id]struct{},
	live_buffers : map[Buffer_id]struct{},
	live_vaos : map[Vao_id]struct{},
	*/
}

gpu_state : GL_state;
cpu_state : GL_state_ex;
info : GL_info;			//fecthed in the begining and can be read from to get system information.

GL_state :: struct {

	bound_shader : Shader_program_id,
	bound_target : Fbo_id,
	bound_vao : Vao_id,
	
	bound_buffer : #sparse [Buffer_type]Buffer_id,
}

GL_state_ex :: struct {
	
	gl_version : GL_version,

	blend_mode : Blend_mode,
	depth_write : bool,
	depth_test : bool,
	polygon_mode : Polygon_mode,
	culling : Cull_method,
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

debug_callback : gl.debug_proc_t : proc "c" (source: gl.GLenum, type: gl.GLenum, id: gl.GLuint, severity: gl.GLenum, length: gl.GLsizei, message: cstring, user_param : rawptr) {
	context = runtime.default_context();
    // Print or handle the debug message here
    fmt.printf("OpenGL Debug Message: %.*s\n", length, message);
}

init :: proc() {
	when RECORD_DEBUG {
		setup_call_recorder();
		gl.capture_gl_callback = record_call;
		gl.capture_error_callback = record_err;
		
		if cpu_state.gl_version >= .opengl_4_3 {
			// Enable debug messages
			//fmt.printf("Enable : %v", gl.Enable);
			gl.Enable(.DEBUG_OUTPUT);
			gl.Enable(.DEBUG_OUTPUT_SYNCHRONOUS);

			// Set up debug callback function
			//gl.DebugMessageCallback(debug_callback, nil);

			// Optionally, specify debug message control
			//gl.DebugMessageControl(.DONT_CARE, .DONT_CARE, .DONT_CARE, 0, nil, true);
			//fmt.printf("Subscribed to OpenGL debug messages\n");
		}
	}

	info = fetch_gl_info();
	fmt.printf("System info : %#v\n", info);
}

destroy :: proc(loc := #caller_location) {
	when RECORD_DEBUG {
		destroy_call_recorder();
	}
	when RENDER_DEBUG {
		leaks := 0;
		
		for field in reflect.struct_fields_zipped(GL_debug_state) {
			s := cast(^map[u32]Source_Code_Location)(cast(uintptr)&debug_state + field.offset);
			
			for id, loc in s {
				fmt.printf("Leak detected! %v with id %i has not been deleted, but allocated at location : %v\n", field.name, id, loc);
				leaks += 1;
			}
		}
		
		fmt.assertf(leaks == 0, "%v OpenGL objects has not been destroyed\n", leaks, loc = loc);
	}
}

/////////// recording ///////////

Error_Enum :: gl.Error_Enum;

when RECORD_DEBUG {
	record_output : os.Handle;
	time_being : time.Time;
}

setup_call_recorder :: proc (filename : string = "gl_calls.txt") {
	when RECORD_DEBUG {
		err : os.Errno;
		record_output, err = os.open(filename, os.O_CREATE|os.O_TRUNC);
		if err != 0 {
			panic("Could not open record file");
		}
		else {
			fmt.printf("recording calles to %v\n", filename);
		}
		time_being = time.now();
	}
}

destroy_call_recorder :: proc () {
	when RECORD_DEBUG {
		err := os.close(record_output);
		if err != 0 {
			fmt.panicf("Could not close record file, %v", err);
		}
	}
}

record_call :: proc(from_loc : runtime.Source_Code_Location, ret_val : any, args : []any, loc : runtime.Source_Code_Location = #caller_location) {
	
	when RECORD_DEBUG {
		call_time_mil_sec : f64 = time.duration_milliseconds(time.since(time_being));
		os.write_string(record_output, fmt.tprintf("%.3f : gl%s(", call_time_mil_sec, loc.procedure));

		for arg, i in args {
			
			if i > 0 { os.write_string(record_output, ", ") }
			
			if v, ok := arg.(gl.GLenum); ok {
				os.write_string(record_output, fmt.tprintf("GL_%v", v));
			} 
			else if v, ok := arg.(gl.GLbitfield); ok {
				os.write_string(record_output, fmt.tprintf("GL_%v", v));
			} 
			else if v, ok := arg.(u32); ok {
				os.write_string(record_output, fmt.tprintf("%v", v));
			}
			else if v, ok := arg.(i32); ok {
				os.write_string(record_output, fmt.tprintf("%v", v));
			}
			else if v, ok := arg.(f32); ok {
				os.write_string(record_output, fmt.tprintf("%v", v));
			}
			else {
				os.write_string(record_output, fmt.tprintf("(%v)%v", arg.id, arg));
			}
		}

		if ret_val != nil {
			os.write_string(record_output, fmt.tprintf(") -> %v", ret_val));
		}
		else {
			os.write_string(record_output, ")");
		}
		
		os.write_string(record_output, "\n");
	}
}

record_err :: proc(from_loc: runtime.Source_Code_Location, err_val: any, err : Error_Enum, args : []any, loc : runtime.Source_Code_Location) {

	fmt.printf("glGetError() returned GL_%v\n", err)
	fmt.printf("	from: gl%s(", loc.procedure);
	for arg, i in args {
		if i != 0 {
			fmt.printf(", ");
		}
		fmt.printf("%v", arg);
	}
	fmt.printf(")\n");

	// add location
	//fmt.printf("	in:   %s(%d:%d)\n", from_loc.file_path, from_loc.line, from_loc.column)

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

			fmt.printf("	recive debug message : %v\n", string(err_str));
			gl.GetIntegerv(.DEBUG_LOGGED_MESSAGES, &mes_cnt)
		}
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
	
	v := gl.GetString(auto_cast gl.VERSION); //TODO: This does not need to be deleted i think?
	version := strings.clone_from(v);

	Major : int = strconv.atoi(version[0:1]);
	Minor : int = strconv.atoi(version[2:3]);

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

/////////// shaders ///////////

//return true if error
@(require_results)
load_shader_program :: proc(name : string, vertex_src : string, fragment_src : string, loc := #caller_location) -> (Shader_program_id, bool) {

	compile_shader :: proc (shader_id : u32) -> (err : bool, msg : string) {
		gl.CompileShader(auto_cast shader_id);

		success : i32;
		gl.GetShaderiv(shader_id, .COMPILE_STATUS, &success);

		if success == 0 {
			log_length  : i32;
			gl.GetShaderiv(shader_id, .INFO_LOG_LENGTH, &log_length);

			err_info : []u8 = make([]u8, log_length + 1, allocator = context.temp_allocator);
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

			err_info : []u8 = make_slice([]u8, log_length + 1, allocator = context.temp_allocator);
			gl.GetProgramInfoLog(shader_id, log_length, nil, auto_cast raw_data(err_info));

			return {};
		}

		return {};
	}

	shader_id_vertex := gl.CreateShader(.VERTEX_SHADER);
	shader_id_fragment := gl.CreateShader(.FRAGMENT_SHADER);

	fmt.printf("Sending the vertex shader code to openGL : \n%s\n", vertex_src);
	shader_sources_vertex : [1]cstring = { strings.clone_to_cstring(vertex_src, allocator = context.temp_allocator) }
	gl.ShaderSource(shader_id_vertex, 1, auto_cast &shader_sources_vertex, nil);
	
	fmt.printf("Sending the fragment shader code to openGL : \n%s\n", fragment_src);
	shader_sources_fragment : [1]cstring = { strings.clone_to_cstring(fragment_src, allocator = context.temp_allocator) }
	gl.ShaderSource(shader_id_fragment, 1, auto_cast &shader_sources_fragment, nil);

	if err, msg := compile_shader(auto_cast shader_id_vertex); err {
		fmt.printf("Failed to compile vertex shader %v, ERROR : '%s'\n", name, msg);
		return 0, true;
	}

	if err, msg := compile_shader(auto_cast shader_id_fragment); err {
		fmt.printf("Failed to compile fragment shader %v, ERROR : '%s'\n", name, msg);
		return 0, true;
	}

	shader_program : Shader_program_id = auto_cast gl.CreateProgram();
	gl.AttachShader(auto_cast shader_program, auto_cast shader_id_vertex);
	gl.AttachShader(auto_cast shader_program, auto_cast shader_id_fragment);
	
	if err := link_shader_program(auto_cast shader_program); err != {} {
		fmt.printf("Failed to link shader program %v, ERROR : %s\n", name, err);
		return 0, true;
	}

	gl.DeleteShader(shader_id_vertex);
	gl.DeleteShader(shader_id_fragment);

	when RENDER_DEBUG {
		debug_state.programs[shader_program] = loc;
	}

	return shader_program, false;
}

unload_shader_program :: proc(shader : Shader_program_id) {
	
	gl.DeleteProgram(auto_cast shader);
	
	when RENDER_DEBUG {
		delete_key(&debug_state.programs, shader);
	}
}

@(deprecated="should it be cpu_state or gpu_state?")
use_program :: proc(id : Shader_program_id) {
	
	if gpu_state.bound_shader == id {
		return;
	}
	
	gl.UseProgram(auto_cast id);
	
	cpu_state.bound_shader = id;
	gpu_state.bound_shader = id;
}

clear :: proc(clear_color : [4]f32, flags : Clear_flags = {.color_bit, .depth_bit}) {
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

bind_vertex_array :: proc (vao : Vao_id) {
	
	if gpu_state.bound_vao == vao {
		return
	}

	gl.BindVertexArray(auto_cast vao);

	cpu_state.bound_vao = vao;
	gpu_state.bound_vao = vao;
}

unbind_vertex_array :: proc () {
	cpu_state.bound_vao = 0;
}

delete_vertex_arrays :: proc (vaos : []Vao_id) {
	
	if cpu_state.bound_vao == 0 {
		for vao in vaos {
			if gpu_state.bound_vao == vao {
				gl.BindVertexArray(auto_cast vao);
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
			gl.BindVertexArray(auto_cast vao);
			gpu_state.bound_vao = 0;
		}
	}
	
	gl.DeleteVertexArrays(1, cast([^]u32)&vao);

	when RENDER_DEBUG {
		delete_key(&debug_state.vaos, vao);
	}

}

//TODO this assumes only one buffer per VAO
associate_buffer_with_vao :: proc (vao : Vao_id, buffer : Buffer_id, attributes : []Attribute_info_ex, loc := #caller_location) {

	bind_vertex_array(auto_cast vao);
	bind_buffer(.array_buffer, auto_cast buffer);
	
	for attrib, i in attributes {
		//fmt.printf("setting up VertexAttribPointer : %v, %v, %v, %v, %v, %v\n", attrib.location, get_attribute_type_dimensions(attrib.attribute_type), get_attribute_primary_type(attrib.attribute_type), attrib.normalized, attrib.stride, attrib.offset);
		gl.VertexAttribPointer(auto_cast attrib.location, auto_cast get_attribute_type_dimensions(attrib.attribute_type), auto_cast get_attribute_primary_type(attrib.attribute_type), attrib.normalized, attrib.stride, attrib.offset);
		gl.EnableVertexAttribArray(auto_cast attrib.location);
		//VertexAttribPointer      :: proc "c" (index: u32, size: i32, type: u32, normalized: bool, stride: i32, pointer: uintptr)
	}

	unbind_buffer(.array_buffer);
	unbind_vertex_array();
}

draw_arrays :: proc (vao : Vao_id, primitive : Primitive, #any_int first, count : i32) {
	bind_vertex_array(auto_cast vao);
    gl.DrawArrays(auto_cast primitive, first, count);
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
	
	if gpu_state.bound_buffer[location] == buffer {
		return
	}

	gl.BindBuffer(auto_cast location, auto_cast buffer);

	cpu_state.bound_buffer[location] = buffer;
	gpu_state.bound_buffer[location] = buffer;
}

unbind_buffer :: proc(location : Buffer_type) {
	cpu_state.bound_buffer[location] = 0;
}

//Setup the buffer (with optional data, data = nil. No data)
buffer_data :: proc(buffer : Buffer_id, target : Buffer_type, size : int, data : rawptr, usage : Resource_usage) {	
	
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

/* 
buffer_sub_data :: proc (buffer : Buffer_id, target : Buffer_type, #any_int offset_bytes : int, data : []u8) {
	if cpu_state.gl_version >= .opengl_4_5 {
		gl.NamedBufferSubData(auto_cast buffer, offset_bytes, len(data), raw_data(data));
	}
	else {
		bind_buffer(target, buffer);
		gl.BufferSubData(auto_cast target, offset_bytes, len(data), raw_data(data));
		unbind_buffer(target);
	}
}
*/

map_buffer_range :: proc (buffer : Buffer_id, buffer_type : Buffer_type, offset, length : int, usage : Resource_usage) -> (p : rawptr) {

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

unmap_buffer :: proc (buffer : Buffer_id, buffer_type : Buffer_type) {

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
make_resource_parameterized :: proc(bytes_count : int, buffer_type : Buffer_type, resource_usage : Resource_usage, data : []u8, loc :=#caller_location) -> Resource {
	
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

make_resource :: proc {make_resource_parameterized, make_resource_desc};

@(deprecated="TODO place fences and stuff")
destroy_resource :: proc(resource : ^Resource) {

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
		unmap_buffer(resource.buffer, resource.buffer_type);
	}

	delete_buffer(resource.buffer_type, resource.buffer);
}

//this may unbind/(delete/create) the/a buffer if bound and invalidate/delete any data, after calling this you will have to reupload any data. Be sure
resize_buffer :: proc (resource : ^Resource, #any_int new_size : int, loc := #caller_location) {

	#partial switch resource.usage {
		case .static_read, .static_write, .static_read_write, .static_host_only:
			panic("A static buffer cannot be resized, it is static!", loc = loc);
		case:
			//stream and dynamic can resize.
	}

	panic("TODO!");
}

//if range == nil then the entire buffer is returned. Range is {being, end}
//You must sync, so that you do not write to any data currently being used.
@(require_results)
begin_buffer_write :: proc(resource : ^Resource, range : Maybe([2]int) = nil, loc := #caller_location) -> (data : []u8) {
	
	begin : int = 0;
	length : int = resource.bytes_count;
	p : rawptr = nil;

	if r, ok := range.?; ok {
		begin = r.x;
		length = r.y - r.x;
	}

	switch resource.usage {

		case .stream_write, .stream_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				//Nothing happens, sync happen by the user (in the render lib)
			}
			else {
				p = map_buffer_range(resource.buffer, resource.buffer_type, begin, length, resource.usage);
			}
		
		case .dynamic_write, .dynamic_read_write:
			if cpu_state.gl_version >= .opengl_4_4 {
				p = map_buffer_range(resource.buffer, resource.buffer_type, begin, length, resource.usage);
			}
			else {
				p = map_buffer_range(resource.buffer, resource.buffer_type, begin, length, resource.usage);
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
	raw : runtime.Raw_Slice = {data = p, len = resource.bytes_count}

	return transmute([]u8)raw;
}

//after calling this you may not change the buffer data (or even keep a refernce to it)
@(deprecated="this should not unmap buffer that are persistent, so what do we do here? just a sync point?")
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


/*
//Return false if a unnecessary stall/wait is required if end_buffer_write is called at this time.
//return true if it is a good idea to call end_buffer_write.
@(require_results)
is_end_buffer_write_ready :: proc(resource : Resource) -> bool {
	
	switch resource.behavior {
		case .sync:
			return true;

		case .async:
			panic("todo");

		case .persistent:
			if cpu_state.gl_version >= .opengl_4_4 {
				panic("TODO");
			}
			else {
				panic("TODO");
			}
	}
	
	unreachable();
}

 
request_buffer_read :: proc(buffer : Resource, range : Maybe([2]int) = nil) {
	//TODO
}

commit_buffer_read :: proc() -> (data : []u8) {
	//TODO
}
*/


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

	gl.DeleteRenderbuffers(auto_cast len(rbos), auto_cast raw_data(rbos));
	
	when RENDER_DEBUG {
		for r in rbos {
			delete_key(&debug_state.rbos, r);
		}
	}
}

delete_render_buffer :: proc(rbo : Rbo_id) {
	
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
	
	if cpu_state.bound_target == 0 && gpu_state.bound_target == fbo {
		gl.BindFramebuffer(.FRAMEBUFFER, 0);
		gpu_state.bound_target = 0;
	}

	fbo := fbo;
	gl.DeleteFramebuffers(1, auto_cast &fbo);

	when RENDER_DEBUG {
		delete_key(&debug_state.fbos, fbo);
	}
}

bind_frame_buffer :: proc(fbo : Fbo_id, loc := #caller_location) {
	
	if gpu_state.bound_target == fbo {
		return;
	}

	gl.BindFramebuffer(.FRAMEBUFFER, auto_cast fbo);
	
	cpu_state.bound_target = fbo;
	gpu_state.bound_target = fbo;
}

unbind_frame_buffer  :: proc() {
	
	cpu_state.bound_target = 0;

	//This will not unbind the framebuffer, it will just note that should do it if required by another call.
	//gl.BindFramebuffer(.FRAMEBUFFER, 0);
}

Color_format :: enum u32 {
	rgba8 = gl.RGBA8,
	rgba16f = gl.RGBA16F,
	rgba32f = gl.RGBA32F,
	rgb8 = gl.RGB8,
	rgb16f = gl.RGB16F,
	rgb32f = gl.RGB32F,
}

associate_color_render_buffers_with_frame_buffer :: proc(fbo : Fbo_id, render_buffers : []Rbo_id, width, height, samples_hint : i32, start_index : int = 0, color_format : Color_format = .rgba8, loc := #caller_location) -> (samples : i32) {

	assert(len(render_buffers) + start_index <= MAX_COLOR_ATTACH, "you can only have up to 8 color attachments", loc);
	assert(color_format != nil, "color_format is nil", loc);

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
		gl.BindFramebuffer(.FRAMEBUFFER, auto_cast fbo);
		
		// Create a multisampled renderbuffer object for color attachment
		for i in 0 ..< len(render_buffers) {

			gl.BindRenderbuffer(.RENDERBUFFER, auto_cast render_buffers[i]);

			if samples == 1 {
				gl.RenderbufferStorage(.RENDERBUFFER, auto_cast color_format, width, height);
			}
			else {
				gl.RenderbufferStorageMultisample(.RENDERBUFFER, samples, auto_cast color_format, width, height);
			}
			
			gl.FramebufferRenderbuffer(.FRAMEBUFFER, auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast (i + start_index)), .RENDERBUFFER, auto_cast render_buffers[i]);
		}

		gl.BindRenderbuffer(.RENDERBUFFER, 0);
		gl.BindFramebuffer(.FRAMEBUFFER, 0);	
	}

	return;
}

Depth_format :: enum u32 {
	depth_component16 = gl.DEPTH_COMPONENT16,
	depth_component24 = gl.DEPTH_COMPONENT24,
	depth_component32 = gl.DEPTH_COMPONENT32,
}

associate_depth_render_buffer_with_frame_buffer :: proc(fbo : Fbo_id, render_buffer : Rbo_id, width, height, samples_hint : i32, depth_format : Depth_format = .depth_component24, loc := #caller_location) -> (samples : i32) {

	assert(depth_format != nil, "color_format is nil", loc);
	
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
		gl.BindFramebuffer(.FRAMEBUFFER, auto_cast fbo);
		gl.BindRenderbuffer(.RENDERBUFFER, auto_cast render_buffer);
		
		if samples == 1 {
			gl.RenderbufferStorage(.RENDERBUFFER, auto_cast depth_format, width, height);
		}
		else {
			gl.RenderbufferStorageMultisample(.RENDERBUFFER, samples, auto_cast depth_format, width, height);
		}
		gl.FramebufferRenderbuffer(.FRAMEBUFFER, .DEPTH_ATTACHMENT, .RENDERBUFFER, auto_cast render_buffer);
		
		gl.BindFramebuffer(.FRAMEBUFFER, 0);
		gl.BindRenderbuffer(.RENDERBUFFER, 0);
	}

	return;
}

//TODO make this return an error instead of crashing
validate_frame_buffer :: proc (fbo : Fbo_id, loc := #caller_location) -> (valid : bool) {
	// Check if framebuffer is complete
	
	status := gl.CheckFramebufferStatus(.FRAMEBUFFER);

	if (status != .FRAMEBUFFER_COMPLETE) {
		
		/* 
		TODO move the the associate functions
		for ca, i in color_attachements {
			if attachment, ok := ca.?; ok {

				attachment_type : gl.GLenum;
				attachemnt_id_enum : gl.GLenum = auto_cast (cast(u32)gl.GLenum.COLOR_ATTACHMENT0 + auto_cast i);
				gl.GetFramebufferAttachmentParameteriv(.FRAMEBUFFER, attachemfvt_id_enum, .FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, auto_cast &attachment_type);

				if (attachment_type == .NONE) {
					fmt.printf("Framebuffer is missing a color attachment %v", i);
				}
				assert(attachment_type == .RENDERBUFFER, "attachment_type is not a renderbuffer!");
			}
		}

		depth_attachment_type : gl.GLenum;
		gl.GetFramebufferAttachmentParameteriv(.FRAMEBUFFER, .DEPTH_ATTACHMENT, .FRAMEBUFFER_ATTACHMENT_OBJECT_TYPE, auto_cast &depth_attachment_type);
		if (depth_attachment_type == .NONE) {
			fmt.printf("Framebuffer is missing a depth attachment");
		}
		assert(depth_attachment_type == .RENDERBUFFER, "attachment_type is not a renderbuffer!");
		fmt.panicf("TODO move this. Framebuffer is not complete! Statues : %v", status, loc = loc);
		*/
		return false;
	}

	return true;
}

blit_fbo_to_screen :: proc(fbo : Fbo_id, src_x, src_y, src_width, src_height, dst_x, dst_y, dst_width, dst_height : i32, use_linear_interpolation := false) {
	
	interpolation : gl.GLenum = .NEAREST;

	if use_linear_interpolation {
		interpolation = .LINEAR;
	}

	if cpu_state.gl_version >= .opengl_4_5 {
		gl.BlitNamedFramebuffer(auto_cast fbo, 0, src_x, src_y, src_width, src_height, dst_x, dst_y, dst_width, dst_height, .COLOR_BUFFER_BIT, interpolation);
	}
	else {
		gl.BindFramebuffer(.READ_FRAMEBUFFER, auto_cast fbo);
		gl.BindFramebuffer(.DRAW_FRAMEBUFFER, 0);
		gl.BlitFramebuffer(src_x, src_y, src_width, src_height, dst_x, dst_y, dst_width, dst_height, .COLOR_BUFFER_BIT, interpolation); //TODO options for .COLOR_BUFFER_BIT, .NEAREST
		gl.BindFramebuffer(.READ_FRAMEBUFFER, 0);
	}
}

//////////////////////////////////////////// Private functions ////////////////////////////////////////////

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
		res[name] = Uniform_info{location = get_uniform_location(program_id, name), uniform_type = auto_cast shader_type, array_size = size};
	}

	return;
}

@(require_results)
get_attribute_location :: proc(shader_id : Shader_program_id, attrib_name : string) -> Attribute_id {
	return auto_cast gl.GetAttribLocation(auto_cast shader_id, fmt.ctprintf(attrib_name));
}

@(require_results)
get_uniform_location :: proc(shader_id : Shader_program_id, uniform_name : string) -> Uniform_id {
	return auto_cast gl.GetUniformLocation(auto_cast shader_id, fmt.ctprintf(uniform_name));
}