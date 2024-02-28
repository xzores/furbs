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







