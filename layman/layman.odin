package furbs_layman;

import "../render"
import "../layren"
import "../laycal"

Element :: struct {
	render : layren.To_render,
	options : layren.Rect_options,
}

Layout_mananger :: struct {
	ls : laycal.Layout_state,
	lr : layren.Layout_render,

	renders : [dynamic]layren.To_render,
	options : [dynamic]Options,	
}

Layout_dir :: laycal.Layout_dir;
Alignment ::laycal.Alignment;
Anchor_point :: laycal.Anchor_point;
Axis :: laycal.Axis;
Size :: laycal.Size;
Min_size :: laycal.Min_size;
Max_size :: laycal.Max_size;
Absolute_postion :: laycal.Absolute_postion;
Overflow :: laycal.Overflow;
Parameters :: laycal.Parameters;

Shadow :: layren.Shadow;
Color_stop :: layren.Color_stop;
Gradient :: layren.Gradient;
Render_rect :: layren.Render_rect; 
Render_polygon :: layren.Render_polygon; 
To_render :: layren.To_render; 
Layout_render :: layren.Layout_render;

Fixed :: laycal.Fixed;
Parent_ratio :: laycal.Parent_ratio;
Fit :: laycal.Fit;
Grow :: laycal.Grow;
Grow_fit :: laycal.Grow_fit;
fit :: laycal.fit;
grow :: laycal.grow;
grow_fit :: laycal.grow_fit;
layout :: laycal.parameters;
visual :: laycal.parameters;

make_layout_render :: proc (lm : ^Layout_mananger = nil) -> ^Layout_mananger {
	lm := lm;

	if lm == nil {
		lm = new(Layout_mananger);
	}

	laycal.make_layout_state(&lm.ls);
	layren.make_layout_render(&lm.lr);
	
	return lm;
}

destroy_layout_render :: proc (lm : ^Layout_mananger) {
	laycal.destroy_laytout_state(&lm.ls);
	layren.destroy_layout_render(&lm.lr);
}

begin :: proc (lm : ^Layout_mananger) {
	laycal.begin_layout_state(&lm.ls, render.get_render_target_size(render.get_current_render_target()));
}

Rect_options :: layren.Rect_options;

Animation :: struct {
	rect_options : []Rect_options,
	params : laycal.Parameters,

	global_time : bool,
	time_multiplier : f32,
}

Options :: struct {
	parameters : Parameters,
	mode : union {
		Rect_options,
		Animation,
	},
}

//This uses the temp allocator.
open_element :: proc (lm : ^Layout_mananger, options : Options, debug_name : cstring = "") {

	laycal.open_element(&lm.ls, options.parameters, debug_name);
	append(&lm.options, clone_options(options, context.temp_allocator));
}

close_element :: proc (lm : ^Layout_mananger) {

	laycal.close_element(&lm.ls);
}

end :: proc (lm : ^Layout_mananger) {
	elems := laycal.end_layout_state(&lm.ls);
	
	options := Rect_options {
		Gradient{
			[]Color_stop{
				{
					[4]f32{0.8,0.2,0.5,1},
					0.1,
				},
				{
					[4]f32{0.3,0.4,0.8,1},
					0.8,
				}
			},
			{0,0},	//start the gradient at start and end it at end.
			{1,1},	//0,0 is bottom left, 1,1 is top right
			true, 	//repeat when outside 0 to 1
		},

		true,
		0, //set this if there is border (width is pixels) default is fill.
		nil,
		[4]f32{5,5,5,5} // TL, TR, BR, BL
	}
	
	for e, i in elems {
		pos := [4]f32{cast(f32)e.position.x, cast(f32)e.position.y, cast(f32)e.size.x, cast(f32)e.size.y};
		opts := lm.options[i];

		switch o in opts.mode {
			case layren.Rect_options: {
				append(&lm.renders, layren.Render_rect{
					pos,
					render.texture2D_get_white(), 
					o,
					0,
				});
			}
			case Animation: {
				panic("TODO");
			}
		}
	}
	
	layren.render(&lm.lr, lm.renders[:]);
	clear(&lm.renders)
	clear(&lm.options)
}

clone_options :: proc (options : Options, alloc := context.allocator) -> Options {
	options := options;

	switch &o in options.mode {
		case layren.Rect_options: {
			o = layren.clone_options(o, alloc);
			return options;
		}
		case Animation: {
			panic("TODO");
		}
	}

	unreachable();
}

