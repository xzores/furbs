package render;

import "core:fmt"
import "core:mem"
import "core:math"

import glfw "vendor:glfw"
import linalg "core:math/linalg"
import glsl "core:math/linalg/glsl"

// Camera projection
CameraProjection :: enum {
	perspective,				// Perspective projection
	orthographic,				// Orthographic projection
}

Camera3D :: struct {
	position		: [3]f32,            	// Camera position
	target			: [3]f32,            	// Camera target it looks-at
	up				: [3]f32,            	// Camera up vector (rotation over its axis)
	fovy			: f32,                	// Camera field-of-view apperture in Y (degrees) in perspective
	ortho_height 	: f32,					// Camera ortho_height when using orthographic projection
	projection		: CameraProjection, 	// Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
	
	near 			: f32,
	far 			: f32,
}

//Zoom = 1 for no zoom
Camera2D :: struct {
	position		: [2]f32,            	// Camera position
	target_relative	: [2]f32,				// 
	rotation		: f32,				// in degrees
	zoom 			: f32,            	//
	
	near 			: f32,
	far 			: f32,
}

Camera :: union {
	Camera2D,
	Camera3D,
}

//////////////////////////////////////////////////////////////////////////////////

get_camera_3D_prj_view :: proc(using camera : Camera3D, aspect : f32, loc := #caller_location) -> (view : matrix[4,4]f32, prj : matrix[4,4]f32) {

	view = camera_look_at(camera.position, camera.target, camera.up);

    if (camera.projection == .perspective)
    {
		assert(camera.near > 0, "camera near plane must be above zero for a perspective matrix", loc);
		prj = linalg.matrix4_perspective(camera.fovy * math.PI / 180, aspect, near, far, false); //matrix_perspective(math.to_radians(fovy), aspect, near, far);
		//prj = glsl.mat4Perspective(camera.fovy * math.PI / 180, aspect, near, far);
    }
    else if (camera.projection == .orthographic)
    {	
        top : f32 = ortho_height / 2.0;
        right : f32 = top * aspect;

		prj = ortho_mat(-right, right, -top, top, near, far);
    }

	return;
};

get_camera_2D_prj_view :: proc(using camera : Camera2D, aspect : f32) -> (view : matrix[4,4]f32, prj : matrix[4,4]f32) {

	translation_mat := linalg.matrix4_translate(-linalg.Vector3f32{position.x, position.y, 0});
	rotation_mat := linalg.matrix4_from_quaternion(linalg.quaternion_angle_axis_f32(math.to_radians(-rotation), {0,0,1}));
	view = linalg.mul(translation_mat, rotation_mat);
	
	top : f32 = 1 / zoom;
    right : f32 = top * aspect;
	prj = ortho_mat(-right, right, -top, top, near, far);
	
	return;
};

@(private)
bind_camera_3D :: proc(using camera : Camera3D, loc := #caller_location) {

    aspect : f32 = state.target_pixel_width / state.target_pixel_height;

	state.view_mat, state.prj_mat = get_camera_3D_prj_view(camera, aspect);
	state.inv_view_mat = linalg.matrix4_inverse(state.view_mat);	
	state.inv_prj_mat = linalg.matrix4_inverse(state.prj_mat);

	state.view_prj_mat = state.prj_mat * state.view_mat;
	state.inv_view_prj_mat = linalg.inverse(state.view_prj_mat);
}

@(private)
bind_camera_2D :: proc(using camera : Camera2D, loc := #caller_location) {
	
	aspect : f32 = state.target_pixel_width / state.target_pixel_height;

	state.view_mat, state.prj_mat = get_camera_2D_prj_view(camera, aspect);
	state.inv_prj_mat = linalg.matrix4_inverse(state.prj_mat);
	
	state.view_prj_mat = state.prj_mat * state.view_mat;
	state.inv_view_prj_mat = linalg.inverse(state.view_prj_mat);
}

@(private)
bind_camera :: proc (camera : Camera, loc := #caller_location) {

	if cam, ok := camera.(Camera2D); ok {
		bind_camera_2D(cam);
	}
	else if cam, ok := camera.(Camera3D); ok {
		bind_camera_3D(cam);
	}
	else {
		panic("??");
	}
}

//////////////////////////////////////////////////////////////////////////////////

get_pixel_space_camera :: proc(target : Render_target, loc := #caller_location) -> (cam : Camera2D) {

	w, h : f32;
	
	switch t in target {
		case nil:
			panic("!?!?");
		case ^Frame_buffer:
			w, h = cast(f32)t.width, cast(f32)t.height;
		case ^Window:
			w, h = cast(f32)t.width, cast(f32)t.height;
	}
	
	aspect := w / h;

	cam = {
		position 		= {w/2, h/2},
		target_relative = {0,0},
		rotation		= 0,
		zoom			= 2/(h),

		near			= -1,
		far 			= 1,
	}

	return cam;
}

///////////////////////////////////////////

camera_forward :: proc(cam : Camera3D) -> [3]f32 {
	res := linalg.normalize(cam.target - cam.position);
	return res;
} 

camera_forward_horizontal :: proc(cam : Camera3D) -> [3]f32 {
	forward := camera_forward(cam);
	res := linalg.normalize([3]f32{forward.x, 0, forward.z});
	return res;
}

camera_right :: proc(cam : Camera3D) -> [3]f32 {
	forward := camera_forward(cam);
	return linalg.normalize(linalg.cross(cam.up, forward));
}

camera_move :: proc(cam : ^Camera3D, movement : [3]f32) {
	cam.position += movement;
	cam.target += movement;
}

camera_rotation :: proc(cam : ^Camera3D, yaw, pitch : f32) {
	using linalg;

	yaw := -math.to_radians(yaw);
	pitch := -math.to_radians(pitch);

	direction : [3]f32;

	direction.x = cos(yaw) * cos(pitch);
	direction.y = sin(pitch);
	direction.z = sin(yaw) * cos(pitch);

	cam.target = direction + cam.position;
}

