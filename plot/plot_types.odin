package plot;

import "../render"
import "../regui"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:slice"
import "core:strings"
import "core:math/linalg"

import "base:runtime"

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

get_callout_info :: proc (plot : ^Plot_xy, target_size : [2]i32, rect : [4]f32, color_theme : Color_theme, callout_line_length : f32, callout_line_width : f32) -> (lines : []Line, texts : []Text, x_callout, y_callout : []Callout_line) {
	
	using color_theme;
	
	//Callouts
	{
		grid_cnt := [2]f64{5.0 * cast(f64)rect.z, 12 * cast(f64)rect.w};
		
		get_callout_lines_linear :: proc (min_view, max_view : f64, grid_cnt : int, sub_divisions : int, min_max_callouts : bool, callout_line_length, callout_line_width : f32) -> ([dynamic]Callout_line) {
			
			callout_dyn := make([dynamic]Callout_line);
			total := max_view - min_view;
			
			if min_max_callouts {
				append(&callout_dyn, Callout_line{callout_line_length / 3, callout_line_width, 0, min_view, true});
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
						append(&callout_dyn, Callout_line{callout_line_length, callout_line_width, placement, cur, true});
					}
					else {
						append(&callout_dyn, Callout_line{callout_line_length, callout_line_width, placement, cur, false});
					}
				}
				else {
					append(&callout_dyn, Callout_line{callout_line_length / 3, callout_line_width / 3, placement, cur, false});
				}
			}
			
			if min_max_callouts {
				append(&callout_dyn, Callout_line{callout_line_length, callout_line_width, 1, max_view, true});
			}
			
			return callout_dyn;
		}

		get_callout_lines_log :: proc (min_view, max_view : f64, grid_cnt : int, base : f64, sub_divisions : int, min_max_callouts : bool, callout_line_length, callout_line_width : f32) -> ([dynamic]Callout_line) {
			
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
						append(&callout_dyn, Callout_line{callout_line_length, callout_line_width, placement, cur, false});
					}
					else {
						append(&callout_dyn, Callout_line{callout_line_length, callout_line_width, placement, cur, true});
						last_text = cur;
					}
				}
				else {
					append(&callout_dyn, Callout_line{callout_line_length / 3, callout_line_width / 3, placement, cur, false});
				}
				
			}
			
			return callout_dyn;
		}
		
		p := plot;
		switch p.log_x {
			case .no_log:
				x_callout = get_callout_lines_linear(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, 5, true, callout_line_length, callout_line_width)[:];
			case .base10:
				x_callout = get_callout_lines_log(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, 10, 5, true, callout_line_length, callout_line_width)[:];
			case .base_2:
				x_callout = get_callout_lines_log(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, 2, 5, true, callout_line_length, callout_line_width)[:];
			case .base_ln:
				x_callout = get_callout_lines_log(p.x_view[0], p.x_view[1], auto_cast grid_cnt.x, math.e, 5, true, callout_line_length, callout_line_width)[:];
		}
		
		switch p.log_y {
			case .no_log:
				y_callout = get_callout_lines_linear(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, 5, true, callout_line_length, callout_line_width)[:];
			case .base10:
				y_callout = get_callout_lines_log(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, 10, 5, true, callout_line_length, callout_line_width)[:];
			case .base_2:
				y_callout = get_callout_lines_log(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, 2, 5, true, callout_line_length, callout_line_width)[:];
			case .base_ln:
				y_callout = get_callout_lines_log(p.y_view[0], p.y_view[1], auto_cast grid_cnt.y, math.e, 5, true, callout_line_length, callout_line_width)[:];
		}
	}
	
	_lines : [dynamic]Line;
	_texts : [dynamic]Text;
	
	for call in x_callout {
		x := rect.x + (cast(f32)call.placement * rect.z);
		append(&_lines, Line{{x, rect.y}, {x, rect.y - call.length}, call.thickness, inverse_color})
	}
	for call in y_callout {
		y := rect.y + (cast(f32)call.placement * rect.w);
		append(&_lines, Line{{rect.x, y}, {rect.x - call.length, y}, call.thickness, inverse_color})
	}
	
	append(&_lines, Line{{rect.x, rect.y}, {rect.x + rect.z, rect.y}, callout_line_width, inverse_color});
	append(&_lines, Line{{rect.x, rect.y}, {rect.x, rect.y + rect.w}, callout_line_width, inverse_color});
	
	//Draw the callout lines around the plot, including the entries (like numbers).
	{
		text_size : f32 = cast(f32)target_size.y / 26;
		for call in x_callout {
			if call.display_value {
				x := rect.x + (cast(f32)call.placement * rect.z);
				
				low_p, high_p := plot.x_view[0], plot.x_view[1];
				
				val := low_p + call.placement * (high_p - low_p);						
				s_val := format_val(val);
				bounds := render.text_get_visible_bounds(s_val, text_size, render.get_default_fonts().normal);
				text_pos : [2]f32 = ({x, rect.y - call.length} * cast(f32)target_size.y) - ({bounds.z/2, bounds.w} * 1.1);
				append(&_texts, Text{strings.clone(s_val), text_pos, text_size, inverse_color, 0, backdrop_color, {1.5,-1.5}});
			}				
		}
		for call in y_callout {
			if call.display_value {
				y := rect.y + (cast(f32)call.placement * rect.w);
				
				low_p, high_p := plot.y_view[0], plot.y_view[1];
				
				val := low_p + call.placement * (high_p - low_p);
				s_val := format_val(val);
				bounds := render.text_get_visible_bounds(s_val, text_size, render.get_default_fonts().normal);
				text_pos : [2]f32 = ({rect.x - call.length, y} * cast(f32)target_size.y) - ([2]f32{bounds.z, bounds.w/2} * 1.1);
				append(&_texts, Text{strings.clone(s_val), text_pos, text_size, inverse_color, 0, backdrop_color, {1.5,-1.5}});
			}
		}
	}
	
	return _lines[:], _texts[:], x_callout, y_callout;
}

plot_inner :: proc (p : ^Plot_xy, inner_target_size : [2]i32, rect : [4]f32, x_callout, y_callout : []Callout_line, allow_state_change : bool) {
	
	//Calculate normalized space coordinates.
	width_f, height_f := cast(f32)inner_target_size.x, cast(f32)inner_target_size.y;
	aspect_ratio := width_f / height_f;
	width, height : f32 = aspect_ratio, 1.0;
	
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
		
		pv_size : [2]f32 = {rect.x - (1.0 - rect.z), rect.y - (1.0 - rect.w)};
		
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
					
					if len(trace.abscissa) == 0 {
						continue;
					}
					
					trace_draw_data := make([]render.Default_instance_data, len(trace.abscissa), allocator = context.temp_allocator);
					color, marker_style := get_trace_info(it);
					
					//TODO draw_quad_instanced();
					//assert(len(abscissa) != 0, "The signal is empty");
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
						
						x1 : f32 = cast(f32)((x_coor1 - p.x_view[0]) / (p.x_view[1] - p.x_view[0]));
						x2 : f32 = cast(f32)((x_coor2 - p.x_view[0]) / (p.x_view[1] - p.x_view[0]));
						y1 : f32 = cast(f32)((y_coor1 - p.y_view[0]) / (p.y_view[1] - p.y_view[0]));
						y2 : f32 = cast(f32)((y_coor2 - p.y_view[0]) / (p.y_view[1] - p.y_view[0]));
						
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

update_xy_plot :: proc (plot : Plot_xy, mouse_pos : [2]f32, hover, focus : bool) {
	
	// x_view, y_view,
	
}

//Renders the plot into the target texture.
render_xy_plot :: proc (plot : ^Plot_xy, target : render.Frame_buffer, mouse_pos : [2]f32, color_theme := light_color_theme) {
	target := target;
	
	//////////////////////////// Framebuffers and size calculations ////////////////////////////
	
	assert(target.id != 0, "framebuffer is nil");
	assert(plot.inner_plot_framebuffer.id != 0, "framebuffer is nil");
	
	//Calculate normalized space coordinates.
	width_i, height_i := render.get_render_target_size(&target);
	width_f, height_f := cast(f32)width_i, cast(f32)height_i;
	aspect_ratio := width_f / height_f;
	width, height : f32 = aspect_ratio, 1.0; //in unit size
	
	label_size : f32 = 1.0 / 18.0;
	margin : f32 = 0.04;
	callout_line_length : f32 = 0.03;
	callout_line_width : f32 = 0.003;
	
	callout_x_space : f32 = callout_line_length + label_size * 1.5; //WHY times 1.5? well, i pulled it out my ass.
	callout_y_space : f32 = callout_line_length + label_size * 0.4; //WHY times 1.5? well, i pulled it out my ass.
	inner_plot_rect := [4]f32{0, 0, width_f, height_f} + height_f * [4]f32{margin + callout_x_space, margin + callout_y_space, - 2 * margin - callout_x_space, - 2 * margin - callout_y_space};
	
	r_state := render.store_target(); {
		
		//////////////////////////// FIND INNER PLOT SIZE ////////////////////////////
		
		label_text_size : f32 = height_f * label_size;
		
		if plot.x_label != "" {
			text_pos := [2]f32{0.5 * width_f, margin * height_f};
			dims := render.text_get_visible_bounds(plot.x_label, label_text_size);
			inner_plot_rect.y += dims.w;
			inner_plot_rect.w -= dims.w;
		}
		if plot.y_label != "" {
			text_pos := [2]f32{margin * width_f, 0.5 * height_f};
			dims := render.text_get_visible_bounds(plot.y_label, label_text_size);
			inner_plot_rect.x += dims.w;
			inner_plot_rect.z -= dims.w;
		}
		if plot.title != "" {
			text_pos := [2]f32{0.5 * width_f, (1 - margin) * height_f};
			dims := render.text_get_visible_bounds(plot.title, label_text_size);
			inner_plot_rect.w -= dims.w;
		}
		
		inner_target_size_i := linalg.array_cast(inner_plot_rect.zw, i32);
		if plot.inner_plot_framebuffer.width != inner_target_size_i.x || plot.inner_plot_framebuffer.height != inner_target_size_i.y {
			
			render.frame_buffer_resize(&plot.inner_plot_framebuffer, inner_target_size_i);
			render.texture2D_resize(&plot.inner_plot_texture, inner_target_size_i);
		}
		
		//////////////////////////// Callout info ////////////////////////////
		
		lines, texts, x_callout, y_callout := get_callout_info(plot, {width_i, height_i}, inner_plot_rect / height_f, color_theme, callout_line_length, callout_line_width);
		defer {
			delete(lines);
			
			for t in texts {
				delete(t.value);
			}
			delete(texts);
			delete(x_callout);
			delete(y_callout);
		}
		
		//////////////////////////// DRAWING ////////////////////////////
		
		render.target_begin(&plot.inner_plot_framebuffer,  color_theme.plot_bg_color);
			plot_inner(plot, linalg.array_cast(inner_plot_rect.zw, i32), inner_plot_rect / height_f, x_callout, y_callout, false);
		render.target_end();
		
		cam_2d : render.Camera2D = {
			position		= {width / 2, height / 2},
			target_relative	= {width / 2, height / 2},
			rotation		= 0,
			zoom 			= 2,
			near 			= -1,
			far 			= 1,
		};		
		render.target_begin(&target, [4]f32{1,1,1,1});
			
			if plot.x_label != "" {
				text_pos := [2]f32{0.5 * width_f, margin * height_f};
				dims := render.text_get_visible_bounds(plot.x_label, label_text_size);
				render.text_draw(plot.x_label, text_pos - dims.zw/2, label_text_size, false, false, color_theme.inverse_color, {color_theme.backdrop_color, {1.5,-1.5}}, rotation = 0);
			}
			if plot.y_label != "" {
				text_pos := [2]f32{margin * width_f, 0.5 * height_f};
				dims := render.text_get_visible_bounds(plot.y_label, label_text_size);
				render.text_draw(plot.y_label, text_pos - dims.wz/2, label_text_size, false, false, color_theme.inverse_color, {color_theme.backdrop_color, {1.5,-1.5}}, rotation = 90);
			}
			if plot.title != "" {
				text_pos := [2]f32{0.5 * width_f, (1 - margin) * height_f};
				dims := render.text_get_visible_bounds(plot.title, label_text_size);
				render.text_draw(plot.title, text_pos - dims.zw/2, label_text_size, false, false, color_theme.inverse_color, {color_theme.backdrop_color, {1.5,-1.5}}, rotation = 0);
			}
			
			draw_pipeline := render.pipeline_make(render.get_default_shader(), depth_test = false);
			defer render.pipeline_destroy(draw_pipeline);
			render.pipeline_begin(draw_pipeline, cam_2d);
				
				//it was using direct draw, so draw whatever is in the texture.
				render.frame_buffer_blit_color_attach_to_texture(&plot.inner_plot_framebuffer, 0, plot.inner_plot_texture);
				render.set_texture(.texture_diffuse, plot.inner_plot_texture);
				render.draw_quad_rect(inner_plot_rect / height_f, 0);
				
				render.set_texture(.texture_diffuse, render.texture2D_get_white());
				text_pos := [2]f32{0.5 * width_f, 1 * width_f};
				dims := render.text_get_visible_bounds(plot.title, label_text_size);
				
				for l in lines {
					render.draw_line_2D(l.a, l.b, l.thickness, 0, l.color);
				}
				
				for t in texts {
					render.text_draw(t.value, t.position, t.size, false, false, t.color, {t.backdrop_color, t.backdrop}, rotation = t.rotation);
				}
				
			render.pipeline_end()
		
			
		render.target_end();
		
	} render.restore_target(r_state);

	
}
