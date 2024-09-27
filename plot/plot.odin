package plot;

import "../render"
import gui "../regui"
import "core:time"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:slice"

Grid_desc :: struct {
	color : [4]f32,
	line_width : f32,
}

Axis_desc :: struct {
	name : string, 
	span : Span(f64),
	unit : string,
}

Plot_xy :: struct {
	abscissa : []f32,
	ordinate : []f32,
	
	//plot_desc : 
	grid_desc : Grid_desc,
	axis_desc : [2]Maybe(Axis_desc),
	
	x_view : [2]f32,
	y_view : [2]f32,
	
	top_bar : gui.Panel,
}

Plot_type :: union {
	Plot_xy,
};

Plot_window :: struct {
	window : ^render.Window,
	plot_type : Plot_type,
	gui_state : gui.Scene,
	
	plot_framebuffer : render.Frame_buffer,
	plot_texture : render.Texture2D,
}

Light_mode :: enum {
	dark_mode,
	bright_mode,
}

plot_bg_colors : [Light_mode][4]f32 = 	{.dark_mode = [4]f32{0.2, 0.2, 0.2, 1}, 	.bright_mode = [4]f32{1, 1, 1, 1}};
base_colors : [Light_mode][4]f32 = 		{.dark_mode = [4]f32{0.17, 0.17, 0.17, 1}, 	.bright_mode = [4]f32{1, 1, 1, 1}};
inverse_colors : [Light_mode][4]f32 = 	{.dark_mode = [4]f32{0.8, 0.8, 0.8, 1}, 			.bright_mode = [4]f32{0, 0, 0, 1}};
backdrop_colors : [Light_mode][4]f32 = 	{.dark_mode = [4]f32{0, 0, 0, 1}, 			.bright_mode = [4]f32{1, 1, 1, 1}};

Span :: struct(T : typeid) {
	begin : T,
	end : T,
	dist : T,
}

Ordinate :: union {
	[]int,
	[]f32,	//included beacuse it is common
	[]f64,
	[][2]f64,
	[][3]f64,
	[]complex128,
}

Abscissa :: union {
	Span(int),
	Span(f32),
	Span(f64),
	//TODO: Complex_span(complex128),
	[]int,
	[]f32,
	[]f64,
	[]string,
}

Signal :: struct {
	name : string,
	ordinate : Ordinate, //y-coordinate
	abscissa : Abscissa, //x-coordinate
}

Math_func_1D :: #type proc(time : f64) -> f64;
Math_func_2D :: #type proc(time : f64) -> (x : f64, y : f64);
Math_func_3D :: #type proc(time : f64) -> (x : f64, y : f64, z : f64);	

Math_func_real_complex :: #type proc(time : f64) -> complex128;				//Maps a real number to a complex number 
Math_func_complex_complex :: #type proc(time : complex128) -> complex128;	//Maps a complex number to a complex number
Math_func_complex_real :: #type proc(time : complex128) -> f64;				//Maps a complex number to a real number

Math_func :: union {
	Math_func_1D,
	Math_func_2D,
	Math_func_3D,
	Math_func_real_complex,
	Math_func_complex_complex,
	Math_func_complex_real,
}

set_signal_name :: proc () {
	
}

fill_signal :: proc (s : ^Signal, span : Span($T), func : Math_func_1D, loc := #caller_location) {
	
	s.abscissa = span;
	
	arr := array_from_span(span);
	defer delete(arr);
	
	ordinate := make([]T, len(arr));
	for e, i in arr {
		ordinate[i] = cast(T)func(cast(f64)e);
	}
	s.ordinate = ordinate;
	
	/*
	switch mf in func {
		case Math_func_1D:
			ordinate := make([]T, len(arr));
			for e, i in arr {
				ordinate[i] = cast(T)mf(cast(f64)e);
			}
			s.ordinate = ordinate;
		case Math_func_2D:
			ordinate := make([][2]f64, len(arr));
			for e, i in arr {
				ordinate[i][0], ordinate[i][1] = mf(cast(f64)e);
			}
			s.ordinate = ordinate;
		case Math_func_3D:
			ordinate := make([][3]f64, len(arr));
			for e, i in arr {
				ordinate[i][0], ordinate[i][1], ordinate[i][2] = mf(cast(f64)e);
			}
			s.ordinate = ordinate;
		case Math_func_real_complex:
			ordinate := make([]complex128, len(arr));
			for e, i in arr {
				ordinate[i] = mf(cast(f64)e);
			}
			s.ordinate = ordinate;
		
		case Math_func_complex_complex, Math_func_complex_real:
			panic("TODO");
	}
	*/
}

destroy_signal :: proc (s : Signal, loc := #caller_location) {
	
	if s.name != "" {
		delete(s.name);
	}
	
	switch abscissa in s.abscissa {
		case Span(int), Span(f32), Span(f64):
		case []int:
			delete(abscissa);
		case []f32:
			delete(abscissa);
		case []f64:
			delete(abscissa);
		case []string:
			for s in abscissa {
				delete(s);
			}
			delete(abscissa);			
	}
	
	switch ordinate in s.ordinate {
		case []int:
			delete(ordinate);
        case []f32:
			delete(ordinate);
        case []f64:
			delete(ordinate);
        case [][2]f64:
			delete(ordinate);
        case [][3]f64:
			delete(ordinate);
        case []complex128:
			delete(ordinate);
	}
}

plot_xy :: proc (signal : Signal, loc := #caller_location) {
	
	span_pos : []f32;
	
	switch abscissa in signal.abscissa {
		case Span(int):
			span_pos = array_from_span(convert_span(abscissa, f32));
		case Span(f32):
			span_pos = array_from_span(convert_span(abscissa, f32));
		case Span(f64):
			span_pos = array_from_span(convert_span(abscissa, f32));
		case []int:
			span_pos = make([]f32, len(abscissa));
			for e, i in abscissa {
				span_pos[i] = cast(f32)e;
			}
		case []f32:
			span_pos = slice.clone(abscissa);
		case []f64:
			span_pos = make([]f32, len(abscissa));
			for e, i in abscissa {
				span_pos[i] = cast(f32)e;
			}
		case []string:
			panic("Cannot do an xy plot for a string abscissa");
	}
	
	value_pos : []f32;
	
	switch ordinate in signal.ordinate {
		case []int:
			value_pos = make([]f32, len(ordinate));
			for e, i in ordinate {
				value_pos[i] = cast(f32)e;
			}
		case []f32:
			value_pos = slice.clone(ordinate);
		case []f64:
			value_pos = make([]f32, len(ordinate));
			for e, i in ordinate {
				value_pos[i] = cast(f32)e;
			}
		case [][2]f64:
			panic("Cannot do an xy plot for a 2D signal");
		case [][3]f64:
			panic("Cannot do an xy plot for a 3D signal");
		case []complex128:
			panic("Cannot do an xy plot for a complex signal");
	}
	
	xlow, xhigh := get_extremes(span_pos);
	ylow, yhigh := get_extremes(value_pos);
	
	total_y : f32 = yhigh - ylow;
		
	pt := Plot_xy{
		span_pos,											//X coord
		value_pos,											//Y coord
		Grid_desc{line_width = 0.001, color = {0.5, 0.5, 0.5, 0.5}}, //Grid desc
		[2]Maybe(Axis_desc){nil, nil},
		{xlow, xhigh},										//x_view
		{ylow - 0.1 * total_y, yhigh + 0.1 * total_y},		//y_view
		{},													//Top bar panel
	}
	
	make_plot_window(pt);
	
}

plot_surface :: proc () {
	//...
}


plot_windows : [dynamic]^Plot_window;
//Pauses execution until all windows are closed, and continuesly updates the windows.
hold :: proc () {
	
	light_mode : Light_mode = .dark_mode;
	
	for len(plot_windows) != 0 {
		render.begin_frame();
		
		//Handle changing color mode
		{
			if render.is_key_pressed(.l) || render.is_key_pressed(.d) {
				if light_mode == .bright_mode {
					light_mode = .dark_mode;
				}
				else {
					light_mode = .bright_mode;
				}
			}
		}
		
		plot_bg_color : [4]f32 = plot_bg_colors[light_mode];
		base_color	: [4]f32 = base_colors[light_mode];
		inverse_color : [4]f32 = inverse_colors[light_mode];
		backdrop_color := backdrop_colors[light_mode];
		
		to_remove : [dynamic]int;
		defer delete(to_remove);
		
		for &w, i in plot_windows {
			
			if render.window_should_close(w.window) {
				append(&to_remove, i);
				destroy_plot_window(w);
				continue;
			}
			
			draw_pipeline := render.pipeline_make(render.get_default_shader(), depth_test = false);
			
			target_size : [2]i32 = {w.window.width, w.window.height};
			
			assert(w.plot_framebuffer.id != 0, "frambuffer is nil");
			if w.plot_framebuffer.width != target_size.x || w.plot_framebuffer.height != target_size.y {
				render.frame_buffer_resize(&w.plot_framebuffer, target_size);
				render.texture2D_resize(&w.plot_texture, target_size);
			}
			
			//Calculate normalized space coordinates.
			width_i, height_i := render.get_render_target_size(&w.plot_framebuffer);
			width_f, height_f := cast(f32)width_i, cast(f32)height_i;
			aspect_ratio := width_f / height_f;
			width, height : f32 = aspect_ratio, 1.0;
			
			cam_2d : render.Camera2D = {
				position		= {width / 2, height / 2},
				target_relative	= {width / 2, height / 2},
				rotation		= 0,
				zoom 			= 2,
				near 			= -1,
				far 			= 1,
			};
			
			render.target_begin(&w.plot_framebuffer, plot_bg_color);
				render.pipeline_begin(draw_pipeline, cam_2d);
					pv_pos, pv_size, x_view, y_view, grid_cnt := plot_inner(&w.plot_type, width_i, height_i);
				render.pipeline_end();
			render.target_end();
			
			render.target_begin(w.window, base_color);
				render.pipeline_begin(draw_pipeline, cam_2d);
					
					render.frame_buffer_blit_color_attach_to_texture(&w.plot_framebuffer, 0, w.plot_texture);
					render.set_texture(.texture_diffuse, w.plot_texture);
					render.draw_quad_rect({pv_pos.x, pv_pos.y, pv_size.x, pv_size.y}, 0)
					
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					for grid_x in 0..=grid_cnt.x {
						x := pv_pos.x + ((cast(f32)(grid_x) / cast(f32)grid_cnt.x) * pv_size.x);
						render.draw_line_2D({x, pv_pos.y}, {x, pv_pos.y - 0.03}, 0.003, 0, inverse_color);
						
						if grid_x != grid_cnt.x {
							for sub_x in 1..<5 {
								diff := (pv_pos.x + ((cast(f32)(grid_x + 1) / cast(f32)grid_cnt.x) * pv_size.x) - x) / 5;
								render.draw_line_2D({x + diff * cast(f32)sub_x, pv_pos.y}, {x + diff * cast(f32)sub_x, pv_pos.y - 0.01}, 0.001, 0, inverse_color);
							}
						}
					}
					for grid_y in 0..=grid_cnt.y {
						y := pv_pos.y + ((cast(f32)(grid_y) / cast(f32)grid_cnt.y) * pv_size.y);						
						render.draw_line_2D({pv_pos.x, y}, {pv_pos.x - 0.03, y}, 0.003, 0, inverse_color);
						
						if grid_y != grid_cnt.y {
							for sub_y in 1..<5 {
								diff := (pv_pos.y + ((cast(f32)(grid_y + 1) / cast(f32)grid_cnt.y) * pv_size.y) - y) / 5.0;
								render.draw_line_2D({pv_pos.x, y + diff * cast(f32)sub_y}, {pv_pos.x - 0.01, y + diff * cast(f32)sub_y}, 0.001, 0, inverse_color);
							}
						}
					}
					
					render.draw_line_2D({pv_pos.x, pv_pos.y}, {pv_pos.x + pv_size.x, pv_pos.y}, 0.003, 0, inverse_color);
					render.draw_line_2D({pv_pos.x, pv_pos.y}, {pv_pos.x, pv_pos.y + pv_size.y}, 0.003, 0, inverse_color);
				
				render.pipeline_end();
				
				//Draw the lines around the plot, including the entries (like numbers).
				{
					text_size : f32 = cast(f32)target_size.y / 27;
					for grid_x in 0..=grid_cnt.x {
						x := pv_pos.x + ((cast(f32)(grid_x) / cast(f32)grid_cnt.x) * pv_size.x);
						
						low_p, high_p := x_view[0], x_view[1];
						
						val := low_p + cast(f32)(grid_x) / cast(f32)grid_cnt.x * (high_p - low_p);						
						s_val := format_val(val);
						bounds := render.text_get_visible_bounds(s_val, render.get_default_fonts().normal, text_size);
						text_pos : [2]f32 = ({x, pv_pos.y - 0.03} * cast(f32)target_size.y) - ({bounds.z/2, bounds.w} * 1.1);
						render.text_draw(s_val, text_pos, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}});						
					}
					for grid_y in 0..=grid_cnt.y {
						y := pv_pos.y + ((cast(f32)(grid_y) / cast(f32)grid_cnt.y) * pv_size.y);
						
						low_p, high_p := y_view[0], y_view[1];
						
						val := low_p + cast(f32)(grid_y) / cast(f32)grid_cnt.y * (high_p - low_p);
						s_val := format_val(val);
						bounds := render.text_get_visible_bounds(s_val, render.get_default_fonts().normal, text_size);
						text_pos : [2]f32 = ({pv_pos.x - 0.03, y} * cast(f32)target_size.y) - ([2]f32{bounds.z, bounds.w/2} * 1.1);
						render.text_draw(s_val, text_pos, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}});
					}
				}
				
				//Draw the plot texture to the gui panel
				gui.begin(&w.gui_state, w.window);
				
				//TODO make the plot drawn as a gui element instead of emitiate mode.
				
				gui.end(&w.gui_state);
			render.target_end();
		}
			
		render.end_frame();
		
		#reverse for i in to_remove {
			free(plot_windows[i]);
			unordered_remove(&plot_windows, i);
		}
	}
}

get_extremes :: proc (arr : []$T) -> (low, high : T){
	
	low, high = math.inf_f32(1), math.inf_f32(-1);
	
	for e, i in arr {
		if e < low {
			low = e;
		}
		if e > high {
			high = e;
		}
	}
	
	return;
}

end :: proc () {
	render.destroy();
	delete(plot_windows);
}

















//////////////////////////////////////// PRIVATE ////////////////////////////////////////

//Uses temp alloc
@(private)
format_val :: proc (val : f32) -> string {
	val : f64 = cast(f64)val;
	prefix : i64 = 0; //In base 10
	
	if math.is_inf(val, 1) {
		return "∞";
	}
	if math.is_inf(val, -1) {
		return "-∞";
	}
	if math.is_nan(val) {
		return "NAN";
	}
	
	for val >= 1000.0 && prefix < 12 {
		val /= 1000.0;
		prefix += 3;
	}
	/*for val < 1.0 && prefix > -12 {
		val *= 1000.0;
		prefix -= 3;
	}*/
	
	s_val := fmt.tprintf("%.7f", val);
	
	//Find the where the "." is, if there is any.
	dot_loc := max(int)
	b_index : int = 0;
	for i in 0..<utf8.rune_count_in_string(s_val) {
		r := utf8.rune_at(s_val, b_index);
		b_index += utf8.rune_size(r);
		if r == '.' {
			dot_loc = b_index;
			break;
		}
	}
	
	r, r_size := utf8.decode_last_rune(s_val);
	for (((r == '0' || r == '.') && len(s_val) > 1) || utf8.rune_count_in_string(s_val) > 6) && len(s_val) >= dot_loc {
		s_val = s_val[:len(s_val)-r_size];
		r, r_size = utf8.decode_last_rune(s_val);
	}
	
	si_prefixes : map[i64]rune = {
		-12 = 'p', // pico (10^-12)
		-9 = 'n',  // nano (10^-9)
		-6 = 'µ',  // micro (10^-6)
		-3 = 'm',  // milli (10^-3)
		0 = ' ',   // no prefix (10^0)
		3 = 'k',   // kilo (10^3)
		6 = 'M',   // mega (10^6)
		9 = 'G',   // giga (10^9)
		12 = 'T',  // tera (10^12)
	}
	defer delete(si_prefixes);
	
	return fmt.tprintf("%s%c", s_val, si_prefixes[prefix]);
}

@(private)
make_plot_window :: proc (pt : Plot_type, loc := #caller_location) -> ^Plot_window {
	ensure_render_init(loc = loc);
	
	w := render.window_make(512, 512, "Plot", .allow_resize, .msaa32, loc = loc);
	
	pw : ^Plot_window = new(Plot_window, loc = loc);
	
	pw^ = Plot_window {
		w,
		pt,
		gui.init(),
		render.frame_buffer_make_render_buffers({.RGBA8}, w.width, w.height, 16, .depth_component32, loc = loc),
		render.texture2D_make(false, .clamp_to_edge, .nearest, .RGBA8, w.width, w.height, .no_upload, nil),
	}
	
	append_elem(&plot_windows, pw, loc = loc);
	
	return pw;
}


@(private)
convert_span :: proc (span : Span($T), $TT : typeid) -> Span(TT) {
	
	return Span(f32){
		begin = cast(f32)span.begin,
		end = cast(f32)span.end,
		dist = cast(f32)span.dist,
	};
}

@(private)
array_from_span :: proc (span : Span($T), loc := #caller_location) -> []T {
	
	assert(span.begin < span.end, "The begining of the span must be higher then the end of the span", loc)
	
	steps : int = cast(int)((span.end - span.begin) / span.dist);
	
	arr := make([]T, steps + 1);
	
	for i in 0..=steps{
		arr[i] = cast(T)(cast(f64)i * cast(f64)span.dist + cast(f64)span.begin);
	}
	
	return arr;
}

@(private)
ensure_render_init :: proc (loc := #caller_location) {
	if !render.state.is_init {
		render.init({}, loc = loc);
	}
	
	render.window_set_vsync(true);
}

@(private)
destroy_plot_window :: proc (w : ^Plot_window) {
	render.window_destroy(w.window);
	render.frame_buffer_destroy(w.plot_framebuffer);
	gui.destroy(&w.gui_state);
	
	switch p in w.plot_type {
		case Plot_xy:
			delete(p.abscissa);
			delete(p.ordinate);
	}
	
	render.texture2D_destroy(w.plot_texture);
}


