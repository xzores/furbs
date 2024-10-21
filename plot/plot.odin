package plot;

import "../render"
import gui "../regui"

import "core:time"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:slice"

import "base:intrinsics"

Grid_desc :: struct {
	color : [4]f32,
	line_width : f32,
}

Axis_desc :: struct {
	name : string, 
	span : Span(f64),
	unit : string,
}

Trace :: struct {
	abscissa : []f64,
	ordinate : []f64,
}

Marker_style :: enum {
	line,
	circle,
	square,
}

Plot_xy :: struct {
	traces : []Trace,
	
	//plot_desc : 
	grid_desc : Grid_desc,
	axis_desc : [2]Maybe(Axis_desc),
	
	x_label : string,
	y_label : string,
	title : string,
	
	x_view : [2]f64,
	y_view : [2]f64,
	
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

default_trace_colors := [?][4]f32{
	[4]f32{0.9, 0.2, 0.2, 1},
	[4]f32{0.1, 0.4, 0.9, 1},
	[4]f32{0.9, 0.5, 0.1, 1},
	[4]f32{0.05, 0.4, 0.05, 1},
	[4]f32{0.8, 0.2, 0.8, 1},
	
	[4]f32{0.2, 0.8, 0.8, 1},
	[4]f32{0.6, 0.3, 0.1, 1},
	[4]f32{0.3, 1.0, 0.3, 1},
	[4]f32{0.5, 0.2, 0.9, 1},
	[4]f32{0.9, 0.9, 0.2, 1},
};


light_mode : Light_mode = .dark_mode;

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
	
	ordinate_label : string,
	ordinate : Ordinate, //y-coordinate
	
	abscissa_label : string,
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

fill_signal :: proc (s : ^Signal, span : Span($T), func : Math_func_1D, time_mul : f64 = 1, amp_mul : f64 = 1, loc := #caller_location) {
	
	s.abscissa = span;
	
	arr := array_from_span(span);
	defer delete(arr);
	
	ordinate := make([]T, len(arr));
	for e, i in arr {
		ordinate[i] = amp_mul * cast(T)func(cast(f64)e * time_mul);
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
	if s.abscissa_label != "" {
		delete(s.abscissa_label);
	}
	if s.ordinate_label != "" {
		delete(s.ordinate_label);
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

xy_plots :: proc (signals : []Signal, x_label : Maybe(string) = nil, y_label : Maybe(string) = nil, title : Maybe(string) = nil, loc := #caller_location) {
	assert(len(signals) != 0, "No signals given", loc);
	
	traces := make([]Trace, len(signals));
	xlow, xhigh : f64 = max(f64), min(f64);
	ylow, yhigh : f64 = max(f64), min(f64);
	
	_x_label := signals[0].abscissa_label;
	_y_label := signals[0].ordinate_label;
	_title := signals[0].name;
	
	for signal, i in signals {
		
		span_pos : []f64 = abscissa_to_array(signal.abscissa);
		if len(span_pos) == 0 {
			delete(span_pos);
			continue;
		}
		
		xl, xh := get_extremes(span_pos);
		xlow, xhigh = math.min(xlow, xl), math.max(xhigh, xh);
		
		value_pos : []f64 = ordinate_to_array(signal.ordinate);
		
		yl, yh := get_extremes(value_pos);
		ylow, yhigh = math.min(ylow, yl), math.max(yhigh, yh);
		
		traces[i] = {span_pos, value_pos};
		
		if _x_label != signal.abscissa_label {
			_x_label = "";
		}
		if _y_label != signal.ordinate_label {
			_y_label = "";
		}
		if _title != signal.name {
			_title = "";
		}
	}
	
	//Overwrite trace name if a name is given
	if s, ok := x_label.?; ok {
		_x_label = s;
	}
	if s, ok := y_label.?; ok {
		_y_label = s;
	}
	if s, ok := title.?; ok {
		_title = s;
	}
	
	if _x_label != "" {
		_x_label = fmt.aprintf(_x_label)
	}
	if _y_label != "" {
		_y_label = fmt.aprintf(_y_label)
	}
	if _title != "" {
		_title = fmt.aprintf(_title)
	}
	
	pt := Plot_xy{
		traces,															//Y coord
		Grid_desc{line_width = 0.001, color = {0.5, 0.5, 0.5, 0.5}}, 	//Grid desc
		[2]Maybe(Axis_desc){nil, nil},
		_x_label,
		_y_label,
		_title,
		{cast(f64)xlow, cast(f64)xhigh},								//x_view
		find_good_display_extremes(ylow, yhigh),						//y_view
		{},																//Top bar panel
	}
	
	make_plot_window(pt);
}

trig_dft :: proc (signal : Signal, use_hertz := true, loc := #caller_location) {
	
	span_pos : []f64 = abscissa_to_array(signal.abscissa);	//The y-value
	value_pos : []f64 = ordinate_to_array(signal.ordinate);	//The x-value
	defer delete(span_pos);
	defer delete(value_pos);
	
	freq_text : string;
	
	if use_hertz {
		freq_text = "Frequency [Hz]";
	}
	else {
		freq_text = "Frequency [rad/s]";
	}
	
	a_coeff, b_coeff, freq_span := calculate_trig_dft(span_pos, value_pos, use_hertz);
	defer delete(a_coeff);
	defer delete(b_coeff);
	defer delete(freq_span);
	
	signal_a_coeff := Signal {
	 	"",
		
		freq_text,
		a_coeff, 		//y-coordinate
		
		"",
		freq_span, 		//x-coordinate
	};
	signal_b_coeff := Signal {
	 	"",				//Name
		
		freq_text,		//y-label
		b_coeff, 		//y-coordinate
		
		"",				//x-label
		freq_span, 		//x-coordinate
	};
	
	xy_plots({signal_a_coeff, signal_b_coeff});
}

bode :: proc (signal : Signal, use_hertz := true, range : Maybe([2]f64) = nil, loc := #caller_location) {
	
	span_pos : []f64 = abscissa_to_array(signal.abscissa);	//The y-value
	value_pos : []f64 = ordinate_to_array(signal.ordinate);	//The x-value
	defer delete(span_pos);
	defer delete(value_pos);
	
	freq_text : string;
	
	if use_hertz {
		freq_text = "Frequency [Hz]";
	}
	else {
		freq_text = "Frequency [rad/s]";
	}
	
	phasors, freq_span := calculate_complex_dft(span_pos, value_pos, use_hertz, range);
	defer delete(phasors);
	defer delete(freq_span);
	magnetude, phase := complex_to_mag_and_phase(phasors);
	defer delete(magnetude);
	defer delete(phase);
	
	signal_mag := Signal {
	 	"",
		
		freq_text,
		magnetude, 		//y-coordinate
		
		"",
		freq_span, 		//x-coordinate
	};
	
	xy_plots({signal_mag});
}

plot_surface :: proc () {
	//...
}

plot_windows : [dynamic]^Plot_window;

//Pauses execution until all windows are closed, and continuesly updates the windows.
hold :: proc () {
	
	for len(plot_windows) != 0 {
		render.begin_frame();
		
		//Handle changing color mode
		if render.window_is_any_focus() {
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
			
			render.target_begin(&w.plot_framebuffer, plot_bg_color);
					pv_pos, pv_size, x_view, y_view, x_callout, y_callout, x_label, y_label, title := plot_inner(&w.plot_type, width_i, height_i, render.window_is_focus(w.window));
					defer delete(x_callout);
					defer delete(y_callout);
			render.target_end();
			
			cam_2d : render.Camera2D = {
				position		= {width / 2, height / 2},
				target_relative	= {width / 2, height / 2},
				rotation		= 0,
				zoom 			= 2,
				near 			= -1,
				far 			= 1,
			};
			
			render.target_begin(w.window, base_color);
				render.pipeline_begin(draw_pipeline, cam_2d);
					
					render.frame_buffer_blit_color_attach_to_texture(&w.plot_framebuffer, 0, w.plot_texture);
					render.set_texture(.texture_diffuse, w.plot_texture);
					render.draw_quad_rect({pv_pos.x, pv_pos.y, pv_size.x, pv_size.y}, 0)
					
					render.set_texture(.texture_diffuse, render.texture2D_get_white());
					for call in x_callout {
						x := pv_pos.x + (cast(f32)call.placement * pv_size.x);
						render.draw_line_2D({x, pv_pos.y}, {x, pv_pos.y - call.length}, call.thickness, 0, inverse_color);
					}
					for call in y_callout {
						y := pv_pos.y + (cast(f32)call.placement * pv_size.y);						
						render.draw_line_2D({pv_pos.x, y}, {pv_pos.x - call.length, y}, call.thickness, 0, inverse_color);
					}
					
					render.draw_line_2D({pv_pos.x, pv_pos.y}, {pv_pos.x + pv_size.x, pv_pos.y}, 0.003, 0, inverse_color);
					render.draw_line_2D({pv_pos.x, pv_pos.y}, {pv_pos.x, pv_pos.y + pv_size.y}, 0.003, 0, inverse_color);
				
				render.pipeline_end();
				
				//Draw the callout lines around the plot, including the entries (like numbers).
				{
					text_size : f32 = cast(f32)target_size.y / 26;
					for call in x_callout {
						if call.display_value {
							x := pv_pos.x + (cast(f32)call.placement * pv_size.x);
							
							low_p, high_p := x_view[0], x_view[1];
							
							val := low_p + call.placement * (high_p - low_p);						
							s_val := format_val(val);
							bounds := render.text_get_visible_bounds(s_val, text_size, render.get_default_fonts().normal);
							text_pos : [2]f32 = ({x, pv_pos.y - call.length} * cast(f32)target_size.y) - ({bounds.z/2, bounds.w} * 1.1);
							render.text_draw(s_val, text_pos, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}});
						}				
					}
					for call in y_callout {
						if call.display_value {
							y := pv_pos.y + (cast(f32)call.placement * pv_size.y);
							
							low_p, high_p := y_view[0], y_view[1];
							
							val := low_p + call.placement * (high_p - low_p);
							s_val := format_val(val);
							bounds := render.text_get_visible_bounds(s_val, text_size, render.get_default_fonts().normal);
							text_pos : [2]f32 = ({pv_pos.x - call.length, y} * cast(f32)target_size.y) - ([2]f32{bounds.z, bounds.w/2} * 1.1);
							render.text_draw(s_val, text_pos, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}});
						}
					}
				}
				
				if x_label != "" {
					text_size : f32 = cast(f32)w.window.height / 26;
					text_pos := [2]f32{0.5 * cast(f32)w.window.width, 0.03 * cast(f32)w.window.height};
					dims := render.text_get_visible_bounds(x_label, text_size)
					render.text_draw(x_label, text_pos - dims.zw/2, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}});
				}
				if y_label != "" {
					text_size : f32 = cast(f32)w.window.height / 18;
					text_pos := [2]f32{0.08 * cast(f32)w.window.height, 0.5 * cast(f32)w.window.height};
					dims := render.text_get_visible_bounds(y_label, text_size)
					render.text_draw(y_label, text_pos - dims.wz/2, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}}, rotation = 90);
				}
				if title != "" {
					text_size : f32 = cast(f32)w.window.height / 18;
					text_pos := [2]f32{0.5 * cast(f32)w.window.width, 0.97 * cast(f32)w.window.height};
					dims := render.text_get_visible_bounds(title, text_size)
					render.text_draw(title, text_pos - dims.zw/2, text_size, false, false, inverse_color, {backdrop_color, {1.5,-1.5}});
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
		
		free_all(context.temp_allocator);
	}
}

end :: proc () {
	render.destroy();
	delete(plot_windows);
}





//////////////////////////////////////// PRIVATE ////////////////////////////////////////

@(private, require_results)
abscissa_to_array :: proc (a : Abscissa, alloc := context.allocator, loc := #caller_location) -> []f64 {
	context.allocator = alloc;
	
	span_pos : []f64;
	
	switch abscissa in a {
		case Span(int):
			span_pos = array_from_span(convert_span(abscissa, f64), loc);
		case Span(f32):
			span_pos = array_from_span(convert_span(abscissa, f64), loc);
		case Span(f64):
			span_pos = array_from_span(convert_span(abscissa, f64), loc);
		case []int:
			span_pos = make([]f64, len(abscissa));
			for e, i in abscissa {
				span_pos[i] = cast(f64)e;
			}
		case []f32:
			span_pos = make([]f64, len(abscissa));
			for e, i in abscissa {
				span_pos[i] = cast(f64)e;
			}
		case []f64:
			span_pos = slice.clone(abscissa, loc = loc);
		case []string:
			panic("Cannot do an xy plot for a string abscissa");
	}
	
	return span_pos;
}

@(private, require_results)
ordinate_to_array :: proc (o : Ordinate, alloc := context.allocator, loc := #caller_location) -> []f64 {
	context.allocator = alloc;
	
	value_pos : []f64;
	
	switch ordinate in o {
		case []int:
			value_pos = make([]f64, len(ordinate));
			for e, i in ordinate {
				value_pos[i] = cast(f64)e;
			}
		case []f32:
			value_pos = make([]f64, len(ordinate));
			for e, i in ordinate {
				value_pos[i] = cast(f64)e;
			}
		case []f64:
			value_pos = slice.clone(ordinate, loc = loc);
		case [][2]f64:
			panic("Cannot do an xy plot for a 2D signal");
		case [][3]f64:
			panic("Cannot do an xy plot for a 3D signal");
		case []complex128:
			panic("Cannot do an xy plot for a complex signal");
	}
	
	return value_pos;
}


@(private, require_results)
nice_round :: proc (val : $T, round_amount : f64 = 10) -> f64 where intrinsics.type_is_numeric(T) {
	
	sign :=  math.sign(cast(f64)val);
	val : f64 = math.abs(cast(f64)val);
	exp : int = 0;
	
	for val >= 1000.0 && exp < 12 {
		val /= 1000.0;
		exp += 3;
	}
	for val <= 1.0 && exp > -12 {
		val *= 1000.0;
		exp -= 3;
	}
	if val != 0 {
		for val < 1.0 && val > -1.0 && exp > -12 {
			val = val * 1000.0;
			exp -= 3;
		}
	}
	
	val *= round_amount;
	val = math.round(val);
	
	return sign * val * math.pow10(cast(f64)exp) / round_amount;
}

@(private, require_results)
find_good_display_extremes :: proc (ylow, yhigh : f64) -> [2]f64 {
	
	low_exp : int = 0;
	high_exp : int = 0;
	
	total_y := yhigh - ylow;
	
	if total_y <= 1e-12 {
		return {ylow-1e-12, yhigh+1e-12};
	}
	
	return {nice_round(ylow - total_y * 0.1), nice_round(yhigh + total_y * 0.1)};
}

@(private, require_results)
get_extremes :: proc (arr : []$T) -> (low, high : T){
	
	low, high = math.inf_f64(1), math.inf_f64(-1);
	
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

//Uses temp alloc
@(private, require_results)
format_val :: proc (val : f64) -> string {
	
	sign :=  math.sign(cast(f64)val);
	val : f64 = math.abs(cast(f64)val);
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
	if val != 0 {
		for val < 1.0 && val > -1.0 && prefix > -12 {
			val = val * 1000.0;
			prefix -= 3;
		}
	}
	
	val *= 10000.0;
	val = math.round(val) / 10000;
	s_val := fmt.tprintf("%.5f", sign * val);
	
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
	
	if s_val == "0" {
		return "0";
	}
	if s_val == "-0" {
		return "0";
	}
	
	return fmt.tprintf("%s%c", s_val, si_prefixes[prefix]);
}

@(private, require_results)
get_trace_info :: proc(index : int) -> ([4]f32, Marker_style) {
	
	return default_trace_colors[index %% 10], .line;
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


@(private, require_results)
convert_span :: proc (span : Span($T), $TT : typeid) -> Span(TT) {
	
	return Span(f64){
		begin = cast(f64)span.begin,
		end = cast(f64)span.end,
		dist = cast(f64)span.dist,
	};
}

@(private, require_results)
array_from_span :: proc (span : Span($T), loc := #caller_location) -> []T {
	
	assert(span.begin < span.end, "The begining of the span must be higher then the end of the span", loc)
	
	steps : int = cast(int)((span.end - span.begin) / span.dist);
	
	arr := make([]T, steps + 1, loc = loc);
	
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
			for t in p.traces {
				delete(t.abscissa);
				delete(t.ordinate);
			}
			delete(p.traces)
	}
	
	render.texture2D_destroy(w.plot_texture);
}


