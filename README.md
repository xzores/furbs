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
		position 			= {0,0},			// Camera position
		target_relative 	= {0,0},			// 
		rotation	 		= 0,				// In degrees
		zoom	   			= 1,				//
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


Furbs also include a gui library.<br />
The gui library includes the following elements:<br />
 	-Rect<br />
		-Button<br />
	-Checkbox<br />
	-Slide_input<br />
	-Slider<br />
	-Input_field<br />
	-Selector<br />
	-Slot<br />
	-Label<br />

Below is an example with a button:<br />
![Skærmbillede 2024-01-01 201929](https://github.com/xzores/furbs/assets/17770917/6a34fc64-dff5-42b5-a364-a693a62c661f) <br />

and here is a little menu:<br />
![Skærmbillede 2024-01-01 202136](https://github.com/xzores/furbs/assets/17770917/5ba1545e-3a0d-4082-a905-bf1f038e6f2a) <br />
resizing happens automagicly.<br />
![Skærmbillede 2024-01-01 202311](https://github.com/xzores/furbs/assets/17770917/19cf8897-fd62-4f06-b04f-d27a8abdd6fa) <br />
this gui system is suitable for in-game guis. Once can retrive events like: hover, active and  triggered. <br />
hover : being true when the elements is hovered over. <br />
active : being trie when the element is currently selected in one way or another, this is element dependent.<br />
triggered : being true when the element recives an 1 time event (like being clicked) also element dependent.<br />

A collection of gui elements are shown below:<br />
![Skærmbillede 2024-01-01 202400](https://github.com/xzores/furbs/assets/17770917/e76d26b1-7091-40c5-a6b7-51162db3527c)

![image](https://github.com/user-attachments/assets/1d4d60b2-856e-4a58-b3d9-cac42ad2dde4)

