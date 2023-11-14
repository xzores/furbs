package render;

import "core:slice"
import "core:fmt"
import "core:mem"
import "core:math"
import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

Mesh_data :: struct {
	
	vertex_count : i32, 					//The amount of verticies
	
	//something

	indices	: union {
		[]u16,
		[]u32,
	},           							// optional

}

Mesh_identifiers :: struct {
	// OpenGL identifiers
	vao_id		: Vao_id,                									// OpenGL Vertex Array Object id
	vbo_ids		: ???,
	vbo_indices : Vbo_id,													//special for indicies 
}

Mesh_buffer_index :: struct {
	start : int,
	length : int,
	used : int,
}

Reserve_behavior :: enum {
	skinny, 	//Don't reserve more then needed, always shink.
	moderate, 	//Reserve 2x the needed at resize and shrink down when going below 50% use. (including padding)
	thick,		//Reserve 2x needed and don't shrink.
}

//Don't touch use init_mesh_buffer
Mesh_buffer :: struct {
	free_space : [dynamic][2]int,
	total_mem : int,
	padding : int, // allowes the meshs to slightly resize without a new allocation.
	reserve_behavior : Reserve_behavior,
	use_indicies : bool,
	active_locations : map[Attribute_client_index]struct{}, // index with Attribute_client_index to find the correct. Attribute_location
	
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
