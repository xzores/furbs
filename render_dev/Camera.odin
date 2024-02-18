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

