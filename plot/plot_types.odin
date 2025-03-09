package plot;

import "../render"
import gui "../regui"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:slice"

Line :: struct {
	a : [2]f32,
	b : [2]f32,
	thickness : f32,
	color : [4]f32,
}

Callout_line :: struct {
	length : f32,
	thickness : f32,
	
	placement : f64,
	
	value : f64,
	display_value : bool,
}

Arc :: struct {
	
}

Text :: struct {
	value : string,
	position : [2]f32,
	size : f32,
	color : [4]f32,
	
	rotation : f32,
	
	backdrop_color : [4]f32,
	backdrop : [2]f32,
}

Image :: struct {
	rect : [4]f32,
	tex : render.Texture2D,
}

Image_data :: struct {
	width : int,
	height : int,
	data : []u8,
}

Plot_data :: struct {
	lines : []Line,
	arcs : []Arc,
	texts : []Text,
}

//If this is nil, it will assume direct draw (you call draw from the function)
Plot_result :: union {
	//Image_data, //TODO
	Plot_data,
}

get_callout_lines_linear :: proc (min_view, max_view : f64, grid_cnt : int, sub_divisions : int = 5, min_max_callouts : bool = true) -> ([dynamic]Callout_line) {
	
	callout_dyn := make([dynamic]Callout_line);
	total := max_view - min_view;
	
	if min_max_callouts {
		append(&callout_dyn, Callout_line{0.03, 0.003, 0, min_view, true});
	}
	
	r := 1e-15;
	base : f64 = nice_round(total / f64(grid_cnt), r);
	for base == 0 && total != 0 {
		r *= 10;
		base = nice_round(total / f64(grid_cnt), r);
	}
	
	cur : f64 = math.round(min_view / base) * base - base;
	
	for i in 0..=((2 * grid_cnt + 10) * sub_divisions) {
		cur += base / f64(sub_divisions);
		
		if cur < (min_view) {
			continue;
		}
		
		if cur > (max_view) {
			continue;
		}
		
		placement := (cur - min_view) / total;
		if i %% sub_divisions == 0 {
			
			if !(cur < (min_view + base / 2)) && !(cur > (max_view - base / 2)) || !min_max_callouts { //Dont draw text if it gets to close.
				append(&callout_dyn, Callout_line{0.03, 0.003, placement, cur, true});
			}
			else {
				append(&callout_dyn, Callout_line{0.03, 0.003, placement, cur, false});
			}
		}
		else {
			append(&callout_dyn, Callout_line{0.01, 0.001, placement, cur, false});
		}
	}
	
	if min_max_callouts {
		append(&callout_dyn, Callout_line{0.03, 0.003, 1, max_view, true});
	}
	
	return callout_dyn;
}

get_callout_lines_log :: proc (min_view, max_view : f64, grid_cnt : int, base : f64, sub_divisions : int = 10) -> ([dynamic]Callout_line) {
	
	callout_dyn := make([dynamic]Callout_line);
	total := max_view - min_view;
	
	assert(min_view > 0, "Cannot plot a log plot and start at zero or below.");
	
	exp : f64 = 1;
	for exp > min_view {
		exp /= base;
	}
	
	for exp < min_view {
		exp *= base;
	}
	
	last_text := math.inf_f64(-1);
	
	cur : f64 = exp;
	i := -(sub_divisions-1);
	for cur < max_view {
		cur = math.pow(base, f64(i)/f64(sub_divisions)) * exp;
		defer i += 1;
		
		if cur < (min_view) {
			continue;
		}
		
		if cur > (max_view) {
			continue;
		}
		
		placement := (cur - min_view) / total;
		
		if i %% sub_divisions == 0 {
			
			if !(cur - last_text > total / f64(grid_cnt) / 2) {
				append(&callout_dyn, Callout_line{0.03, 0.003, placement, cur, false});
			}
			else {
				append(&callout_dyn, Callout_line{0.03, 0.003, placement, cur, true});
				last_text = cur;
			}
		}
		else {
			append(&callout_dyn, Callout_line{0.01, 0.001, placement, cur, false});
		}
		
	}
	
	return callout_dyn;
}

plot_inner :: proc (p : ^Plot_xy, width_i, height_i : i32, allow_state_change : bool) -> 
		(res : Plot_result, pv_pos, pv_size : [2]f32, x_view, y_view : [2]f64, x_callout, y_callout : []Callout_line, x_label, y_label, title : string) {
	
	//Calculate normalized space coordinates.
	width_f, height_f := cast(f32)width_i, cast(f32)height_i;
	aspect_ratio := width_f / height_f;
	width, height : f32 = aspect_ratio, 1.0;
	
	res = nil;
	{
		instanced_pipeline := render.pipeline_make(render.get_default_instance_shader(), depth_test = false);
		defer render.pipeline_destroy(instanced_pipeline);
		
		cam_2d : render.Camera2D = {
			position		= {width / 2, height / 2},
			target_relative	= {width / 2, height / 2},
			rotation		= 0,
			zoom 			= 2,
			near 			= -1,
			far 			= 1,
		};
		
		//handle export variables
		{
			
			x_label = p.x_label;
			y_label = p.y_label;
			title = p.title;
			
			//plot view
			pv_pos = {0.20, 0.10};
			size : [2]f32 = {0.75, 0.82};
			pv_size = {width - (1.0 - size.x), height - (1.0 - size.y)};
			
			//inner view
			x_view = p.x_view;
			y_view = p.y_view;

		}
		
		//handle input and change state
		if allow_state_change {
			
			//TODO handle this differently we are in log mode.
			if render.is_button_down(.middel) {
				md := render.mouse_delta();
				
				total_x : f32 = cast(f32)(p.x_view[1] - p.x_view[0]);
				total_y : f32 = cast(f32)(p.y_view[1] - p.y_view[0]);
				p.x_view -= cast(f64)((total_x / pv_size.x) * (md.x / height_f));
				p.y_view += cast(f64)((total_y / pv_size.y) * (md.y / height_f));
			}
			
			//TODO handle this differently we are in log mode.
			{
				scroll_delta := render.scroll_delta();
				
				total_x : f64 = cast(f64)(p.x_view[1] - p.x_view[0]);
				total_y : f64 = cast(f64)(p.y_view[1] - p.y_view[0]);
				
				d : f64 = -0.02 * cast(f64)scroll_delta.y;
				
				if !render.is_key_down(.shift_left) {
					p.x_view = p.x_view + d * [2]f64{-total_x, total_x};
				}
				if !render.is_key_down(.control_left) {
					p.y_view = p.y_view + d * [2]f64{-total_y, total_y};
				}
			}
			
			if render.is_key_down(.r) {
				xlow, xhigh, ylow, yhigh : f64 = max(f64), min(f64), max(f64), min(f64);
				for trace in p.traces {
					xl, xh := get_extremes(trace.abscissa);
					yl, yh := get_extremes(trace.ordinate);
					xlow = 	math.min(xlow, xl);
					xhigh = math.max(xhigh, xh);
					ylow = 	math.min(ylow, yl);
					yhigh = math.max(yhigh, yh);
				}
				
				total_y := yhigh - ylow;
				
				p.x_view = {xlow, xhigh};
				p.y_view = {ylow - 0.1 * total_y, yhigh + 0.1 * total_y};
			}
		}
		
		if p.log_x != .no_log {
			p.x_view[0] = math.max(p.x_view[0], 1e-15);
		}				
		p.x_view[1] = math.max(p.x_view[0] + 1e-15, p.x_view[1]);
		
		if p.log_y != .no_log {
			p.y_view[0] = math.max(p.y_view[0], 1e-15);
		}
		p.y_view[1] = math.max(p.y_view[0] + 1e-15, p.y_view[1]);
		
		//Callouts
		{
			grid_cnt := [2]f64{5.0 * cast(f64)width, 12 * cast(f64)height};
			
			switch p.log_x {
				case .no_log:
					x_callout = get_callout_lines_linear(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x)[:];
				case .base10:
					x_callout = get_callout_lines_log(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, 10)[:];
				case .base_2:
					x_callout = get_callout_lines_log(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, 2)[:];
				case .base_ln:
					x_callout = get_callout_lines_log(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, math.e)[:];
			}
			
			switch p.log_y {
				case .no_log:
					y_callout = get_callout_lines_linear(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y)[:];
				case .base10:
					y_callout = get_callout_lines_log(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, 10)[:];
				case .base_2:
					y_callout = get_callout_lines_log(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, 2)[:];
				case .base_ln:
					y_callout = get_callout_lines_log(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, math.e)[:];
			}
		}
		
		//Plot the inner plot
		{
			render.pipeline_begin(instanced_pipeline, cam_2d);
				render.set_texture(.texture_diffuse, render.texture2D_get_white());
				
				grid_line_width := p.grid_desc.line_width * min(width, height);
				
				call_draw_data := make([]render.Default_instance_data, len(x_callout) + len(y_callout), allocator = context.temp_allocator);
				i : int = 0;
				for call in x_callout {
					x : f32 = cast(f32)call.placement * width;
					trans, rot, scale := render.line_2D_to_quad_trans_rot_scale({x,0}, {x,height}, grid_line_width);
					
					call_draw_data[i] = render.Default_instance_data {
							instance_position 	= trans,
							instance_scale 		= scale,
							instance_rotation 	= rot, //Euler rotation
							instance_tex_pos_scale 	= {},
					};
					i += 1;
				}
				for call in y_callout {
					y : f32 = cast(f32)call.placement * height;
					trans, rot, scale := render.line_2D_to_quad_trans_rot_scale({0,y}, {width,y}, grid_line_width);
					
					call_draw_data[i] = render.Default_instance_data {
							instance_position 	= trans,
							instance_scale 		= scale,
							instance_rotation 	= rot, //Euler rotation
							instance_tex_pos_scale 	= {},
					};
					i += 1;
				}
				
				render.draw_quad_instanced(call_draw_data[:], p.grid_desc.color, offset = {0.5, 0, 0});
				
				line_width := 0.005 * min(width, height);
				
				for trace, it in p.traces {
					using trace;
					
					trace_draw_data := make([]render.Default_instance_data, len(trace.abscissa), allocator = context.temp_allocator);
					color, marker_style := get_trace_info(it);
					
					//TODO draw_quad_instanced();
					assert(len(abscissa) != 0, "The signal is empty");
					fmt.assertf(len(abscissa) == len(ordinate), "The x and y does not have same length. x length is %v, y length is %v", len(abscissa), len(ordinate));
					
					_, max_x_val := get_extremes(abscissa);
					_, max_y_val := get_extremes(ordinate);
					
					for e, i in ordinate[:len(ordinate)-1] {
						x_coor1 := abscissa[i];
						x_coor2 := abscissa[i+1];
						
						y_coor1 := cast(f64)e;
						y_coor2 := cast(f64)ordinate[i+1];
						
						switch p.log_x {
							case .no_log:
								//do nothing
							case .base10:
								x_coor1 = math.log10(x_coor1);
								x_coor2 = math.log10(x_coor2);
							case .base_2:
								x_coor1 = math.log2(x_coor1);
								x_coor2 = math.log2(x_coor2);
							case .base_ln:
								x_coor1 = math.ln(x_coor1);
								x_coor2 = math.ln(x_coor2);
						}
						
						/*
						switch p.log_y {
							case .no_log:
								//do nothing
							case .base10:
								mult := max_y_val / math.log10(max_y_val);
								y_coor1 = math.log10(y_coor1) * mult;
								y_coor2 = math.log10(y_coor2) * mult;
							case .base_2:
								mult := max_y_val / math.log2(max_y_val);
								y_coor1 = math.log2(y_coor1);
								y_coor2 = math.log2(y_coor2);
							case .base_ln:
								mult := max_y_val / math.ln(max_y_val);
								y_coor1 = math.ln(y_coor1);
								y_coor2 = math.ln(y_coor2);
						}
						*/						
						
						x1 : f32 = cast(f32)((x_coor1 - x_view[0]) / (x_view[1] - x_view[0]));
						x2 : f32 = cast(f32)((x_coor2 - x_view[0]) / (x_view[1] - x_view[0]));
						y1 : f32 = cast(f32)((y_coor1 - y_view[0]) / (y_view[1] - y_view[0]));
						y2 : f32 = cast(f32)((y_coor2 - y_view[0]) / (y_view[1] - y_view[0]));
						
						trans, rot, scale := render.line_2D_to_quad_trans_rot_scale({x1 * width, y1 * height}, {x2 * width, y2 * height}, line_width, 0);
						
						trace_draw_data[i] = render.Default_instance_data {
							instance_position 	= trans,
							instance_scale 		= scale,
							instance_rotation 	= rot, //Euler rotation
							instance_tex_pos_scale 	= {},
						};
					}
					
					render.draw_quad_instanced(trace_draw_data[:], color, offset = {0.5, 0, 0});
			}
			render.pipeline_end();
		}
		
		return;
	}
	
	unreachable();
}

