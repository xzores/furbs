package render;

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"

@(private)
_generate_char :: proc () -> (verts : []Default_vertex, indices : Indices) {
	
	char_verts : [4]Default_vertex = {
        Default_vertex{
                position = {
                        -0.5,
                        -0.5,
                        0,
				},
                texcoord = {0,0},
                normal = 0,
        },
        Default_vertex{
                position = {
                        0.5,
                        -0.5,
                        0,
				},
                texcoord = {1,0},
                normal = 0,
        },
        Default_vertex{
                position = {
                        -0.5,
                        0.5,
                        0,
				},
                texcoord = {0,1},
                normal = 0,
        },
        Default_vertex{
                position = {
                        0.5,
                        0.5,
                        0,
				},
                texcoord = {1,1},
                normal = 0,
        },
	};

	char_index : [6]u16 = {
		0,
		1,
		2,
		2,
		1,
		3,
	}

	verts 		= make([]Default_vertex, len(char_verts));
	indices		= make([]u16, len(char_index));

	for v, ii in char_verts {
		verts[ii] = v;
	}

	for i, ii in char_index {
		indices.([]u16)[ii] = i;
	}

	return;
}


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

			arrv, arri := generate_arrow({1,0,0}, 0.6, 0.4, 0.25, 0.5, 20, use_index_buffer);
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

draw_arrow :: proc(model_matrix : matrix[4,4]f32, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	_ensure_shapes_loaded();
	draw_mesh_single(&state.shapes, model_matrix, color, state.shape_arrow);
}

//TODO move to state
arrow_forward 	: Mesh_single;
arrow_up 		: Mesh_single;
arrow_right 	: Mesh_single;
arrow_init 		: bool;

shapes_pipeline 	: Pipeline;
overlay_pipeline 	: Pipeline;
arrow_fbo			: Frame_buffer;

//TODO move to gui
get_coordinate_overlay_texture :: proc(camera : Camera3D, texture_size : [2]i32 = {256,256}, loc := #caller_location) -> Texture2D {

	camera := camera;
	camera.fovy = 61;
	camera.projection = .perspective;
	
	if arrow_init == false {
		arrow_forward 	= make_mesh_arrow({0,0,1}, 0.35, 0.15, 0.05, 0.15, 20, true);
		arrow_up 		= make_mesh_arrow({0,1,0}, 0.35, 0.15, 0.05, 0.15, 20, true);
		arrow_right 	= make_mesh_arrow({1,0,0}, 0.35, 0.15, 0.05, 0.15, 20, true);
		shapes_pipeline = make_pipeline(get_default_shader(), .no_blend, true, false, .fill, .no_cull);
		overlay_pipeline = make_pipeline(get_default_shader(), .blend, true, true, .fill, .no_cull);
		init_frame_buffer_textures(&arrow_fbo, 1, texture_size.x, texture_size.y, .RGBA8, .depth_component16, false, .linear);
		arrow_init = true;
	}
	
	f := camera_forward(camera);
	r := camera_right(camera);
	u := camera.up;
	
	overlay_camera := Camera3D {
		position		= {0,0,-1},            	// Camera position
		target			= {0,0,0},            	// Camera target it looks-at
		up				= {0,1,0},            	// Camera up vector (rotation over its axis)
		fovy			= 0,                	// Camera field-of-view apperture in Y (degrees) in perspective
		ortho_height 	= 1,					// Camera ortho_height when using orthographic projection
		projection		= .orthographic, 	// Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
		far 			= 10,
		near 			= 0.01,
	};
	

	begin_target(&arrow_fbo, [4]f32{0,0,0,0});
		begin_pipeline(shapes_pipeline, overlay_camera);
			
			//view, prj := get_camera_3D_prj_view(camera, 1);
			mat : matrix[4,4]f32 = linalg.matrix4_look_at_f32({0,0,0}, f, u); //(linalg.matrix4_translate_f32(camera.position + f));
			/*mat = matrix[4,4]f32{
					1,0,0,0,
					0,1,0,0,
					0,0,-1,overlay_camera.far,
					0,0,0,1,} * mat;
			*/
			
			set_texture(.texture_diffuse, get_white_texture());

			draw_mesh_single(&arrow_right, 		mat, [4]f32{1,0,0,1});
			draw_mesh_single(&arrow_up, 		mat, [4]f32{0,1,0,1});
			draw_mesh_single(&arrow_forward, 	mat, [4]f32{0,0,1,1});

		end_pipeline();
		
		draw_text_simple("Coordinate system", {0,10}, 20);

	end_target();

	return arrow_fbo.color_attachments[0].(Texture2D);
	//return arrow_fbo.depth_attachment.(Texture2D);
}

draw_coordinate_overlay :: proc (target : Render_target, camera : Camera3D, offset : [2]f32 = {0.75, 0.75}, scale : f32 = 0.5, loc := #caller_location) {
	
	assert(state.current_target == nil, "There must not be a target, call end_target", loc);

	tex := get_coordinate_overlay_texture(camera);

	cam : Camera2D = {
		position 		= {0,0},            	// Camera position
		target_relative = {0,0},				// 
		rotation 		= 0,				// in degrees
		zoom 			= 1,            	//
		near 			= -1,
		far 			= 1,
	};
	
	begin_target(target, nil);
		begin_pipeline(overlay_pipeline, cam);
			set_texture(.texture_diffuse, tex);
			draw_quad(linalg.matrix4_from_trs_f32({offset.x, offset.y, 0}, 0, {-scale,scale,1}));
			//draw_quad(1);
		end_pipeline();
	end_target();

}