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

collision_rect_rect :: proc(rect1 : [4]f32, rect2 : [4]f32) -> bool {

	return rect1.x < rect2.x + rect2.z &&
		rect1.x + rect1.z > rect2.x &&
		rect1.y < rect2.y + rect2.w &&
		rect1.y + rect1.w > rect2.y;
}