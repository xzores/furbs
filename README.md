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
Codeveloped by albe194e


Examples are included to do the following:
    -Drawing 2D<br />
![Drawing_a_quad](https://github.com/xzores/furbs/assets/17770917/af20e297-bbad-422a-b0a1-90c6a34333d7)

    -Drawing 3D<br />
![Drawing_a_quad_3D](https://github.com/xzores/furbs/assets/17770917/df6b56d2-5fe3-49fd-b045-4ecaecfbbe4e)

    -Drawing 2D shapes, transparetcy and textures 3D<br />
![Drawing_shapes](https://github.com/xzores/furbs/assets/17770917/4d89a90a-9518-4967-8636-f11c02e11bbf)

    -Drawing text<br />
![Drawing_text](https://github.com/xzores/furbs/assets/17770917/9e2c1360-17cd-4d08-a3c3-a0a00f867dac)

    -Drawing 3D<br />
![Drawing_3D](https://github.com/xzores/furbs/assets/17770917/fdf7f63d-a190-41eb-9c47-4cfdccfd5597)
![Skærmbillede 2023-12-23 000822](https://github.com/xzores/furbs/assets/17770917/8146e1c2-8aa6-4fe7-9923-9bdd1b1468b1)
