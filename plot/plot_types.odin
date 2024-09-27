package plot;

import "../render"
import gui "../regui"
import "core:fmt"
import "core:math"
import "core:unicode/utf8"
import "core:slice"


plot_inner :: proc (plot_type : ^Plot_type, width_i, height_i : i32) -> (pv_pos, pv_size, x_view, y_view : [2]f32, grid_cnt : [2]i32) {
	
	//Calculate normalized space coordinates.
	width_f, height_f := cast(f32)width_i, cast(f32)height_i;
	aspect_ratio := width_f / height_f;
	width, height : f32 = aspect_ratio, 1.0;
	
	//Draw the polt to the plot_texture
	switch &p in plot_type {
		case Plot_xy:
			
			//handle export variables
			{
				//plot view
				pv_pos = {0.15, 0.10};
				size : [2]f32 = {0.78, 0.85};
				pv_size = {width - (1.0 - size.x), height - (1.0 - size.y)};
				
				//Default spacing
				grid_cnt = [2]i32{cast(i32)(6.0 * width), 12};
				
				//inner view
				x_view = p.x_view;
				y_view = p.y_view;
				
				//TODO find a better spacing, max 6(+1) (so text can fit)
				//There is a max of 7 chars
			}
			
			//handle input and change state
			{
				if render.button_down(.middel) {
					md := render.mouse_delta();
					
					p.x_view -= ((p.x_view[1] - p.x_view[0]) / pv_size.x) * (cast(f32)md.x / height_f);
					p.y_view += ((p.y_view[1] - p.y_view[0]) / pv_size.y) * (cast(f32)md.y / height_f);
				}
				
				{
					scroll_delta := render.scroll_delta();
					
					
					total_x : f32 = p.x_view[1] - p.x_view[0];
					total_y : f32 = p.y_view[1] - p.y_view[0];
					
					d : f32 = -scroll_delta.y * 0.02;
					
					if !render.is_key_down(.shift_left) {
						p.x_view = p.x_view + d * [2]f32{-total_x, total_x};
					}
					if !render.is_key_down(.control_left) {
						p.y_view = p.y_view + d * [2]f32{-total_y, total_y};
					}
				}
				
				if render.is_key_down(.r) {
					xlow, xhigh := get_extremes(p.abscissa);
					ylow, yhigh := get_extremes(p.ordinate);
					
					total_y : f32 = yhigh - ylow;
					
					p.x_view = {xlow, xhigh};
					p.y_view = {ylow - 0.1 * total_y, yhigh + 0.1 * total_y};
				}
			}
			
			//Plot the inner plot
			{
				render.set_texture(.texture_diffuse, render.texture2D_get_white());
				
				grid_line_width := p.grid_desc.line_width * min(width, height);
				
				for grid_x in 0..=grid_cnt.x {
					x := (cast(f32)(grid_x) / cast(f32)grid_cnt.x) * width;						
					render.draw_line_2D({x,0}, {x,height}, grid_line_width, 0, p.grid_desc.color);
				}
				for grid_y in 0..=grid_cnt.y {
					y := (cast(f32)(grid_y) / cast(f32)grid_cnt.y) * height;						
					render.draw_line_2D({0,y}, {width,y}, grid_line_width, 0, p.grid_desc.color);
				}
				
				line_width := 0.005 * min(width, height);
				
				assert(len(p.abscissa) == len(p.ordinate), "The x and y does not have same length");
				for e, i in p.ordinate[:len(p.ordinate)-1] {
					x1, x2 : f32 = (p.abscissa[i] - x_view[0]) / (x_view[1] - x_view[0]), (p.abscissa[i+1] - x_view[0]) / (x_view[1] - x_view[0]);
					y1, y2 : f32 = (cast(f32)e - y_view[0]) / (y_view[1] - y_view[0]), (cast(f32)p.ordinate[i+1] - y_view[0]) / (y_view[1] - y_view[0]);
					
					//x1, x2, y1, y2 = math.clamp(x1, 0, 1), math.clamp(x2, 0, 1), math.clamp(y1, 0, 1), math.clamp(y2, 0, 1);
					
					render.draw_line_2D({x1 * width, y1 * height}, {x2 * width, y2 * height}, line_width, 0, {1,0,0,1});
					//fmt.printf("a : %v, b : %v\n", [2]f32{x1, y1}, [2]f32{x2, y2});
				}
			}
			
			return;
	}
	
	unreachable();
}




