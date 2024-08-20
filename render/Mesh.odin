package render;

import "core:fmt"
import "core:reflect"
import "base:runtime"
import "core:mem"
import "core:slice"
import "core:log"
import "core:math"
import "core:container/queue"

import "core:math/linalg/glsl"
import "core:math/linalg"

import "gl"
import glgl "gl/OpenGL"

////////////////////////////// Single mesh //////////////////////////////
//Welcome to the mesh.odin file. Meshes are complicated because it is alot about how we render them.
/////////////////////////////////////////////////////////////////////////

//This is the vertex that is used internally in furbs, you can use your own, but this is what is returned when you genereate the buildin meshes.
Default_vertex :: struct {
	position 	: [3]f32,
	texcoord 	: [2]f32,
	normal 		: [3]f32,
}

Default_instance_data :: struct {
	instance_position 	: [3]f32,
	instance_scale 		: [3]f32,
	instance_rotation 	: [3]f32, //Euler rotation
	instance_tex_pos_scale 	: [4]f32,
}

//These are removed to other locations
	//Occlusion culling should be handled somehow? 											- 

//mesh should be more complex, as it needs to handle:
	//Async upload 																			- done
	//Dynamicly changing the mesh (sync or async)											- done
	//Frustum culling should be a thing we handle											- We can do this when we have made a camera, so now
	//Somehow there is also a need for instance drawing (closely realated to mesh)			- Can we do this?? we need extra attribute data

//used internally, descipes some mesh features
Mesh_desc :: struct {
	vertex_count 	: int,
	index_count 	: int,

	primitive : gl.Primitive,

	data_type : typeid,
	usage : Usage,
	indices_type : Index_buffer_type,
}

Index_buffer_type :: gl.Index_buffer_type;

Usage :: enum {
	static_use 	= auto_cast gl.Resource_usage.static_write,		//You cannot update this mesh
	dynamic_use = auto_cast gl.Resource_usage.dynamic_write,	//Will use BufferSubData for updates
	stream_use	= auto_cast gl.Resource_usage.stream_write,		//Will use persistent mapped buffer and fallback to unsyncronized mapped buffers.
}

Instance_usage :: enum {
	dynamic_upload = auto_cast gl.Resource_usage.dynamic_write,		//Will use BufferSubData for updates
	stream_upload	= auto_cast gl.Resource_usage.stream_write,		//Will use persistent mapped buffer and fallback to unsyncronized mapped buffers.

	dynamic_copy = auto_cast gl.Resource_usage.dynamic_host_only,	//Will use BufferSubData for updates
	stream_copy	= auto_cast gl.Resource_usage.stream_host_only,		//Will use persistent mapped buffer and fallback to unsyncronized mapped buffers.
}

Indices :: union {
	[]u16,
	[]u32,
}

indices_delete :: proc (indices : Indices, loc := #caller_location) {
	switch ind in indices {
		case nil:
		case []u16:
			delete(ind, loc = loc); 
		case []u32:
			delete(ind, loc = loc); 
	}
}

indices_len  :: proc (indices : Indices) -> int {
	switch ind in indices {
		case nil:
			return 0;
		case []u16:
			return len(ind);
		case []u32:
			return len(ind);
	}
	unreachable();
}

////////////////////////////// Common mesh interface //////////////////////////////

//A mesh_single, mesh_buffered and mesh_shared server at a high level the same purpose.
//It is the underleying implementation that differes for preformence reasons.
//So a common interface is made for them to abstract away the implementation.
//This makes it easier to change the implementation later if so needed.
//There is a small overhead associated with check the type for every call. This is a very small overhead.

Mesh_ptr :: union {
	^Mesh_single,
	^Mesh_buffered,
	^Mesh_shared,
}

//Destroys a mesh_single, mesh_buffered and mesh_shared
mesh_destroy :: proc (mesh : Mesh_ptr) {
	switch v in mesh {
		case ^Mesh_single:
			mesh_destroy_single(v);
		case ^Mesh_buffered:
			mesh_destroy_buffered(v);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Upload to a mesh_single, mesh_buffered and mesh_shared
upload_vertex_data :: proc (mesh : Mesh_ptr, #any_int start_vertex : int, data : []$T, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			upload_vertex_data_single(v, start_vertex, data, loc = loc);
		case ^Mesh_buffered:
			upload_vertex_data_buffered(v, start_vertex, data, loc = loc);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Upload to a mesh_single, mesh_buffered and mesh_shared
upload_index_data :: proc(mesh : Mesh_ptr, #any_int start_index : int, data : Indices, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			upload_index_data_single(v, start_index, data, loc = loc);
		case ^Mesh_buffered:
			upload_index_data_buffered(v, start_index, data, loc = loc);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Upload instance data to a mesh_single, mesh_buffered and mesh_shared
upload_instance_data :: proc(mesh : Mesh_ptr, #any_int start_index : int, data : []$T, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			upload_instance_data_single(v, start_index, data, loc = loc);
		case ^Mesh_buffered:
			upload_instance_data_buffered(v, start_index, data, loc = loc);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Will copy data, so data is not destroyed.
mesh_resize :: proc(mesh : Mesh_ptr, #any_int new_vert_size, new_index_size : int, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			mesh_resize_single(v, new_vert_size, new_index_size, loc);
		case ^Mesh_buffered:
			resize_mesh_bufferd(v, new_vert_size, new_index_size);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Draws a mesh_single, mesh_buffered and mesh_shared
//There is a limitation here, and that is not that only the entire model can be drawn.
//This is because  mesh_single, mesh_buffered and mesh_shared requires handling draw_range in different ways.
mesh_draw :: proc (mesh : Mesh_ptr, model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			mesh_draw_single(v, model_matrix, color, nil, loc);
		case ^Mesh_buffered:
			i := mesh_buffered_next_draw_source(v);
			draw_mesh_buffered(v, model_matrix, color, i, loc = loc);
		case ^Mesh_shared:
			panic("TODO");
	}
}

mesh_draw_instanced :: proc (mesh : Mesh_ptr, #any_int instance_cnt : int, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			mesh_draw_single_instanced(v, instance_cnt, color, nil, loc);
		case ^Mesh_buffered:
			i := mesh_buffered_next_draw_source(v);
			draw_mesh_buffered_instanced(v, instance_cnt, i, color, nil, loc);
		case ^Mesh_shared:
			panic("TODO");
	}
}





////////////////////////////// Single mesh //////////////////////////////

Instance_data_desc :: struct {
	data_type : typeid,
	data_points : int,
	usage : Instance_usage,
}

Instance_data :: struct {
	data : gl.Resource,
	using desc : Instance_data_desc,
}

Mesh_single :: struct {
	
	using desc 		: Mesh_desc,
	
	vao : Vao_id,							//The VAO
	vertex_data : gl.Resource,				//Vertex data is required
	indices_buf : Maybe(gl.Resource),		//Using indicies is optional //TODO maybe rename "buf" to "data"
	instance_data : Maybe(Instance_data),	//Using instace data is optional
	read_fence : gl.Fence, 					//Only used when streaming. When fence is signaled then we are done reading.
}

//Index_data may be nil if there should be no incidies. 
@(require_results)
mesh_make_single :: proc (vertex_data : []$T, index_data : Indices, usage : Usage, primitive : gl.Primitive = .triangles, instance : Maybe(Instance_data_desc) = nil, loc := #caller_location) -> (mesh : Mesh_single) {
	
	mesh.vertex_count = len(vertex_data);
	mesh.data_type = T;
	mesh.primitive = primitive;
	mesh.usage = usage;
	
	mesh_index_buf_data : []u8;
	switch indicies in index_data {
		case []u16:
			assert(indicies != nil, "there is no indicies index_data, but type is []u16", loc);
			assert(len(vertex_data) <= auto_cast max(u16), "The range of a u16 is exceeded", loc);
			mesh.indices_type = .unsigned_short;
			mesh.index_count = len(indicies);
			mesh_index_buf_data = slice.reinterpret([]u8, indicies);
		case []u32:
			assert(indicies != nil, "there is no indicies index_data, but type is []u32", loc);
			assert(len(vertex_data) <= auto_cast max(u32), "The range of a u32 is exceeded", loc);
			mesh.indices_type = .unsigned_int;
			mesh.index_count = len(indicies);
			mesh_index_buf_data = slice.reinterpret([]u8, indicies);
		case nil:
			mesh.indices_type = .no_index_buffer;
			mesh.index_count = 0;
			mesh_index_buf_data = nil;
	}
	
	setup_mesh_single(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, instance, loc);

	return;
}

//Makes a mesh_single without data
@(require_results)
mesh_make_single_empty :: proc (#any_int vertex_size : int, data_type : typeid, #any_int index_size : int, index_type : Index_buffer_type, usage : Usage, primitive : gl.Primitive = .triangles, instance : Maybe(Instance_data_desc) = nil, loc := #caller_location) -> (mesh : Mesh_single) {

	if index_type != .no_index_buffer {
		assert(index_size != 0, "index size must not be 0, if index_type is not no_index_buffer", loc);
	}
	else {
		assert(index_size == 0, "index size must be 0, if index_type is no_index_buffer", loc);
	}

	mesh.vertex_count = vertex_size;
	mesh.data_type = data_type;
	mesh.primitive = primitive;
	mesh.usage = usage;
	
	mesh.index_count = index_size;
	mesh.indices_type = index_type;
	
	setup_mesh_single(&mesh, nil, nil, instance, loc);

	return;
}

//Destroys the mesh (frees all associated resources)
mesh_destroy_single :: proc (mesh : ^Mesh_single) {
	
	gl.destroy_resource(mesh.vertex_data);
	gl.discard_fence(&mesh.read_fence); //discarding an nil fence is allowed
	if ib, ok := mesh.indices_buf.?; ok {
		gl.destroy_resource(ib);
	}
	gl.delete_vertex_array(mesh.vao);

	if inst, ok := mesh.instance_data.?; ok {
		gl.destroy_resource(inst.data);
	}

}

//TODO it seems like a bad idea that upload_vertex_data_single uses persistent mapped buffers.
//It requires us to place a flag when drawing, but we have to do that anyway because, even if we move that to map_vertex_data_single, then it should be known.
//Currently we do that only when it is streaming. Is that a good idea?

//The mesh does not change its size, it will error of you pass to much data.
//If you just want to update a some verticeis
upload_vertex_data_single :: proc(mesh : ^Mesh_single, #any_int start_vertex : int, data : []$T, loc := #caller_location) {
	
	assert(start_vertex >= 0, "start_vertex cannot be negative", loc);
	assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
	assert(mesh.vertex_count >= len(data) + start_vertex, "data out of bounds", loc);
	
	byte_size := reflect.size_of_typeid(mesh.data_type);
	
	when ODIN_DEBUG {
		if mesh.usage == .stream_use && !gl.is_fence_ready(mesh.read_fence) {
			log.warnf("Preformence warning: upload_mesh_data sync is not ready\n");
		}
	}
	
	if mesh.usage == .stream_use {
		gl.sync_fence(&mesh.read_fence);
	}

	//We need to check the current resouce size is the same as the vertex_size
	if mesh.vertex_data.bytes_count < byte_size * mesh.vertex_count {
		//The resouce should be resized
		fmt.panicf("We cannot resize, resource_bytes_count : %v. vertex_byte_count : %v", mesh.vertex_data.bytes_count, mesh.vertex_count, loc = loc);
	}
	
	byte_data := slice.reinterpret([]u8, data);

	//Then upload
	upload_mesh_resource_bytes(mesh.usage, &mesh.vertex_data, byte_data, byte_size, start_vertex);
}

upload_index_data_single :: proc(mesh : ^Mesh_single, #any_int start_index : int, data : Indices, loc := #caller_location) {

	assert(start_index >= 0, "start_vertex cannot be negative", loc);
	//TODO similar for Indices assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
	assert(mesh.indices_type != .no_index_buffer, "this mesh has no index buffer", loc);

	when ODIN_DEBUG {
		if mesh.usage == .stream_use && !gl.is_fence_ready(mesh.read_fence) {
			log.warnf("Preformence warning: upload_mesh_data sync is not ready\n");
		}
	}
	
	if mesh.usage == .stream_use {
		gl.sync_fence(&mesh.read_fence);
	}

	byte_size := 0;

	switch mesh.indices_type {
		case .no_index_buffer:
			panic("!?!?");
		case .unsigned_short:
			byte_size = size_of(u16);
		case .unsigned_int:
			byte_size = size_of(u32);
	}

	if indicies, ok := &mesh.indices_buf.?; ok {
		
		assert(indicies.bytes_count >= byte_size * mesh.index_count);
		
		byte_data : []u8;

		switch d in data {
			case nil:
				panic("!?!");
			case []u16:
				assert(mesh.index_count >= len(d) + start_index, "data out of bounds", loc);
				byte_data = slice.reinterpret([]u8, d);
			case []u32:
				assert(mesh.index_count >= len(d) + start_index, "data out of bounds", loc);
				byte_data = slice.reinterpret([]u8, d);	
		}

		//Then upload
		upload_mesh_resource_bytes(mesh.usage, indicies, byte_data, byte_size, start_index);
	}
	else {
		panic("invalid mesh state", loc);
	}
}

//TODO upload consistent!?!??! so we dont overwrite things many times.
upload_instance_data_single :: proc(mesha : ^Mesh_single, #any_int start_index : int, data : []$T, loc := #caller_location) {
	assert(start_index >= 0, "start_index cannot be negative", loc);

	if instance_data, ok := &mesha.instance_data.?; ok {
		assert(T == instance_data.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
		byte_size := reflect.size_of_typeid(instance_data.data_type);
		fmt.assertf(instance_data.data.bytes_count == instance_data.data_points * byte_size, "internal error : %v, %v", instance_data.data.bytes_count, instance_data.data_points * byte_size, loc = loc);
		assert(instance_data.data.bytes_count >= (len(data) + start_index) * byte_size, "data out of bounds", loc);
		
		//TODO needed?
		/*
		when ODIN_DEBUG {
			if (instance_data.usage == .stream_upload ||  instance_data.usage == .stream_copy)  && !gl.is_fence_ready(mesh.read_fence) {
				log.warnf("Preformence warning: upload_instance_data_single sync is not ready\n");
			}
		}
		
		if instance_data.usage == .stream_upload || instance_data.usage == .stream_upload {
			gl.sync_fence(&mesh.read_fence);
		}
		*/

		byte_data := slice.reinterpret([]u8, data);
		
		//Then upload
		switch instance_data.usage {				
			case .dynamic_upload, .dynamic_copy:
				gl.buffer_upload_sub_data(&instance_data.data, byte_size * start_index, byte_data);
			case .stream_upload, .stream_copy:
				dst : []u8 = gl.begin_buffer_write(&instance_data.data, byte_size * start_index, len(byte_data));
				fmt.assertf(len(dst) == len(byte_data), "length of buffer and length of data does not match. dst : %i, data : %i", len(dst), len(byte_data), loc = loc);
				mem.copy_non_overlapping(raw_data(dst), raw_data(data), len(dst)); //TODO this mapping and unmapping is not nice when we upload multiple time a frame... in the mesh share for example.
				gl.end_buffer_writes(&instance_data.data);
		}
	} else { 
		panic("This mesh is not instanced");
	}
}

//Internal use only
@(private)
remake_resource :: proc (old_res : gl.Resource, new_size : int, loc := #caller_location) -> gl.Resource {
	new_desc := old_res.desc;
	new_desc.bytes_count = new_size;
	new_res := gl.make_resource_desc(new_desc, nil, loc = loc);

	is_streaming : bool = old_res.usage == .stream_host_only ||old_res.usage == .stream_read || old_res.usage == .stream_read_write || old_res.usage == .stream_write;

	if is_streaming {
		panic("TODO this will not work for streaming buffers");
	}
	else {
		gl.copy_buffer_sub_data(old_res.buffer, new_res.buffer, 0, 0, math.min(new_res.bytes_count, old_res.bytes_count));
		gl.destroy_resource(old_res);
	}
	
	return new_res;
}

//Data will be copied over
mesh_resize_single :: proc(mesh : ^Mesh_single, #any_int new_vert_size, new_index_size : int, loc := #caller_location) {
	assert(mesh.usage != .static_use, "Cannot resize a static usage mesh", loc);
	if new_index_size == 0 {
		assert(mesh.index_count == 0, "new_index_size may not be non-zero if existing size is zero", loc);
	}

	log.infof("resizing mesh old sizes : %v, %v, new sizes : %v, %v", mesh.vertex_count, mesh.index_count, new_vert_size, new_index_size);

	{
		byte_size := reflect.size_of_typeid(mesh.data_type);
		attrib_info := get_attribute_info_from_typeid(mesh.data_type, loc);
		defer delete(attrib_info);

		mesh.vertex_data = remake_resource(mesh.vertex_data, byte_size * new_vert_size);
		gl.associate_buffer_with_vao(mesh.vao, mesh.vertex_data.buffer, attrib_info, 0, loc);
		
		mesh.vertex_count = new_vert_size;
	}

	switch mesh.indices_type {

		case .no_index_buffer:
			assert(new_index_size == 0, "if there is no index buffer then new_index_size must be 0", loc);
		
		case .unsigned_short:
			byte_size : int = 16;
			if i, ok := mesh.indices_buf.(gl.Resource); ok {
				new_buf := remake_resource(i, byte_size * new_index_size);
				mesh.indices_buf = new_buf;
				gl.associate_index_buffer_with_vao(mesh.vao, new_buf.buffer);
			}
			else {
				assert(ok, "internal error");
			}
			
		case .unsigned_int:
			byte_size : int = 32;
			if i, ok := mesh.indices_buf.(gl.Resource); ok {
				new_buf := remake_resource(i, byte_size * new_index_size);
				mesh.indices_buf = new_buf;
				gl.associate_index_buffer_with_vao(mesh.vao, new_buf.buffer);
			}
			else {
				assert(ok, "internal error");
			}
	}

	mesh.index_count = new_index_size;
}

//Data will be copied over
mesh_resize_instance_single :: proc(mesh : ^Mesh_single, instance_size : int, loc := #caller_location) {
	
	if instance, ok := &mesh.instance_data.?; ok {

		instanced_attrib_info := get_attribute_info_from_typeid(instance.data_type, loc);
		defer delete(instanced_attrib_info);

		instance.data = remake_resource(instance.data, instance_size * reflect.size_of_typeid(instance.data_type), loc = loc);
		gl.associate_buffer_with_vao(mesh.vao, instance.data.buffer, instanced_attrib_info, 1, loc);
		
		instance.data_points = instance_size;
	}
	else {
		panic("This mesh is not instanced");
	}
}

mesh_draw_single :: proc (mesh : ^Mesh_single, model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	assert(mesh.instance_data == nil, "This is an instanced mesh, use the draw_*_instanced function.", loc)
	assert(mesh.primitive != nil);
	
	start : int = 0;
	vertex_count := mesh.vertex_count;
	index_count := mesh.index_count;

	if r, ok := draw_range.?; ok {
		start = r.x;
		vertex_count = r.y - r.x;
		index_count = r.y - r.x;
	}
	
	set_uniform(state.bound_shader, .color_diffuse, color);
	set_uniform(state.bound_shader, .model_mat, model_matrix);
	set_uniform(state.bound_shader, .inv_model_mat, linalg.matrix4_inverse(model_matrix));
	mvp := state.prj_mat * state.view_mat * model_matrix;
	set_uniform(state.bound_shader, .mvp, mvp);
	set_uniform(state.bound_shader, .inv_mvp, linalg.matrix4_inverse(mvp));
	
	switch mesh.indices_type {
		case .no_index_buffer:
			gl.draw_arrays(mesh.vao, mesh.primitive, start, vertex_count); //TODO triangles should be an option
		case .unsigned_short, .unsigned_int:
			if i_buf, ok := mesh.indices_buf.?; ok {
				gl.draw_elements(mesh.vao, mesh.primitive, start, index_count, mesh.indices_type, i_buf.buffer);//TODO triangles should be an option
			}
			else {
				panic("The mesh does not have a index buffer", loc);
			}
	}

	if mesh.usage == .stream_use {
		gl.discard_fence(&mesh.read_fence);
		mesh.read_fence = gl.place_fence();
	}
}

mesh_draw_single_instanced :: proc (mesh : ^Mesh_single, #any_int instance_cnt : i32, color : [4]f32 = {1,1,1,1}, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	assert(mesh.instance_data != nil, "This is an not an instanced mesh", loc);
	assert(mesh.primitive != nil);
	
	start : int = 0;
	vertex_count := mesh.vertex_count;
	index_count := mesh.index_count;
	if r, ok := draw_range.?; ok {
		start = r.x;
		vertex_count = r.y - r.x;
		index_count = r.y - r.x;
	}
	
	set_uniform(state.bound_shader, .color_diffuse, color);
	model_matrix : matrix[4,4]f32 = 1;
	set_uniform(state.bound_shader, .model_mat, model_matrix);
	set_uniform(state.bound_shader, .inv_model_mat, linalg.matrix4_inverse(model_matrix));
	mvp := state.view_prj_mat * model_matrix;
	set_uniform(state.bound_shader, .mvp, mvp);
	set_uniform(state.bound_shader, .inv_mvp, linalg.matrix4_inverse(mvp));
	
	switch mesh.indices_type {
		case .no_index_buffer:
			gl.draw_arrays_instanced(mesh.vao, mesh.primitive, 0, vertex_count, instance_cnt); //TODO triangles should be an option
		case .unsigned_short, .unsigned_int:
			if i_buf, ok := mesh.indices_buf.?; ok {
				gl.draw_elements_instanced(mesh.vao, mesh.primitive, start, index_count, mesh.indices_type, i_buf.buffer, instance_cnt); //TODO triangles should be an option
			}
			else {
				panic("The mesh does not have a index buffer", loc);
			}
	}
	
	if mesh.usage == .stream_use {
		gl.discard_fence(&mesh.read_fence);
		mesh.read_fence = gl.place_fence();
	}
}













////////////////////////////// Buffered mesh //////////////////////////////

Mesh_buffered :: struct {
	using desc : Mesh_desc,

	backing : [dynamic]Backing_mesh,
	current_read : int,		//This is the mesh/buffers we are currently drawing from
	current_write : int,	//This is the mesh/buffers we are currently reading from
}

@(require_results)
//Passing 1 in buffering is allowed but not recommended, if this is a behavior you want use a Mesh_single.
make_mesh_buffered :: proc (#any_int buffering, vertex_size : int, data_type : typeid, #any_int index_size : int, index_type : Index_buffer_type,
								 usage : Usage, primitive : gl.Primitive = .triangles, instance : Maybe(Instance_data_desc) = nil, loc := #caller_location) -> (mesh :Mesh_buffered) {
	
	assert(buffering >= 1, "must have at least 1 buffer", loc);
	assert(usage != .static_use, "A buffered mesh cannot be static", loc);

	mesh.desc = Mesh_desc {
		vertex_count 	= vertex_size,
		index_count 	= index_size,

		primitive = primitive,

		data_type 		= data_type,
		usage 			= usage,
		indices_type 	= index_type,
	};
	
	for i in 0..<buffering {
		vertex_data_queue 	: queue.Queue(^Upload_data); //just always upload
		index_data_queue  	: queue.Queue(^Upload_data); //just always upload
		instance_data_queue : queue.Queue(^Upload_data); //just always upload
		queue.init(&vertex_data_queue);
		queue.init(&index_data_queue);
		queue.init(&instance_data_queue);
		b := Backing_mesh {
			mesh = mesh_make_single_empty(vertex_size, data_type, index_size, index_type, usage, primitive, instance),
			vertex_data_queue = vertex_data_queue,
			index_data_queue = index_data_queue,
			instance_data_queue = instance_data_queue,
		};

		append(&mesh.backing, b);
	}
	mesh.current_read = 0;
	mesh.current_write = 0;

	return;
}

mesh_destroy_buffered :: proc (mesh : ^Mesh_buffered) {
	
	for &b in &mesh.backing {
		mesh_destroy_single(&b.mesh);
		for queue.len(b.vertex_data_queue) != 0 {
			d := queue.pop_front(&b.vertex_data_queue);
			d.ref_cnt -= 1;
			if d.ref_cnt == 0 {
				delete(d.data);
				free(d);
			}
		}
		for queue.len(b.index_data_queue) != 0 {
			d := queue.pop_front(&b.index_data_queue);
			d.ref_cnt -= 1;
			if d.ref_cnt == 0 {
				delete(d.data);
				free(d);
			}
		}
		for queue.len(b.instance_data_queue) != 0 {
			d := queue.pop_front(&b.instance_data_queue);
			d.ref_cnt -= 1;
			if d.ref_cnt == 0 {
				delete(d.data);
				free(d);
			}
		}
		queue.destroy(&b.vertex_data_queue);
		queue.destroy(&b.index_data_queue);
		queue.destroy(&b.instance_data_queue);
		gl.discard_fence(&b.transfer_fence);
	}

	delete(mesh.backing);
}

upload_vertex_data_buffered :: proc (mesh : ^Mesh_buffered, #any_int start_vertex : int, data : []$T, keep_consistent := true, loc := #caller_location) {
	
	//Append data to all vertex_data_queue in all the backing
	d := new(Upload_data);
	d.data = slice.clone(slice.reinterpret([]u8, data));
	d.start_index = start_vertex;
	
	if keep_consistent {
		d.ref_cnt = len(mesh.backing);
		for &b in mesh.backing {
			queue.append(&b.vertex_data_queue, d);
		}
	}
	else {
		d.ref_cnt = 1;
		l := &mesh.backing[mesh.current_write];
		queue.append(&l.vertex_data_queue, d);
	}
}

upload_index_data_buffered :: proc (mesh : ^Mesh_buffered, #any_int start_index : int, data : Indices, keep_consistent := true, loc := #caller_location) {
	
	//Append data to all vertex_data_queue in all the backing
	d := new(Upload_data);
	d.start_index = start_index;
	
	switch v in data {
		case nil:
			panic("!??!");
		case []u16:
			d.data = slice.clone(slice.reinterpret([]u8, v));
		case []u32:
			d.data = slice.clone(slice.reinterpret([]u8, v)); 
	}
	
	if keep_consistent {
		d.ref_cnt = len(mesh.backing);
		for &b in mesh.backing {
			queue.append(&b.index_data_queue, d);
		}
	}
	else {
		d.ref_cnt = 1;
		l := &mesh.backing[mesh.current_write];
		queue.append(&l.index_data_queue, d);
	}
}

upload_instance_data_buffered :: proc (mesh : ^Mesh_buffered, #any_int start_index : int, data : []$T, keep_consistent := true, loc := #caller_location) {
	
	//Append data to all vertex_data_queue in all the backing
	d := new(Upload_data);
	d.data = slice.clone(slice.reinterpret([]u8, data));
	d.start_index = start_index;
	
	if keep_consistent {
		d.ref_cnt = len(mesh.backing);
		for &b in mesh.backing {
			queue.append(&b.instance_data_queue, d);
		}
	}
	else {
		d.ref_cnt = 1;
		l := &mesh.backing[mesh.current_write];
		queue.append(&l.instance_data_queue, d);
	}
}

resize_mesh_bufferd :: proc (mesh_buffer : ^Mesh_buffered, new_vertex_size : int, new_index_size : int) {
	mesh_buffer.vertex_count = new_vertex_size;
	mesh_buffer.index_count = new_index_size;
}

@(require_results)
//This will swap buffers, upload data and return the buffer index that should be used to draw with.
mesh_buffered_next_draw_source :: proc (using mesh_buffer : ^Mesh_buffered, loc := #caller_location) -> int {
	
	if len(backing) == 1 {
		upload_buffered_data(mesh_buffer, 0);
		return 0; //We don't need to upload and we don't need to sync
	}
	
	//Move upload forward
	next_write := (current_write+1) %% len(backing);
	if gl.is_fence_ready(backing[next_write].read_fence) {

		//upload data and move to next if free
		upload_buffered_data(mesh_buffer, current_write, loc = loc);
		assert(queue.len(mesh_buffer.backing[current_write].index_data_queue) == 0, "Data was not cleared?");
		assert(queue.len(mesh_buffer.backing[current_write].vertex_data_queue) == 0, "Data was not cleared?");
		
		current_write = next_write;
	}
	
	//Move read/draw forward
	next_read := (current_read+1) %% len(backing);
	if gl.is_fence_ready(backing[next_read].transfer_fence) {
		current_read = next_read;
	}

	return current_read;
}

//make sure that the draw_range and draw_source fits each other.
//The server side (GPU) might not have the newest update of the draw_source yet.
draw_mesh_buffered :: proc (mesh_buffer : ^Mesh_buffered, model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, draw_source : int, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	
	mesh := &mesh_buffer.backing[draw_source];
	
	if len(mesh_buffer.backing) != 1 {
		when ODIN_DEBUG {
			if !gl.is_fence_ready(mesh.transfer_fence) {
				if state.pref_warn { log.warnf("Preformence warning: waiting for mesh transfer. Caller location : %v", loc); };
				for !gl.is_fence_ready(mesh.transfer_fence) {}; //keep waiting
			}
		}
		else {
			for !gl.is_fence_ready(mesh.transfer_fence) {}; //keep waiting
		}
	}
	
	mesh_draw_single(mesh, model_matrix, color, draw_range, loc);
	
	if len(mesh_buffer.backing) != 1 && mesh.usage != .stream_use {
		gl.discard_fence(&mesh.read_fence);
		mesh.read_fence = gl.place_fence();
	}
}

draw_mesh_buffered_instanced :: proc (mesh_buffer : ^Mesh_buffered, #any_int instance_cnt : int, draw_source : int, color : [4]f32 = {1,1,1,1}, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	
	mesh := &mesh_buffer.backing[draw_source];
	
	if len(mesh_buffer.backing) != 1 {
		when ODIN_DEBUG {
			if !gl.is_fence_ready(mesh.transfer_fence) {
				if state.pref_warn { log.warnf("Preformence warning: waiting for mesh transfer. Caller location : %v", loc); };
				for !gl.is_fence_ready(mesh.transfer_fence) {}; //keep waiting
			}
		}
		else {
			for !gl.is_fence_ready(mesh.transfer_fence) {}; //keep waiting
		}
	}
	
	mesh_draw_single_instanced(mesh, instance_cnt, color, draw_range, loc);
	
	if len(mesh_buffer.backing) != 1 && mesh.usage != .stream_use {
		gl.discard_fence(&mesh.read_fence);
		mesh.read_fence = gl.place_fence();
	}
}













////////////////////////////// Shared mesh //////////////////////////////

Shared_mesh_buffer :: struct {
	using _ : Mesh_buffered,
}

//This is an implementation for a mesh, this will point to a mesh share (^Shared_mesh_buffer).
//Used internally
Mesh_shared :: struct {
	share : ^Shared_mesh_buffer,

	verts_range : [2]int,
	index_range : [2]int,
}

draw_mesh_shared_instanced :: proc (mesh : ^Mesh_shared, instance_data : Instance_data, loc := #caller_location) {
	panic("TODO");
}










////////////////////////////// Mesh batching //////////////////////////////

//A mesh batch is a a collection of meshes that can be drawn with a single drawcall
//These are only good for static meshes, or meshes that rarely move.
//If the meshes are small there might a an advantage to mesh batching even if they move alot.
//A mesh batch transforms the verticies in memeory, not in the shader, this means that the CPU will spend time moving the meshes.
//This also means that draw them is as simple as drawing everything in a single drawcall, this can give high speedups for certian applications.

//TODO mesh batching















////////////////////////////// For internal use //////////////////////////////

//Used internally
@(require_results)
get_attribute_id_from_name :: proc (name : string, loc := #caller_location) -> Attribute_id {
	
	location, ok := reflect.enum_from_name(Attribute_location, name);

	if !ok {
		fmt.panicf("The name : %v is not a valid Attribute_location", name, loc = loc);
	}
	
	return auto_cast location;
}

//Used internally
@(require_results)
get_attribute_info_from_typeid :: proc (t : typeid, loc := #caller_location) -> []gl.Attribute_info_ex {
	
	ti := type_info_of(t);

	attribs := make([dynamic]gl.Attribute_info_ex);

	//Strip the name
	if named, ok := ti.variant.(runtime.Type_Info_Named); ok {
		ti = named.base;
	}

	if struct_type_info, ok := ti.variant.(runtime.Type_Info_Struct); ok {
		fields := reflect.struct_fields_zipped(t);
		for field in fields {

			normalized : bool = false;
			
			if val, ok := reflect.struct_tag_lookup(field.tag, "ignore"); ok {
				if val == "true" {
					continue;
				}
				else if val == "false" {
					
				}
				else {
					fmt.panicf("%v ignore tag must have the value of 'true' or 'false'", t, loc = loc);
				}
			}
			
			if val, ok := reflect.struct_tag_lookup(field.tag, "normalized"); ok {
				if val == "true" {
					normalized = true;
				}
				else if val == "false" {
					normalized = false;
				}
				else {
					fmt.panicf("%v normalized tag must have the value of 'true' or 'false'", t, loc = loc);
				}
			}

			attrib_ex : gl.Attribute_info_ex = {
				location = get_attribute_id_from_name(field.name),
				attribute_type = gl.odin_type_to_attribute_type(field.type.id),
				offset = field.offset,
				stride = auto_cast reflect.size_of_typeid(t),
				normalized = normalized,
			}
			
			fmt.assertf(attrib_ex.attribute_type != .invalid, "The odin type %v, does not a have an equivalent opengl type\n", field.type.id, loc = loc);

			append(&attribs, attrib_ex);
		}

	}
	else{
		panic("Type must be a struct", loc = loc);
	}

	return attribs[:];
}

@private
//Used internally for setup up a resource for a mesh
//Nil may be passed for init_vertex_data and init_index_data. 
//If they are not nil, then the len must match that of mesh.vertex_cnt and mesh.index_count respectively.
setup_mesh_single :: proc (mesh : ^Mesh_single, init_vertex_data : []u8, init_index_data : []u8, instance : Maybe(Instance_data_desc), loc := #caller_location) {

	assert(mesh.vao == 0, "This mesh is not clean... what are you doing?");

	desc : gl.Resource_desc = {
		usage = cast(gl.Resource_usage)mesh.usage,
		buffer_type = .array_buffer,
		bytes_count = mesh.vertex_count * reflect.size_of_typeid(mesh.data_type),
	}

	attrib_info := get_attribute_info_from_typeid(mesh.data_type, loc);
	defer delete(attrib_info);

	mesh.vao = gl.gen_vertex_array(loc);

	//The vertex data
	mesh.vertex_data = gl.make_resource_desc(desc, init_vertex_data, loc);
	gl.associate_buffer_with_vao(mesh.vao, mesh.vertex_data.buffer, attrib_info, 0, loc);

	//The indicies
	switch mesh.indices_type {

		case .no_index_buffer:
			mesh.indices_buf = nil;

		case .unsigned_short, .unsigned_int:

			s : int;
			if mesh.indices_type == .unsigned_short {
				s = size_of(u16);
			} else if mesh.indices_type == .unsigned_int {
				s = size_of(u32);
			}
			else {
				panic("???");
			}

			index_desc : gl.Resource_desc = {
				usage = cast(gl.Resource_usage)mesh.usage,
				buffer_type = .element_array_buffer,
				bytes_count = mesh.index_count * s,
			}
			indices_buf := gl.make_resource_desc(index_desc, init_index_data, loc);

			gl.associate_index_buffer_with_vao(mesh.vao, indices_buf.buffer);
			mesh.indices_buf = indices_buf;
	}

	//The optional instance data
	if inst, ok := instance.?; ok {
		
		instanced_attrib_info := get_attribute_info_from_typeid(inst.data_type, loc);
		defer delete(instanced_attrib_info);

		instance_data := Instance_data{data = gl.make_resource(inst.data_points * reflect.size_of_typeid(inst.data_type), .array_buffer, cast(gl.Resource_usage)inst.usage, nil), desc = inst};
		gl.associate_buffer_with_vao(mesh.vao, instance_data.data.buffer, instanced_attrib_info, 1, loc);
		mesh.instance_data = instance_data;
	}

}

@(private)
//used internally
upload_mesh_resource_bytes :: proc(usage : Usage, resource : ^gl.Resource, data : []u8, byte_size, start : int, loc := #caller_location) {
	switch usage {
		case .static_use:
			panic("Cannot upload to a static mesh");
		case .dynamic_use:
			gl.buffer_upload_sub_data(resource, byte_size * start, data);
		case .stream_use:
			dst : []u8 = gl.begin_buffer_write(resource, byte_size * start, len(data));
			fmt.assertf(len(dst) == len(data), "length of buffer and length of data does not match. dst : %i, data : %i", len(dst), len(data), loc = loc);
			mem.copy_non_overlapping(raw_data(dst), raw_data(data), len(dst)); //TODO this mapping and unmapping is not nice when we upload multiple time a frame... in the mesh share for example.
			gl.end_buffer_writes(resource);
	}
}

@(private)
//used internally
upload_mesh_resource_instance_bytes :: proc(usage : Instance_usage, resource : ^gl.Resource, data : []u8, byte_size, start : int, loc := #caller_location) {
	switch usage {
		case .dynamic_copy, .dynamic_upload:
			gl.buffer_upload_sub_data(resource, byte_size * start, data);
		case .stream_copy, .stream_upload:
			dst : []u8 = gl.begin_buffer_write(resource, byte_size * start, len(data));
			fmt.assertf(len(dst) == len(data), "length of buffer and length of data does not match. dst : %i, data : %i", len(dst), len(data), loc = loc);
			mem.copy_non_overlapping(raw_data(dst), raw_data(data), len(dst)); //TODO this mapping and unmapping is not nice when we upload multiple time a frame... in the mesh share for example.
			gl.end_buffer_writes(resource);
	}
}

//Used internally
Upload_data :: struct {ref_cnt : int, data : []u8, start_index : int};

//Used internally
Backing_mesh :: struct {
	transfer_fence 			: gl.Fence,					//If this is not signaled, then reading/drawing from it will block.

	using mesh 					: Mesh_single,				//This contains the read_fence
	
	vertex_data_queue 		: queue.Queue(^Upload_data), //just always upload
	index_data_queue 		: queue.Queue(^Upload_data), //just always upload
	instance_data_queue 	: queue.Queue(^Upload_data), //just always upload
};

@(private)
//Used internally
upload_buffered_data :: proc (mesh : ^Mesh_buffered, index : int, loc := #caller_location) {

	backing : ^Backing_mesh = &mesh.backing[index];

	if mesh.vertex_count != backing.vertex_count || mesh.index_count != backing.index_count{
		
		//We must first be very sure that we are not transfering as resizing will copy from the old buffer.
		gl.sync_fence(&backing.transfer_fence);
		gl.sync_fence(&backing.read_fence); //TODO is this needed?
		
		//Resize the submesh
		mesh_resize_single(backing, mesh.vertex_count, mesh.index_count);
		
		log.debugf("Resizing backing mesh, new size : %v, %v", mesh.vertex_count, mesh.index_count);
	}
	
	if queue.len(backing.index_data_queue) != 0 || queue.len(backing.vertex_data_queue) != 0 || queue.len(backing.instance_data_queue) != 0 {

		if !gl.is_fence_ready(backing.read_fence) {
			if state.pref_warn { log.warnf("Preformence warning: waiting for mesh drawing %i before uploading new data, caller location : %v", index, loc); };
			for !gl.is_fence_ready(backing.read_fence) {};
		}

		//Upload vertex data
		{
			byte_size := reflect.size_of_typeid(mesh.data_type);
			for queue.len(backing.vertex_data_queue) != 0 {
				
				data := queue.pop_front(&backing.vertex_data_queue);

				//Then upload
				upload_mesh_resource_bytes(mesh.usage, &backing.mesh.vertex_data, data.data, byte_size, data.start_index);

				data.ref_cnt -= 1;

				if data.ref_cnt == 0 {
					delete(data.data);
					free(data);
				}
			}
		}

		//Upload index data
		{
			byte_size : int = 0;
			switch mesh.indices_type {
				case .no_index_buffer:
					byte_size = 0;
				case .unsigned_short:
					byte_size = size_of(u16);
				case .unsigned_int:
					byte_size = size_of(u32);
			}
			for queue.len(backing.index_data_queue) != 0 {
				
				data := queue.pop_front(&backing.index_data_queue);

				//Then upload
				indicies, ok := &backing.mesh.indices_buf.(gl.Resource);
				assert(ok);
				assert(byte_size != 0);
				upload_mesh_resource_bytes(mesh.usage, indicies, data.data, byte_size, data.start_index);

				data.ref_cnt -= 1;

				if data.ref_cnt == 0 {
					delete(data.data);
					free(data);
				}
			}
		}

		//Upload instance data
		if inst, ok := &backing.instance_data.?; ok {
			byte_size := reflect.size_of_typeid(inst.data_type);
			for queue.len(backing.instance_data_queue) != 0 {
				
				data := queue.pop_front(&backing.instance_data_queue);
				
				//Then upload
				upload_mesh_resource_instance_bytes(inst.usage, &inst.data, data.data, byte_size, data.start_index);

				data.ref_cnt -= 1;

				if data.ref_cnt == 0 {
					delete(data.data);
					free(data);
				}
			}
		}
		
		//Place a flag
		gl.discard_fence(&backing.transfer_fence);
		backing.transfer_fence = gl.place_fence();
	}
}

//NOTES on transform feedback
//Transform feedback only allows us to draw POINTS, LINES, TRIANGLES. We can also only use glDrawArrays and glDrawArrays instanced.
//We cannot use a EBO
//We will use interleaved outputs.


//Setup
//TransformFeedbackVarayings //This must be called before linking or re-calling linking.


//Render loop
//bindBufferBase
//BeginTransformFeedback
//DrawArrays
//EndtransformsFeedback

//somthing else
//pauseTransformFeedback
//resumeTransformFeedback

//gl.Enable(gl.Rasterizer_discard) //This will ignore the fragments shader so we only use the vertex shader for transform feedback.

