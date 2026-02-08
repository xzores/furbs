package furbs_layani

import "../layren"
import "../laycal"

/*
Visuals :: struct {
	color : Color_or_gradient,
	
	border : f32, //set this if it is border (width is pixels)
	shadow : Maybe(Shadow),
	rounding : [4]f32 // TL, TR, BR, BL
}

Transform :: struct {
	offset : [2]int,
	offset_anchor : Anchor_point,
	size_multiplier : f32,
	size_anchor : Anchor_point,
	rotation : f32,
	rotation_anchor : Anchor_point,
}

Animation_behavior :: enum {
	stop,
	wrap,
	reverse,
}


Layout :: struct {
	//How do children behave
	padding : [4]i32, //from sub-elements to this
	child_gap : [2]i32, //between each sub element
	
	//How does this size behave
	sizing : [2]Size,
	min_size : [2]Min_size,
	max_size : [2]Max_size,
	grow_weight : f32,

	abs_position : Maybe(Absolute_postion), //user ensure continuity
}

Options :: struct {
	// Laycal parameters
	layout_dir : Layout_dir, //for the sub-elements
	alignment : [2]Alignment, //where should we align the children to
	overflow : Overflow,
	sizing : [2]Size,
	
	layout : []struct{keyframe : f32, layout : Layout},
	
	//layren parameters (options)
	fill : bool,
	
	visual : []struct{keyframe : f32, visual : Visuals},
	transform : []struct{keyframe : f32, transform : Transform},
	
	time_multiplier : f32, 	//if some elements should animate faster
	time_offset : f32,		//if some elements times should be offset
	animation_behavior : Animation_behavior,
}






end :: proc (lm : ^Layout_mananger, time : f32, loc := #caller_location) {
	options := make([dynamic]Options, 0, len(lm.options) / 2, context.temp_allocator)
	
	//time := time;
	//time = time - math.floor(time);

	for opt in lm.options {
		switch o in opt.what {
			case Options: {

				interpolated_params : laycal.Parameters;
				
				{ //find interpolated_params
					if len(o.layout) == 0 {
						panic("There are no layout parameters", loc);
					}
					if len(o.layout) == 1 {
						l := o.layout[0].layout;
						//log.debugf("l : %v\n", l);
						interpolated_params = laycal.Parameters {
							l.padding,
							l.child_gap,
							o.layout_dir,
							o.alignment,
							o.overflow,
							
							o.sizing,
							l.min_size,
							l.max_size,
							cast(i32)(l.grow_weight * 512),

							l.abs_position,
						};
					}
					else {
						low : Layout;
						low_time : f32;
						high : Layout;
						high_time : f32;

						for p, i in o.layout {
							if p.keyframe >= time {
								//we found the lower end
								low = p.layout;
								low_time = p.keyframe;
								p2 := o.layout[(i + 1) %% len(o.layout)];
								high = p2.layout;
								high_time = p2.keyframe;
							}
							
							break;
						}

						t := (time - low_time) / (high_time - low_time);
							
						l := Layout{
							acast((acast(low.padding, f32) * t) + acast(high.padding, f32) * (1-t), i32),
							acast((acast(low.child_gap, f32) * t) + acast(high.child_gap, f32) * (1-t), i32),
							
							{interpolate_size(low.sizing[0], high.sizing[0], t), interpolate_size(low.sizing[1], high.sizing[1], t)},
							{interpolate_min_size(low.min_size[0], high.min_size[0], t), interpolate_min_size(low.min_size[1], high.min_size[1], t)},
							{interpolate_max_size(low.max_size[0], high.max_size[0], t), interpolate_max_size(low.max_size[1], high.max_size[1], t)},
							((low.grow_weight * t) + high.grow_weight * (1-t)),
							
							interpolate_abs_position(low.abs_position, high.abs_position, t), //user ensure continuity
						}

						interpolated_params = laycal.Parameters {
							l.padding,
							l.child_gap,
							o.layout_dir,
							o.alignment,
							o.overflow,
							
							o.sizing,
							l.min_size,
							l.max_size,
							cast(i32)(l.grow_weight * 512),

							l.abs_position,
						};
					}
				}
				
				//log.debugf("interpolated_params : %v\n", interpolated_params);
				laycal.open_element(&lm.ls, interpolated_params, fmt.ctprint("", opt.loc));
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
		
		rect_options : layren.Rect_options;
		
		if len(opts.visual) == 0 {
			panic("missing visual");
		}
		else if len(opts.visual) == 1 {
			visual := opts.visual[0].visual;

			rect_options = {
				visual.color,
				
				opts.fill,
				visual.border, //set this if it is border (width is pixels)
				visual.shadow,
				visual.rounding, // TL, TR, BR, BL
			}
		}
		else {
			visual : Visuals;
			
			{
				low_vis : Visuals;
				low_time : f32 = -1;
				high_vis : Visuals;
				high_time : f32 = -1;
				
				time := time * opts.time_multiplier + opts.time_offset;

				switch opts.animation_behavior {
					case .stop: {
						time = clamp(time, 0, 1);
					}
					case .wrap:{
						time = time - math.floor(time);
						//fmt.printf("wrap t : %v", time);
					}
					case .reverse: {
						if cast(int)math.floor(time) %% 2 == 0 {
							time = time - math.floor(time);
						}
						else {
							time = 1 - (time - math.floor(time));
						}
						//fmt.printf("REVERSE t : %v", time);
					}
				}

				for vis, i in opts.visual {
					if vis.keyframe <= time {
						low_vis = vis.visual;
						low_time = vis.keyframe;
						//log.debugf("i is %v and i+1 is %v", i, (i + 1) %% len(opts.visual));
						high := opts.visual[(i + 1) %% len(opts.visual)];
						high_time = high.keyframe;
						high_vis = high.visual;
					}
				}

				//log.debugf("vis was not it, time : %v, key: %v", time, low_time);
				if low_time == -1 && high_time == -1 {
					//we did not find a place that was higher then time, so we wrap back or clamp depending on behavior
				}

				fmt.assertf(high_time != low_time, "both high and low end is %v and %v, t : %v", high_time, low_time, time);
				
				//interpolate the two
				visual = Visuals {
					interpolate_color_or_gradient(low_vis.color, high_vis.color, time),
					low_vis.border * time + high_vis.border * (1-time),
					nil,
					low_vis.rounding * time + high_vis.rounding * (1-time),
				}
				//log.debugf("settings rect options : %v\n", t);
			}
			
			rect_options = {
				visual.color,
				
				opts.fill,
				visual.border, //set this if it is border (width is pixels)
				visual.shadow,
				visual.rounding, // TL, TR, BR, BL
			}
		}

		/*
		log.debugf("a : %v", layren.Render_rect{
			pos,
			render.texture2D_get_white(), 
			rect_options,
			0,
		});
		*/
		append(&lm.renders, layren.Render_rect{
			pos,
			render.texture2D_get_white(), 
			rect_options,
			0,
		});
	}
	
	layren.render(&lm.lr, lm.renders[:]);
	clear(&lm.renders);
	clear(&lm.options);
}

clone_options :: proc (options : Options, alloc := context.allocator) -> Options {
	options := options;
	
	options.layout = slice.clone(options.layout, alloc);
	options.visual = slice.clone(options.visual, alloc);
	for &visual in options.visual {
		switch &v in visual.visual.color {
			case Gradient:
				v.color_stops = slice.clone(v.color_stops);
			case [4]f32:
				//nothing
		}
	}
	options.transform = slice.clone(options.transform, alloc);

	return options; 
}


*/

Color_or_gradient :: layren.Color_or_gradient;
Color_stop :: layren.Color_stop;
Gradient :: layren.Gradient;


Fixed :: laycal.Fixed;
Fit :: laycal.Fit;
Parent_ratio :: laycal.Parent_ratio;
Min_size :: laycal.Min_size;
Max_size :: laycal.Max_size;
Size :: laycal.Size;


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