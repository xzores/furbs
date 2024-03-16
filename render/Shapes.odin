package render;

import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:math/linalg/glsl"


@(private)
_ensure_shapes_loaded :: proc () {
	panic("TODO load shapes");
}

draw_quad :: proc() {

}

draw_circle :: proc() {
	
}

draw_cube :: proc() {

}

draw_cylinder :: proc() {

}

draw_sphere :: proc() {

}

draw_arrow :: proc() {
	
}

//TODO move to state
arrow_forward 	: Mesh_single;
arrow_up 		: Mesh_single;
arrow_right 	: Mesh_single;
arrow_init : bool

shapes_pipeline : Pipeline;

//TODO move to gui
draw_coordinate_overlay :: proc(target : Render_target, camera : Camera3D, offset : [2]f32 = {0.8, 0.8}, scale : f32 = 1, pipeline := shapes_pipeline) {

	camera := camera;
	camera.fovy = 61;
	camera.projection = .perspective;

	if arrow_init == false {
		arrow_forward 	= make_mesh_arrow({0,0,1}, 0.35, 0.15, 0.05, 0.15, 20, true);
		arrow_up 		= make_mesh_arrow({0,1,0}, 0.35, 0.15, 0.05, 0.15, 20, true);
		arrow_right 	= make_mesh_arrow({1,0,0}, 0.35, 0.15, 0.05, 0.15, 20, true);
		shapes_pipeline = make_pipeline(target, get_default_shader(), .no_blend, true, true, .fill, .back_cull);
		arrow_init = true;
	}
	
	f := camera_forward(camera);
	r := camera_right(camera);
	u := camera.up;

	overlay_camera := Camera2D {
		position 		= {0,0}, //  -{offset.x * aspect, offset.y}, // Camera position
		target_relative = {0,0}, // 
		rotation		= 0,	 // in degrees
		zoom 			= 1,     //
		far 			= 0,
		near 			= -camera.far - 1,
	};

	begin_pipeline(pipeline, overlay_camera, nil);
	
	view, prj := get_camera_3D_prj_view(camera, 1);
	mat := (prj * view * linalg.matrix4_translate_f32(camera.position + f) * linalg.matrix4_scale_f32({scale, scale, scale}));
	mat = matrix[4,4]f32{
			1,0,0,0,
			0,1,0,0,
			0,0,-1,camera.far,
			0,0,0,1,} * mat;
		
	set_texture(.texture_diffuse, get_white_texture());
	set_uniform(pipeline.shader, .color_diffuse, [4]f32{0,0,1,1});
	draw_mesh_single(&arrow_forward, mat);
	set_uniform(pipeline.shader, .color_diffuse, [4]f32{0,1,0,1});
	draw_mesh_single(&arrow_up, mat);
	set_uniform(pipeline.shader, .color_diffuse, [4]f32{1,0,0,1});
	draw_mesh_single(&arrow_right, mat);
	end_pipeline(pipeline);
} 





















