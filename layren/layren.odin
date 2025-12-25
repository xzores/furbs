package furbs_layren;

import "core:c"
import "vendor:fontstash"
import "core:fmt"
import "core:relative"
import "core:math"
import "core:reflect"

import "../render"

/*
import "../laycal"
Layout_dir :: laycal.Layout_dir; 
Alignment :: laycal.Alignment; 
Anchor_point :: laycal.Anchor_point; 
Axis :: laycal.Axis; 
Fixed :: laycal.Fixed; 
Parent_ratio :: laycal.Parent_ratio; 
Fit :: laycal.Fit; 
Grow :: laycal.Grow; 
Grow_fit :: laycal.Grow_fit; 
fit :: laycal.fit; 
grow :: laycal.grow; 
grow_fit :: laycal.grow_fit; 
Size :: laycal.Size; 
Min_size :: laycal.Min_size; 
Max_size :: laycal.Max_size; 
Absolute_postion :: laycal.Absolute_postion; 
Overflow :: laycal.Overflow;
Parameters :: laycal.Parameters; 
Element :: laycal.Element; 
Element_layout :: laycal.Element_layout;

Layout_render :: struct {
	ls : laycal.Layout_state,

}

make_layout_render :: proc (lr : ^Layout_render = nil, params : Parameters = laycal.default_root_params) -> ^Layout_render {
	lr := lr;

	if lr == nil {
		lr = new(Layout_render);
	}
	
	laycal.make_layout_state(&lr.ls, params);
	

	return lr;
}

destroy_laytout_render :: proc (lr : ^Layout_render) {
	laycal.destroy_laytout_state(lr);
}
*/

Shadow :: struct {
	offset : [2]f32,
	blur   : f32,
	spread : f32,
	color  : [4]f32,
}

Color_stop :: struct {
	color : [4]f32,
	stop : f32,
}

Gradient :: struct {
	color_stops : []Color_stop,
	start : [2]f32,	//start the gradient at start and end it at end.
	end   : [2]f32,	//0,0 is bottom left, 1,1 is top right
	wrap : bool, 	//repeat when outside 0 to 1
}

Rect_options :: struct {
	color : union {
		[4]f32,
		Gradient,
	},
	
	border : Maybe(i32), //set this if it is border (width is pixels) default is fill.
	shadow : Maybe(Shadow),
	rounding : [4]f32 // TL, TR, BR, BL
	
	//clip : enum { none, hard, rounded }
}

Layout_render :: struct {
	pipeline : render.Pipeline,
	shader : ^render.Shader,
}

@private
Rect_gpu_layout :: struct #packed {
	fill : b32,
	is_color : b32,
	color : [4]u8,

	//gradients is a length and of how many after this struct:
	gradient_cnt : i32,
	//lines is after gradients
	line_cnt : i32,
}

make_layout_render :: proc (lr : ^Layout_render = nil) -> ^Layout_render {
	lr := lr;

	defines : [dynamic][2]string;
	defer delete(defines);

	for field in reflect.struct_fields_zipped(Rect_gpu_layout) {
		append(&defines, [2]string{fmt.tprintf("%v%v", "lr_", field.name), fmt.tprintf("%v", field.offset)});
	}

	render.set_shader_defines(defines[:]);

	if lr == nil {
		lr = new(Layout_render);
	}

	ok : render.Shader_load_error;
	lr.shader, ok = render.shader_load_from_path("bezier_shader.glsl");
	assert(ok == nil, "could not load rect shader");

	lr.pipeline = render.pipeline_make(render.get_default_shader(), .blend, true, false, .fill, .no_cull);

	

	return lr;
}

destroy_layout_render :: proc (lr : ^Layout_render) {
	
}

begin_render :: proc (lr : ^Layout_render, loc := #caller_location) {
	render.pipeline_begin(lr.pipeline, render.camera_get_pixel_space(render.get_current_render_target()), loc);
}

end_render :: proc(loc := #caller_location) {
	render.pipeline_end(loc);
}

render :: proc (lr : ^Layout_render, rect : [4]f32, options : Rect_options) {
	
	render.set_texture(.texture_diffuse, render.texture2D_get_white());
	render.draw_quad(rect, 0, options.color.([4]f32));
	
	return;
}

@(private)
write_options_to_texture :: proc (tex : render.Texture1D, index : i32, rect : Rect_options) {
	
	
}