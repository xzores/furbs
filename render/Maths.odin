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
		0,	0,	0, 		1,
	}
	
	t_mat : matrix[4,4]f32 = {
		1,	0,	0, 		eye.x,
		0,	1,	0, 		eye.y,
		0,	0,	1, 		eye.z,
		0,	0,	0, 		1,
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
		0,	0,	0, 		1,
	}

	t_mat : matrix[4,4]f32 = {
		1,	0,	0, 		-eye.x,
		0,	1,	0, 		-eye.y,
		0,	0,	1, 		-eye.z,
		0,	0,	0, 		1,
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
extract_translation_from_matrix4 :: proc "contextless" (mat : matrix[4,4]f32) -> [3]f32 {
	return {mat[0,3], mat[1,3], mat[2,3]};
}

extract_scale_from_matrix4 :: proc "contextless" (mat : matrix[4,4]f32) -> [3]f32 {
	return {mat[0,0], mat[1,1], mat[2,2]};
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

// plane is 3 3D points spanning a plane
// ray is origin and then a direction
@require_results
plane_ray_intersection :: proc (plane: [3][3]f32, ray: [2][3]f32) -> (intersection: [3]f32, hit: bool) {
    origin := ray[0];
    dir := ray[1];

    // Calculate the normal of the plane
    v0 := plane[1] - plane[0];
    v1 := plane[2] - plane[0];
    normal := linalg.cross(v0, v1); // normal = cross product of two vectors on the plane

    // Plane equation: N dot (P - P0) = 0, where P0 is a point on the plane (plane[0])
    // Ray equation: P(t) = origin + t * dir
    // Substituting into the plane equation, we get N dot (origin + t * dir - P0) = 0
    // Rearranging for t: t = (N dot (P0 - origin)) / (N dot dir)

    denom := linalg.dot(normal, dir);
    
    // If the denominator is close to 0, the ray is parallel to the plane (no intersection)
    if abs(denom) < 1e-6 {
        return [3]f32{}, false; // No hit
    }

    t := linalg.dot(normal, plane[0] - origin) / denom;

    // If t is negative, the intersection is behind the ray's origin
    if t < 0 {
        return [3]f32{}, false; // No hit
    }

    // Calculate intersection point
    intersection = origin + t * dir;
    
    return intersection, true;
}

@(optimization_mode="favor_size")
line_2D_to_quad_mat :: proc (p1 : [2]f32, p2 : [2]f32, width : f32, z : f32 = 0) -> matrix[4,4]f32 {

	// Calculate the difference vector and its length
	diff := p2 - p1;
	length := linalg.length(diff);
	
	// Calculate the angle of rotation needed
	angle := #force_inline math.atan2(diff.y, diff.x);
	
	// Create the transformation matrix
	translation := #force_inline linalg.matrix4_translate_f32({p1.x, p1.y, z});
	rotation := #force_inline linalg.matrix4_from_quaternion_f32( #force_inline linalg.quaternion_from_pitch_yaw_roll_f32(0, 0, angle));
	scale := #force_inline linalg.matrix4_scale_f32({length, width, 1});
	
	// Offset the quad, so we draw from the x-left, y-center.
	offset := #force_inline linalg.matrix4_translate_f32({0.5, 0, 0});
	
	// Combine the transformations in the correct order
	mat := translation * rotation * scale * offset;
	
	return mat;
}

//Will not provide any offset to the quad, this must be done in mesh creation.
@(optimization_mode="favor_size")
line_2D_to_quad_trans_rot_scale :: proc (p1 : [2]f32, p2 : [2]f32, width : f32, z : f32 = 0) -> (trans : [3]f32, rot : [3]f32, scale : [3]f32) {
	
	// Calculate the difference vector and its length
	diff := p2 - p1;
	length := #force_inline linalg.length(diff);
	
	// Calculate the angle of rotation needed
	angle := #force_inline math.atan2(diff.y, diff.x);
	
	// Create the transformation matrix
	trans = {p1.x, p1.y, z};
	rot =  {0, 0, angle} * 180 / math.PI;
	
	scale = {length, width, 1};
	
	return trans, rot, scale;
}