#+feature dynamic-literals
package plot;

import "../render"
import fs "../fontstash"
import "../regui"
import "../regui/regui_base"
import haru "../libharu"

import "core:time"
import "core:fmt"
import "core:math"
import "core:math/linalg"
import "core:unicode/utf8"
import "core:slice"
import "core:strings"
import "core:os"

import stb_img "vendor:stb/image"

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

Log_style :: enum {
	no_log = 0,
	base_2,
	base10,
	base_ln,
	
	//These are implicit in base10 i think.
	//db_10,	//For power signals
	//db_20, 	//For voltage and amp signals
}

//https://www.youtube.com/watch?v=pfjiwxhqd1M
Magnetude_representation :: enum {
	accumulative,				//This just sums the values and returns unmodified
	amplitude,					//This allows you to observe the amplitude of each sinusoide in the signal
	power_spectrum,				//This used for distint sine-wave contributions, so not broad-band.
	power_speactral_density, 	//This is used for broad band signals //This is kinda a bullshit idea/approximation which idk why people use it. 
}

Plot_xy :: struct {
	plot_framebuffer : render.Frame_buffer,
	plot_texture : render.Texture2D,
	
	traces : []Trace,
	
	//plot_desc : 
	grid_desc : Grid_desc,
	axis_desc : [2]Maybe(Axis_desc),
	
	x_label : string,
	y_label : string,
	title : string,
	
	x_view : [2]f64,
	y_view : [2]f64,
	
	log_x : Log_style,
	log_y : Log_style,
	
	top_panel : regui.Panel, //This is a panel
}

Plot_type :: union {
	Plot_xy,
}

Plot_window :: struct {
	window : ^render.Window,
	plots : [dynamic]Plot_type,
	gui_state : regui.Scene,
}

Light_mode :: enum {
	dark_mode,
	bright_mode,
}

plot_bg_colors : [Light_mode][4]f32 = 	{.dark_mode = [4]f32{0.2, 0.2, 0.2, 1}, 	.bright_mode = [4]f32{1, 1, 1, 1}};
base_colors : [Light_mode][4]f32 = 		{.dark_mode = [4]f32{0.17, 0.17, 0.17, 1}, 	.bright_mode = [4]f32{1, 1, 1, 1}};
inverse_colors : [Light_mode][4]f32 = 	{.dark_mode = [4]f32{0.8, 0.8, 0.8, 1}, 	.bright_mode = [4]f32{0, 0, 0, 1}};
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

make_signal :: proc (x_axis, y_axis : []f64, x_label := "", y_label := "", name := "", loc := #caller_location) -> Signal {
	
	sig : Signal = {
		strings.clone(name, loc = loc),
		strings.clone(y_label, loc = loc),
		y_axis, //y-coordinate
		strings.clone(x_label, loc = loc),
		x_axis, //x-coordinate
	}
	
	return sig;
}

fill_signal :: proc (s : ^Signal, span : Span($T), func : Math_func_1D, time_mul : f64 = 1, amp_mul : f64 = 1, loc := #caller_location) {
	
	s.abscissa = span;
	
	arr := array_from_span(span);
	defer delete(arr);
	
	ordinate := make([]T, len(arr), loc = loc);
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

destroy_signals :: proc (signals : []Signal, loc := #caller_location) {
	
	for s in signals  {
		destroy_signal(s);
	}
	delete(signals);
}

//Will not create a window, it will jst return the xy_plot struct
make_xy_plot :: proc (signals : []Signal, x_label : Maybe(string) = nil, y_label : Maybe(string) = nil, title : Maybe(string) = nil, x_range : Maybe([2]f64) = nil, y_range : Maybe([2]f64) = nil, x_log : Log_style = .no_log, y_log : Log_style = .no_log, loc := #caller_location) -> Plot_xy {
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
	
	display_range_x := [2]f64{cast(f64)xlow, cast(f64)xhigh};
	display_range_y := find_good_display_extremes(ylow, yhigh);
	
	if v, ok := x_range.?; ok {
		display_range_x = v;
	}
	if v, ok := y_range.?; ok {
		display_range_y = v;
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
		//{}, //Framebuffer
		//{}, //Texture
		render.frame_buffer_make_render_buffers({.RGBA8}, 1, 1, 16, .depth_component32, loc = loc),
		render.texture2D_make(false, .clamp_to_edge, .nearest, .RGBA8, 1, 1, .no_upload, nil, loc = loc),
		
		traces,															//Y coord
		Grid_desc{line_width = 0.001, color = {0.5, 0.5, 0.5, 0.5}}, 	//Grid desc
		[2]Maybe(Axis_desc){nil, nil},
		_x_label,
		_y_label,
		_title,
		display_range_x,								//x_view
		display_range_y,								//y_view
		x_log,
		y_log,
		{},																//Top bar panel
	}
	
	return pt;
}

destroy_plot :: proc (p : Plot_type) {
	
	switch plot in p {
		case Plot_xy: {
			render.frame_buffer_destroy(plot.plot_framebuffer);
			render.texture2D_destroy(plot.plot_texture);
			
			for t in plot.traces {
				delete(t.abscissa)
				delete(t.ordinate)
			}
			
			delete(plot.traces);
			
			delete(plot.x_label);
			delete(plot.y_label);
			delete(plot.title);
			
			//top_bar : regui_base.Panel,
			//top_bar : regui_base.Panel,
		}
	}
	
}

//Will create a window and display. A const view is returned, can be used to export as PDF 
xy_plots :: proc (signals : []Signal, x_label : Maybe(string) = nil, y_label : Maybe(string) = nil, title : Maybe(string) = nil, x_range : Maybe([2]f64) = nil, y_range : Maybe([2]f64) = nil, x_log : Log_style = .no_log, y_log : Log_style = .no_log, loc := #caller_location) -> Plot_xy {
	
	pt := make_xy_plot(signals, x_label, y_label, title, x_range, y_range, x_log, y_log, loc);
	window := make_plot_window(pt);
	
	return pt;
}

//Will create a window and display. A const view is returned, can be used to export as PDF 
xy_plot :: proc (signal : Signal, x_label : Maybe(string) = nil, y_label : Maybe(string) = nil, title : Maybe(string) = nil, x_range : Maybe([2]f64) = nil, y_range : Maybe([2]f64) = nil, x_log : Log_style = .no_log, y_log : Log_style = .no_log, loc := #caller_location) -> Plot_xy {
	return xy_plots({signal}, x_label, y_label, title, x_range, y_range, x_log, y_log, loc);
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

bodes :: proc (signals : []Signal, use_hertz := true, range : Maybe([2]f64) = nil, x_log := true, y_log := true, representation : Magnetude_representation = .amplitude,
				 y_unit : Maybe(string) = nil, x_label : Maybe(string) = nil, y_label : Maybe(string) = nil, title : Maybe(string) = nil, x_view_range : Maybe([2]f64) = nil,
				 	 y_view_range : Maybe([2]f64) = nil, freq_resolution : Maybe(f64) = nil, loc := #caller_location) -> Plot_xy {
	
	to_plot : [dynamic]Signal;
	//defer delete(to_plot);
	
	for signal in signals {
		span_pos : []f64 = abscissa_to_array(signal.abscissa);	//The y-value
		value_pos : []f64 = ordinate_to_array(signal.ordinate);	//The x-value
		//defer delete(span_pos);
		//defer delete(value_pos);
		
		freq_text : string;
		_y_labal : string;
		_title : string;
		db_text : string;
		
		if l, ok := x_label.?; ok {
			freq_text = strings.clone(l);
		}
		else {
			if use_hertz {
				freq_text = strings.clone("Frequency [Hz]");
			}
			else {
				freq_text = strings.clone("Frequency [rad/s]");
			}
		}
		//defer delete(freq_text);
		
		if l, ok := y_label.?; ok {
			_y_labal = strings.clone(l);
		}
		else {
			if unit, ok := y_unit.?; ok {
				switch representation {
					case .accumulative:
						//No name
					case .amplitude:
						_y_labal = fmt.aprintf("Amplitude [%v]", unit);
					case .power_spectrum:
						_y_labal = fmt.aprintf("Power [%v^2]", unit);
					case .power_speactral_density:
						_y_labal = fmt.aprintf("Power Spectral Density [%v^2]/Hz", unit);
				}
			}
			else {
				switch representation {
					case .accumulative:
						//No name
					case .amplitude:
						_y_labal = fmt.aprint("Amplitude");
					case .power_spectrum:
						_y_labal = fmt.aprint("Power");
					case .power_speactral_density:
						_y_labal = fmt.aprint("Power Spectral Density");
				}
			}
		}
		//defer delete(_y_labal);
		
		if t, ok := title.?; ok {
			_title = strings.clone(t);
		}
		//defer delete(_title);
		
		phasors, freq_span := calculate_complex_dft(span_pos, value_pos, use_hertz, range, freq_resolution, loc);
		//defer delete(phasors);
		//defer delete(freq_span);
		
		magnetude, phase := complex_to_mag_and_phase(phasors);
		//defer delete(magnetude);
		//defer delete(phase);
		
		N := f64(len(span_pos));
		switch representation {
			
			case .accumulative:
				//Do nothing
			
			case .amplitude:
				for &m in magnetude {
					m = 2 * math.abs(m) / N;
				}
			
			case .power_spectrum:
				for &m in magnetude {
					m = 2 * (m * m) / (N * N);
				}
			
			case .power_speactral_density:
				fs : f64 = (cast(f64)len(span_pos) - 1) / (span_pos[len(span_pos)-1] - span_pos[0]);
				for &m in magnetude {
					m = (m * m) / (fs * N);
				}
		}
		
		signal_mag := make_signal(freq_span, magnetude, freq_text, _y_labal, _title, loc);
		
		append(&to_plot, signal_mag);
	}
	
	return xy_plots(to_plot[:], x_range = x_view_range, y_range = y_view_range);
}

bode :: proc (signal : Signal, use_hertz := true, range : Maybe([2]f64) = nil, x_log := true, y_log := true, representation : Magnetude_representation = .amplitude,
				y_unit : Maybe(string) = nil, x_label : Maybe(string) = nil, y_label : Maybe(string) = nil, title : Maybe(string) = nil, x_view_range : Maybe([2]f64) = nil,
				y_view_range : Maybe([2]f64) = nil, freq_resolution : Maybe(f64) = nil, loc := #caller_location) -> Plot_xy {
	
	return bodes({signal}, use_hertz, range, x_log, y_log, representation, y_unit, x_label, y_label, title, x_view_range, y_view_range, freq_resolution, loc);
}

plot_surface :: proc () {
	//...
}

Color_theme :: struct {
	plot_bg_color : [4]f32,
	base_color	: [4]f32,
	inverse_color : [4]f32,
	backdrop_color : [4]f32,
}

light_mode : Light_mode = .dark_mode;

default_color_theme := Color_theme{
	plot_bg_color 	= plot_bg_colors[light_mode],
	base_color 		= base_colors[light_mode],
	inverse_color 	= inverse_colors[light_mode],
	backdrop_color	= backdrop_colors[light_mode],
}

light_color_theme := Color_theme{
	plot_bg_color 	= plot_bg_colors[.bright_mode],
	base_color 		= base_colors[.bright_mode],
	inverse_color 	= inverse_colors[.bright_mode],
	backdrop_color	= backdrop_colors[.bright_mode],
}

get_callout_info :: proc (plot_res : Plot_result, target_size : [2]i32, pv_pos, pv_size : [2]f32, x_view, y_view : [2]f64, x_callout, y_callout : []Callout_line, x_label, y_label, title : string, color_theme : Color_theme) ->
								(inner_plot_placement : [4]f32, lines : []Line, texts : []Text) {
	
	using color_theme;
	
	_lines : [dynamic]Line;
	_texts : [dynamic]Text;
	
	switch res in plot_res {
		case Plot_data:
			
			inner_plot_placement = {}; //Do not draw it.
			
		case:
			//it was using direct draw, so draw whatever is in the texture.
			//append(&_textures, Image{[4]f32{pv_pos.x, pv_pos.y, pv_size.x, pv_size.y}, render.Texture2D{}})
			inner_plot_placement = [4]f32{pv_pos.x, pv_pos.y, pv_size.x, pv_size.y};
	}
	
	for call in x_callout {
		x := pv_pos.x + (cast(f32)call.placement * pv_size.x);
		append(&_lines, Line{{x, pv_pos.y}, {x, pv_pos.y - call.length}, call.thickness, inverse_color})
	}
	for call in y_callout {
		y := pv_pos.y + (cast(f32)call.placement * pv_size.y);
		append(&_lines, Line{{pv_pos.x, y}, {pv_pos.x - call.length, y}, call.thickness, inverse_color})
	}
	
	append(&_lines, Line{{pv_pos.x, pv_pos.y}, {pv_pos.x + pv_size.x, pv_pos.y}, 0.003, inverse_color});
	append(&_lines, Line{{pv_pos.x, pv_pos.y}, {pv_pos.x, pv_pos.y + pv_size.y}, 0.003, inverse_color});
	
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
				append(&_texts, Text{strings.clone(s_val), text_pos, text_size, inverse_color, 0, backdrop_color, {1.5,-1.5}});
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
				append(&_texts, Text{strings.clone(s_val), text_pos, text_size, inverse_color, 0, backdrop_color, {1.5,-1.5}});
			}
		}
	}
	
	if x_label != "" {
		text_size : f32 = cast(f32)target_size.y / 26;
		text_pos := [2]f32{0.5 * cast(f32)target_size.x, 0.03 * cast(f32)target_size.y};
		dims := render.text_get_visible_bounds(x_label, text_size);
		append(&_texts, Text{strings.clone(x_label), text_pos - dims.zw/2, text_size, inverse_color, 0, backdrop_color, {1.5,-1.5}});
	}
	if y_label != "" {
		text_size : f32 = cast(f32)target_size.y / 18;
		text_pos := [2]f32{0.08 * cast(f32)target_size.y, 0.5 * cast(f32)target_size.y};
		dims := render.text_get_visible_bounds(y_label, text_size);
		append(&_texts, Text{strings.clone(y_label), text_pos - dims.wz/2, text_size, inverse_color, 90, backdrop_color, {1.5,-1.5}});
	}
	if title != "" {
		text_size : f32 = cast(f32)target_size.y / 18;
		text_pos := [2]f32{0.5 * cast(f32)target_size.x, 0.97 * cast(f32)target_size.y};
		dims := render.text_get_visible_bounds(title, text_size);
		append(&_texts, Text{strings.clone(title), text_pos - dims.zw/2, text_size, inverse_color, 0, backdrop_color, {1.5,-1.5}});
	}
	
	return inner_plot_placement, _lines[:], _texts[:];
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////

make_regui_plot :: proc (parent : regui_base.Parent, dest : regui_base.Destination, plot : Plot_type, show : bool = true, appearance : Maybe(regui_base.Appearance) = nil, loc := #caller_location) -> regui_base.Element {
	
	def_appearance, hov_appearance, sel_appearance, act_appearance := regui_base.get_appearences(parent, appearance, appearance, appearance, appearance);
	
	Gui_plot_data :: struct {
		
	}
	
	update :: proc(data : rawptr) {
		data := cast(^Gui_plot_data)data;
		
	}
	
	draw :: proc(data : rawptr) {
		data := cast(^Gui_plot_data)data;
		fmt.printf("DRAWing\n");
	}
	
	destroy :: proc(data : rawptr) {
		data := cast(^Gui_plot_data)data;
		free(data);
	}
	
	data := new(Gui_plot_data);
	
	element : regui_base.Custom_info = {
		update_call 	= update,
		draw_call 		= draw,
		destroy_call	= destroy,
		custom_data 	= data,
	}
	
	container : regui_base.Element_container = {
		element_info = element,
		dest = dest,
		is_showing = show,
		is_selected = false,
		stay_selected = false,
		tooltip = nil,
		style = {
			default = def_appearance,
			hover = hov_appearance,
			selected = sel_appearance,
			active = act_appearance,
		}
	}

	return auto_cast regui_base.element_make(parent, container, loc);	
}

plot_windows : [dynamic]^Plot_window;

//Pauses execution until all windows are closed, and continuesly updates the windows.
hold :: proc (color_theme := default_color_theme) {
	
	color_theme := color_theme;
	
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
				
				color_theme = {
					plot_bg_color 	= plot_bg_colors[light_mode],
					base_color 		= base_colors[light_mode],
					inverse_color 	= inverse_colors[light_mode],
					backdrop_color	= backdrop_colors[light_mode],
				}
			}
		}
		
		to_remove : [dynamic]int;
		defer delete(to_remove);
		
		for &w, i in plot_windows {
			
			if render.window_should_close(w.window) {
				append(&to_remove, i);
				continue;
			}
			
			draw_pipeline := render.pipeline_make(render.get_default_shader(), depth_test = false);
			
			render.target_begin(w.window, color_theme.base_color);
								
				//Draw the plot texture to the gui panel
				regui.begin(&w.gui_state, w.window);
				
				//TODO make the plot drawn as a gui element instead of emitiate mode.
				
				regui.end(&w.gui_state);
			render.target_end();
		}
		
		render.end_frame();
		
		#reverse for i in to_remove {
			destroy_plot_window(plot_windows[i]);
		}
		
		free_all(context.temp_allocator);
	}
}

end :: proc (loc := #caller_location) {
	render.destroy(loc);
	delete(plot_windows, loc);
}

export_pdf :: proc (plot : Plot_type, save_location : string, width_i : i32 = 1000, height_i : i32 = 1000, color_theme := light_color_theme, loc := #caller_location) {
	ensure_render_init(loc = loc);
	
	plot : Plot_type = plot;
	
	width : f32 = auto_cast width_i;
	height : f32 = auto_cast height_i;
	
	{ //Scope for deleteing
		haru.init();
		defer haru.destroy();
		
		pdf := haru.new();
		assert(pdf != nil, "Failed to create PDF handle");
		defer haru.free(pdf);
		
		page := haru.add_page(pdf);
		assert(page != nil, "Failed to create page");
		
		haru.page_set_width(page, width);
		haru.page_set_height(page, height);
		
		font : haru.Font;
		
		// Set font and font size
		{
			//THIS IS HACKY, libharu DOES NO ALLOW LOADING A FONT FROM MEMORY SO WE SAVE TO A FILE AND LOAD FROM THERE.
			suc := os.write_entire_file("temp_LinLibertine_R.ttf", render.font_norm_data);
			assert(suc, "failed to save default font to file (to then be loaded...)");
			
			font_name := haru.load_tt_font_from_file(pdf, "temp_LinLibertine_R.ttf", true, context.temp_allocator);
			assert(font_name != "", "failed to load font");
			font = haru.get_font(pdf, font_name, "StandardEncoding");
		}
		
		//Draw the background color
		haru.page_g_save(page);
			// Choose your background color
			haru.page_set_rgb_fill(page, color_theme.base_color.r, color_theme.base_color.g, color_theme.base_color.b);  // Light grey background (R, G, B)
			
			// Draw a filled rectangle over the entire page to simulate a background color
			haru.page_rectangle(page, 0, 0, width, height);
			haru.page_fill(page);  // This applies the fill with the specified color
		haru.page_g_restore(page);
		
		plot_framebuffer : render.Frame_buffer = render.frame_buffer_make_render_buffers({.RGBA8}, width_i, height_i, 32, .depth_component32, loc = loc);
		assert(plot_framebuffer.id != 0, "frambuffer is nil");
		defer render.frame_buffer_destroy(plot_framebuffer);
		
		draw_texture := render.texture2D_make(false, .clamp_to_border, .nearest, .RGBA8, width_i, height_i, .no_upload, nil);
		defer render.texture2D_destroy(draw_texture);
		
		draw_pipeline := render.pipeline_make(render.get_default_shader(), depth_test = false);
		defer render.pipeline_destroy(draw_pipeline);
		
		render.begin_frame();
			render.target_begin(&plot_framebuffer, color_theme.plot_bg_color);
				plot_res, pv_pos, pv_size, x_view, y_view, x_callout, y_callout, x_label, y_label, title := plot_inner(&plot.(Plot_xy), width_i, height_i, false);
				defer delete(x_callout);
				defer delete(y_callout);
			render.target_end();
			
			render.frame_buffer_blit_color_attach_to_texture(&plot_framebuffer, 0, draw_texture);
			image_data := render.texture2D_download_texture(draw_texture);
			defer delete(image_data);
			
			//fmt.printf("image_data : %v\n", image_data);
		render.end_frame();
		
		data := make([]u8, len(image_data) * 3);
		defer delete(data);
		for d, i in image_data {
			data[i * 3 + 0] = d.r;
			data[i * 3 + 1] = d.g;
			data[i * 3 + 2] = d.b;
		}
		render.texture2D_flip(data, draw_texture.width, draw_texture.height, 3);
		
		image := haru.load_raw_image_from_mem(pdf, data, auto_cast draw_texture.width, auto_cast draw_texture.height, .CS_DEVICE_RGB, 8);
		assert(image != nil, "image is nil");
		r : [4]f32 = {pv_pos.x, pv_pos.y, pv_size.x, pv_size.y} * height;
		haru.page_draw_image(page, image, r.x, r.y, r.z, r.w);
		
		haru.push_clipping_region(page, r);
		switch p in plot_res {
			case Plot_data:
				for l in p.lines { //TODO move to new sub-space coordinates 
					haru.page_set_line_cap(page, .BUTT_END);
					haru.draw_lines(pdf, page, {l.a, l.b}, l.thickness, l.color);			
					//draw_connected_points();
				}
				for t in p.texts { //TODO move to new sub-space coordinates 
					text_size_normalized := t.size / render.text_get_pixel_EM_ratio(t.size);
					haru.draw_text(pdf, page, font, t.value, t.position, text_size_normalized, t.color, t.rotation);
				}
		}
		haru.pop_clipping_region(page);
		
		inner_plot_position, lines, texts := get_callout_info(plot_res, {width_i, height_i}, pv_pos, pv_size, x_view, y_view, x_callout, y_callout, x_label, y_label, title, color_theme);
		defer {
			delete(lines);
			
			for t in texts {
				delete(t.value);
			}
			delete(texts);
		}
		
		for l in lines {
			a := l.a * height;
			b := l.b * height;
			t := l.thickness * height;
			haru.page_set_line_cap(page, .ROUND_END);
			haru.draw_lines(pdf, page, {{a, b}}, t, l.color);
		}
		
		// Place the text at a specific position
		for t in texts {
			text_size_normalized := t.size / render.text_get_pixel_EM_ratio(t.size);
			haru.draw_text(pdf, page, font, t.value, t.position, text_size_normalized, t.color, t.rotation);
		}
		
		// Save the PDF document
		haru.save_to_file(pdf, save_location);
		
		free_all(context.temp_allocator);
	}
	
	os.remove("temp_LinLibertine_R.ttf");
}

destroy_plot_window :: proc (w : ^Plot_window) {
	render.window_destroy(w.window);
	regui.destroy(&w.gui_state);
	
	for plot in w.plots {
		switch p in plot {
			case Plot_xy:
				for t in p.traces {
					delete(t.abscissa);
					delete(t.ordinate);
				}
				delete(p.traces)
				delete(p.x_label);
				delete(p.y_label);
				delete(p.title);
		}
	}
	
	free(w);
	
	for win, i in plot_windows {
		if win == w {
			unordered_remove(&plot_windows, i);
		}
	}
}

@(require_results)
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

@(require_results)
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

//////////////////////////////////////// PRIVATE ////////////////////////////////////////

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
	
	w := render.window_make(1080, 1080, "Plot", .allow_resize, .msaa32, loc = loc);
	
	pw : ^Plot_window = new(Plot_window, loc = loc);
	
	pw^ = Plot_window {
		w,
		make([dynamic]Plot_type),
		regui.init(),
	}
	
	append_elem(&pw.plots, pt, loc = loc);
	
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
	if !render.is_init() {
		render.init({}, loc = loc);
	}
	
	render.window_set_vsync(true);
}



/*

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

render.target_begin(&w.plot_framebuffer, color_theme.plot_bg_color);
	plot_res, pv_pos, pv_size, x_view, y_view, x_callout, y_callout, x_label, y_label, title := plot_inner(&w.plot_type, width_i, height_i, render.window_is_focus(w.window));
	defer delete(x_callout);
	defer delete(y_callout);
	
	switch p in plot_res {
		case Plot_data:
			for l in p.lines {
				
			}
			for t in p.texts {
				
			}
	}
render.target_end();

cam_2d : render.Camera2D = {
	position		= {width / 2, height / 2},
	target_relative	= {width / 2, height / 2},
	rotation		= 0,
	zoom 			= 2,
	near 			= -1,
	far 			= 1,
};

inner_plot_position, lines, texts := get_callout_info(plot_res, target_size, pv_pos, pv_size, x_view, y_view, x_callout, y_callout, x_label, y_label, title, color_theme);
defer {
	delete(lines);
	
	for t in texts {
		delete(t.value);
	}
	delete(texts);
}


	render.pipeline_begin(draw_pipeline, cam_2d);
		
		//it was using direct draw, so draw whatever is in the texture.
		render.frame_buffer_blit_color_attach_to_texture(&w.plot_framebuffer, 0, w.plot_texture);					
		render.set_texture(.texture_diffuse, w.plot_texture);
		render.draw_quad_rect(inner_plot_position, 0);
		
		render.set_texture(.texture_diffuse, render.texture2D_get_white());
		for l in lines {
			render.draw_line_2D(l.a, l.b, l.thickness, 0, l.color);
		}
		
	render.pipeline_end();
	
	for t in texts {
		render.text_draw(t.value, t.position, t.size, false, false, t.color, {t.backdrop_color, t.backdrop}, rotation = t.rotation);
	}
*/