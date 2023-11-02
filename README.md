# Furbs
A Odin library for games, currently under construction not ready for production.

Furbs library collection aims to provide all the necessities for shipping 3D/2D indie games. 

The libary collection current holds the following capabilities:<br />
    -Utils (used internally)<br />
    -Render, used for opening a windows and rending OpenGL 3.3 to 4.6, this might in the furture support 3.0, OpenGL ES 2/3<br />
    -GUI library<br />
    -Networking library<br />
    -Sound library (comming)<br />
    -Partical system library (comming)<br />

It is heavily inspired by Raylib with a greater emphasis om preformence while still being easy to use.

Here is how you would open draw a few 2D shapes with the render library (more examples in "exampels")
```
import "path/render" //or replace "path"

main :: proc {
	using render;
	
	window := init_window(600, 400, "Hello world", "res/shaders", culling = false);
	
	my_texture := load_texture_from_file("res/textures/test.png");

	mouse_mode(.normal);
	enable_vsync(false); //disable Vsync
	
	my_rect : [4][2]f32 = {};

	my_camera : Camera2D = {
		position 			= {0,0},            // Camera position
		target_relative 	= {0,0},			// 
		rotation	 		= 0,				// In degrees
		zoom	   			= 1,            	//
		far					= 1,
		near 				= -1,
	};
	
	for !should_close(window) {
		begin_frame(window, clear_color = {0.5,0.5,0.5,1});
		begin_mode_2D(my_camera);

		//Draw rects
		draw_shape([4]f32{0, 0, 0.5, 0.5}, rot = 45, texture = my_texture);
		draw_shape([4]f32{-0.5, -0.5, 0.5, 0.5}, color = {1,0,0,1});
		
		//Draw lines
		draw_shape(Circle{1, [2]f32{0,0}}, color = {0,0,1,0.5});

		end_mode_2D(my_camera);
		end_frame(window);
	}
	
	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}
```

Tutorials, documentation and more exampels are on the way.
