package utils;

Bounding_box :: struct {
	min : [3]f32,
	max : [3]f32,
}

test_AABB_against_frustum :: proc(aabb : Bounding_box) -> bool {

	panic("Unimplemented");
	
	/* 
	within :: proc(val : f32, min : f32, max : f32) -> bool {
		return val >= min && val <= max;
	}
	
	// Use our min max to define eight corners
	corners : [8][4]f32 = {
		{aabb.min.x, aabb.min.y, aabb.min.z, 1.0}, // x y z
		{aabb.max.x, aabb.min.y, aabb.min.z, 1.0}, // X y z
		{aabb.min.x, aabb.max.y, aabb.min.z, 1.0}, // x Y z
		{aabb.max.x, aabb.max.y, aabb.min.z, 1.0}, // X Y z

		{aabb.min.x, aabb.min.y, aabb.max.z, 1.0}, // x y Z
		{aabb.max.x, aabb.min.y, aabb.max.z, 1.0}, // X y Z
		{aabb.min.x, aabb.max.y, aabb.max.z, 1.0}, // x Y Z
		{aabb.max.x, aabb.max.y, aabb.max.z, 1.0}, // X Y Z
	};

	inside : bool = false;

	for corner in corners {
		// Transform vertex
		corner : [4]f32 = MVP * corner;
		// Check vertex against clip space bounds
		inside = inside || 
		within(-corner.w, corner.x, corner.w) &&
		within(-corner.w, corner.y, corner.w) &&
		within(0.0, corner.z, corner.w)
	}

	return inside;
	*/
}

collision_point_rect :: proc(point : [2]f32, rect : [4]f32) -> bool {

	return point.x >= rect.x && point.x <= rect.x + rect.z && point.y >= rect.y && point.y <= rect.y + rect.w
}

collision_line_rect :: proc(p1, p2 : [2]f32, rect : [4]f32) -> bool {
	// Helper function to check line-line intersection
	line_intersect :: proc(a1, a2, b1, b2: [2]f32) -> bool {
		denom := (b2.y - b1.y) * (a2.x - a1.x) - (b2.x - b1.x) * (a2.y - a1.y);
		if denom == 0 { return false; } // Parallel lines

		ua := ((b2.x - b1.x) * (a1.y - b1.y) - (b2.y - b1.y) * (a1.x - b1.x)) / denom;
		ub := ((a2.x - a1.x) * (a1.y - b1.y) - (a2.y - a1.y) * (a1.x - b1.x)) / denom;
		return ua >= 0 && ua <= 1 && ub >= 0 && ub <= 1;
	}
	
	// Check if either endpoint of the line is inside the rectangle
	if collision_point_rect(p1, rect) || collision_point_rect(p2, rect) {
		return true;
	}

	// Define rectangle corners
	rect_p1 := [2]f32{rect.x, rect.y};
	rect_p2 := [2]f32{rect.x + rect.z, rect.y};
	rect_p3 := [2]f32{rect.x + rect.z, rect.y + rect.w};
	rect_p4 := [2]f32{rect.x, rect.y + rect.w};

	// Check if the line intersects any of the rectangle's edges
	return line_intersect(p1, p2, rect_p1, rect_p2) ||
		line_intersect(p1, p2, rect_p2, rect_p3) ||
		line_intersect(p1, p2, rect_p3, rect_p4) ||
		line_intersect(p1, p2, rect_p4, rect_p1);
}

collision_rect_rect :: proc(rect1 : [4]f32, rect2 : [4]f32) -> bool {

	return rect1.x < rect2.x + rect2.z &&
		rect1.x + rect1.z > rect2.x &&
		rect1.y < rect2.y + rect2.w &&
		rect1.y + rect1.w > rect2.y;
}