package furbs_layren;

import "base:runtime"
import "core:c"
import "vendor:fontstash"
import "core:fmt"
import "core:relative"
import "core:math"
import "core:slice"
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
	
	fill : bool,
	border : Maybe(i32), //set this if it is border (width is pixels) default is fill.
	shadow : Maybe(Shadow),
	rounding : [4]f32 // TL, TR, BR, BL
	
	//clip : enum { none, hard, rounded }
}

To_render :: struct{
	rect : [4]f32,
	tex : render.Texture2D,
	index : int
}

Layout_render :: struct {
	pipeline : render.Pipeline,
	shader : ^render.Shader,

	//render data
	to_render : [dynamic]To_render,
	gui_data : [dynamic]u32,
	gui_texture : render.Texture1D,

	has_begun : bool,
}


make_layout_render :: proc (lr : ^Layout_render = nil) -> ^Layout_render {
	lr := lr;
	
	defines : [dynamic][2]string;
	defer delete(defines);

	for field in reflect.struct_fields_zipped(Rect_gpu_layout) {
		append(&defines, [2]string{fmt.tprintf("%v%v", "lr_", field.name), fmt.tprintf("%v", field.offset / 4)});
	}
	append(&defines, [2]string{"lr_struct_size", fmt.tprintf("%v", size_of(Rect_gpu_layout))});
	
	render.set_shader_defines(defines[:]);

	if lr == nil {
		lr = new(Layout_render);
	}

	ok : render.Shader_load_error;
	lr.shader, ok = render.shader_load_from_path("gui_shader.glsl");
	assert(ok == nil, "could not load rect shader");

	lr.pipeline = render.pipeline_make(lr.shader, .blend, true, false, .fill, .no_cull);
	lr.gui_texture = render.texture1D_make(false, .clamp_to_border, .nearest, .R32_uint, 1, .no_upload, nil, {}, nil);

	return lr;
}

destroy_layout_render :: proc (lr : ^Layout_render) {
	
}

begin_render :: proc (lr : ^Layout_render, loc := #caller_location) {
	assert(lr.has_begun == false, "you must first end with 'end_render'", loc);
	lr.has_begun = true;
	clear(&lr.gui_data);
	clear(&lr.to_render);
}

render_rect :: proc (lr : ^Layout_render, rect : [4]f32, tex : render.Texture2D, options : Rect_options, loc := #caller_location) {
	assert(lr.has_begun == true, "you must first begin with 'begin_render'", loc);

	index := len(lr.gui_data);
	write_rect_options(&lr.gui_data, options);
	append(&lr.to_render, To_render{rect, tex, index});

	return;
}

render_polygon :: proc (lr : ^Layout_render, loc := #caller_location) {
	assert(lr.has_begun == true, "you must first begin with 'begin_render'", loc);

	panic("TODO");
}

end_render :: proc(lr : ^Layout_render, loc := #caller_location) {
	assert(lr.has_begun == true, "you must first begin with 'begin_render'", loc);
	lr.has_begun = false;
	
	render.pipeline_begin(lr.pipeline, render.camera_get_pixel_space(render.get_current_render_target()), loc);

		if lr.gui_texture.width <= auto_cast len(lr.gui_data) {
			render.texture1D_resize(&lr.gui_texture, auto_cast len(lr.gui_data));
		}
		assert(lr.gui_texture.width >= auto_cast len(lr.gui_data), "texture not big enough");

		if lr.gui_data != nil {
			data := slice.reinterpret([]u8, lr.gui_data[:]);
			render.texture1D_upload_data(&lr.gui_texture, 0, len(lr.gui_data), .R32_uint, data);
		}

		render.set_texture(.texture_layren, lr.gui_texture, loc);
		for obj in lr.to_render {
			render.set_texture(.texture_diffuse, obj.tex, loc);
			render.set_uniform(.layren_index, cast(i32)obj.index);
			render.draw_quad(obj.rect);
		}

	render.pipeline_end(loc);
}

//GPU side this is a []u32
//everything must be 4 bytes
@private
Rect_gpu_layout :: struct #packed {
	fill : b32,
	is_color : b32,
	color_r : f32,
	color_g : f32,
	color_b : f32,
	color_a : f32,

	is_rect : b32, //otherwise it is a polygon, if rect use the verticies data, if polygon use the lines data.

	rounding : f32,
	
	//gradients is a length and of how many after this struct:
	gradient_cnt : u32,
	//lines is after gradients
	line_cnt : u32,
}

//texture must be a R32_uint
@(private)
write_rect_options :: proc (data : ^[dynamic]u32, opts : Rect_options) {
	
	s : Rect_gpu_layout = {};

	s.fill = auto_cast opts.fill;
	s.is_rect = true; //for this function we upload rects, so this is already true.

	s.rounding = opts.rounding[0];

	switch c in opts.color {
		case [4]f32: {
			s.is_color = true;
			s.color_r = c.r;
			s.color_g = c.g;
			s.color_b = c.b;
			s.color_a = c.a;
		} 
		case Gradient:{
			s.is_color = false;
			s.gradient_cnt = auto_cast len(c.color_stops);		
		}
	}

	s_data := transmute([]u32)runtime.Raw_Slice{&s, size_of(Rect_gpu_layout)};
	for b in s_data {
		append(data, b);
	}

	//fmt.printf("asd : %v\n", s_data);

	switch c in opts.color {
		case [4]f32: {
			//nothing to do here
		}
		case Gradient:{
			panic("todo write the gradient data here in the end");
		}
	}
}

