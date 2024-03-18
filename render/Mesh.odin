package render;

import "core:fmt"
import "core:reflect"
import "core:runtime"
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

Indicies :: union {
	[]u16,
	[]u32,
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
destroy_mesh :: proc (mesh : Mesh_ptr) {

	switch v in mesh {
		case ^Mesh_single:
			destroy_mesh_single(v);
		case ^Mesh_buffered:
			destroy_mesh_buffered(v);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Upload to a mesh_single, mesh_buffered and mesh_shared
upload_vertex_data :: proc (mesh : Mesh_ptr, #any_int start_vertex : int, data : []$T, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			upload_vertex_data_single(v, start_vertex, data, loc);
		case ^Mesh_buffered:
			upload_vertex_data_buffered(v, start_vertex, data, loc);
		case ^Mesh_shared:
			panic("TODO"); 
	}
}

//Upload to a mesh_single, mesh_buffered and mesh_shared
upload_index_data :: proc(mesh : Mesh_ptr, #any_int start_index : int, data : Indicies, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			upload_index_data_single(v, start_index, data, loc);
		case ^Mesh_buffered:
			upload_index_data_buffered(v, start_index, data, loc);
		case ^Mesh_shared:
			panic("TODO");
	}
}

//Draws a mesh_single, mesh_buffered and mesh_shared
//There is a limitation here, and that is not that only the entire model can be drawn.
//This is because  mesh_single, mesh_buffered and mesh_shared requires handling draw_range in different ways.
draw_mesh :: proc (mesh : Mesh_ptr, model_matrix : matrix[4,4]f32, loc := #caller_location) {
	switch v in mesh {
		case ^Mesh_single:
			draw_mesh_single(v, model_matrix, nil, loc);
		case ^Mesh_buffered:
			i := mesh_buffered_next_draw_source(v);
			draw_mesh_buffered(v, model_matrix, i, loc = loc);
		case ^Mesh_shared:
			panic("TODO"); 
	}
}


////////////////////////////// Single mesh //////////////////////////////

Mesh_single :: struct {
	
	using desc 		: Mesh_desc,

	//TODO bouding_distance for culling??
	
	vao : Vao_id,						//The VAO
	vertex_data : gl.Resource,			//Vertex data is required
	indices_buf : Maybe(gl.Resource),	//Using indicies is optional
	read_fence : gl.Fence, 				//Only used when streaming. When fence is signaled then we are done reading.
}

//Index_data may be nil if there should be no incidies. 
@(require_results)
make_mesh_single :: proc (vertex_data : []$T, index_data : Indicies, usage : Usage, loc := #caller_location) -> (mesh : Mesh_single) {

	mesh.vertex_count = len(vertex_data);
	mesh.data_type = T;
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
	
	setup_mesh_single(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);

	return;
}

//Makes a mesh_single without data
@(require_results)
make_mesh_single_empty :: proc (#any_int vertex_size : int, data_type : typeid, #any_int index_size : int, index_type : Index_buffer_type, usage : Usage, loc := #caller_location) -> (mesh : Mesh_single) {

	if index_type != .no_index_buffer {
		assert(index_size != 0, "index size must not be 0, if index_type is not no_index_buffer", loc);
	}
	else {
		assert(index_size == 0, "index size must be 0, if index_type is no_index_buffer", loc);
	}

	mesh.vertex_count = vertex_size;
	mesh.data_type = data_type;
	mesh.usage = usage;
	
	mesh.index_count = index_size;
	mesh.indices_type = index_type;
	
	setup_mesh_single(&mesh, nil, nil, loc);

	return;
}

//Destroys the mesh (frees all associated resources)
destroy_mesh_single :: proc (mesh : ^Mesh_single) {
	
	gl.destroy_resource(mesh.vertex_data);
	gl.discard_fence(&mesh.read_fence); //discarding an nil fence is allowed
	if ib, ok := mesh.indices_buf.?; ok {
		gl.destroy_resource(ib);
	}
	gl.delete_vertex_array(mesh.vao);
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
		panic("We cannot resize");
	}
	
	byte_data := slice.reinterpret([]u8, data);

	//Then upload
	upload_mesh_resource_bytes(mesh.usage, &mesh.vertex_data, byte_data, byte_size, start_vertex);
}

upload_index_data_single :: proc(mesh : ^Mesh_single, #any_int start_index : int, data : Indicies, loc := #caller_location) {

	assert(start_index >= 0, "start_vertex cannot be negative", loc);
	//TODO similar for Indicies assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
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

//TODO test
resize_mesh_single :: proc(mesh : ^Mesh_single, new_vert_size, new_index_size : int, loc := #caller_location) {

	remake_resource :: proc (old_res : gl.Resource, new_size : int) -> gl.Resource {
		new_desc := old_res.desc;
		new_desc.bytes_count = new_size;
		new_res := gl.make_resource_desc(new_desc, nil);
		gl.copy_buffer_sub_data(old_res.buffer, new_res.buffer, 0, 0, math.min(new_res.bytes_count, old_res.bytes_count));
		gl.destroy_resource(old_res);
		return new_res;
	}

	mesh.vertex_data = remake_resource(mesh.vertex_data, new_vert_size);

	switch mesh.indices_type {
		case .no_index_buffer:
			assert(new_index_size == 0, "if there is no index buffer then new_index_size must be 0", loc);
		case .unsigned_short:
			i, ok := mesh.indices_buf.(gl.Resource);
			assert(ok, "internal error");
			mesh.indices_buf = remake_resource(i, new_index_size);
		case .unsigned_int:
			i, ok := mesh.indices_buf.(gl.Resource);
			assert(ok, "internal error");
			mesh.indices_buf = remake_resource(i, new_index_size);
	}

	panic("TODO this will not work for streaming buffers");
}

draw_mesh_single :: proc (mesh : ^Mesh_single, model_matrix : matrix[4,4]f32, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	
	vertex_count := mesh.vertex_count;
	index_count := mesh.index_count;
	if r, ok := draw_range.?; ok {
		vertex_count = r.y - r.x;
		index_count = r.y - r.x;
	}

	set_uniform(state.bound_shader, .model_mat, model_matrix);
	set_uniform(state.bound_shader, .inv_model_mat, linalg.matrix4_inverse(model_matrix));
	mvp := state.prj_view_mat * model_matrix;
	set_uniform(state.bound_shader, .mvp, mvp);
	set_uniform(state.bound_shader, .inv_mvp, linalg.matrix4_inverse(mvp));
	
	switch mesh.indices_type {
		case .no_index_buffer:
			gl.draw_arrays(mesh.vao, .triangles, 0, vertex_count);
		case .unsigned_short, .unsigned_int:
			if i_buf, ok := mesh.indices_buf.?; ok {
				gl.draw_elements(mesh.vao, .triangles, index_count, mesh.indices_type, i_buf.buffer);
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
make_mesh_buffered :: proc (#any_int buffering, vertex_size : int, data_type : typeid, #any_int index_size : int, index_type : Index_buffer_type, usage : Usage, loc := #caller_location) -> (mesh :Mesh_buffered) {
	assert(buffering >= 1, "must have at least 1 buffer", loc);
	assert(usage != .static_use, "A buffered mesh cannot be static", loc);

	mesh.desc = Mesh_desc {	
		vertex_count 	= vertex_size,
		index_count 	= index_size,

		data_type 		= data_type,
		usage 			= usage,
		indices_type 	= index_type,
	};
	
	for i in 0..<buffering {
		vertex_data_queue : queue.Queue(^Upload_data); //just always upload
		index_data_queue  : queue.Queue(^Upload_data); //just always upload
		queue.init(&vertex_data_queue);
		queue.init(&index_data_queue);
		b := Backing_mesh {
			mesh = make_mesh_single_empty(vertex_size, data_type, index_size, index_type, usage),
			vertex_data_queue = vertex_data_queue,
			index_data_queue = index_data_queue, 
		};

		append(&mesh.backing, b);
	}
	mesh.current_read = 0;
	mesh.current_write = 0;

	return;
}

destroy_mesh_buffered :: proc (mesh : ^Mesh_buffered) {
	
	for &b in &mesh.backing {
		destroy_mesh_single(&b.mesh);
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
		queue.destroy(&b.vertex_data_queue);
		queue.destroy(&b.index_data_queue);
		gl.discard_fence(&b.transfer_fence);
	}

	delete(mesh.backing);
}

upload_vertex_data_buffered :: proc (mesh : ^Mesh_buffered, #any_int start_vertex : int, data : []$T, loc := #caller_location) {
	
	//Append data to all vertex_data_queue in all the backing
	d := new(Upload_data);
	d.ref_cnt = len(mesh.backing);
	d.data = slice.clone(slice.reinterpret([]u8, data));
	d.start_index = start_vertex;
	
	for &b in mesh.backing {
		queue.append(&b.vertex_data_queue, d);
	}

	//Begin the upload
	upload_buffered_data(mesh, mesh.current_write, loc = loc);	//this will upload and placing a flag.
}

upload_index_data_buffered :: proc (mesh : ^Mesh_buffered, #any_int start_index : int, data : Indicies, loc := #caller_location) {
	
	//Append data to all vertex_data_queue in all the backing
	d := new(Upload_data);
	d.ref_cnt = len(mesh.backing);
	d.start_index = start_index;

	switch v in data {
		case nil:
			panic("!??!");
		case []u16:
			d.data = slice.clone(slice.reinterpret([]u8, v));
		case []u32:
			d.data = slice.clone(slice.reinterpret([]u8, v)); 
	}
	
	for &b in mesh.backing {
		queue.append(&b.index_data_queue, d);
	}

	//Begin the upload
	upload_buffered_data(mesh, mesh.current_write, loc = loc);	//this will upload and placing a flag.
}

//TODO make a resize_mesh_bufferd

@(require_results)
//This will swap buffers, upload data and return the buffer index that should be used to draw with.
mesh_buffered_next_draw_source :: proc (using mesh_buffer : ^Mesh_buffered, loc := #caller_location) -> int {
	
	if len(backing) == 1 {
		return 0; //We don't need to upload and we don't need to sync
	}
 
	//Move upload forward
	next_write := (current_write+1) %% len(backing);
	if gl.is_fence_ready(backing[next_write].read_fence) {
		current_write = next_write;
		//fmt.printf("Next write is ready, moving to %i\n", next_write);
		
		//upload data and move to next if free
		upload_buffered_data(mesh_buffer, current_write, loc = loc);
		assert(queue.len(mesh_buffer.backing[current_write].index_data_queue) == 0, "Data was not cleared?");
		assert(queue.len(mesh_buffer.backing[current_write].vertex_data_queue) == 0, "Data was not cleared?");
		
		//next_write = (next_write+1) %% len(backing);
		//if current_write == current_read || next_write == current_read {
		//	break;
		//}
	}
	
	//Move read/draw forward
	next_read := (current_read+1) %% len(backing);
	if gl.is_fence_ready(backing[next_read].transfer_fence) {
		current_read = next_read;
		//fmt.printf("Next read is ready, moving to %i\n", next_read);

		//next_read = (next_read+1) %% len(backing);
		//if current_read == current_write || next_read == current_write {
		//	break;
		//}
	}

	//fmt.printf("\n");

	return current_read;
}

//make sure that the draw_range and draw_source fits each other.
//The server side (GPU) might not have the newest update of the draw_source yet.
draw_mesh_buffered :: proc (mesh_buffer : ^Mesh_buffered, model_matrix : matrix[4,4]f32, draw_source : int, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
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
	
	draw_mesh_single(mesh, model_matrix, draw_range, loc);
	
	if len(mesh_buffer.backing) != 1 && mesh.usage != .stream_use{
		gl.discard_fence(&mesh.read_fence);
		mesh.read_fence = gl.place_fence();
	}
}




////////////////////////////// Instaced mesh //////////////////////////////














////////////////////////////// Shared mesh //////////////////////////////

//This is an implementation for a mesh, this will point to a mesh share (^Shared_mesh_buffer).
//Used internally
Mesh_shared :: struct {
	//TODO share : ^Shared_mesh_buffer,

	verts_range : [2]int,
	index_range : [2]int,

	//fence : gl.Fence, //Only used when streaming.
}








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

			log.debugf("attrib_ex : %#v\n", attrib_ex);

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
setup_mesh_single :: proc (mesh : ^Mesh_single, init_vertex_data : []u8, init_index_data : []u8, loc := #caller_location) {

	assert(mesh.vao == 0, "This mesh is not clean... what are you doing?");

	desc : gl.Resource_desc = {
		usage = cast(gl.Resource_usage)mesh.usage,
		buffer_type = .array_buffer,
		bytes_count = mesh.vertex_count * reflect.size_of_typeid(mesh.data_type),
	}

	attrib_info := get_attribute_info_from_typeid(mesh.data_type, loc);
	defer delete(attrib_info);

	mesh.vao = gl.gen_vertex_array();

	mesh.vertex_data = gl.make_resource_desc(desc, init_vertex_data, loc);
	gl.associate_buffer_with_vao(mesh.vao, mesh.vertex_data.buffer, attrib_info, loc);

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
			mesh.indices_buf = gl.make_resource_desc(index_desc, init_index_data, loc);
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

//Used internally
Upload_data :: struct {ref_cnt : int, data : []u8, start_index : int};

//Used internally
Backing_mesh :: struct {
	transfer_fence 			: gl.Fence,					//If this is not signaled, then reading/drawing from it will block.

	using mesh 					: Mesh_single,				//This contains the read_fence
	
	vertex_data_queue 		: queue.Queue(^Upload_data), //just always upload
	index_data_queue 		: queue.Queue(^Upload_data), //just always upload
};

@(private)
//Used internally
upload_buffered_data :: proc (mesh : ^Mesh_buffered, index : int, loc := #caller_location) {

	backing : ^Backing_mesh = &mesh.backing[index];
	
	if queue.len(backing.index_data_queue) != 0 || queue.len(backing.vertex_data_queue) != 0 {

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
		
		//Place a flag
		gl.discard_fence(&backing.transfer_fence);
		backing.transfer_fence = gl.place_fence();
	}
}






/*

	//A mesh share or Shared_mesh_buffer is a datastructure that holds multiple meshes inside the same backing buffer.
	//This is great for preformence because you don't swap buffer all the time. It also allow drawing multiple meshes in the same drawcall.
	//A share mesh allow you to do:
		//Double/triple and auto buffering
		//Multidraw

	//You can create a mesh from a mesh share by calling make_mesh_share.
	//Note: this will fraqment a lot if you do a lot of make_shared_mesh with different sized meshes and destroy them to allocate new ones multiple times. Be aware.

	Reserve_behavior :: enum {
		skinny, 	//Don't reserve more then needed always shrink when available.
		moderate, 	//Reserve 2x the needed at resize and shrink when available and low usage.
		thick,		//Reserve 2x needed and don't shrink.
	}

	//A shared mesh can hold multiple backing meshes. This means you can upload while drawing, this is called buffering.
	//Buffering can drasticly increase preformence if uploading happens freqenctly.
	//Single buffering, is the same as no buffering. This is only recommened if you setup your meshes in the begining and then don't update them.
	//Double is good if there is a few frames or more between each time you upload or create a new mesh from the share.
	//Trible is good if you need to upload more or less every frame.
	//Auto will create a new buffer if writing to a buffer will cause a halt in the Graphics pipeline.
		//This means, auto will start with a single buffer and then add a new if there is no space to write to, there is no limited to the amount of buffers.
		//This is usefull if you need to write every frame or don't know/care how many buffers you need.
	//Note, if you don't really know what to use, double buffering is a nice compromise.
	//Note: If you require the data to be shown the same frame, you must use single buffering. For other buffering the new data will be shown a few frames later.
	Buffering :: enum {
		single,		//Upload is immediate
		double,		//Takes a minimum of 1 frames before content is seen, TODO we should make it so it does not
		triple,		//Takes a minimum of 2 frames before content is seen, TODO we should make it so it does not
		auto,		//We should not do this, because it requires us to store all the data CPU side. //No garenties are made //Only available when usage is .stream_use
	}

	Shared_mesh_buffer :: struct {
		using desc 		: Mesh_desc,

		backing_meshs 	: Buffered_mesh,

		reserve : Reserve_behavior,
		
		free_vertex_ranges 		: [dynamic][2]int, //This is ordered. lowest to highest.
		free_indicies_ranges 	: [dynamic][2]int, //This is ordered. lowest to highest.
	}

	//Internal use only
	@(private)
	add_backing_mesh_for_share :: proc (share : ^Shared_mesh_buffer, vertex_size, index_size : int) {
		new_backing := make_mesh_empty(vertex_size, share.data_type, index_size, share.indices_type, share.usage);
		
		append(&share.backing_meshs, Backing_mesh{
			mesh = new_backing,
			//vertex_data_queue	= nil, //Nil until something is appended?? i guess
			//index_data_queue	= nil, //Nil until something is appended?? i guess	
		});
	}

	//Internal use only
	@(private)
	expand_mesh_share :: proc (share : ^Shared_mesh_buffer, loc := #caller_location) {
		share.vertex_count *= 2;
		share.index_count *= 2;
		log.debugf("Expanded mesh, new size : %v, %v", share.vertex_count, share.index_count);
	}

	//Internal use only, called by destroy_mesh.
	@(private)
	free_mesh_from_share :: proc(share : ^Shared_mesh_buffer) {
		panic("TODO");
	}

	//Internal use only
	@(private)
	upload_vertex_data_to_share :: proc (share : ^Shared_mesh_buffer, start : int, data : []$Default_vertex) {
		//Somehow this need to upload to all the backing meshes at some point.
		
		//append this to be uploaded to all the buffers.
		switch share.buffering {
			case 1:
				//resize the buffer if needed
				//upload and wait, this is basicly just upload, the wait in implicit
				upload_vertex_data();
			case:
				//check flag of next, if it is done go to that, if not do nothing.
		}
	}

	//Internal use only
	@(private)
	update_mesh_share :: proc (share : ^Shared_mesh_buffer) {

		//this is a check that should run every drawcall? NO everyframe because, you do want wierd behavior when drawing shadow maps and such.
		//So yeah, also if we don't call draw it should still upload to all buffers, and clear the queue of data upstream.
		//This means we must have a list of Shared_mesh_buffers that we can call update on ONCE every frame.

		uploads := &share.backing_meshs[share.current_backing];

		//upload
		for queue.len(uploads.vertex_data_queue) != 0 {
			d := queue.pop_front(&uploads.vertex_data_queue);
			upload_vertex_data(&uploads.mesh, d.start_index, d.data);
			d.ref_cnt -= 1;
			if d.ref_cnt == 0 {
				delete(d.data);
				free(d);
			}
		}

		//if buffering != .single, then place flag
		if share.buffering != 1 {
			//What happens when usage is stream
			something = gl.place_fence();
		}
		//move to the next buffer, new drawcall will use this buffer
		
		//Then if the next buffer is advaliable, move to that and begin uploading the same data to the next buffer.
		//Then when the next buffer is advaliable, move to that and begin uploading (for triple this is back to start).
		//So what we want is to kinda append missing uploaded data to each mesh.
	}

	@(require_results)
	make_mesh_share :: proc ($data_type : typeid, index_type : Index_buffer_type, usage : Usage, buffering : Buffering,
									reserve : Reserve_behavior = .moderate, #any_int init_vertex_size := 100, loc := #caller_location) -> (share : ^Shared_mesh_buffer) {
		
		share = new(Shared_mesh_buffer);

		assert(usage != .static_use, "usage may not be static", loc);

		index_size := init_vertex_size;

		if index_type == .no_index_buffer {
			index_size = 0;
		}
		else {
			append(&share.free_indicies_ranges, [2]int{0, init_vertex_size});
		}
		append(&share.free_vertex_ranges, [2]int{0, init_vertex_size});

		share.backing_mesh = make_mesh_empty(init_vertex_size, data_type, index_size, index_type, usage);
		share.reserve = reserve;
		share.buffering = buffering;

		switch buffering {
			case .single:
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
			case .double:
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
			case .triple:
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
			case .auto:
				add_backing_mesh_for_share(&share, init_vertex_size, init_vertex_size);
				//More is added later when needed
		}
		
		append(&state.mesh_shares, share); //They will be updated once a frame, so they must be a in a list in the state.
	}

	@(require_results)
	make_shared_mesh :: proc(share : ^Shared_mesh_buffer, vert_size, index_size : int, loc := #caller_location) -> (mesh : Mesh) {
		
		if share.indices_type == .no_index_buffer {
			assert(index_size == 0, "The share does not use an index buffer so index_size must be 0", loc);
		}
		
		@(require_results)
		find_placement :: proc(ranges : ^[dynamic][2]int, req_size : int) -> (cur_range : ^[2]int, index : int) {
			cur_length : int = max(int);
			for &r, i in ranges {
				length := r.y - r.x;
				if length >= req_size && length < cur_length {
					//this is the smallest length found that fills the requirement
					cur_range = &r;
					index = i;
					if length == req_size {
						break;//if we have found a perfect match, we don't need to search anymore.
					}
				}
			}
			return;
		}
		
		@(require_results)
		reserve_range :: proc (share : ^Shared_mesh_buffer, ranges : ^[dynamic][2]int, req_size : int, loc := #caller_location) -> (fetched : [2]int) {

			range : ^[2]int = nil;
			range_index : int;
			for range == nil {
				//resize
				expand_mesh_share(share, loc = loc); //TODO, we expand both indiceis and verticeis.
				//See if there is space now, otherwise expand again.
				range, range_index = find_placement(ranges, req_size);
			}
			//Consume the range
			//If the range matches exactly then we can remove the range.
			if (range.y - range.x) == req_size {
				fetched = range^;
				ordered_remove(ranges, range_index);
			}
			else {
				//Just move the front of the range forward by the req_size
				fetched = [2]int{range.x, range.x + req_size};
				range.x += req_size;
			}

			return;
		}
		
		vert_range := reserve_range(share, &share.free_vertex_ranges, vert_size);
		
		index_range : [2]int = {0,0};
		if share.indices_type != .no_index_buffer {
			index_range = reserve_range(share, &share.free_indicies_ranges, index_size);
		}
		
		impl : Mesh_shared = Mesh_shared {
			share		= share,
			verts_range = vert_range,
			index_range = index_range,
		};

		mesh = Mesh{
			vertex_count 	= vert_size,
			index_count 	= index_size,

			data_type		= share.data_type,
			usage 			= share.usage,
			indices_type 	= share.indices_type,
			
			impl 			= impl,
		};

		return;
	}

	/*
	draw_mesh_multi :: proc (share : ^Shared_mesh_buffer, mesh : ^Mesh, model_matrix : matrix[4,4]f32, draw_range : Maybe([2]int) = nil, loc := #caller_location) {

	}
	*/
*/

















////////////////////////////// Mesh batching //////////////////////////////

//A mesh batch is a a collection of meshes that can be drawn with a single drawcall
//These are only good for static meshes, or meshes that rarely move.
//If the meshes are small there might a an advantage to mesh batching even if they move alot.
//A mesh batch transforms the verticies in memeory, not in the shader, this means that the CPU will spend time moving the meshes.
//This also means that draw them is as simple as drawing everything in a single drawcall, this can give high speedups for certian applications.

//TODO mesh batching
