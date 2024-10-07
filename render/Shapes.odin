package render;

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:time"

draw_quad_mat :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded(loc);
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_quad, loc);
}

draw_quad_rect:: proc(rect : [4]f32, z : f32 = 0, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	mat : matrix[4,4]f32 = linalg.matrix4_from_trs_f32({rect.x, rect.y, z} + {rect.z/2, rect.w/2, 0}, 1, {rect.z, rect.w, 1});
	draw_quad_mat(mat, color, loc);
}

draw_quad :: proc {draw_quad_mat, draw_quad_rect};

//Rot is in degrees
//Single use draw quads, reasonably fast, but custom solutions can be much faster.
draw_quad_instanced :: proc (instances : []Default_instance_data, color : [4]f32 = {1,1,1,1}, offset : [3]f32 = {}, use_index_buffer := true, loc := #caller_location) {
	
	qv, qi := generate_quad({1,1,1}, offset, use_index_buffer);
	defer { delete(qv); indices_delete(qi); }
	instance_desc := Instance_data_desc{Default_instance_data, len(instances), .dynamic_upload};
	
	quad_instaces : Mesh_single = mesh_make_single(qv, qi, .static_use, .triangles, instance_desc);
	defer mesh_destroy(&quad_instaces);
	
	upload_instance_data(&quad_instaces, 0, instances);
	mesh_draw_instanced(&quad_instaces, len(instances), color, loc = loc);
}

//Draw as quad between two points presented as a line.
draw_line_2D :: proc (p1 : [2]f32, p2 : [2]f32, width : f32, z : f32 = 0, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	draw_quad_mat(line_2D_to_quad_mat(p1, p2, width, z), color);
}

//TODO
//draw_line_3D :: proc () {}

//TODO not needed, should it be deleted?
draw_char :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_char);
}

draw_circle :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_circle);
}

draw_cube :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_cube);
}

draw_cylinder :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_cylinder);
}

draw_sphere :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_sphere);
}

draw_cone :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	mesh_draw_single(&state.shapes, model_matrix, color, state.shape_cone);
}

draw_arrow :: proc(position : [3]f32, direction : [3]f32, color : [4]f32 = {1,1,1,1}, up : [3]f32 = {0,1,0}, loc := #caller_location) {
	_ensure_shapes_loaded();
	
	using linalg;

	arb := up;
	if math.abs(linalg.dot(arb, direction)) >= 0.9999 {
		arb = [3]f32{1,0,0}; //is there something better? likely...
	}
	
	mat := look_at(position, position + direction, arb);

	mesh_draw_single(&state.shapes, mat, color, state.shape_arrow);
}


////////////////////////////////////////// PRIVATE //////////////////////////////////////////

@(private)
_ensure_shapes_loaded :: proc (loc := #caller_location) {
	
	if !state.shapes_init {
		state.shapes_init = true;
		
		use_index_buffer := true; //We can change later if we want. but don't.
		
		vertex_data : []Default_vertex;
		index_data : Indices;
		
		i : int = 0;
		
		{
			cubev, cubei := generate_cube({1,1,1}, {0,0,0}, use_index_buffer);
			state.shape_cube = [2]int{i, i + indices_len(cubei)}; i += indices_len(cubei);
			
			cirv, ciri := generate_circle(1, {0,0,0}, 10, use_index_buffer);
			state.shape_circle = [2]int{i, i + indices_len(ciri)}; i += indices_len(ciri);
			
			qv, qi := generate_quad({1,1,1}, {0,0,0}, use_index_buffer);
			state.shape_quad = [2]int{i, i + indices_len(qi)}; i += indices_len(qi);
			
			cyv, cyi := generate_cylinder({0,0,0}, 1, 1, 10, 10, use_index_buffer);
			state.shape_cylinder = [2]int{i, i + indices_len(cyi)}; i += indices_len(cyi);
			
			sv, si := generate_sphere({0,0,0}, 1, 10, 10, use_index_buffer);
			state.shape_sphere = [2]int{i, i + indices_len(si)}; i += indices_len(si);
			
			conv, coni := generate_cone({0,0,0}, 1, 1, 10, use_index_buffer);
			state.shape_cone = [2]int{i, i + indices_len(coni)}; i += indices_len(coni);
			
			arrv, arri := generate_arrow({1,0,0}, 0.65, 0.35, 0.15, 0.35, 10, use_index_buffer);
			state.shape_arrow = [2]int{i, i + indices_len(arri)}; i += indices_len(arri);
			
			defer {
				delete(cubev); indices_delete(cubei);
				delete(cirv); indices_delete(ciri);
				delete(qv); indices_delete(qi);
				delete(cyv); indices_delete(cyi);
				delete(sv); indices_delete(si);
				delete(conv); indices_delete(coni);
				delete(arrv); indices_delete(arri);
			};
			
			D :: Mesh_combine_data(Default_vertex);
			vertex_data, index_data = combine_mesh_data_multi(Default_vertex, []D{
				D{1, cubev, cubei}, 
				D{1, cirv, ciri}, 
				D{1, qv, qi},
				D{1, cyv, cyi}, 
				D{1, sv, si},
				D{1, conv, coni},
				D{1, arrv, arri}
			});
			
			assert(vertex_data != nil);
			//fmt.printf("indices_len(index_data) : %v\n", indices_len(index_data));
			assert(len(vertex_data) <= auto_cast max(u16));
			assert(indices_len(index_data) <= auto_cast max(u16));
		}

		state.shapes = mesh_make_single(vertex_data, index_data, .static_use);
		delete(vertex_data);
		indices_delete(index_data);
	}
}

@(private)
shapes_destroy :: proc() {
	if state.shapes_init {
		mesh_destroy(&state.shapes); state.shapes = {};
		state.shapes_init = false;
		state.shape_cube 		= {};
		state.shape_circle 		= {};
		state.shape_quad 		= {};
		state.shape_char		= {};
		state.shape_cylinder	= {};
		state.shape_sphere		= {};
		state.shape_cone		= {};
		state.shape_arrow		= {};
	}
}
