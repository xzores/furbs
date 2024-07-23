package render;

import "core:math"

import linalg "core:math/linalg"

@require_results
ortho_mat :: proc "contextless" (left, right, bottom, top, near, far : f32) -> matrix[4,4]f32 {
	
	l, r, b, t, n, f := left, right, bottom, top, near, far;

	mat : matrix[4,4]f32 = {
		2 / (r-l),	0,			0,			-2*(r+l)/(r-l),
		0,			2 / (t-b),	0,			-2*(b+t)/(t-b),
		0,			0,			2/(f-n),	-2*(f+n)/(f-n),
		0,			0,			0,			1,
	}

	return mat;
}

//TODO "contextless"
perspective_mat :: proc (fovy, aspect, near, far: f32) -> matrix[4,4]f32 {
	/*tan_half_fovy := math.tan(0.5 * fovy)
	
	m[0, 0] = 1 / (aspect*tan_half_fovy)
	m[1, 1] = 1 / (tan_half_fovy)
	m[2, 2] = +(far + near) / (far - near)
	m[3, 2] = +1
	m[2, 3] = -2*far*near / (far - near)

	if flip_z_axis {
		m[2] = -m[2]
	}
	*/
	
	assert(false);
	
	return 1;
}

@(require_results)
look_at :: proc "contextless" (eye, centre, up: [3]f32) -> matrix[4,4]f32 {
	using linalg;
	
	f := normalize(centre - eye);
	r := normalize(cross(up, f));
	u := cross(f, r);

	r_mat : matrix[4,4]f32 = {
		+r.x, +u.x, +f.x,   0,
		+r.y, +u.y, +f.y,   0,
		+r.z, +u.z, +f.z,   0,
		0,    0,    0, 		1,
	}
	
	t_mat : matrix[4,4]f32 = {
		1,    0,    0, 		eye.x,
		0,    1,    0, 		eye.y,
		0,    0,    1, 		eye.z,
		0,    0,    0, 		1,
	}

	return t_mat * r_mat;
}

@(require_results)
camera_look_at :: proc "contextless" (eye, centre, up: [3]f32) -> matrix[4,4]f32 {
	using linalg;
	
	f := normalize(centre - eye);
	r := normalize(cross(up, f));
	u := cross(f, r);

	r_mat : matrix[4,4]f32 = {
		+r.x, +r.y, +r.z,   0,
		+u.x, +u.y, +u.z,   0,
		+f.x, +f.y, +f.z,   0,
		0,    0,    0, 		1,
	}

	t_mat : matrix[4,4]f32 = {
		1,    0,    0, 		-eye.x,
		0,    1,    0, 		-eye.y,
		0,    0,    1, 		-eye.z,
		0,    0,    0, 		1,
	}
	
	return r_mat * t_mat;
}

@require_results
extract_rotation_from_matrix3 :: proc "contextless" (mat : matrix[3,3]f32) -> [3]f32 {
	angle_x := math.atan2(mat[1][2], mat[2][2]);
    angle_y := math.atan2(-mat[0][2], math.sqrt(mat[1][2] * mat[1][2] + mat[2][2] * mat[2][2]));
    angle_z := math.atan2(mat[0][1], mat[0][0]);

    return {angle_x, angle_y, angle_z};
}

@require_results
extract_rotation_from_matrix4 :: proc "contextless" (mat : matrix[4,4]f32) -> [3]f32 {
    return extract_rotation_from_matrix3(matrix[3,3]f32{
		mat[0,0], mat[0,1], mat[0,2],
		mat[1,0], mat[1,1], mat[1,2],
		mat[2,0], mat[2,1], mat[2,2],
	});
}

//ONLY WORKS IF THE MATRIX IS SPEACIAL ORTHOGONAL (aka it only rotates).
extract_rotation_from_matrix :: proc {extract_rotation_from_matrix3, extract_rotation_from_matrix4};

//Rotation is applied in x,y,z. postive rotation = counter clock wise.
@require_results
rotation_matrix :: proc "contextless" (euler_angles : [3]f32) -> matrix[3,3]f32 {
	using math;
	
    cx := cos(euler_angles.x);
    sx := sin(euler_angles.x);

    cy := cos(euler_angles.y);
    sy := sin(euler_angles.y);
    
	cz := cos(euler_angles.z);
    sz := sin(euler_angles.z);

    rot_x := matrix[3,3]f32{1, 0, 0,
							0, cx, sx,
							0, -sx, cx};

    rot_y := matrix[3,3]f32{cy, 0, -sy,
							0,  1, 0,
							sy, 0, cy};

    rot_z := matrix[3,3]f32{cz, sz, 0,
							-sz, cz, 0,
							0, 0, 1};

    return rot_z * rot_y * rot_x;
}

@require_results
get_mouse_cast :: proc (camera : Camera3D, window : ^Window) -> (direction : [3]f32) {
	
	width : f32 = cast(f32)window.width;
	height : f32 = cast(f32)window.height;
	
	cam_view, cam_prj := camera3D_get_prj_view(camera, width / height);
	
	m_pos := mouse_pos(window);
	
	inv_prj := linalg.inverse(cam_prj);
	ray_clip : [4]f32 = {(2 * m_pos.x / width) - 1, (2 * m_pos.y / height) - 1, 1, 1};
	ray_eye : [3]f32 = linalg.normalize((inv_prj * ray_clip).xyz);

	ray_world := (linalg.inverse(camera_look_at(camera.position, camera.target, camera.up)) * [4]f32{ray_eye.x, ray_eye.y, ray_eye.z, 0}).xyz;

	return linalg.normalize(ray_world);
}
