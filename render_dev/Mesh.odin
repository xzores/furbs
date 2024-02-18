package render;

import "core:slice"
import "core:fmt"
import "core:mem"
import "core:math"
import "core:intrinsics"
import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

Mesh_attribute :: struct {
	//client side
	active : bool,
	data_type : Attribute_type,

	//Set when uploaded (do not set)
	vbo : Vbo_ID,
}


Mesh_data :: struct(A : typeid) where intrinsics.type_is_enum(A) {
	
	vertex_count : int, 					//The amount of verticies
	
	attributes_desc : [A]Mesh_attribute,

	indices : union {
		[]u16,
		[]u32,
	},           							// optional
}

Mesh_identifiers :: struct(A : typeid) where intrinsics.type_is_enum(A) {
	// OpenGL identifiers
	vao_id		: Vao_ID,                // OpenGL Vertex Array Object id
	vbo_id		: [A]Vbo_ID,              // OpenGL Vertex Buffer Objects id (default vertex data)
	vbo_indices : Vbo_ID,				//special for indicies 
}

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

//TODO allow option not to copy memeory
//makes a copy of the data, you can delete the source array afterwards.
set_mesh_attribute :: proc(s : ^Render_state($U,$A), mesh_data : ^Mesh_data(A), attrib : A, data : []$T, loc := #caller_location) {

	attrib_type := odin_type_to_attribute_type(T);
	fmt.assertf(attrib_type != .invalid, "The datatype %v is not a valid attribute type", type_info_of(T), loc = loc);
	assert(len(data) != 0, "please do not set empty data on a mesh", loc = loc);
	fmt.assertf(mesh_data.attributes[attrib].active == false, "the attribute %v is already set on the mesh", attrib, loc = loc);

	if mesh_data.vertex_count == 0 {
		mesh_data.vertex_count = len(data);
	}
	else {
		fmt.assertf(mesh_data.vertex_count == len(data), "The passed data containing %v verticies does not match the vertex_count of the mesh (vertex_count : %v). The vertex count is set the first time set_mesh_attribute is called",
			len(data), mesh_data.vertex_count,loc = loc);
	}

	mesh_data.attributes[attrib].active = true;
	mesh_data.attributes[attrib].data_type = attrib_type;
	mesh_data.attributes[attrib].data = make([]u8, len(data) * size_of(T));
	mem.copy(raw_data(mesh_data.attributes[attrib].data), raw_data(data), len(data) * size_of(T));
}

//TODO allow option not to copy memeory
set_mesh_indices :: proc(s : ^Render_state($U,$A), mesh_data : ^Mesh_data(A), data : union {[]u16, []u32}, loc := #caller_location) {
	
	if d, ok := data.([]u16); ok {
		indices : []u16 = make([]u16, len(d));
		copy_slice(indices, d);
		mesh_data.indices = indices;
	}
	else if d, ok := data.([]u32); ok {
		indices : []u32 = make([]u32, len(d));
		copy_slice(indices, d);
		mesh_data.indices = indices;
	}
	else {
		panic("data is invalid");
	}
}

// Creates pointers to begin async upload  
upload_mesh_single :: proc (using s : ^Render_state($U,$A), mesh : ^Mesh(A), dyn : bool = false, loc := #caller_location) {
	
	upload_mesh_data :: proc(using s : ^Render_state($U,$A), mesh : ^Mesh_data(A), dyn : bool, loc := #caller_location) -> (identifiers : Mesh_identifiers(A)) {
		
		identifiers.vao_id = 0;        // Vertex Array Object

		for &vbo in  identifiers.vbo_id {
			vbo = 0;     // Vertex buffer set to 0
		}
		
		identifiers.vao_id = load_vertex_array(s); //glGenVertexArrays(1, &vao_id);
		//enable_vertex_array(s, identifiers.vao_id);
		
		when ODIN_DEBUG {
			for a in mesh.attributes {
				//TODO
				//assert(mesh.attributes[A.position].vertex_cnt == mesh.attributes[a].vertex_cnt || mesh.texcoords == nil, "vertices and texcoords lengths does not match", loc = loc);
			}
		}
		
		for attrib, a in mesh.attributes {
			if attrib.active {
				dims := get_attribute_type_dimensions(attrib.data_type);
				prim_type := get_attribute_primary_type(attrib.data_type);
				size_of_prim_type := get_attribute_primary_byte_len(prim_type);
				
				identifiers.vbo_id[a] = load_vertex_buffer(s, nil, mesh.vertex_count * dims * size_of_prim_type, dyn); //TODO upload data here instead of below. nil = attrib.data?
				setup_vertex_attribute(s, identifiers.vao_id, identifiers.vbo_id[a], dims, prim_type, a, loc = loc);
				upload_vertex_sub_buffer_data(s, identifiers.vbo_id[a], 0, mesh.vertex_count * dims * size_of_prim_type, attrib.data);
			}
		}

		if (mesh.indices != nil) {
			if indices, ok := mesh.indices.([]u16); ok {
				identifiers.vbo_indices = load_vertex_buffer(s, raw_data(indices), len(indices) * size_of(u16), dyn);
				//TODO is something needed here?
			}
			else if indices, ok := mesh.indices.([]u32); ok {
				identifiers.vbo_indices = load_vertex_buffer(s, raw_data(indices), len(indices) * size_of(u32), dyn);
				//TODO is something needed here?
			}
			else {
				panic("Unimplemented");
			}
		}
		
		return;
	}

	if mesh.implementation == nil {
		mesh.implementation = upload_mesh_data(s, mesh, dyn, loc);
	}
	else {
		panic("You have already uploaded this mesh", loc = loc);
	}
}

// Unload mesh from memory (RAM and VRAM)
unload_mesh_single :: proc(using s : ^Render_state($U,$A), mesh : ^Mesh(A), loc := #caller_location) {

	assert(mesh.implementation != nil, "The mesh is not uploaded", loc = loc);

	if identifiers, ok := mesh.implementation.(Mesh_identifiers(A)); ok {
		
		unload_vertex_array(s, identifiers.vao_id);
		identifiers.vao_id = 0;

		for i in A {
			if identifiers.vbo_id[i] != 0 {
				unload_vertex_buffer(s, identifiers.vbo_id[i], loc = loc);
				identifiers.vbo_id[i] = -1;
			}
		}
		
		for &attrib in mesh.attributes {
			if attrib.active {
				delete(attrib.data);
				attrib = {};
			}
		}

		if (mesh.indices != nil)
		{
			if indices, ok := mesh.indices.([]u16); ok {
				cond_delete(indices, loc);
			}
			else if indices, ok := mesh.indices.([]u32); ok {
				cond_delete(indices, loc);
			}
			else {
				panic("Unimplemented");
			}
		}

		mesh.vertex_count = 0;
	}
	else {
		panic("You cannot upload the mesh using unload_mesh_single, use unload_mesh_shared instead", loc = loc);
	}
}

draw_mesh_single :: proc (using s : ^Render_state($U,$A), shader : Shader(U, A), mesh : Mesh(A), transform : matrix[4, 4]f32, loc := #caller_location) {
	
	when ODIN_DEBUG {
		assert(shader.id == s.bound_shader_program, "The shader must be bound before drawing with it", loc = loc);
		assert(mesh.implementation != nil, "The mesh is not uploaded", loc = loc);
	}

	mvp : matrix[4,4]f32 = prj_mat * view_mat * transform;
	
	place_uniform(s, shader, U.model_mat, transform);
	place_uniform(s, shader, U.mvp, mvp);
	
	if identifiers, ok := mesh.implementation.(Mesh_identifiers(A)); ok {
		enable_vertex_array(s, identifiers.vao_id);
		
		// Draw mesh
		if (mesh.indices != nil) {
			//TODO bind mesh.indices buffer
			//TODO enable_vertex_buffer_element	

			enable_vertex_buffer_element(s, identifiers.vbo_indices);

			assert(identifiers.vbo_indices != 0, "indices are not uploaded", loc = loc);
			
			if indices, ok := mesh.indices.([]u16); ok {
				draw_vertex_array_elements(s, cast(i32)len(indices)); //TODO don't draw with mesh.indices as input make a buffer instead, that is way faster.
			}
			else if indices, ok := mesh.indices.([]u32); ok {
				draw_vertex_array_elements(s, cast(i32)len(indices)); //TODO don't draw with mesh.indices as input make a buffer instead, that is way faster.
			}
			else {
				panic("Unimplemented");
			}

			disable_vertex_buffer_element(s, identifiers.vbo_indices);
		}
		else {
			assert(identifiers.vbo_indices == 0, "There is a vbo_indices, but it is not uploaded", loc = loc);
			draw_vertex_array(s, 0, mesh.vertex_count);
		}

		disable_vertex_array(s, identifiers.vao_id);
	}
	else {
		panic("You cannot draw the mesh using draw_mesh_single, use draw_mesh_shared instead", loc = loc);
	}
}

calculate_tangents :: proc (using s : ^Render_state($U,$A), mesh : ^Mesh(A)) {
	//TODO
	panic("TODO");
}

@(private)
cond_free :: proc(using s : ^Render_state($U,$A), to_free : rawptr, loc := #caller_location) {
	if to_free != nil {
		free(to_free, loc = loc);
	}
}	

@(private)
cond_delete :: proc(using s : ^Render_state($U,$A), to_delete : $T, loc := #caller_location) {
	if to_delete != nil {
		delete(to_delete, loc = loc);
	}
}	

//This will not upload it
generate_quad :: proc(using s : ^Render_state($U,$A), size : [3]f32, position : [3]f32, use_index_buffer : bool, loc := #caller_location) -> Mesh(A) {

	quad : Mesh(A);

	if use_index_buffer {
		vertices : [4][3]f32;
		texcoords : [4][2]f32;
		normals : [4][3]f32;

		vertices[0] = {0,0,0} * size + position;
		vertices[1] = {1,0,0} * size + position;
		vertices[2] = {0,1,0} * size + position;
		vertices[3] = {1,1,0} * size + position;
		set_mesh_attribute(s, &quad, A.position, vertices[:]);

		texcoords[0] = {0,0};
		texcoords[1] = {1,0};
		texcoords[2] = {0,1};
		texcoords[3] = {1,1};
		set_mesh_attribute(s, &quad, A.texcoord, texcoords[:]);

		normals[0] = {0,0,1};
		normals[1] = {0,0,1};
		normals[2] = {0,0,1};
		normals[3] = {0,0,1};
		set_mesh_attribute(s, &quad, A.normal, normals[:]);

		indices := [6]u16{0,1,2,2,1,3};
		set_mesh_indices(s, &quad, indices[:]);
	}
	else {
		vertices : [6][3]f32;
		texcoords : [6][2]f32;
		normals : [6][3]f32;
		
		vertices[0] = {0,0,0} * size + position;
		vertices[1] = {1,0,0} * size + position;
		vertices[2] = {0,1,0} * size + position;
		vertices[3] = {1,0,0} * size + position;
		vertices[4] = {0,1,0} * size + position;
		vertices[5] = {1,1,0} * size + position;
		set_mesh_attribute(s, &quad, A.position, vertices[:]);

		texcoords[0] = {0,0};
		texcoords[1] = {1,0};
		texcoords[2] = {0,1};
		texcoords[3] = {1,0};
		texcoords[4] = {0,1};
		texcoords[5] = {1,1};
		set_mesh_attribute(s, &quad, A.texcoord, texcoords[:]);

		normals[0] = {0,0,1};
		normals[1] = {0,0,1};
		normals[2] = {0,0,1};
		normals[3] = {0,0,1};
		normals[4] = {0,0,1};
		normals[5] = {0,0,1};
		set_mesh_attribute(s, &quad, A.normal, normals[:]);
	}

	return quad;
}

generate_circle :: proc(using s : ^Render_state($U,$A), diameter : f32, positon : [2]f32, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (circle : Mesh(A)) {

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
generate_cube :: proc(using s : ^Render_state($U,$A), size : [3]f32, position : [3]f32, use_index_buffer : bool, loc := #caller_location) -> (cube : Mesh(A)) {

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
generate_cylinder :: proc(using s : ^Render_state($U,$A), offset : [3]f32, transform : matrix[4, 4]f32, stacks : int, sectors : int, use_index_buffer : bool, loc := #caller_location) -> (cylinder : Mesh(A)) {

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
generate_sphere :: proc(using s : ^Render_state($U,$A), offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 10, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (sphere : Mesh(A)) {

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

