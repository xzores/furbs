package render;

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"
import "core:time"

//TODO delete draw char
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
			state.shape_cube = [2]int{i, i + len_indices(cubei)}; i += len_indices(cubei);

			cirv, ciri := generate_circle(1, {0,0,0}, 20, use_index_buffer);
			state.shape_circle = [2]int{i, i + len_indices(ciri)}; i += len_indices(ciri);

			qv, qi := generate_quad({1,1,1}, {0,0,0}, use_index_buffer);
			state.shape_quad = [2]int{i, i + len_indices(qi)}; i += len_indices(qi);

			cyv, cyi := generate_cylinder({0,0,0}, 1, 1, 20, 20, use_index_buffer);
			state.shape_cylinder = [2]int{i, i + len_indices(cyi)}; i += len_indices(cyi);

			sv, si := generate_sphere({0,0,0}, 1, 20, 20, use_index_buffer);
			state.shape_sphere = [2]int{i, i + len_indices(si)}; i += len_indices(si);

			conv, coni := generate_cone({0,0,0}, 1, 1, 20, use_index_buffer);
			state.shape_cone = [2]int{i, i + len_indices(coni)}; i += len_indices(coni);

			arrv, arri := generate_arrow({1,0,0}, 0.65, 0.35, 0.15, 0.35, 20, use_index_buffer);
			state.shape_arrow = [2]int{i, i + len_indices(arri)}; i += len_indices(arri);

			defer {
				delete(cubev); delete_indices(cubei);
				delete(cirv); delete_indices(ciri);
				delete(qv); delete_indices(qi);
				delete(cyv); delete_indices(cyi);
				delete(sv); delete_indices(si);
				delete(conv); delete_indices(coni);
				delete(arrv); delete_indices(arri);
			};

			D :: Mesh_combine_data(Default_vertex);
			vertex_data, index_data = combine_mesh_data_multi(Default_vertex, D{1, cubev, cubei}, D{1, cirv, ciri}, D{1, qv, qi},
				D{1, cyv, cyi}, D{1, sv, si}, D{1, conv, coni}, D{1, arrv, arri});
			assert(vertex_data != nil);
			//fmt.printf("len_indices(index_data) : %v\n", len_indices(index_data));
			assert(len(vertex_data) <= auto_cast max(u16));
			assert(len_indices(index_data) <= auto_cast max(u16));
		}

		state.shapes = make_mesh_single(vertex_data, index_data, .static_use);
		delete(vertex_data);
		delete_indices(index_data);
	}
}

@(private)
destroy_shapes :: proc() {
	destroy_mesh(&state.shapes); state.shapes = {};
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

draw_quad :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_quad);
}

draw_char :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_char);
}

draw_circle :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_circle);
}

draw_cube :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_cube);
}

draw_cylinder :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_cylinder);
}

draw_sphere :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_sphere);
}

draw_cone :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_cone);
}

draw_arrow :: proc(position : [3]f32, direction : [3]f32, color : [4]f32 = {1,1,1,1}, up : [3]f32 = {0,1,0}, loc := #caller_location) {
	_ensure_shapes_loaded();
	
	using linalg;

	arb := up;
	if math.abs(linalg.dot(arb, direction)) >= 0.9999 {
		arb = [3]f32{1,0,0}; //is there something better? likely...
	}
	
	mat := look_at(position, position + direction, arb);

	draw_mesh_single(&state.shapes, mat, color, state.shape_arrow);
}

