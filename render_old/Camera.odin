package render;

import "core:fmt"
import "core:mem"
import "core:math"

import glfw "vendor:glfw"

import glsl "core:math/linalg/glsl"
import linalg "core:math/linalg"

// Camera projection
CameraProjection :: enum {
	perspective = 0,                  // Perspective projection
	orthographic,                     // Orthographic projection
}

Camera3D :: struct {
	position: [3]f32,            	// Camera position
	target:   [3]f32,            	// Camera target it looks-at
	up:       [3]f32,            	// Camera up vector (rotation over its axis)
	fovy:     f32,                	// Camera field-of-view apperture in Y (degrees) in perspective
	projection: CameraProjection, 	// Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC

	far, near : f32,
}

//space from (-1,-1) to (1,1) with zoom = 1.
Camera2D :: struct {
	position: 		[2]f32,            	// Camera position
	target_relative:[2]f32,				// 
	rotation: 		f32,				// in degrees
	zoom:   		f32,            	//
	
	far, near : 	f32,
}

begin_mode_3D :: proc(using s : ^Render_state($U,$A), using camera : Camera3D, use_transparency : bool, loc := #caller_location) {

	assert(bound_camera == nil, "A camera is already bound, unbind it first", loc = loc);
	bound_camera = camera;

    aspect : f32 = current_render_target_width / current_render_target_height;

	view_mat = glsl.mat4LookAt(cast(glsl.vec3)camera.position, cast(glsl.vec3)camera.target, -cast(glsl.vec3)camera.up);
	inv_view_mat = linalg.matrix4_inverse(view_mat);

	assert(near != 0, "near is 0", loc);
	assert(far != 0, "far is 0", loc);
	
    if (camera.projection == .perspective)
    {
		prj_mat = linalg.matrix4_perspective(camera.fovy, aspect, near, far, flip_z_axis = true); //matrix_perspective(math.to_radians(fovy), aspect, near, far);
    }
    else if (camera.projection == .orthographic)
    {	
        top : f32 = camera.fovy/2.0;
        right : f32 = top*aspect;
		
		prj_mat = glsl.mat4Ortho3d(-right, right, -top,top, near, far);
    }
	
	inv_prj_mat = linalg.matrix4_inverse(prj_mat);
	
	enable_depth_test(s);

	enable_transparency(s, use_transparency);
}

// Ends 3D mode and returns to default 2D orthographic mode
end_mode_3D :: proc(using s : ^Render_state($U,$A), camera : Camera3D, loc := #caller_location) {
	
	assert(camera == bound_camera, "The camera you are trying to unbind is not the currently bound camera", loc = loc);
	bound_camera = nil;

	disable_depth_test(s);

	enable_transparency(s, false);
}

begin_mode_2D :: proc(using s : ^Render_state($U,$A), using camera : Camera2D, use_transparency : bool, loc := #caller_location) {

	assert(bound_camera == nil, "A camera is already bound, unbind it first", loc = loc);
	bound_camera = camera;

    aspect : f32 = current_render_target_width / current_render_target_height;
	
	translation_mat := linalg.matrix4_translate(-linalg.Vector3f32{position.x, position.y, 0});
	rotation_mat := linalg.matrix4_from_quaternion(linalg.quaternion_angle_axis_f32(math.to_radians(-rotation), {0,0,1}));
	view_mat = linalg.mul(translation_mat, rotation_mat);
	inv_view_mat = linalg.matrix4_inverse(view_mat);
	
	top : f32 = 1/zoom;
    right : f32 = top*aspect;
	prj_mat = glsl.mat4Ortho3d(-right, right, -top, top, near, far);
	inv_prj_mat = linalg.matrix4_inverse(prj_mat);

	enable_transparency(s, use_transparency);
}

// Ends 3D mode and returns to default 2D orthographic mode
end_mode_2D :: proc(using s : ^Render_state($U,$A), camera : Camera2D = {{0,0}, {0,0}, 0, 1, 1, -1}, loc := #caller_location) {
	assert(bound_camera == bound_camera, "A camera is already bound, unbind it first", loc = loc);
	bound_camera = nil;

	enable_transparency(s, false);
}

get_pixel_space_camera :: proc(using s : ^Render_state($U,$A), loc := #caller_location) -> (cam : Camera2D) {

	aspect : f32 = current_render_target_width / current_render_target_height;

	cam = {
		position 		= {current_render_target_width/2,current_render_target_height/2},
		target_relative = {0,0},
		rotation		= 0,
		zoom			= 2/(current_render_target_height),

		far 			= 1,
		near			= -1,
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
	return linalg.cross(forward, cam.up);
} 

camera_move :: proc(cam : ^Camera3D, movement : [3]f32) {
	cam.position += movement;
	cam.target += movement;
}

camera_rotation :: proc(cam : ^Camera3D, yaw, pitch : f32) {
	using linalg;

	//forward := camera_forward(cam^);
	//quaternion_from_forward_and_up_f32()
	//m := linalg.matrix3_rotate_f32(math.to_radians(angle_degress), auto_cast around);
	//matrix4_from_quaternion
	/* 
	qx := quaternion_angle_axis_f32(math.to_radians(angles_degress.x), {1,0,0});
	qy := quaternion_angle_axis_f32(math.to_radians(angles_degress.y), {0,1,0});
	qz := quaternion_angle_axis_f32(math.to_radians(angles_degress.z), {0,0,1});

	//m := linalg.matrix3_from_euler_angles(math.to_radians(angles_degress.x), math.to_radians(angles_degress.y), math.to_radians(angles_degress.z), .XYZ);
	m := matrix4_from_quaternion(mul(qx, qy));	
	*/

	yaw := math.to_radians(yaw);
	pitch := math.to_radians(pitch);

	direction : [3]f32;
	direction.x = cos(yaw); // Note that we convert the angle to radians first
	direction.z = sin(yaw);

	direction.y = sin(pitch);
	direction.x = cos(yaw) * cos(pitch);
	direction.y = sin(pitch);
	direction.z = sin(yaw) * cos(pitch);

	cam.target = direction + cam.position;
}

