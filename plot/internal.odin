package plot;

import "../render"
import gui "../regui"
import "core:time"
import "core:fmt"
import "core:math"

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
}

Plot_type :: union {
	Plot_xy,
};

Plot_window :: struct {
	window : ^render.Window,
	plot_type : Plot_type,
	gui_state : gui.Scene,
	
	plot_framebuffer : render.Frame_buffer,
}

plot_windows : [dynamic]^Plot_window;

//Pauses execution until all windows are closed, and continuesly updates the windows.
hold :: proc () {
	
	for len(plot_windows) != 0 {
		render.begin_frame();
		
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
			
			//TODO multi smaple texture
			if w.plot_framebuffer.width != target_size.x || w.plot_framebuffer.height != target_size.y {
				render.frame_buffer_resize(&w.plot_framebuffer, target_size);
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
			
			render.target_begin(&w.plot_framebuffer, [4]f32{0.2,0.2,0.2,1});
				render.pipeline_begin(draw_pipeline, cam_2d);
					
					//Draw the polt to the plot_texture
					switch p in w.plot_type {
						case Plot_xy:
							render.set_texture(.texture_diffuse, render.texture2D_get_white());
							
							//Default spacing
							grid_x_cnt : int = cast(int)(6.0 * width);
							grid_y_cnt : int = cast(int)(6.0);
							
							grid_line_width := p.grid_desc.line_width * min(width, height);
							
							for grid_x in 0..=grid_x_cnt {
								x := (cast(f32)(grid_x) / cast(f32)grid_x_cnt) * width;						
								render.draw_line_2D({x,0}, {x,height}, grid_line_width, 0, p.grid_desc.color);
							}
							for grid_y in 0..=grid_y_cnt {
								y := (cast(f32)(grid_y) / cast(f32)grid_y_cnt) * height;						
								render.draw_line_2D({0,y}, {width,y}, grid_line_width, 0, p.grid_desc.color);
							}
							
							line_width := 0.005 * min(width, height);
							
							xlow, xhigh := get_extremes(p.abscissa);
							ylow, yhigh := get_extremes(p.ordinate);
							
							assert(len(p.abscissa) == len(p.ordinate), "The x and y does not have same length");
							for e, i in p.ordinate[:len(p.ordinate)-1] {
								x1, x2 : f32 = (p.abscissa[i] - xlow) / (xhigh - xlow), (p.abscissa[i+1] - xlow) / (xhigh - xlow);
								y1, y2 : f32 = (cast(f32)e - ylow) / (yhigh - ylow), (cast(f32)p.ordinate[i+1] - ylow) / (yhigh - ylow);
								
								//x1, x2, y1, y2 = math.clamp(x1, 0, 1), math.clamp(x2, 0, 1), math.clamp(y1, 0, 1), math.clamp(y2, 0, 1);
								
								render.draw_line_2D({x1 * width, y1 * height}, {x2 * width, y2 * height}, line_width, 0, {1,0,0,1});
								//fmt.printf("a : %v, b : %v\n", [2]f32{x1, y1}, [2]f32{x2, y2});
							}
						
					}
				render.pipeline_end();
			render.target_end();
			
			render.target_begin(w.window, [4]f32{0.2,0.2,0.2,1});
				render.pipeline_begin(draw_pipeline, cam_2d);
				
				t := render.frame_buffer_color_attach_as_texture(&w.plot_framebuffer, 0);
				render.set_texture(.texture_diffuse, t)
				render.draw_quad_rect({0, 0, width, height}, 0)
				
				render.pipeline_end();
				
				//Draw the plot texture to the gui panel
				gui.begin(&w.gui_state, w.window);
				
				
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

@(private)
make_plot_window :: proc (pt : Plot_type, loc := #caller_location) -> ^Plot_window {
	ensure_render_init(loc = loc);
	
	w := render.window_make(512, 512, "Plot", .allow_resize, .msaa32, loc = loc);
	
	pw : ^Plot_window = new(Plot_window, loc = loc);
	
	pw^ = Plot_window {
		w,
		pt,
		gui.init(),
		render.frame_buffer_make_textures({{.clamp_to_edge, .linear, .RGBA8}}, 1000, 1000, .depth_component32, nil, loc = loc),
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
	
	arr := make([]T, steps);
	
	for i in 0..<steps{
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
}




