package render

import    "vendor:glfw"
import gl "vendor:OpenGL"

import "core:testing"
import "core:fmt"

import "core:math"
import "core:math/linalg"

Circle :: struct {
	diameter : f32,
	position : [2]f32,
}
Line :: struct {
	p1, p2 : [2]f32,
	thickness : f32,
}


Rounded_rectangle :: struct {
	rect : [4]f32,
	roundness : f32,
	segments : Maybe(int),
}

Rounded_rectangle_outline :: struct {
	rect : [4]f32,
	roundness : f32,
	thickness : f32,
	segments : Maybe(int),
}

//triangles, rects and circles.
Shape :: union {
	Line,			//A line
	//[3][2]f32,		//Triangle
	[4]f32,				//Rectangle
	Circle,				
	Rounded_rectangle,
}

_ensure_shapes_loaded :: proc() {

	if shape_quad.vertex_count == 0 {
		shape_quad = generate_quad({1, 1, 1}, {-0.5,-0.5,0});
		upload_mesh_single(&shape_quad);
	}
	if shape_circle.vertex_count == 0 {
		shape_circle = generate_circle(1, {0,0});
		upload_mesh_single(&shape_circle);
	}
}

//This is ok fast if you dont specifify roundness, segments or thickness in Rounded_rectangle. And/Or if you dont 
draw_shape :: proc(shape : Shape, rot : f32 = 0, texture : Maybe(Texture2D) = nil, shader := gui_shader, color : [4]f32 = {1,1,1,1}, loc := #caller_location) {
	
	assert(bound_camera != nil, "A camera must be bound before a mesh can be drawn", loc = loc);
	shader := shader;
	
	if shader.id == 0 {
		fmt.printf("loading default gui shader\n");
		gui_shader = get_default_gui_shader();
		shader = gui_shader;
	}
	
	_ensure_shapes_loaded();

	bind_shader(shader);
	
	place_uniform(shader, .col_diffuse, color);
	
	if tex_diffuse, ok := texture.?; ok {
		place_uniform(shader, .texture_diffuse, tex_diffuse);
	}
	else {
		place_uniform(shader, .texture_diffuse, get_white_texture());
	}
	
	if rect, ok := shape.([4]f32); ok {
		transform := linalg.matrix4_from_trs_f32({rect.x + rect.z / 2, rect.y + rect.w / 2, 0}, linalg.quaternion_angle_axis(math.to_radians(rot), linalg.Vector3f32{0,0,1}), {rect.z, rect.w, 0});
		draw_mesh_single(shader, shape_quad, transform);
	}
	else if circle, ok := shape.(Circle); ok {
		transform := linalg.matrix4_from_trs_f32({circle.position.x, circle.position.y, 0}, linalg.quaternion_angle_axis(math.to_radians(rot), linalg.Vector3f32{0,0,1}), {circle.diameter, circle.diameter, 0});
		draw_mesh_single(shader, shape_circle, transform);
	}
	else if line, ok := shape.(Line); ok {
		using linalg;
		forward := normalize(line.p2 - line.p1);
		
		offset : Vector3f32 = {linalg.vector_length(line.p2 - line.p1)/2, 0, 0};
		
		t : Vector3f32 = {line.p1.x, line.p1.y, 0};
		r := quaternion_angle_axis_f32(math.atan2(-forward.y, forward.x), {0,0,-1});
		s : Vector3f32 = {linalg.vector_length(line.p2 - line.p1), line.thickness, 1};
		
        transform := matrix_mul(linalg.matrix4_from_trs_f32(t, r, {1,1,1}), linalg.matrix4_from_trs_f32(offset, 0, s));
        draw_mesh_single(shader, shape_quad, transform);
    }
	else {
		panic("Unimplemented");
	}
	
	unbind_shader(shader);
}
