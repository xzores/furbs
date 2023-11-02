package utils;

Bezier_path :: struct(dim : int) {
	pass_point : [dynamic][dim]f32,
	gradient : [dynamic][dim]f32,
}

init_bezier :: proc (using path : ^Bezier_path($D)) {
	pass_point = make([dynamic][D]f32, 2);
	gradient = make([dynamic][D]f32, 2);

	pass_point[0] = 0;
	pass_point[1] = 1;
}

eval_bezier_single :: proc (p0, p1, p2, p3 : [2]f32, t : f32) -> [2]f32 {

	t := (t - p0) / (p3 - p0);
	t1 := (1-t);

	return t1*t1*t1*p0 + 3*t1*t1*t*p1 + 3*t1*t*t*p2 + t*t*t*p3;
}

eval_bezier :: proc (using path : Bezier_path($D), t : f32) -> [D]f32 {
	
	assert(t >= 0 && t <= 1);

	i : int = 0;

	for pp, k in pass_point {
		if pp > t {
			//We have found what entires to evaluate.
			break;
		}
		i = k;
	}

	p0 := pass_point[i];
	p3 := pass_point[i+1];
	p1 := p0+gradient[i];
	p2 := p3-gradient[i+1];

	t := (t - p0) / (p3 - p0);
	t1 := (1-t);

	return t1*t1*t1*p0 + 3*t1*t1*t*p1 + 3*t1*t*t*p2 + t*t*t*p3;
}

destroy_bezier :: proc (using path : Bezier_path($D)) {
	delete(pass_point);
	delete(gradient);
}