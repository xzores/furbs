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

Mesh_buffers :: struct {
	vao : Vao_id,
	vertex_data : gl.Resource,
	indices_buf : Maybe(gl.Resource),
	fence : gl.Fence, //Only used when streaming.
}

//mesh should be more complex, as it needs to handle:
	//static meshes																			- done
	//Async upload 																			- done
	//Dynamicly changing the mesh (sync or async)											- done
	//Double/triple and auto buffering														- this can be done now
	//Frustum culling should be a thing we handle											- We can do this when we have made a camera
	//Somehow there is also a need for instance drawing (closely realated to mesh)			- 
	//And we should make multidraw a thing too												- 
	//Occlusion culling should be handled somehow? 											- 
	//If this supportes dynamic meshes, then we should have multiple VAO's					- 
Mesh :: struct {
	
	vertex_count 	: int, 				//The amount of verticies
	triangle_count 	: int, 				//The amount of verticies

	data_type : typeid,
	buffering : Buffering,
	usage : Usage,
	indices_type : Index_buffer_type,

	//TODO bouding_distance for culling??

	//TODO make mesh implementation.
	//implementaion :
	current_resource : int,
	resources : [dynamic]Mesh_buffers,
}

Index_buffer_type :: gl.Index_buffer_type;

Buffering :: enum {
	single,
	double,
	trible,
	auto,
}

Usage :: enum {
	static_use 	= auto_cast gl.Resource_usage.static_write,		//You cannot update this mesh
	dynamic_use = auto_cast gl.Resource_usage.dynamic_write,	//Will use BufferSubData for updates
	stream_use	= auto_cast gl.Resource_usage.stream_write,		//Will use persistent mapped buffer and fallback to unsyncronized mapped buffers.
}

@private
//Used internally for setup up a resource for a mesh
add_resource :: proc (mesh : ^Mesh, init_vertex_data : []u8, init_index_data : []u8, loc := #caller_location) {

	desc : gl.Resource_desc = {
		usage = cast(gl.Resource_usage)mesh.usage,
		buffer_type = .array_buffer,
		bytes_count = mesh.vertex_count * reflect.size_of_typeid(mesh.data_type),
	}

	attrib_info := get_attribute_info_from_typeid(mesh.data_type, loc);
	defer delete(attrib_info);

	vao := gl.gen_vertex_array();

	vertex_resouce := gl.make_resource_desc(desc, init_vertex_data, loc);
	gl.associate_buffer_with_vao(vao, vertex_resouce.buffer, attrib_info, loc);

	index_buf : Maybe(gl.Resource);

	switch mesh.indices_type {
		
		case .no_index_buffer:
			index_buf = nil;

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
			index_buf = gl.make_resource_desc(index_desc, init_index_data, loc);
	}

	append(&mesh.resources, Mesh_buffers{vao, vertex_resouce, index_buf, {}});
}

Indicies_types :: union {
	[]u16,
	[]u32,
}

//vertex_data and index_data may be nil if no data is to be uploaded. 
make_mesh :: proc (vertex_data : []$T, index_data : Indicies_types, buffering : Buffering, usage : Usage, loc := #caller_location) -> Mesh {
	mesh : Mesh;

	if usage == .static_use {
		assert(buffering == .single, "It does not make sense to use anything else then single buffering for a static mesh", loc);
	}
	if usage == .stream_use {
		assert(buffering != .single, "It does not make sense to use single buffering for a streaming mesh", loc);
	}

	mesh.vertex_count = len(vertex_data);
	mesh.data_type = T;
	mesh.buffering = buffering;
	mesh.usage = usage;
	
	mesh_index_buf_data : []u8;
	switch indicies in index_data {
		case []u16:
			assert(indicies != nil, "there is no indicies index_data", loc);
			mesh.indices_type = .unsigned_short;
			mesh.triangle_count = len(indicies);
			mesh_index_buf_data = slice.reinterpret([]u8, indicies);
		case []u32:
			assert(indicies != nil, "there is no indicies index_data", loc);
			mesh.indices_type = .unsigned_int;
			mesh.triangle_count = len(indicies);
			mesh_index_buf_data = slice.reinterpret([]u8, indicies);
		case nil:
			mesh.indices_type = .no_index_buffer;
			mesh.triangle_count = 0;
			mesh_index_buf_data = nil;
	}
	
	switch mesh.buffering {
		case .single:
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
		case .double:
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
		case .trible:
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
		case .auto:
			//more will be added as the mesh needs it.
			add_resource(&mesh, slice.reinterpret([]u8,vertex_data), mesh_index_buf_data, loc);
	}

	return mesh;
}

destroy_mesh :: proc (mesh : Mesh) {

	for &res in mesh.resources {
		gl.destroy_resource(res.vertex_data);
		gl.discard_fence(&res.fence); //discarding an nil fence is allowed
		if ib, ok := res.indices_buf.?; ok {
			gl.destroy_resource(ib);
		}
		gl.delete_vertex_array(res.vao);
	}

	delete(mesh.resources);
}

//You can upload once per frame
upload_mesh_data :: proc(mesh : ^Mesh, data : []$T, loc := #caller_location) {
	
	assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
	assert(mesh.vertex_count == len(data), "data is not the same length as vertex count (should that be legal?)", loc);
	
	buffers : Mesh_buffers = mesh.resources[mesh.current_resource];
	
	when ODIN_DEBUG {
		if mesh.usage == .stream_use && !gl.is_fence_ready(buffers.fence) {
			log.warnf("Preformence warning: upload_mesh_data sync is not ready, increase the amount of buffering\n");
		}
	}

	if mesh.usage == .stream_use {
		gl.sync_fence(&buffers.fence);
	}
	
	switch mesh.usage {
		case .static_use:
			panic("Cannot upload to a static mesh");
		case .dynamic_use:
			gl.buffer_upload_sub_data(&buffers.vertex_data, 0, slice.reinterpret([]u8, data));
		case .stream_use:
			dst : []u8 = gl.begin_buffer_write(&buffers.vertex_data);
			assert(len(dst) == len(data) * size_of(T), "length of buffer and length of data does not match", loc);
			mem.copy_non_overlapping(raw_data(dst), raw_data(data), len(dst));
			gl.end_buffer_writes(&buffers.vertex_data);
	}
	
	mesh.current_resource = (mesh.current_resource + 1) %% len(mesh.resources);
}

draw_mesh_single :: proc (mesh : ^Mesh, model_matrix : matrix[4,4]f32, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	
	set_uniform(state.bound_shader, .model_mat, model_matrix);
	set_uniform(state.bound_shader, .inv_model_mat, linalg.matrix4_inverse(model_matrix));

	mvp := state.prj_mat * state.view_mat * model_matrix;
	set_uniform(state.bound_shader, .mvp, mvp);
	set_uniform(state.bound_shader, .inv_mvp, linalg.matrix4_inverse(mvp));

	buffers : ^Mesh_buffers = &mesh.resources[mesh.current_resource];
	switch mesh.indices_type {
		case .no_index_buffer:
			gl.draw_arrays(buffers.vao, .triangles, 0, mesh.vertex_count);
		case .unsigned_short, .unsigned_int:
			if i_buf, ok := buffers.indices_buf.?; ok {
				gl.draw_elements(buffers.vao, .triangles, mesh.triangle_count, mesh.indices_type, i_buf.buffer);
			}
			else {
				panic("The mesh does not have a index buffer", loc);
			}
	}

	if mesh.usage == .stream_use {
		gl.discard_fence(&buffers.fence);
		buffers.fence = gl.place_fence();
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

//converts a index buffer and an vertex arrsay into a vertex arrray without an index buffer
//Used internally
convert_to_non_indexed :: proc (verts : []$T, indices : Indicies_types) -> (new_verts : []T){

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

@(require_results)
generate_quad :: proc(size : [3]f32, position : [3]f32, use_index_buffer : bool, alloc := context.allocator) -> (verts : []Default_vertex, indices : []u16) {

	context.allocator = alloc;

	if use_index_buffer {
		verts = make([]Default_vertex, 4)
		_indices := make([]u16, 6);
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + position - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + position - {0.5,0.5,0}, {0,1}, {0,0,1}};
		verts[3] = Default_vertex{[3]f32{1,1,0} * size + position - {0.5,0.5,0}, {1,1}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + position - {0.5,0.5,0}, {1,0}, {0,0,1}};
		
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
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + position - {0.5,0.5,0}, {0,0}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + position - {0.5,0.5,0}, {1,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + position - {0.5,0.5,0}, {0,1}, {0,0,1}};

		verts[3] = Default_vertex{[3]f32{0,1,0} * size + position - {0.5,0.5,0}, {0,1}, {0,0,1}};
		verts[4] = Default_vertex{[3]f32{1,0,0} * size + position - {0.5,0.5,0}, {1,0}, {0,0,1}};
		verts[5] = Default_vertex{[3]f32{1,1,0} * size + position - {0.5,0.5,0}, {1,1}, {0,0,1}};
	}
	
	return;
}

//returns a static mesh containing a quad.
@(require_results)
make_mesh_quad :: proc(size : [3]f32, position : [3]f32, use_index_buffer : bool) -> (res : Mesh) {

	vert, index := generate_quad(size, position, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .single, .static_use);
	}
	else {
		res = make_mesh(vert, index, .single, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}

@(require_results)
generate_circle :: proc(diameter : f32, positon : [3]f32, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : []u16) {
	
	vertices := make([dynamic]Default_vertex);
	temp_indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	defer delete(vertices);
	defer delete(temp_indices);

	for phi in 0..<sectors {
		//TODO this does not reuse verticies!
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		y := math.sin(t);
		x2 := math.cos(t2);
		y2 := math.sin(t2);

		vert 	:= [3]f32{x, y, 0} * 2;
		vert2 	:= [3]f32{x2, y2, 0} * 2;

		//the center only added once
		if len(vertices) == 0 {
			append(&vertices, 	Default_vertex{[3]f32{0,0,0} *  diameter / 4 + positon, [2]f32{0,0} + 0.5, 	[3]f32{0,0,1}});
		}

		if len(vertices) == 1 {
			append(&vertices,  	Default_vertex{vert * diameter / 4 + positon, 			vert.xy/4 + 0.5, 	[3]f32{0,0,1}});
		}

		append(&vertices, 		Default_vertex{vert2 * diameter / 4 + positon, 			vert2.xy/4 + 0.5, 	[3]f32{0,0,1}});

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
make_mesh_circle :: proc(diameter : f32, position : [3]f32, sectors : int, use_index_buffer : bool) -> (res : Mesh) {

	vert, index := generate_circle(diameter, position, sectors, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .single, .static_use);
	}
	else {
		res = make_mesh(vert, index, .single, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}

//
@(require_results)
generate_cube :: proc(size : [3]f32, position : [3]f32, use_index_buffer : bool, loc := #caller_location) -> (verts : []Default_vertex, indices : []u16) {

	corners : [24]Default_vertex = {
		//XP
		Default_vertex{{1,0,0}, {0,0}, {1,0,0}},	
		Default_vertex{{1,1,0}, {1,0}, {1,0,0}},
		Default_vertex{{1,1,1}, {1,1}, {1,0,0}},
		Default_vertex{{1,0,1}, {0,1}, {1,0,0}},

		//XN
		Default_vertex{{0,0,0}, {0,0}, {-1,0,0}},
		Default_vertex{{0,0,1}, {0,1}, {-1,0,0}},
		Default_vertex{{0,1,1}, {1,1}, {-1,0,0}},
		Default_vertex{{0,1,0}, {1,0}, {-1,0,0}},

		//YP
		Default_vertex{{0,1,0}, {0,0}, {0,1,0}},
		Default_vertex{{0,1,1}, {0,1}, {0,1,0}},
		Default_vertex{{1,1,1}, {1,1}, {0,1,0}},
		Default_vertex{{1,1,0}, {1,0}, {0,1,0}},

		//YN
		Default_vertex{{0,0,0}, {0,0}, {0,-1,0}},
		Default_vertex{{1,0,0}, {1,0}, {0,-1,0}},
		Default_vertex{{1,0,1}, {1,1}, {0,-1,0}},
		Default_vertex{{0,0,1}, {0,1}, {0,-1,0}},

		//ZP
		Default_vertex{{0,0,1}, {0,0}, {0,0,1}},
		Default_vertex{{1,0,1}, {1,0}, {0,0,1}},
		Default_vertex{{1,1,1}, {1,1}, {0,0,1}},
		Default_vertex{{0,1,1}, {0,1}, {0,0,1}},

		//ZN
		Default_vertex{{0,0,0}, {0,0}, {0,0,-1}},
		Default_vertex{{0,1,0}, {0,1}, {0,0,-1}},
		Default_vertex{{1,1,0}, {1,1}, {0,0,-1}},
		Default_vertex{{1,0,0}, {1,0}, {0,0,-1}},
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
		verts[i] = Default_vertex{(c.position - {0.5,0.5,0.5} + position) * size, c.texcoord, c.normal};
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
make_mesh_cube :: proc(size : [3]f32, position : [3]f32, use_index_buffer : bool) -> (res : Mesh) {
	
	vert, index := generate_cube(size, position, use_index_buffer);

	if index == nil {
		res = make_mesh(vert, nil, .single, .static_use);
	}
	else {
		res = make_mesh(vert, index, .single, .static_use);
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
		
		for phi in 0..<sectors {
			
			angle : f32 = f32(phi);

			x := math.cos_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);
			z := math.sin_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);

			vert := [3]f32{x / 2 + offset.x, y + offset.y - 0.5, z / 2 + offset.z};

			append(&vertices, Default_vertex{{vert.x * diameter, vert.y * height, vert.z * diameter}, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)}, [3]f32{x,0,z}});
			
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

	/*
	TODO add top and bottom
	//add top center vertex
	top_index := len(vertices);
	append(&vertices, Default_vertex{{0, height / 2, 0}, [2]f32{0,0} + 0.5, [3]f32{0,1,0}});
	//add bottom center vertex
	bottom_index := len(vertices) + 1;
	append(&vertices, Default_vertex{{0, -height / 2, 0}, [2]f32{0,0} + 0.5, [3]f32{0,1,0}});
	*/

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
		res = make_mesh(vert, nil, .single, .static_use);
	}
	else {
		res = make_mesh(vert, index, .single, .static_use);
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

			t := f32(angle) / f32(sectors-1) * 2 * math.PI;
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
		res = make_mesh(vert, nil, .single, .static_use);
	}
	else {
		res = make_mesh(vert, index, .single, .static_use);
		delete(index);
	}
	delete(vert);

	return;
}