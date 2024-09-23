package plot;

import "core:time"
import "core:slice"

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
	
	pt := Plot_xy{
		span_pos,
		value_pos,
		Grid_desc{line_width = 0.001, color = {0.8, 0.8, 0.8, 0.2}},
		[2]Maybe(Axis_desc){nil, nil},
	}
	
	make_plot_window(pt);
	
}

plot_surface :: proc () {
	//...
}









