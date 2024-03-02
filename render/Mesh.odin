package render;

import "core:fmt"
import "core:reflect"
import "core:runtime"
import "core:mem"
import "core:slice"
import "core:log"

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

//mesh should be more complex, as it needs to handle:
	//static meshes																			- Static_mesh maybe?
	//Async upload 																			- done
	//Dynamicly changing the mesh (sync or async)											- done
	//Double/triple and auto buffering														- this can be done now
	//LOD (swapping index buffer)															
	//Frustum culling should be a thing we handle											- We can do this when we have made a camera
	//Somehow there is also a need for instance drawing (closely realated to mesh)			- 
	//And we should make multidraw a thing too (with occlusion culling)						
	//If this supportes dynamic meshes, then we should have multiple VAO's					-
Mesh :: struct {
	
	vertex_count : int, 					//The amount of verticies

	vao : Vao_id,							
	
	vertex_data : gl.Resource,
	vertex_data_fence : gl.Fence,

	data_type : typeid,

	indices_type : Index_buffer_type,
	indices_buf : Maybe(gl.Resource), 	//if you use a EBO

	//TODO bouding_distance for culling??
}

Index_buffer_type :: enum u32 {
	no_index_buffer,
	unsigned_short = glgl.UNSIGNED_SHORT,
	unsigned_int = glgl.UNSIGNED_INT,
}

Buffering_method :: enum {
	single,
	double,
	trible,
	auto,
}

//vertex_count may be 0 if the size is unknown at creation.
make_mesh :: proc (vertex_count : int, data_type : typeid, index_buffer_type : Index_buffer_type, buffering : Buffering_method = .single, loc := #caller_location) -> Mesh {
	mesh : Mesh;
	
	assert(data_type != nil, "a mesh must have valid data", loc);	

	mesh.vertex_count = vertex_count;
	mesh.data_type = data_type;
	mesh.indices_type = index_buffer_type;

	mesh.vao = gl.gen_vertex_array();
	
	desc : gl.Resource_desc = {
		usage = .dynamic_write,
		buffer_type = .array_buffer,
		bytes_count = vertex_count * reflect.size_of_typeid(data_type),
	}
	
	attrib_info := get_attribute_info_from_typeid(data_type, loc);
	defer delete(attrib_info);

	mesh.vertex_data = gl.make_resource_desc(desc, nil);
	gl.associate_buffer_with_vao(mesh.vao, mesh.vertex_data.buffer, attrib_info, loc);

	switch mesh.indices_type {
		case .no_index_buffer:
			//nothing happens
		case .unsigned_short:
			panic("TODO");
			//mesh.indices_buf = gl.BindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo16);
		case .unsigned_int:
			panic("TODO");
			//mesh.indices_buf = gl.BindBuffer(GL_ELEMENT_ARRAY_BUFFER, ibo32);
	}

	return mesh;
}

destroy_mesh :: proc (mesh : ^Mesh) {
	
	gl.discard_fence(&mesh.vertex_data_fence);
	gl.destroy_resource(&mesh.vertex_data);

	gl.delete_vertex_array(mesh.vao);
	mesh.vao = 0;
}

//You can upload once per frame
upload_mesh_data :: proc(mesh : ^Mesh, data : []$T, loc := #caller_location) {

	when ODIN_DEBUG {
		if !gl.is_fence_ready(mesh.vertex_data_fence) {
			log.warnf("Preformence warning: upload_mesh_data sync is not ready, increase the amount of buffering\n");
		}
	}

	gl.sync_fence(&mesh.vertex_data_fence);

	assert(T == mesh.data_type, "The data type you are trying to upload does not match the meshes data type", loc);
	assert(mesh.vertex_count == len(data), "data is not the same length as vertex count (should that be legal?)", loc);
	
	//data_bytes := slice.reinterpret([]u8, data);

	dst : []u8 = gl.begin_buffer_write(&mesh.vertex_data);
	assert(len(dst) == len(data) * size_of(T), "length of buffer and length of data does not match", loc);
	mem.copy_non_overlapping(raw_data(dst), raw_data(data), len(dst));

	gl.end_buffer_writes(&mesh.vertex_data);
}

draw_mesh_single :: proc (mesh : ^Mesh, model_matrix : matrix[4,4]f32, loc := #caller_location) {
	assert(state.bound_shader != nil, "you must first begin the pipeline with begin_pipeline", loc);
	
	set_uniform(state.bound_shader, .model_mat, model_matrix);
	set_uniform(state.bound_shader, .inv_model_mat, linalg.matrix4_inverse(model_matrix));

	mvp := state.prj_mat * state.view_mat * model_matrix;
	set_uniform(state.bound_shader, .mvp, mvp);
	set_uniform(state.bound_shader, .inv_mvp, linalg.matrix4_inverse(mvp));

	gl.draw_arrays(mesh.vao, .triangles, 0, mesh.vertex_count);
	gl.discard_fence(&mesh.vertex_data_fence);
	mesh.vertex_data_fence = gl.place_fence();

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



Default_vertex :: struct {
	position 	: [3]f32,
	texcoord 	: [2]f32,
	normal 		: [3]f32,
}

//This will not upload it
generate_quad :: proc(size : [3]f32, position : [3]f32, use_index_buffer : bool,
							alloc := context.allocator, loc := #caller_location) -> (verts : []Default_vertex, indicies : Maybe([]u16)) {

	context.allocator = alloc;

	if use_index_buffer {
		verts = make([]Default_vertex, 4)
		indicies = make([]u16, 6);
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + position, {0,0}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + position, {1,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + position, {0,1}, {0,0,1}};
		verts[3] = Default_vertex{[3]f32{1,1,0} * size + position, {1,1}, {0,0,1}};
		
		indices := []u16{ 0,1,2,2,1,3, };
	}
	else {
		verts = make([]Default_vertex, 4)
		indicies = nil;
		
		verts[0] = Default_vertex{[3]f32{0,0,0} * size + position, {0,0}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + position, {1,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + position, {0,1}, {0,0,1}};
		verts[1] = Default_vertex{[3]f32{1,0,0} * size + position, {1,0}, {0,0,1}};
		verts[2] = Default_vertex{[3]f32{0,1,0} * size + position, {0,1}, {0,0,1}};
		verts[3] = Default_vertex{[3]f32{1,1,0} * size + position, {1,1}, {0,0,1}};
	}
	
	return;
}

/*
make_mesh_quad :: proc() -> Static_mesh {

}

generate_circle :: proc(diameter : f32, positon : [2]f32, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (circle : Mesh) {

	vertices := make([dynamic][2]f32, 0, 3 * (sectors+1), context.temp_allocator);
	texcoords := make([dynamic][2]f32, 0, 3 * (sectors+1), context.temp_allocator);
	normals := make([dynamic][3]f32, 0, 3 * (sectors+1), context.temp_allocator);
	indices := make([dynamic]u16, 0, 3 * (sectors+1), context.temp_allocator);
	
	for phi in 0..<sectors {
		//TODO this does not reuse verticies!
		angle : f32 = f32(phi);

		t := f32(angle - 1) / f32(sectors) * 2 * math.PI;
		t2 := f32(angle) / f32(sectors) * 2 * math.PI;
		x := math.cos(t);
		y := math.sin(t);
		x2 := math.cos(t2);
		y2 := math.sin(t2);

		vert 	:= [2]f32{x, y};
		vert2 	:= [2]f32{x2, y2};

		append(&vertices, [2]f32{0,0} *  diameter / 4 + positon);
		append(&vertices, vert * diameter / 4 + positon);
		append(&vertices, vert2 * diameter / 4 + positon);

		append(&texcoords, [2]f32{0,0});
		append(&texcoords, vert);
		append(&texcoords, vert2);
		
		append(&normals, [3]f32{0,0,1});
		append(&normals, [3]f32{0,0,1});
		append(&normals, [3]f32{0,0,1});

		append(&indices, auto_cast len(indices));
		append(&indices, auto_cast len(indices));
		append(&indices, auto_cast len(indices));
	}


	if use_index_buffer {
		circle.vertex_count = auto_cast len(vertices);

		circle.vertices = make([][3]f32, 	circle.vertex_count);
		circle.texcoords = make([][2]f32, 	circle.vertex_count);
		circle.normals = make([][3]f32, 	circle.vertex_count);
		circle_indices := make([]u16, 		circle.vertex_count);

		for v, i in vertices {
			circle.vertices[i] = {v.x, v.y, 0}; //convert from 2D to 3D
		}
		copy_slice(circle.texcoords[:], texcoords[:]);
		copy_slice(circle.normals[:], normals[:]);

		copy_slice(circle_indices[:], indices[:]);
		circle.indices = circle_indices;

	}
	else {
		circle.vertex_count = auto_cast len(vertices);

		circle.vertices = make([][3]f32, 	circle.vertex_count);
		circle.texcoords = make([][2]f32, circle.vertex_count);
		circle.normals = make([][3]f32, 	circle.vertex_count);
		
		for v, i in indices {
			circle.vertices[i] = {vertices[v].x, vertices[v].y, 0};
			circle.texcoords[i] = texcoords[v]; 
			circle.normals[i] = normals[v];
		}
	}

	return;
}

//This will not upload it
generate_cube :: proc(size : [3]f32, position : [3]f32, use_index_buffer : bool, loc := #caller_location) -> (cube : Mesh) {

	Cube_verts := [][3]f32{
		
		{0,1,0}, // triangle 1 : begin
		{0,1,1},
		{1,1,1}, // triangle 1 : end
		{0,1,0}, // triangle 2 : begin
		{1,1,1},
		{1,1,0}, // triangle 2 : end

        {0,0,0},
        {1,0,1},
        {0,0,1},
        {0,0,0},
        {1,0,0},
        {1,0,1},

        {1,0,0},
        {1,1,1},
        {1,0,1},
        {1,0,0},
        {1,1,0},
        {1,1,1},

        {0,0,0},
        {0,0,1},
        {0,1,1},
        {0,0,0},
        {0,1,1},
        {0,1,0},

        {0,0,1},
        {1,1,1},
        {0,1,1},
        {0,0,1},
        {1,0,1},
        {1,1,1},

        {0,0,0},
        {0,1,0},
        {1,1,0},
        {0,0,0},
        {1,1,0},
        {1,0,0},		
	} 

	Cube_tex := [][2]f32{
		
        {0, 0},
        {0, 1},
        {1, 1},
        {0, 0},
        {1, 1},
        {1, 0},

		{0, 0}, // triangle 1 : begin
		{1, 1}, // triangle 1 : end
		{0, 1},
		{0, 0},
		{1, 0}, // triangle 2 : end
		{1, 1}, // triangle 2 : begin
		
		{0, 0}, // triangle 1 : begin
		{1, 1}, // triangle 1 : end
		{0, 1},
		{0, 0},
		{1, 0}, // triangle 2 : end
		{1, 1}, // triangle 2 : begin

		{0, 0}, // triangle 1 : begin
		{0, 1},
		{1, 1}, // triangle 1 : end
		{0, 0},
		{1, 1}, // triangle 2 : begin
		{1, 0}, // triangle 2 : end

		{0, 0}, // triangle 1 : begin
		{1, 1}, // triangle 1 : end
		{0, 1},
		{0, 0},
		{1, 0}, // triangle 2 : end
		{1, 1}, // triangle 2 : begin

		{0, 0}, // triangle 1 : begin
		{0, 1},
		{1, 1}, // triangle 1 : end
		{0, 0},
		{1, 1}, // triangle 2 : begin
		{1, 0}, // triangle 2 : end
	}

	if use_index_buffer {
		panic("Unimplemented");
	}
	else {
		cube.vertex_count = auto_cast len(Cube_verts);
		cube.vertices = make([][3]f32, 	cube.vertex_count);
		cube.texcoords = make([][2]f32, cube.vertex_count);
		//cube.normals = make([][3]f32, 	cube.vertex_count);

		copy_slice(cube.vertices[:], Cube_verts[:]);
		copy_slice(cube.texcoords[:], Cube_tex[:]);
	}

	calculate_tangents(&cube);

	return;
}

//This will not upload it
generate_cylinder :: proc(offset : [3]f32, transform : matrix[4, 4]f32, stacks : int, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (cylinder : Mesh) {

	vertices := make([dynamic][3]f32, 0, 4 * stacks * (sectors+1), context.temp_allocator);
	texcoords := make([dynamic][2]f32, 0, 4 * stacks * (sectors+1), context.temp_allocator);
	normals := make([dynamic][3]f32, 0, 4 * stacks * (sectors+1), context.temp_allocator);
	indices := make([dynamic]u16, 0, 6 * stacks * (sectors+1), context.temp_allocator);

	for up in 0..=stacks {
		
		y : f32 = f32(up) / f32(stacks);
		
		for phi in 0..<sectors {
			
			angle : f32 = f32(phi);

			x := math.cos_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);
			z := math.sin_f32(f32(angle) / f32(sectors-1) * 2 * math.PI);

			vert := [4]f32{x / 2 + offset.x, y + offset.y - 0.5, z / 2 + offset.z, 0};
			append(&vertices, linalg.mul(transform, vert).xyz);
			append(&texcoords, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)});
			append(&normals, [3]f32{x,0,z});
			
			if up != 0 {
				below_neg 	:= up * sectors + ((phi - 1) %% sectors) - sectors;
				below_i	 	:= up * sectors + phi - sectors;
				this 		:= up * sectors + phi;
				pos 		:= up * sectors + ((phi + 1) %% sectors);
				append(&indices, u16(below_i), u16(below_neg), u16(this)); 
				append(&indices, u16(below_i), u16(this), u16(pos)); 
			}
			
		}
	}

	//assert(indices[6 * stacks * sectors - 1] != 0)

	if use_index_buffer {
		
		cylinder.vertex_count = auto_cast len(vertices);
		cylinder.vertices = make([][3]f32, 	cylinder.vertex_count);
		cylinder.texcoords = make([][2]f32, cylinder.vertex_count);
		cylinder.normals = make([][3]f32, 	cylinder.vertex_count);
		cylinder_indices := make([]u16, len(indices));

		copy_slice(cylinder.vertices[:], vertices[:]);
		copy_slice(cylinder.texcoords[:], texcoords[:]);
		copy_slice(cylinder.normals[:], normals[:]);

		copy_slice(cylinder_indices[:], indices[:]);
		cylinder.indices = cylinder_indices;
	}
	else {

		cylinder.vertex_count = auto_cast len(indices);
		cylinder.vertices = make([][3]f32, 	cylinder.vertex_count);
		cylinder.texcoords = make([][2]f32, cylinder.vertex_count);
		cylinder.normals = make([][3]f32, 	cylinder.vertex_count);

		for v, i in indices {
			cylinder.vertices[i] = vertices[v];
			cylinder.texcoords[i] = texcoords[v]; 
			cylinder.normals[i] = normals[v];
		}
	}
	
	calculate_tangents(&cylinder);

	return;
}

//This will not upload it
generate_sphere :: proc(offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 10, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (sphere : Mesh) {

	vertices := make([dynamic][3]f32, 0, 4 * stacks * (sectors+1), context.temp_allocator);
	texcoords := make([dynamic][2]f32, 0, 4 * stacks * (sectors+1), context.temp_allocator);
	normals := make([dynamic][3]f32, 0, 4 * stacks * (sectors+1), context.temp_allocator);
	indices := make([dynamic]u16, 0, 6 * stacks * (sectors+1), context.temp_allocator);
	
	stacks := stacks + 1;

	for up in 0..=stacks {
		
		theta := f32(up) / f32(stacks) * math.PI - math.PI / 2;
		y : f32 = math.sin(theta);
		
		for phi in 0..<sectors {
			
			angle : f32 = f32(phi);

			t := f32(angle) / f32(sectors-1) * 2 * math.PI;
			x := math.cos(t) * math.cos(theta);
			z := math.sin(t) * math.cos(theta);

			vert := [4]f32{x / 2 + offset.x, y / 2 + offset.y, z / 2 + offset.z, 0};
			append(&vertices, linalg.mul(transform, vert).xyz);
			append(&texcoords, [2]f32{f32(phi) / f32(sectors-1), f32(up) / f32(stacks)});
			append(&normals, [3]f32{x,0,z});
			
			if up != 0 {
				below_neg 	:= up * sectors + ((phi - 1) %% sectors) - sectors;
				below_i	 	:= up * sectors + phi - sectors;
				this 		:= up * sectors + phi;
				pos 		:= up * sectors + ((phi + 1) %% sectors);
				append(&indices, u16(below_i), u16(below_neg), u16(this)); 
				append(&indices, u16(below_i), u16(this), u16(pos)); 
			}
			
		}
	}

	//assert(indices[6 * stacks * sectors - 1] != 0)

	if use_index_buffer {
		
		sphere.vertex_count = auto_cast len(vertices);
		sphere.vertices = make([][3]f32, 	sphere.vertex_count);
		sphere.texcoords = make([][2]f32, sphere.vertex_count);
		sphere.normals = make([][3]f32, 	sphere.vertex_count);
		sphere_indices := make([]u16, len(indices));

		copy_slice(sphere.vertices[:], vertices[:]);
		copy_slice(sphere.texcoords[:], texcoords[:]);
		copy_slice(sphere.normals[:], normals[:]);

		copy_slice(sphere_indices[:], indices[:]);
		sphere.indices = sphere_indices;
	}
	else {

		sphere.vertex_count = auto_cast len(indices);
		sphere.vertices = make([][3]f32, 	sphere.vertex_count);
		sphere.texcoords = make([][2]f32, sphere.vertex_count);
		sphere.normals = make([][3]f32, 	sphere.vertex_count);
		
		for v, i in indices {
			sphere.vertices[i] = vertices[v];
			sphere.texcoords[i] = texcoords[v]; 
			sphere.normals[i] = normals[v];
		}
	}
	
	calculate_tangents(&sphere);

	return;
}
*/
