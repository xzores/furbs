package render;

import "core:fmt"
import "core:reflect"
import "core:runtime"
import "core:mem"
import "core:slice"
import "core:log"
import "core:math"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

import "gl"
import glgl "gl/OpenGL"

get_attribute_id_from_name :: proc (name : string, loc := #caller_location) -> Attribute_id {
	
	location, ok := reflect.enum_from_name(Attribute_location, name);

	if !ok {
		fmt.panicf("The name : %v is not a valid Attribute_location", name, loc = loc);
	}
	
	return auto_cast location;
}

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

Default_vertex :: struct {
	position 	: [3]f32,
	texcoord 	: [2]f32,
	normal 		: [3]f32,
}

//These are removed to other locations
	//If this supportes dynamic meshes, then we should have multiple VAO's					- 
	//Occlusion culling should be handled somehow? 											- 
	//Double/triple and auto b uffering																- in the works
	//And we should make multidraw a thing too												- This will not be done for a single mesh

//mesh should be more complex, as it needs to handle:
	//static meshes																			- done
	//Async upload 																			- done
	//Dynamicly changing the mesh (sync or async)											- done
	//Frustum culling should be a thing we handle											- We can do this when we have made a camera
	//Somehow there is also a need for instance drawing (closely realated to mesh)			- Can we do this?? we need extra attribute data

Mesh :: struct {
	
	vertex_count 	: int,
	triangle_count 	: int,

	data_type : typeid,
	usage : Usage,
	indices_type : Index_buffer_type,

	//TODO bouding_distance for culling??
	
	vao : Vao_id,
	vertex_data : gl.Resource,
	indices_buf : Maybe(gl.Resource),
	fence : gl.Fence, //Only used when streaming.
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

////////////////////////////// Single mesh //////////////////////////////

@private
//Used internally for setup up a resource for a mesh
//Nil may be passed for init_vertex_data and init_index_data. 
//If they are not nil, then the len must match that of mesh.vertex_cnt and mesh.triangle_count respectively.
setup_mesh :: proc (mesh : ^Mesh, init_vertex_data : []u8, init_index_data : []u8, loc := #caller_location) {

	assert(mesh.vao == 0, "mesh already setup", loc);

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
				bytes_count = mesh.triangle_count * s,
			}
			mesh.indices_buf = gl.make_resource_desc(index_desc, init_index_data, loc);
	} 

}

//vertex_data and index_data may be nil if no data is to be uploaded. 
make_mesh :: proc (vertex_data : []$T, index_data : Indicies, usage : Usage, loc := #caller_location) -> Mesh {
	mesh : Mesh;
	
	mesh.vertex_count = len(vertex_data);
	mesh.data_type = T;
	mesh.usage = usage;
	
	mesh_index_buf_data : []u8;
	switch indicies in index_data {
		case []u16:
			assert(indicies != nil, "there is no indicies index_data", loc);
			assert(len(vertex_data) <= auto_cast max(u16), "The range of a u16 is exceeded", loc);
			mesh.indices_type = .unsigned_short;
			mesh.triangle_count = len(indicies);
			mesh_index_buf_data = slice.reinterpret([]u8, indicies);
		case []u32:
			assert(indicies != nil, "there is no indicies index_data", loc);
			assert(len(vertex_data) <= auto_cast max(u32), "The range of a u32 is exceeded", loc);
			mesh.indices_type = .unsigned_int;
			mesh.triangle_count = len(indicies);
			mesh_index_buf_data = slice.reinterpret([]u8, indicies);
		case nil:
			mesh.indices_type = .no_index_buffer;
			mesh.triangle_count = 0;
			mesh_index_buf_data = nil;
	}
	
	setup_mesh(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);

	return mesh;
}

make_mesh_empty :: proc (#any_int vertex_size : int, $data_type : typeid, #any_int index_size : int, index_type : Index_buffer_type, usage : Usage, loc := #caller_location) -> Mesh {
	mesh : Mesh;

	if index_type != .no_index_buffer {
		assert(index_size != 0, "index size must not be 0, if index_type is not no_index_buffer", loc);
	}
	else {
		assert(index_size == 0, "index size must be 0, if index_type is no_index_buffer", loc);
	}

	mesh.vertex_count = vertex_size;
	mesh.data_type = data_type;
	mesh.usage = usage;
	
	mesh.triangle_count = index_size;
	mesh.indices_type = index_type;
	
	setup_mesh(&mesh, nil, nil, loc);

	return mesh;
}

destroy_mesh :: proc (mesh : ^Mesh) {

	gl.destroy_resource(mesh.vertex_data);
	gl.discard_fence(&mesh.fence); //discarding an nil fence is allowed
	if ib, ok := mesh.indices_buf.?; ok {
		gl.destroy_resource(ib);
	}
	gl.delete_vertex_array(mesh.vao);
}

//You can upload once per frame when streaming.
//The mesh does not change its size, it will error of you pass to much data.
upload_vertex_data :: proc(mesh : ^Mesh, start_vertex : int, data : []$T, loc := #caller_location) {
	
	assert(start_vertex >= 0, "start_vertex cannot be negative", loc);
	assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
	assert(mesh.vertex_count >= len(data) + start_vertex, "data out of bounds", loc);
	
	byte_size := reflect.size_of_typeid(mesh.data_type);

	when ODIN_DEBUG {
		if mesh.usage == .stream_use && !gl.is_fence_ready(mesh.fence) {
			log.warnf("Preformence warning: upload_mesh_data sync is not ready\n");
		}
	}
	
	if mesh.usage == .stream_use {
		gl.sync_fence(&mesh.fence);
	}

	//Currently 3 things can happen
	//We destroy the old one creating a new buffer that will fit the mesh exactly
		//We should not do this as it would destroy the idea of a persistent mapped buffer
	//Alternatively we could resize if there is not enough space, this would be ok
		//But should we then also shrink? and when? should be a reserve behavior???
	//We could also require there is enough space
	
	//We need to check the current resouce size is the same as the vertex_size
	if mesh.vertex_data.bytes_count < byte_size * mesh.vertex_count {
		//The resouce should be resized
		panic("We cannot resize");
	}
	
	byte_data := slice.reinterpret([]u8, data);

	//Then upload
	switch mesh.usage {
		case .static_use:
			panic("Cannot upload to a static mesh");
		case .dynamic_use:
			gl.buffer_upload_sub_data(&mesh.vertex_data, byte_size * start_vertex, byte_data);
		case .stream_use:
			dst : []u8 = gl.begin_buffer_write(&mesh.vertex_data, byte_size * start_vertex, len(byte_data));
			assert(len(dst) == len(data) * size_of(T), "length of buffer and length of data does not match", loc);
			assert(len(dst) == len(byte_data), "internal error", loc);
			mem.copy_non_overlapping(raw_data(dst), raw_data(data), len(dst));
			gl.end_buffer_writes(&mesh.vertex_data);
			panic("raw_data(dst) is not offset");
	}
}

upload_index_data :: proc(mesh : ^Mesh, #any_int start_index : int, data : Indicies, loc := #caller_location) {

	assert(start_index >= 0, "start_vertex cannot be negative", loc);
	//TODO similar for Indicies assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
	assert(mesh.indices_type != .no_index_buffer, "this mesh has no index buffer", loc);

	when ODIN_DEBUG {
		if mesh.usage == .stream_use && !gl.is_fence_ready(mesh.fence) {
			log.warnf("Preformence warning: upload_mesh_data sync is not ready\n");
		}
	}
	
	if mesh.usage == .stream_use {
		gl.sync_fence(&mesh.fence);
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
		
		assert(indicies.bytes_count >= byte_size * mesh.triangle_count);
		
		byte_data : []u8;

		switch d in data {
			case nil:
				panic("!?!");
			case []u16:
				assert(mesh.triangle_count >= len(d) + start_index, "data out of bounds", loc);
				byte_data = slice.reinterpret([]u8, d);
			case []u32:
				assert(mesh.triangle_count >= len(d) + start_index, "data out of bounds", loc);
				byte_data = slice.reinterpret([]u8, d);	
		}

		//Then upload
		switch mesh.usage {
			case .static_use:
				panic("Cannot upload to a static mesh");
			case .dynamic_use:
				gl.buffer_upload_sub_data(indicies, byte_size * start_index, byte_data);
			case .stream_use:
				dst : []u8 = gl.begin_buffer_write(indicies, byte_size * start_index, len(byte_data));
				assert(len(dst) == len(byte_data), "internal error");
				mem.copy_non_overlapping(raw_data(dst), raw_data(byte_data), len(dst));
				gl.end_buffer_writes(indicies);
		}
	}
	else {
		panic("invalid mesh state", loc);
	}
}

draw_mesh_single :: proc (mesh : ^Mesh, model_matrix : matrix[4,4]f32, draw_range : Maybe([2]int) = nil, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	
	set_uniform(state.bound_shader, .model_mat, model_matrix);
	set_uniform(state.bound_shader, .inv_model_mat, linalg.matrix4_inverse(model_matrix));

	mvp := state.prj_mat * state.view_mat * model_matrix;
	set_uniform(state.bound_shader, .mvp, mvp);
	set_uniform(state.bound_shader, .inv_mvp, linalg.matrix4_inverse(mvp));

	switch mesh.indices_type {
		case .no_index_buffer:
			gl.draw_arrays(mesh.vao, .triangles, 0, mesh.vertex_count);
		case .unsigned_short, .unsigned_int:
			if i_buf, ok := mesh.indices_buf.?; ok {
				gl.draw_elements(mesh.vao, .triangles, mesh.triangle_count, mesh.indices_type, i_buf.buffer);
			}
			else {
				panic("The mesh does not have a index buffer", loc);
			}
	}

	if mesh.usage == .stream_use {
		gl.discard_fence(&mesh.fence);
		mesh.fence = gl.place_fence();
	}
}

/*
Reserve_behavior :: enum {
	skinny, 	//Don't reserve more then needed
	moderate, 	//Reserve 1.5x the needed at resize and shrink down when going below 50% use. (including padding)
	thick,		//Reserve 2x needed and don't shrink.
}

Mesh :: struct(A : typeid) where intrinsics.type_is_enum(A) {
	using _ : Mesh_data(A),

	implementation : union {
		Mesh_identifiers(A),	//It is a standalone mesh, drawing happens with draw_mesh_single.
	},

	//If set it will be used for frustum (and maybe occlusion culling).
	bounding_distance : Maybe(f32),
}
*/




////////////////////////////// Instaced mesh //////////////////////////////




////////////////////////////// Shared mesh //////////////////////////////





////////////////////////////// Mesh generation //////////////////////////////

//converts a index buffer and an vertex arrsay into a vertex arrray without an index buffer
//Used internally
convert_to_non_indexed :: proc (verts : []$T, indices : Indicies) -> (new_verts : []T){

	vert_index : int = 0;
	
	switch index in indices {
		case []u16:
			new_verts = make([]T, len(index));
			for ind in index {
				new_verts[vert_index] = verts[ind];
				vert_index += 1;
			}
		case []u32:
			new_verts = make([]T, len(index));
			for ind in index {
				new_verts[vert_index] = verts[ind];
				vert_index += 1;
			}
		case:
			panic("??");
	}

	return;
}

//append_mesh_data :: proc (verts : [dynamic]Default_vertex, indices : [dynamic]Indicies, to_append_verts : []Default_vertex, to_append_indices : [dynamic]Indicies) {}

@(require_results)
generate_quad :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool, alloc := context.allocator) -> (verts : []Default_vertex, indices : []u16) {

	context.allocator = alloc;

	if use_index_buffer {
		verts = make([]Default_vertex, 4)
		_indices := make([]u16, 6);
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + offset - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + offset - {0.5,0.5,0}, {0,1}, {0,0,1}};
		verts[3] = Default_vertex{[3]f32{1,1,0} * size + offset - {0.5,0.5,0}, {1,1}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + offset - {0.5,0.5,0}, {1,0}, {0,0,1}};
		
		_indices[0] = 0;
		_indices[1] = 1;
		_indices[2] = 2;
		_indices[3] = 2;
		_indices[5] = 3;
		_indices[4] = 1;
		indices = _indices;
	}
	else {
		verts = make([]Default_vertex, 6)
		indices = nil;
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + offset - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + offset - {0.5,0.5,0}, {1,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + offset - {0.5,0.5,0}, {0,1}, {0,0,1}};

		verts[3] = Default_vertex{[3]f32{0,1,0} * size + offset - {0.5,0.5,0}, {0,1}, {0,0,1}};
		verts[4] = Default_vertex{[3]f32{1,0,0} * size + offset - {0.5,0.5,0}, {1,0}, {0,0,1}};
		verts[5] = Default_vertex{[3]f32{1,1,0} * size + offset - {0.5,0.5,0}, {1,1}, {0,0,1}};
	}
	
	return;
}

//returns a static mesh containing a quad.
@(require_results)
make_mesh_quad :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool) -> (res : Mesh) {

	vert, index := generate_quad(size, offset, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .static_use);
	}
	else {
		res = make_mesh(vert, index, .static_use);
		delete(index);
	}
	delete(vert);
	
	return;
}

@(require_results)
generate_circle :: proc(diameter : f32, offset : [3]f32, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : []u16) {
	
	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		y := math.sin(t);
		x2 := math.cos(t2);
		y2 := math.sin(t2);

		vert 	:= [3]f32{x, y, 0};
		vert2 	:= [3]f32{x2, y2, 0};

		//the center only added once
		if len(vertices) == 0 {
			append(&vertices, 	Default_vertex{[3]f32{0,0,0} *  diameter / 2 + offset, [2]f32{0,0} + 0.5, 	[3]f32{0,0,1}});
		}

		if len(vertices) == 1 {
			append(&vertices,  	Default_vertex{vert * diameter / 2 + offset, 			vert.xy/2 + 0.5, 	[3]f32{0,0,1}});
		}

		append(&vertices, 		Default_vertex{vert2 * diameter / 2 + offset, 			vert2.xy/2 + 0.5, 	[3]f32{0,0,1}});

		append(&temp_indices, 0);
		append(&temp_indices, auto_cast (len(vertices) - 2));
		append(&temp_indices, auto_cast (len(vertices) - 1));
	}

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices));
		indices = make([]u16, len(temp_indices));
		
		for v, i in vertices {
			verts[i] = v; 	//convert from 2D to 3D
		}
		for ii, i in temp_indices {
			indices[i] = ii;
		}
	}
	else {
		non_indexed := convert_to_non_indexed(vertices[:], temp_indices[:]);
		verts = non_indexed;
	}

	return;
}

//returns a static mesh containing a circle.
@(require_results)
make_mesh_circle :: proc(diameter : f32, offset : [3]f32, sectors : int, use_index_buffer : bool) -> (res : Mesh) {

	vert, index := generate_circle(diameter, offset, sectors, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .static_use);
	}
	else {
		res = make_mesh(vert, index, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}

//
@(require_results)
generate_cube :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : []u16) {

	corners : [24]Default_vertex = {
		//XP
		Default_vertex{{1,0,0}, {0,0}, {1,0,0}},	
		Default_vertex{{1,0,1}, {0,1}, {1,0,0}},
		Default_vertex{{1,1,1}, {1,1}, {1,0,0}},
		Default_vertex{{1,1,0}, {1,0}, {1,0,0}},

		//XN
		Default_vertex{{0,0,0}, {0,0}, {-1,0,0}},
		Default_vertex{{0,1,0}, {1,0}, {-1,0,0}},
		Default_vertex{{0,1,1}, {1,1}, {-1,0,0}},
		Default_vertex{{0,0,1}, {0,1}, {-1,0,0}},

		//YP
		Default_vertex{{0,1,0}, {0,0}, {0,1,0}},
		Default_vertex{{1,1,0}, {1,0}, {0,1,0}},
		Default_vertex{{1,1,1}, {1,1}, {0,1,0}},
		Default_vertex{{0,1,1}, {0,1}, {0,1,0}},

		//YN
		Default_vertex{{0,0,0}, {0,0}, {0,-1,0}},
		Default_vertex{{0,0,1}, {0,1}, {0,-1,0}},
		Default_vertex{{1,0,1}, {1,1}, {0,-1,0}},
		Default_vertex{{1,0,0}, {1,0}, {0,-1,0}},

		//ZP
		Default_vertex{{0,0,1}, {0,0}, {0,0,1}},
		Default_vertex{{0,1,1}, {0,1}, {0,0,1}},
		Default_vertex{{1,1,1}, {1,1}, {0,0,1}},
		Default_vertex{{1,0,1}, {1,0}, {0,0,1}},

		//ZN
		Default_vertex{{0,0,0}, {0,0}, {0,0,-1}},
		Default_vertex{{1,0,0}, {1,0}, {0,0,-1}},
		Default_vertex{{1,1,0}, {1,1}, {0,0,-1}},
		Default_vertex{{0,1,0}, {0,1}, {0,0,-1}},
	};

	odering : [6]u16 = {
		0, 1, 2,
		0, 2, 3,
	}

	indices = make([]u16, 36);

	index : int = 0;
	for i in 0..<6 {
		for o in odering {
			indices[index] = o + 4 * cast(u16)i;
			index += 1;
		}
	}
	
	verts = make([]Default_vertex, 24);
	for c,i in corners {
		verts[i] = Default_vertex{(c.position - {0.5,0.5,0.5} + offset) * size, c.texcoord, c.normal};
	}

	if !use_index_buffer {
		new_verts := convert_to_non_indexed(verts, indices);
		delete(verts);
		delete(indices);
		verts = new_verts;
		indices = nil;
	}

	return;
}

//returns a static mesh containing a cube.
@(require_results)
make_mesh_cube :: proc(size : [3]f32, offset : [3]f32, use_index_buffer : bool) -> (res : Mesh) {
	
	vert, index := generate_cube(size, offset, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .static_use);
	}
	else {
		res = make_mesh(vert, index, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}

@(require_results)
generate_cylinder :: proc(offset : [3]f32, height, diameter : f32, stacks : int, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : []u16) {

	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	for up in 0..=stacks {
		
		y : f32 = f32(up) / f32(stacks);
		
		sectors := sectors + 1;

		for phi in 0..<sectors {
			
			angle : f32 = f32(-phi);

			x := math.cos_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);
			z := math.sin_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);

			vert := [3]f32{x / 2 + offset.x, y + offset.y - 0.5, z / 2 + offset.z};

			append(&vertices, Default_vertex{{vert.x * diameter, vert.y * height, vert.z * diameter}, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)}, [3]f32{x,0,z}});
			
			if up != 0 {
				below_neg 	:= up * sectors + ((phi - 1) %% sectors) - sectors;
				below_i	 	:= up * sectors + phi - sectors;
				this 		:= up * sectors + phi;
				pos 		:= up * sectors + ((phi + 1) %% sectors);
				append(&temp_indices, u16(below_i), u16(this), u16(pos));
				append(&temp_indices, u16(below_i), u16(below_neg), u16(this)); 
			}
			
		}
	}

	up_center := len(vertices);
	append(&vertices, Default_vertex{[3]f32{0, height / 2,0} + offset, [2]f32{0,0} + 0.5, 	[3]f32{0,1,0}});
	down_center := len(vertices);
	append(&vertices, Default_vertex{[3]f32{0, -height / 2, 0} + offset, [2]f32{0,0} + 0.5, [3]f32{0,-1,0}});

	added_first := false;
	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		z := math.sin(t);
		x2 := math.cos(t2);
		z2 := math.sin(t2);

		vert 	:= [3]f32{x, -height/2, z};
		vert2 	:= [3]f32{x2, -height/2, z2};
		vert.xz = vert.xz * diameter / 2;
		vert2.xz = vert2.xz * diameter / 2;

		//the center only added once
		if added_first == false {
			append(&vertices,  	Default_vertex{vert + offset, 	[2]f32{x, z}/2 + 0.5, 	[3]f32{0,0,-1}}); //TODO calculate the normal correctly
			added_first = true;
		}

		append(&vertices, 		Default_vertex{vert2 + offset, 	[2]f32{x2, z2}/2 + 0.5, 	[3]f32{0,0,-1}}); //TODO calculate the normal correctly

		append(&temp_indices, auto_cast down_center);
		append(&temp_indices, auto_cast (len(vertices) - 1));
		append(&temp_indices, auto_cast (len(vertices) - 2));
	}


	added_first = false;
	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		z := math.sin(t);
		x2 := math.cos(t2);
		z2 := math.sin(t2);

		vert 	:= [3]f32{x, height/2, z};
		vert2 	:= [3]f32{x2, height/2, z2};
		vert.xz = vert.xz * diameter / 2;
		vert2.xz = vert2.xz * diameter / 2;

		//the center only added once
		if added_first == false {
			append(&vertices,  	Default_vertex{vert + offset, 	[2]f32{x, z}/2 + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly
			added_first = true;
		}

		append(&vertices, 		Default_vertex{vert2 + offset, 	[2]f32{x2, z2}/2 + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly

		append(&temp_indices, auto_cast up_center);
		append(&temp_indices, auto_cast (len(vertices) - 2));
		append(&temp_indices, auto_cast (len(vertices) - 1));
	}

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices)); 
		indices = make([]u16, len(temp_indices));

		for v, i in vertices {
			verts[i] = v;
		}
		for ii, i in temp_indices {
			indices[i] = ii;
		}
	}
	else {
		verts = convert_to_non_indexed(vertices[:], temp_indices[:]);
		indices = nil;
	}

	return;
}

//returns a static mesh containing a cylinder.
@(require_results)
make_mesh_cylinder :: proc(offset : [3]f32, height, diameter : f32, stacks : int, sectors : int, use_index_buffer : bool) -> (res : Mesh) {
	
	vert, index := generate_cylinder(offset, height, diameter, stacks, sectors, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .static_use);
	}
	else {
		res = make_mesh(vert, index, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}

@(require_results)
generate_sphere :: proc(offset : [3]f32 = {0,0,0}, diameter : f32, stacks : int = 10, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (verts : []Default_vertex, indices : []u16) {

	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	stacks := stacks + 1;

	for up in 0..=stacks {
		
		theta := f32(up) / f32(stacks) * math.PI - math.PI / 2;
		y : f32 = math.sin(theta);
		
		for phi in 0..<sectors {
			
			angle : f32 = f32(phi);

			t := f32(-angle) / f32(sectors-1) * 2 * math.PI;
			x := math.cos(t) * math.cos(theta);
			z := math.sin(t) * math.cos(theta);

			vert := [3]f32{x / 2 + offset.x, y / 2 + offset.y, z / 2 + offset.z};
			//append(&vertices, linalg.mul(transform, vert).xyz);
			//append(&texcoords, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)});
			//append(&normals, [3]f32{x,0,z});
			
			append(&vertices, Default_vertex{vert * diameter, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)}, [3]f32{x,y,z}});

			if up != 0 {
				below_neg 	:= up * sectors + ((phi - 1) %% sectors) - sectors;
				below_i	 	:= up * sectors + phi - sectors;
				this 		:= up * sectors + phi;
				pos 		:= up * sectors + ((phi + 1) %% sectors);
				append(&temp_indices, u16(below_i), u16(below_neg), u16(this)); 
				append(&temp_indices, u16(below_i), u16(this), u16(pos)); 
			}
			
		}
	}
	
	//assert(indices[6 * stacks * sectors - 1] != 0)

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices)); 
		indices = make([]u16, len(temp_indices));

		for v, i in vertices {
			verts[i] = v;
		}
		for ii, i in temp_indices {
			indices[i] = ii;
		}
	}
	else {
		verts = convert_to_non_indexed(vertices[:], temp_indices[:]);
		indices = nil;
	}

	return;
}

@(require_results)
make_mesh_sphere :: proc(offset : [3]f32, diameter : f32, stacks : int, sectors : int, use_index_buffer : bool) -> (res : Mesh) {
	
	vert, index := generate_sphere(offset, diameter, stacks, sectors, use_index_buffer);
	
	if index == nil {
		res = make_mesh(vert, nil, .static_use);
	}
	else {
		res = make_mesh(vert, index, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}

@(require_results)
generate_cone :: proc (offset : [3]f32, height, diameter : f32, sectors : int, use_index_buffer : bool) -> (verts : []Default_vertex, indices : []u16) {

	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);
	
	for phi in 0..<sectors {
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		z := math.sin(t);
		x2 := math.cos(t2);
		z2 := math.sin(t2);

		vert 	:= [3]f32{x, -height/2, z};
		vert2 	:= [3]f32{x2, -height/2, z2};
		vert.xz = vert.xz * diameter / 2;
		vert2.xz = vert2.xz * diameter / 2; 

		//the center only added once
		if len(vertices) == 0 {
			append(&vertices, 	Default_vertex{[3]f32{0,height/2,0} + offset, [2]f32{0,0} + 0.5, 	[3]f32{0,1,0}}); //TODO calculate the normal correctly
		}
		if len(vertices) == 1 {
			append(&vertices,  	Default_vertex{[3]f32{0,-height/2,0} + offset, 	 [2]f32{0,0} + 0.5, 	[3]f32{0,-1,0}});
		}
		if len(vertices) == 2 {
			append(&vertices,  	Default_vertex{vert + offset, 	vert.xz/diameter + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly
		}

		append(&vertices, 		Default_vertex{vert2 + offset, 	vert2.xz/diameter + 0.5, 	[3]f32{0,0,1}}); //TODO calculate the normal correctly

		append(&temp_indices, 0);
		append(&temp_indices, auto_cast (len(vertices) - 2));
		append(&temp_indices, auto_cast (len(vertices) - 1));
		
		append(&temp_indices, auto_cast (len(vertices) - 2));
		append(&temp_indices, 1);
		append(&temp_indices, auto_cast (len(vertices) - 1));
	}

	if use_index_buffer {
		verts = make([]Default_vertex, len(vertices));
		indices = make([]u16, len(temp_indices));
		
		for v, i in vertices {
			verts[i] = v; 	//convert from 2D to 3D
		}
		for ii, i in temp_indices {
			indices[i] = ii;
		}
	}
	else {
		non_indexed := convert_to_non_indexed(vertices[:], temp_indices[:]);
		verts = non_indexed;
	}
	
	return;
}

@(require_results)
make_mesh_cone :: proc(offset : [3]f32, height, diameter : f32, sectors : int, use_index_buffer : bool) -> (res : Mesh) {
	
	vert, index := generate_cone(offset, height, diameter, sectors, use_index_buffer);
	
	if index == nil {
		res = make_mesh(vert, nil, .static_use);
	}
	else {
		res = make_mesh(vert, index, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}