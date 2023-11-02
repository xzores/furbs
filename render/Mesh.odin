package render;

import "core:slice"
import "core:fmt"
import "core:mem"
import "core:math"
import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

Mesh_data :: struct {
	
	vertex_count : i32, 					//The amount of verticies
	
	//User vertex data here

	// Default vertex data
	vertices		: [][3]f32,           	// Mandatory, vertex positions (shader-location = 0)
	texcoords		: [][2]f32,           	// optional (shader-location = 1)
	normals			: [][3]f32,           	// optional (shader-location = 2)
	//texcoords2		: [][2]f32,         // optional (shader-location = 5)
	tangents		: [][3]f32,         	// optional (shader-location = 4)

	indices			: union {
		[]u16,
		[]u32,
	},           							// optional

	/*
	// Animation vertex data
	animVertices: [^]f32,         // Animated vertex positions (after bones transformations)
	animNormals:  [^]f32,         // Animated normals (after bones transformations)
	boneIds:      [^]u8,          // Vertex bone ids, up to 4 bones influence by vertex (skinning)
	boneWeights:  [^]f32,         // Vertex bone weight, up to 4 bones influence by vertex (skinning)
	*/
}

Mesh_identifiers :: struct {
	// OpenGL identifiers
	vao_id		: Vao_ID,                // OpenGL Vertex Array Object id
	vbo_id		: [Attribute_location]Vbo_ID,              // OpenGL Vertex Buffer Objects id (default vertex data)
	vbo_indices : Vbo_ID,				//special for indicies 
}

Mesh_buffer_index :: struct {
	start : int,
	length : int,
	used : int,
}

Reserve_behavior :: enum {
	skinny, 	//Don't reserve more then needed
	moderate, 	//Reserve 1.5x the needed at resize and shrink down when going below 50% use. (including padding)
	thick,		//Reserve 2x needed and don't shrink.
}

//Don't touch use setup_mesh_buffer
Mesh_buffer :: struct {
	free_space : [dynamic][2]int,
	total_mem : int,
	padding : int, // if the meshs can resize slightly.
	reserve_behavior : Reserve_behavior,
	use_indicies : bool,
	active_locations : bit_set[Attribute_location],
	
	using data : Mesh_data,
	using identifiers : Mesh_identifiers, //THe GPU buffers
}

Mesh :: struct {
	using _ : Mesh_data,

	implementation : union {
		Mesh_identifiers,	//It is a standalone mesh, drawing happens with draw_mesh_single.
		Mesh_buffer_index,	//It is a mesh sharing a buffers with similar meshes, draw with draw_mesh.
	},

	//If set it will be used for frustum (and maybe occlusion culling).
	bounding_distance : Maybe(f32),
}

/*
    // Render generated texture using selected postprocessing shader
    BeginShaderMode(shaders[currentShader]);
        // NOTE: Render texture must be y-flipped due to default OpenGL coordinates (left-bottom)
        DrawTextureRec(target.texture, (Rectangle){ 0, 0, (float)target.texture.width, (float)-target.texture.height }, (Vector2){ 0, 0 }, WHITE);
    EndShaderMode();

	async_upload :: proc (mesh : ^rl.Mesh) {
	using gl;
	
	BindBuffer(ARRAY_BUFFER, mesh.vbo_id);
	BufferData(ARRAY_BUFFER, size, nil, GL_STATIC_DRAW);
	MapBufferRange(ARRAY_BUFFER, 0, 10, MAP_WRITE_BIT);
	glUnmapBuffer(ARRAY_BUFFER);
}
*/

//"initial_mem" and "padding" is in verticies.
init_mesh_buffer :: proc(mesh_buffer : ^Mesh_buffer, initial_mem : u64, padding : u64, active_locations : bit_set[Attribute_location], use_indicies : bool, reserve_behavior : Reserve_behavior = .moderate, loc := #caller_location) {
	
	assert(mesh_buffer.free_space == nil, "This is already setup", loc = loc);
	assert(initial_mem != 0, "initial_mem must not be 0", loc = loc);

	mesh_buffer.free_space = make([dynamic][2]int, 1);
	
	mesh_buffer.free_space[0][0] = 0;
	mesh_buffer.free_space[0][1] = int(initial_mem) - 1;

	mesh_buffer.padding = auto_cast padding;
	mesh_buffer.reserve_behavior = reserve_behavior;

	mesh_buffer.active_locations = active_locations;

	mul := 1;
	dyn : bool;
	if reserve_behavior == .skinny {
		mul = 1;
		dyn = false;
	}
	else if reserve_behavior == .moderate {
		mul = 2;
		dyn = false;
	}
	else if reserve_behavior == .thick {
		mul = 2;
		dyn = true;
	}

	mesh_buffer.total_mem = auto_cast initial_mem * mul;

	{	
		using mesh_buffer;

		identifiers.vao_id = 0;        // Vertex Array Object

		for &vbo in  identifiers.vbo_id {
			vbo = 0;     // Vertex buffer set to 0
		}
		
		identifiers.vao_id = load_vertex_array(); //glGenVertexArrays(1, &vao_id);
		
		//TODO walk though this instead with interspection.
		if .position in active_locations {
			identifiers.vbo_id[.position] = load_vertex_buffer(nil, total_mem * 3 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.position], 3, .float, .position, loc = loc);
		}

		if .texcoord in active_locations {
			identifiers.vbo_id[.texcoord] = load_vertex_buffer(nil, total_mem * 2 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.texcoord], 2, .float, .texcoord, loc = loc);
		}

		if .normal in active_locations {
			identifiers.vbo_id[.normal] = load_vertex_buffer(nil, total_mem * 3 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.normal], 3, .float, .normal, loc = loc);
		}
		
		if .tangent in active_locations {
			identifiers.vbo_id[.tangent] = load_vertex_buffer(nil, total_mem * 4 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.tangent], 4, .float, .tangent, loc = loc);
		}

		if use_indicies {
			panic("Unimplemented");
		}

		mesh_buffer.identifiers = identifiers;
	}
}

// Creates pointers to begin async upload  
upload_mesh_single :: proc (mesh : ^Mesh, dyn : bool = false, loc := #caller_location) {
	
	upload_mesh_data :: proc(mesh : ^Mesh_data, dyn : bool, loc := #caller_location) -> (identifiers : Mesh_identifiers) {
		
		identifiers.vao_id = 0;        // Vertex Array Object

		for &vbo in  identifiers.vbo_id {
			vbo = 0;     // Vertex buffer set to 0
		}
		
		identifiers.vao_id = load_vertex_array(); //glGenVertexArrays(1, &vao_id);
		//enable_vertex_array(identifiers.vao_id);
		
		assert(len(mesh.vertices) == len(mesh.texcoords) || mesh.texcoords == nil, "vertices and texcoords lengths does not match", loc = loc);
		assert(len(mesh.vertices) == len(mesh.normals) || mesh.normals == nil, "vertices and normals lengths does not match", loc = loc);
		assert(len(mesh.vertices) == len(mesh.tangents) || mesh.tangents == nil, "vertices and tangents lengths does not match", loc = loc);
		
		// Enable vertex attributes: position (shader-location = 0)
		//TODO vertices : rawptr = mesh.animVertices != nil ? mesh.animVertices : mesh.vertices;
		
		if (mesh.vertices != nil) {
			identifiers.vbo_id[.position] = load_vertex_buffer(nil, int(int(mesh.vertex_count)) * 3 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.position], 3, .float, .position, loc = loc);
			upload_vertex_sub_buffer_data(identifiers.vbo_id[.position], 0, int(int(mesh.vertex_count)) * 3 * size_of(f32), raw_data(mesh.vertices));
		}

		if (mesh.texcoords != nil) {
			// Enable vertex attributes: texcoords (shader-location = 1)
			identifiers.vbo_id[.texcoord] = load_vertex_buffer(raw_data(mesh.texcoords), int(mesh.vertex_count) * 2 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.texcoord], 2, .float, .texcoord, loc = loc);
		}

		if (mesh.normals != nil) {
			// Enable vertex attributes: normals (shader-location = 2)
			//TODO normals : [][3]f32 = mesh.animNormals != nil ? mesh.animNormals : mesh.normals;
			identifiers.vbo_id[.normal] = load_vertex_buffer(raw_data(mesh.normals), int(mesh.vertex_count) * 3 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.normal], 3, .float, .normal, loc = loc);
		}
		
		if (mesh.tangents != nil) {
			// Enable vertex attribute: tangent (shader-location = 4)
			identifiers.vbo_id[.tangent] = load_vertex_buffer(raw_data(mesh.tangents), int(mesh.vertex_count) * 4 * size_of(f32), dyn);
			setup_vertex_attribute(identifiers.vao_id, identifiers.vbo_id[.tangent], 4, .float, .tangent, loc = loc);
		}
		
		if (mesh.indices != nil) {
			if indices, ok := mesh.indices.([]u16); ok {
				identifiers.vbo_indices = load_vertex_buffer(raw_data(indices), len(indices) * size_of(u16), dyn);
				//TODO is something needed here?
			}
			else if indices, ok := mesh.indices.([]u32); ok {
				identifiers.vbo_indices = load_vertex_buffer(raw_data(indices), len(indices) * size_of(u32), dyn);
				//TODO is something needed here?
			}
			else {
				panic("Unimplemented");
			}
		}
		
		return;
	}

	if mesh.implementation == nil {
		mesh.implementation = upload_mesh_data(mesh, dyn, loc);
	}
	else {
		panic("You have already uploaded this mesh", loc = loc);
	}
}

upload_mesh_shared :: proc (mesh : ^Mesh, mesh_buffer : ^Mesh_buffer, ignore_discrepancies : bool = false, loc := #caller_location) {
	
	//assert(mesh_buffer^ == Mesh_buffer{}, "mesh_buffer is not setup", loc = loc);
	
	if !ignore_discrepancies {
		if .position in mesh_buffer.active_locations {
			assert(mesh.vertices != nil, "The mesh_buffer has .position as an active attribute but the mesh does not.", loc = loc);
		}
		if .texcoord in mesh_buffer.active_locations {
			assert(mesh.texcoords != nil, "The mesh_buffer has texcoords as an active attribute but the mesh does not.", loc = loc);
		}
		if .normal in mesh_buffer.active_locations {
			assert(mesh.normals != nil, "The mesh_buffer has normals as an active attribute but the mesh does not.", loc = loc);
		}
		if .tangent in mesh_buffer.active_locations {
			assert(mesh.tangents != nil, "The mesh_buffer has tangents as an active attribute but the mesh does not.", loc = loc);
		}

		if mesh.vertices == nil {
			assert(!(.position in mesh_buffer.active_locations), "The mesh has vertices active but the mesh_buffer does not.", loc = loc);
		}
		if mesh.texcoords == nil {
			assert(!(.texcoord in mesh_buffer.active_locations), "The mesh has vertices active but the mesh_buffer does not.", loc = loc);
		}
		if mesh.normals == nil {
			assert(!(.normal in mesh_buffer.active_locations), "The mesh has vertices active but the mesh_buffer does not.", loc = loc);
		}
		if mesh.tangents == nil {
			assert(!(.tangent in mesh_buffer.active_locations), "The mesh has vertices active but the mesh_buffer does not.", loc = loc);
		}
	}

	if mesh.implementation == nil {
		
		buffer_index : Mesh_buffer_index;

		//TODO check if there is space.

		buffer_index.start = mesh_buffer.free_space[0][0];
		buffer_index.length = auto_cast mesh.vertex_count + mesh_buffer.padding;
		buffer_index.used = auto_cast mesh.vertex_count;
		
		mesh_buffer.free_space[0][0] += buffer_index.length;
		
		mesh.implementation = buffer_index;

		assert(buffer_index.length != 0, "Length is 0", loc = loc);
		assert(buffer_index.used != 0, "Length is 0", loc = loc);
		
		//TODO walk though this instead with interspection.
		if .position in mesh_buffer.active_locations {
			upload_vertex_sub_buffer_data(mesh_buffer.vbo_id[.position], 	buffer_index.start * 3 * size_of(f32), buffer_index.length * 3 * size_of(f32), raw_data(mesh.vertices));
		}
		if .texcoord in mesh_buffer.active_locations {
			upload_vertex_sub_buffer_data(mesh_buffer.vbo_id[.texcoord],  	buffer_index.start * 2 * size_of(f32), buffer_index.length * 2 * size_of(f32), raw_data(mesh.texcoords));
		}
		if .normal in mesh_buffer.active_locations {
			upload_vertex_sub_buffer_data(mesh_buffer.vbo_id[.normal],  	buffer_index.start * 3 * size_of(f32), buffer_index.length * 3 * size_of(f32), raw_data(mesh.normals));
		}
		if .tangent in mesh_buffer.active_locations {
			upload_vertex_sub_buffer_data(mesh_buffer.vbo_id[.tangent],		buffer_index.start * 4 * size_of(f32), buffer_index.length * 4 * size_of(f32), raw_data(mesh.tangents));
		}

		if mesh_buffer.use_indicies {
			panic("Unimplemented");
		}
	}
	else {
		panic("You have already uploaded this mesh", loc = loc);
	}
}

// Unload mesh from memory (RAM and VRAM)
unload_mesh_single :: proc(mesh : ^Mesh, loc := #caller_location) {

	assert(mesh.implementation != nil, "The mesh is not uploaded", loc = loc);

	if identifiers, ok := &mesh.implementation.(Mesh_identifiers); ok {
		
		unload_vertex_array(identifiers.vao_id);
		identifiers.vao_id = 0;

		for i in Attribute_location {
			if identifiers.vbo_id[i] != 0 {
				unload_vertex_buffer(identifiers.vbo_id[i], loc = loc);
				identifiers.vbo_id[i] = -1;
			}
		}
		
		cond_delete(mesh.vertices, loc);
		cond_delete(mesh.texcoords, loc);
		cond_delete(mesh.normals, loc);
		cond_delete(mesh.tangents, loc);
		
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

		mesh.vertices = nil;
		mesh.texcoords = nil;
		mesh.normals = nil;
		mesh.tangents = nil;
		mesh.indices = nil;

		/*
		cond_free(mesh.animVertices, loc);
		cond_free(mesh.animNormals, loc);
		cond_free(mesh.boneWeights, loc);
		cond_free(mesh.boneIds, loc);
		mesh.animVertices = nil;
		mesh.animNormals = nil;
		mesh.boneWeights = nil;
		mesh.boneIds = nil;
		*/
		
		mesh.vertex_count = 0;
	}
	else {
		panic("You cannot upload the mesh using unload_mesh_single, use unload_mesh_shared instead", loc = loc);
	}
}

/*
unload_mesh_shared :: proc(mesh : ^Mesh, mesh_buffer : ^Mesh_buffer, loc := #caller_location) {

	if identifiers, ok := &mesh.implementation.(Mesh_identifiers); ok {
		
		for i in Attribute_location {
			unload_vertex_buffer(identifiers.vbo_id[i]);
			identifiers.vbo_id[i] = -1;
		}
		
		cond_delete(mesh.vertices, loc);
		cond_delete(mesh.texcoords, loc);
		cond_delete(mesh.normals, loc);
		cond_delete(mesh.tangents, loc);
		
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

		mesh.vertices = nil;
		mesh.texcoords = nil;
		mesh.normals = nil;
		mesh.tangents = nil;
		mesh.indices = nil;
		
		mesh.vertex_count = 0;
	}
	else {
		panic("You cannot upload the mesh using unload_mesh_single, use unload_mesh_shared instead", loc = loc);
	}
}
*/

draw_mesh_single :: proc (shader : Shader, mesh : Mesh, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, loc := #caller_location) {
	
	assert(shader.id == bound_shader_program, "The shader must be bound before drawing with it", loc = loc);
	assert(bound_camera != nil, "A camera must be bound before a mesh can be drawn", loc = loc);
	assert(mesh.vertex_count == auto_cast len(mesh.vertices) || mesh.vertices == nil, "The vertices and vertex_count does not have the same size", loc = loc);
	assert(mesh.implementation != nil, "The mesh is not uploaded", loc = loc);
	
	mvp : matrix[4,4]f32 = prj_mat * view_mat * transform;
	
	place_uniform(shader, .model_mat, transform);
	place_uniform(shader, .mvp, mvp);
	
	if identifiers, ok := mesh.implementation.(Mesh_identifiers); ok {
		enable_vertex_array(identifiers.vao_id);
		
		// Draw mesh
		if (mesh.indices != nil) {
			//TODO bind mesh.indices buffer
			//TODO enable_vertex_buffer_element	

			enable_vertex_buffer_element(identifiers.vbo_indices);

			assert(identifiers.vbo_indices != 0, "indices are not uploaded", loc = loc);
			
			if indices, ok := mesh.indices.([]u16); ok {
				draw_vertex_array_elements(cast(i32)len(indices)); //TODO don't draw with mesh.indices as input make a buffer instead, that is way faster.
			}
			else if indices, ok := mesh.indices.([]u32); ok {
				draw_vertex_array_elements(cast(i32)len(indices)); //TODO don't draw with mesh.indices as input make a buffer instead, that is way faster.
			}
			else {
				panic("Unimplemented");
			}

			disable_vertex_buffer_element(identifiers.vbo_indices);
		}
		else {
			assert(identifiers.vbo_indices == 0, "There is a vbo_indices, but it is not uploaded", loc = loc);
			draw_vertex_array(0, mesh.vertex_count);
		}

		disable_vertex_array(identifiers.vao_id);
	}
	else {
		panic("You cannot draw the mesh using draw_mesh_single, use draw_mesh_shared instead", loc = loc);
	}
}

//This allows you to draw a single mesh even if it part of a mesh_buffer.
//If you need to swap textures or similar, you can use this instead of draw_mesh_shared. This is worse in preformance, so you should try and use texture arrays if possiable.
draw_mesh_single_shared :: proc(shader : Shader, mesh : Mesh, mesh_buffer : Mesh_buffer, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, loc := #caller_location) {
	
	assert(shader.id == bound_shader_program, "The shader must be bound before drawing with it", loc = loc);
	assert(mesh.vertex_count == auto_cast len(mesh.vertices) || mesh.vertices == nil, "The vertices and vertex_count does not have the same size", loc = loc);
	assert(bound_camera != nil, "A camera must be bound before a mesh can be drawn", loc = loc);
	assert(mesh.implementation != nil, "The mesh is not uploaded", loc = loc);

	mvp : matrix[4,4]f32 = prj_mat * view_mat * transform;

	place_uniform(shader, .model_mat, transform);
	place_uniform(shader, .mvp, mvp);
	
	if buffer_index, ok := mesh.implementation.(Mesh_buffer_index); ok {
		
		enable_vertex_array(mesh_buffer.vao_id);
		
		// Draw mesh
		if (mesh.indices != nil) {
			panic("Unimplemented");
		}
		else {
			fmt.assertf(mesh.vertex_count == auto_cast buffer_index.used, "The mesh vertex_count is setup incorrectly, mesh.vertex_count : %v, buffer_index.used : %v", mesh.vertex_count, buffer_index.used, loc = loc);
			draw_vertex_array(auto_cast buffer_index.start, mesh.vertex_count);
		}

		disable_vertex_array(mesh_buffer.vao_id);
	}
	else {
		fmt.panicf("The mesh is not setup correctly for draw_mesh_single_shared. mesh.implementation : %v", mesh.implementation, loc = loc);
	}

}

/* 
draw_mesh_single_instanced :: proc(shader : Shader, mesh : Mesh, ) {
	
	//We want to use a VAO, not uniforms.
	//Uniforms can be kinda ok if SSBO is advaliable as far as I understand, but these are only advaliable since opengl 4.3, so it would exclude a lot of hardware.
	//instead we could use opengl 3.3 and use AttribDivisor to make a per instance VBO. We can make this the bad way where we upload the VBO data every frame.
	//then make some better implementation that allows for better preformance. 
	//Or even better make a call that return a pointer to the data we need and make draw_mesh_single_instanced take in that instance,
	//this could be presistantly mapped (Opengl 4.4) and have the reason fallback to async upload with fallback to upload every frame. Like init_mesh_instance_draw_buffer -> [dynamic]u8 (or maybe template to fit data_type(s)).
	
}
*/

calculate_tangents :: proc (mesh : ^Mesh) {
	//TODO
}

cond_free :: proc(to_free : rawptr, loc := #caller_location) {
	if to_free != nil {
		free(to_free, loc = loc);
	}
}	

cond_delete :: proc(to_delete : $T, loc := #caller_location) {
	if to_delete != nil {
		delete(to_delete, loc = loc);
	}
}	

//This will not upload it
generate_quad :: proc(size : [3]f32 = {1,1,1}, position : [3]f32 = {0,0,0}, use_index_buffer := true, loc := #caller_location) -> Mesh {

	assert(bound_array_buffer == 0, "Cannot generate quad while a array buffer is bound", loc = loc);

	quad : Mesh 
	
	if use_index_buffer {
		quad.vertex_count = 4;
		quad.vertices = make([][3]f32, 4);
		quad.texcoords = make([][2]f32, 4);
		quad.normals = make([][3]f32, 4);

		quad.indices = make([]u16, 6);

		quad.vertices[0] = {0,0,0} * size + position;
		quad.vertices[1] = {1,0,0} * size + position;
		quad.vertices[2] = {0,1,0} * size + position;
		quad.vertices[3] = {1,1,0} * size + position;

		quad.texcoords[0] = {0,0};
		quad.texcoords[1] = {1,0};
		quad.texcoords[2] = {0,1};
		quad.texcoords[3] = {1,1};

		indices := []u16{ 0,1,2,2,1,3, };
		quad.indices = slice.clone(indices);

		quad.normals[0] = {0,0,1};
		quad.normals[1] = {0,0,1};
		quad.normals[2] = {0,0,1};
		quad.normals[3] = {0,0,1};
	}
	else {
		quad.vertex_count = 6;
		quad.vertices = make([][3]f32, 6);
		quad.texcoords = make([][2]f32, 6);
		quad.normals = make([][3]f32, 6);
		
		quad.vertices[0] = {0,0,0} * size + position;
		quad.vertices[1] = {1,0,0} * size + position;
		quad.vertices[2] = {0,1,0} * size + position;
		quad.vertices[3] = {1,0,0} * size + position;
		quad.vertices[4] = {0,1,0} * size + position;
		quad.vertices[5] = {1,1,0} * size + position;

		quad.texcoords[0] = {0,0};
		quad.texcoords[1] = {1,0};
		quad.texcoords[2] = {0,1};
		quad.texcoords[3] = {1,0};
		quad.texcoords[4] = {0,1};
		quad.texcoords[5] = {1,1};

		quad.normals[0] = {0,0,1};
		quad.normals[1] = {0,0,1};
		quad.normals[2] = {0,0,1};
		quad.normals[3] = {0,0,1};
		quad.normals[4] = {0,0,1};
		quad.normals[5] = {0,0,1};
	}
	
	calculate_tangents(&quad);

	return quad;
}

generate_circle :: proc(diameter : f32 = 1, positon : [2]f32 = {0,0}, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (circle : Mesh) {
	
	assert(bound_array_buffer == 0, "Cannot generate circle while a array buffer is bound", loc = loc);
	
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
generate_cube :: proc(size : [3]f32 = {1,1,1}, position : [3]f32 = {0,0,0}, use_index_buffer := true, loc := #caller_location) -> (cube : Mesh) {

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

	assert(bound_array_buffer == 0, "Cannot generate quad while a array buffer is bound", loc = loc);

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
generate_cylinder :: proc(offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 1, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (cylinder : Mesh) {

	assert(bound_array_buffer == 0, "Cannot generate cylinder while a array buffer is bound", loc = loc);
	
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

	assert(bound_array_buffer == 0, "Cannot generate sphere while a array buffer is bound", loc = loc);
	
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

