package furbs_layman;

import "core:math"
import "core:slice"
import "core:fmt"
import "core:log"
import "vendor:OpenEXRCore"
import "core:math/linalg"
import "base:runtime"

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
	options : [dynamic]Options_or_pop,	
}

Pop :: struct {}

@(private)
Options_or_pop :: struct {
	what : union {
		Options,
		Pop,
	},
	loc : runtime.Source_Code_Location,
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

Color_or_gradient :: layren.Color_or_gradient;

Transform :: struct {
	offset : [2]int,
	offset_anchor : Anchor_point,
	size_multiplier : f32,
	size_anchor : Anchor_point,
	rotation : f32,
	rotation_anchor : Anchor_point,
}

Layout :: laycal.Parameters;
Visuals :: layren.Rect_options;

@(private)
Options :: struct {
	layout : Layout,
	visual : Visuals,
	transform : Transform,
}

default_transform := Transform {
	{0,0},
	.center_center,
	1,
	.center_center,
	0,
	.center_center,
}

//This uses the temp allocator.
open_element :: proc (lm : ^Layout_mananger, layout : Layout, visual : Visuals, transform := default_transform, loc := #caller_location) {
	append(&lm.options, Options_or_pop{clone_options({layout, visual, transform}, context.temp_allocator), loc});
}

close_element :: proc (lm : ^Layout_mananger, loc := #caller_location) {
	append(&lm.options, Options_or_pop{Pop{}, loc});
}

interpolate_abs_position :: proc (a, b : Maybe(Absolute_postion), t : f32) -> Absolute_postion {

	return {};
}

acast :: linalg.array_cast;

//time: what is the current time.
end :: proc (lm : ^Layout_mananger, time : f32, loc := #caller_location) {
	options := make([dynamic]Options, 0, len(lm.options) / 2, context.temp_allocator)
	
	//time := time;
	//time = time - math.floor(time);

	for opt in lm.options {
		switch o in opt.what {
			case Options: {
				
				//log.debugf("interpolated_params : %v\n", interpolated_params);
				laycal.open_element(&lm.ls, o.layout, fmt.ctprint("", opt.loc));
				append_elem(&options, o);
			}
			case Pop: {
				laycal.close_element(&lm.ls);
			}
		}
	}
	
	elems := laycal.end_layout_state(&lm.ls);
	for e, i in elems {
		pos := [4]f32{cast(f32)e.position.x, cast(f32)e.position.y, cast(f32)e.size.x, cast(f32)e.size.y};
		opts := options[i];
		
		append(&lm.renders, layren.Render_rect{
			pos,
			render.texture2D_get_white(), 
			opts.visual,
			0,
		});
	}
	
	layren.render(&lm.lr, lm.renders[:]);
	clear(&lm.renders);
	clear(&lm.options);
}

clone_options :: proc (options : Options, alloc := context.allocator) -> Options {
	options := options;
	options.visual = layren.clone_options(options.visual);
	return options; 
}

interpolate_color_or_gradient :: proc (a, b : Color_or_gradient, t : f32, loc := #caller_location) -> Color_or_gradient {

	res : Color_or_gradient;
	
	switch c1 in a {
		case layren.Gradient: {
			switch c2 in b {
				case layren.Gradient:
					//create a new slice with the new color stops
					assert(len(c1.color_stops) == len(c2.color_stops), "must have same number of color stops", loc);
					stops := make([]Color_stop, len(c1.color_stops));
					
					for &s, i in stops {
						s1 := c1.color_stops[i];
						s2 := c2.color_stops[i];

						color := s1.color * t + s2.color * (1-t);
						//log.debugf("color 1 : %v, color 2 : %v, t : %v, ", s1.color, s2.color, t);
						stop := s1.stop * t + s2.stop * (1-t);

						s = {color, stop}
					}

					new_grad : Gradient = {
						stops,
						c1.start * t + c2.start * (1-t),
						c1.end * t + c2.end * (1-t),	//0,0 is bottom left, 1,1 is top right
						c1.wrap, 	//repeat when outside 0 to 1
						c1.offset * t + c2.offset * (1-t),
					}

					res = new_grad;

				case [4]f32:
					panic("TODO");
			}
		}
		case [4]f32: {
			switch c2 in b {
				case layren.Gradient:
					panic("TODO");
				case [4]f32:
					res = c1 * t + c2 * (1 * t);
			}
		}
	}


	return res;
}

@(private, require_results)
interpolate_min_size :: proc (a, b : Min_size, t : f32) -> Min_size {
	switch m1 in a {
		case laycal.Fixed: {
			t := cast(Fixed)t;
			m2, ok := b.(laycal.Fixed);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return t * m1 + m2 * (1-t);
		}
		case laycal.Fit: {
			m2, ok := b.(laycal.Fit);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return laycal.Fit{};
		}
		case laycal.Parent_ratio: {
			t := cast(Parent_ratio)t;
			m2, ok := b.(laycal.Parent_ratio);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return t * m1 + m2 * (1-t);
		}
	}
	
	unreachable();
}

@(private, require_results)
interpolate_max_size :: proc (a, b : Max_size, t : f32) -> Max_size {
	switch m1 in a {
		case laycal.Fixed: {
			t := cast(Fixed)t;
			m2, ok := b.(laycal.Fixed);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return t * m1 + m2 * (1-t);
		}
		case laycal.Parent_ratio: {
			t := cast(Parent_ratio)t;
			m2, ok := b.(laycal.Parent_ratio);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return t * m1 + m2 * (1-t);
		}
	}
	
	unreachable();
}

@(private, require_results)
interpolate_size :: proc (a, b : Size, t : f32) -> Size {
	switch s1 in a {
		case laycal.Fixed: {
			t := cast(Fixed)t;
			s2, ok := b.(laycal.Fixed);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return t * s1 + s2 * (1-t);
		}
		case laycal.Parent_ratio: {
			t := cast(Parent_ratio)t;
			s2, ok := b.(laycal.Parent_ratio);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return t * s1 + s2 * (1-t);
		}
		case laycal.Fit: {
			s2, ok := b.(laycal.Fit);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return laycal.Fit{};
		}
		case laycal.Grow: {
			s2, ok := b.(laycal.Grow);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return laycal.Grow{};
		}
		case laycal.Grow_fit: {
			s2, ok := b.(laycal.Grow_fit);
			assert(ok, "todo, cannot yet interpolate between differnt sizing options");
			return laycal.Grow_fit{};
		}
	}

	unreachable();
}