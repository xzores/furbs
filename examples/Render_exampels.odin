/*

package examples;

import "core:fmt"
import "core:testing"
import "core:math"
import "core:math/linalg"
import "core:image/png"
import "core:os"
import "core:bytes"
import "core:math/rand"

import "vendor:glfw"

import render "../interface";

/*
*/
@test
Draw_quad_2D :: proc(t : ^testing.T) {
	using render;

	window := init_window(600, 400, "Hello world", "res/shaders");
	
	my_quad := generate_quad();
	
	my_shader : Shader;
	load_shader(&my_shader, "gui", "gui");

	my_camera : Camera2D = {
		position 			= {0,0},
		target_relative 	= {0,0},
		rotation 			= 0,
		zoom	   			= 1,

		far 				= 1,
		near 				= -1,
	};

	//Optional: load a cursor
	{
		using png;

		data, ok := os.read_entire_file_from_filename("res/cursor/my_cursor.png");
		defer delete(data);

		options := Options{
			.alpha_add_if_missing,
		};

		img, err := png.load_from_bytes(data, options);
		if err != nil {
			panic("Failed to load cursor");
		}
		defer destroy(img)

		assert(img.width == img.height, "Icon must be square")
		set_cursor(bytes.buffer_to_bytes(&img.pixels), auto_cast img.width);
	}
	
	for !should_close(window) {
		begin_frame(window, {1,0,1,1});
		
		//////// LOGIC ////////

		if is_key_down(Key_code.a) {
			my_camera.position -= {1,0} * delta_time();
		}
		if is_key_down(Key_code.a) {
			my_camera.position += {1,0} * delta_time();
		}
		if is_key_down(Key_code.a) {
			my_camera.position += {0,1} * delta_time();
		}
		if is_key_down(Key_code.a) {
			my_camera.position -= {0,1} * delta_time();
		}
		
		//////// Draw 2D ////////
		//2D
		begin_mode_2D(my_camera); //Camera is optional
		bind_shader(my_shader);

		//keep running
		draw_mesh_single(my_shader, my_quad);
		
		unbind_shader(my_shader);
		end_mode_2D(my_camera);
		//////////////////////////

		end_frame(window);
	}

	destroy_window(&window);

	fmt.printf("Shutdown succesfull");
}

@test
Draw_quad_3D :: proc(t : ^testing.T) {
	using render;

	window := init_window(600, 400, "Hello world", "res/shaders");
	
	my_quad := generate_quad();
	
	my_shader : Shader;
	load_shader(&my_shader, "gui", "gui");
	
	my_camera : Camera3D = {
		position 	= {0,0,-1},
		target 		= {0,0,0},
		up       	= {0,1,0},
		fovy     	= 75,
		projection 	= .perspective,
		far 		= 1000, 
		near 		= 0.1,
	};
	
	cam_rot : [2]f32;

	mouse_mode(.locked);
	
	for !should_close(window) {
		begin_frame(window);

		//////// LOGIC ////////
		
		if is_key_down(Key_code.a) {
			camera_move(&my_camera, -10 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.d) {
			camera_move(&my_camera, 10 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.w) {
			camera_move(&my_camera, 10 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.s) {
			camera_move(&my_camera, -10 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.space) {
			camera_move(&my_camera, 10 * my_camera.up * delta_time());
		}
		if is_key_down(Key_code.control_left) {
			camera_move(&my_camera, -10 * my_camera.up * delta_time());
		}

		cam_rot += 0.1 * {mouse_delta.x, -mouse_delta.y}; //mouse_delta.y
		cam_rot.y = math.clamp(cam_rot.y, -40, 30);
		camera_rotation(&my_camera, cam_rot.x, cam_rot.y);
		
		//////// Draw 3D ////////
		begin_mode_3D(my_camera);
		bind_shader(my_shader);

		//keep running
		draw_mesh_single(my_shader, my_quad);
		
		unbind_shader(my_shader);
		end_mode_3D(my_camera);
		//////////////////////////

		end_frame(window);
	}

	destroy_window(&window);

	fmt.printf("Shutdown succesfull");
}

/* 
main :: proc() {
*/
@test
Draw_shapes :: proc (t : ^testing.T) {
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
		
		//Draw triangles //TODO
		//draw_shape([3][2]f32{{0,0}, {-0.25, 0}, {-0.25, 0}}, color = {0,1,0,1});
		
		//Draw lines
		draw_shape(Circle{1, [2]f32{0,0}}, color = {0,0,1,0.5});

		end_mode_2D(my_camera);

		end_frame(window);
	}
	
	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

/* 
main :: proc () {
*/
@test
Draw_text :: proc (t : ^testing.T) {
	using render;
	
	window := init_window(1000, 800, "Hello world", "res/shaders", culling = false);
	
	//mouse_mode(.normal);
	//enable_vsync(false); //disable Vsync
	
	my_rect : [4][2]f32 = {};
	
	//my_texture := load_texture_from_file("res/textures/test.png");
	my_font := load_font_from_file("some_font", "res/fonts/NotoSansRegular.ttf");
	//my_text_shader : Shader;
	//load_shader(&my_text_shader, "text_shader_vs", "text_shader");
	
	for !should_close(window) {
		
		begin_frame(window, clear_color = {0.5,0.5,0.5,1});
		
		cam := get_pixel_space_camera();
		begin_mode_2D(cam, use_transparency = true);

		//Draw rects
		//draw_shape([4]f32{0, 0, 3400, 10}, color = {1, 0, 0, 0.75});
		//draw_shape([4]f32{100, 200, 200, 200}, texture = my_texture, color = {1, 1, 1, 0.5});
		
		//Draw triangles //TODO
		//draw_shape([3][2]f32{{0,0}, {-0.25, 0}, {-0.25, 0}}, color = {0,1,0,1});
		
		//Draw lines
		//draw_shape(Circle{100, [2]f32{0,0}}, color = {0,0,1,0.5});

		//Drawing text, note this should happen in pixel space
		draw_text("汉字 Hello Albz, TEXT IS WORKING! (YES WTF det tog langt tid) 汉字", {50, 50}, my_font, 50);

		end_mode_2D(cam);

		end_frame(window);
	}
	
	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}


/* 
@test
Draw_to_render_target :: proc (t : ^testing.T) {
*/
main :: proc () {
using render;

	window := init_window(600, 400, "Hello world", "res/shaders", culling = false);

	mouse_mode(.normal);
	enable_vsync(false); //disable Vsync
	
	my_cube 	:= generate_cube(use_index_buffer = false);
	upload_mesh_single(&my_cube);
	
	render_texture : Render_texture = load_render_texture(600, 400); //This should be resized if it shall fill the entire screen.

	//my_texture : Texture2D = load_texture_from_raw_bytes(nil, 600, 400, .uncompressed_RGBA8); //This should be resized if it shall fill the entire screen.

	my_shader : Shader;
	load_shader(&my_shader, "opaque", "opaque");

	my_camera : Camera3D = {
		position 	= {0.5, 0.5, -10},
		target 		= {0.5, 0.5, 0},
		up       	= {0,1,0},
		fovy     	= 75,
		projection 	= .perspective,
		far 		= 1000, 
		near 		= 0.1,
	};
	
	for !should_close(window) {
		begin_frame(window, clear_color = {0.5,0.5,0.5,1});
		
		if is_key_down(Key_code.a) {
			camera_move(&my_camera, -1 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.d) {
			camera_move(&my_camera, 1 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.w) {
			camera_move(&my_camera, 1 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.s) {
			camera_move(&my_camera, -1 * camera_forward(my_camera) * delta_time());
		}

		//////////////////
		begin_texture_mode(render_texture);
		clear_color_depth(clear_color = {1,0,1,1});
		begin_mode_3D(my_camera);

		//bind_shader(my_shader);
		//draw_mesh_single(my_shader, my_cube, linalg.matrix4_translate_f32({0,0,0}));
		//unbind_shader(my_shader);
		
		draw_shape([4]f32{0, 0, 2, 2}, color = {0,1,0,1});

		end_mode_3D(my_camera);
		end_texture_mode(render_texture);
		
		pix_cam := get_pixel_space_camera();
		begin_mode_2D(pix_cam);
		draw_shape([4]f32{0, 0, current_render_target_width / 2, current_render_target_height}, color = {0,0,1,1}); //TODO THIS DOES NOT RENDER THE RIGHT COLOR? GLDRAWBUFFER MAYBE? ;FOLLOW https://learnopengl.com/Advanced-OpenGL/Framebuffers
		//draw_shape([4]f32{current_render_target_width / 2, 0, current_render_target_width / 2, current_render_target_height}, color = {1,1,0.3,0.1});
		end_mode_2D(pix_cam);

		//blit_render_texture_to_screen(render_texture);

		end_frame(window);
	}
	
	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

import "core:math/noise"

/*
This example shown how to draw a lot of similar things (non instanced).
*/

size :: 32;
blocks : [size][size][size]u8;
shared_meshs : [size][size][size]render.Mesh;

//In this example we want to draw many different shapes on the screen (please ignore that there is only 3 types, imagine every draw call has a different mesh).
/*
*/
@test
Voxel_game_a_slow_way :: proc(t : ^testing.T) {
	using render;

	window := init_window(800, 600, "Hello world", "res/shaders", required_gl_verion = .opengl_3_0);
	
	enable_vsync(false); //disable Vsync
	mouse_mode(.locked);
	
	my_cube 	:= generate_cube(use_index_buffer = false);
	my_cylinder := generate_cylinder(use_index_buffer = false, offset = {-0.5,0.5,-0.5});
	my_sphere 	:= generate_sphere(use_index_buffer = false, offset = {-0.5,0.5,-0.5});
	upload_mesh_single(&my_cube);
	upload_mesh_single(&my_cylinder);
	upload_mesh_single(&my_sphere);
	//TODO remove_mesh_cpu_mem(&quad); //NOTE: it is so small we don't need to do it.

	mesh_buffer : Mesh_buffer;
	init_mesh_buffer(&mesh_buffer, 500 * size * size * size, 0, active_locations = {.position, .texcoord}, use_indicies = false);
	
	for x in 0..<size {
		for y in 0..<size {
			for z in 0..<size {
				
				pos : [3]f64 = {auto_cast x, auto_cast y, auto_cast z};
				pos /= 20;
				sample := noise.noise_3d_improve_xz(1234, pos); //You can change the seed to something else then 1234
				
				if sample > 0 {
					blocks[x][y][z] = auto_cast rand.int31_max(3) + 1;
					
					geom : Mesh;
					if blocks[x][y][z] == 1 {
						geom = generate_cube(use_index_buffer = false);
					}
					if blocks[x][y][z] == 2 {
						geom = generate_cylinder(use_index_buffer = false, offset = {-0.5,0,-0.5})
					}
					if blocks[x][y][z] == 3 {
						geom = generate_sphere(use_index_buffer = false, offset = {-0.5,0,-0.5})
					}
					upload_mesh_shared(&geom, &mesh_buffer);
					shared_meshs[x][y][z] = geom;
				}
				else {
					blocks[x][y][z] = 0;
				}
			}
		}
	}

	my_texture1 := load_texture_from_file("res/textures/stone.png");
	my_texture2 := load_texture_from_file("res/textures/dirt.png");
	my_texture3 := load_texture_from_file("res/textures/grass.png");

	my_shader : Shader;
	load_shader(&my_shader, "opaque", "opaque");
	
	my_camera : Camera3D = {
		position 	= {0,0,-1},
		target 		= {0,0,0},
		up       	= {0,1,0},
		fovy     	= 75,
		projection 	= .perspective,
		far 		= 1000, 
		near 		= 0.1,
	};
	
	cam_rot : [2]f32;
	use_slow : bool = true;
	
	for !should_close(window) {
		begin_frame(window);

		//////// LOGIC ////////
		if is_key_down(Key_code.a) {
			camera_move(&my_camera, -10 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.d) {
			camera_move(&my_camera, 10 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.w) {
			camera_move(&my_camera, 10 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.s) {
			camera_move(&my_camera, -10 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.space) {
			camera_move(&my_camera, 10 * my_camera.up * delta_time());
		}
		if is_key_down(Key_code.control_left) {
			camera_move(&my_camera, -10 * my_camera.up * delta_time());
		}
		if is_key_pressed(Key_code.f8) {
			use_slow = !use_slow;
		}

		if is_button_pressed(Mouse_code.left) {
			fmt.printf("Left mouse pressed!\n");
		}

		cam_rot += 0.1 * {mouse_delta.x, -mouse_delta.y}; //mouse_delta.y
		cam_rot.y = math.clamp(cam_rot.y, -89, 89);
		camera_rotation(&my_camera, cam_rot.x, cam_rot.y);

		//////// Draw 3D ////////
		begin_mode_3D(my_camera);
		bind_shader(my_shader);

		if use_slow {
			for x in 0..<size {
				for y in 0..<size {
					for z in 0..<size {
						
						//This code is slow, it has a lot of overhead due to driver interaction.
						//It quick and dirt, slow way to draw things, look at the alternatives.
						if blocks[x][y][z] == 1 {
							place_uniform(my_shader, .texture_diffuse, my_texture1);
							draw_mesh_single(my_shader, my_cube, linalg.matrix4_translate(linalg.Vector3f32{f32(x),f32(y),f32(z)}));
						}
						else if blocks[x][y][z] == 2 {
							place_uniform(my_shader, .texture_diffuse, my_texture2);
							draw_mesh_single(my_shader, my_cylinder, linalg.matrix4_translate(linalg.Vector3f32{f32(x),f32(y),f32(z)}));
						}
						else if blocks[x][y][z] == 3 {
							place_uniform(my_shader, .texture_diffuse, my_texture3);
							draw_mesh_single(my_shader, my_sphere, linalg.matrix4_translate(linalg.Vector3f32{f32(x),f32(y),f32(z)}));
						}
					}
				}
			}
		}
		else {
			for x in 0..<size {
				for y in 0..<size {
					for z in 0..<size {
						
						//This code is slow, it has a lot of overhead due to driver interaction.
						//But is should be faster then the code above (click f8 to see difference without -debug enabled).
						//This is this code shares a mesh(VAO), on my machine it gives about a 10-20% improvement in FPS.
						//This is not a fast way to draw, but in some cases it is about as good as it gets, check the alternatives before using this one.
						if blocks[x][y][z] == 1 {
							place_uniform(my_shader, .texture_diffuse, my_texture1);
							draw_mesh_single_shared(my_shader, shared_meshs[x][y][z], mesh_buffer, linalg.matrix4_translate(linalg.Vector3f32{f32(x),f32(y),f32(z)}));
						}
						else if blocks[x][y][z] == 2 {
							place_uniform(my_shader, .texture_diffuse, my_texture2);
							draw_mesh_single_shared(my_shader, shared_meshs[x][y][z], mesh_buffer, linalg.matrix4_translate(linalg.Vector3f32{f32(x),f32(y),f32(z)}));
						}
						else if blocks[x][y][z] == 3 {
							place_uniform(my_shader, .texture_diffuse, my_texture3);
							draw_mesh_single_shared(my_shader, shared_meshs[x][y][z], mesh_buffer, linalg.matrix4_translate(linalg.Vector3f32{f32(x),f32(y),f32(z)}));
						}
					}
				}
			}
		}

		unbind_shader(my_shader);
		end_mode_3D(my_camera);
		//////////////////////////

		end_frame(window);
	}

	destroy_window(&window);

	fmt.printf("Shutdown succesfull");
}


//This is an example of instanced drawing
@test
Instanced_drawing :: proc (t : ^testing.T) {
	using render;

	window := init_window(800, 600, "Hello world", "res/shaders");
	
	enable_vsync(false); //disable Vsync
	mouse_mode(.locked);
	
	my_cube 	:= generate_cube(use_index_buffer = false);
	upload_mesh_single(&my_cube);
	//TODO remove_mesh_cpu_mem(&quad); //NOTE: it is so small we don't need to do it.
	
	my_texture1 := load_texture_from_file("res/textures/stone.png");

	mesh_buffer : Mesh_buffer;
	init_mesh_buffer(&mesh_buffer, 1, 0, active_locations = {.position, .texcoord}, use_indicies = false);

	my_shader : Shader;
	load_shader(&my_shader, "opaque", "opaque");
	
	my_camera : Camera3D = {
		position 	= {0,0,-1},
		target 		= {0,0,0},
		up       	= {0,1,0},
		fovy     	= 75,
		projection 	= .perspective,
		far 		= 1000, 
		near 		= 0.1,
	};
	
	cam_rot : [2]f32;
	
	for !should_close(window) {
		begin_frame(window);

		//////// LOGIC ////////
		if is_key_down(Key_code.a) {
			camera_move(&my_camera, -10 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.d) {
			camera_move(&my_camera, 10 * camera_right(my_camera) * delta_time());
		}
		if is_key_down(Key_code.w) {
			camera_move(&my_camera, 10 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.s) {
			camera_move(&my_camera, -10 * camera_forward(my_camera) * delta_time());
		}
		if is_key_down(Key_code.space) {
			camera_move(&my_camera, 10 * my_camera.up * delta_time());
		}
		if is_key_down(Key_code.control_left) {
			camera_move(&my_camera, -10 * my_camera.up * delta_time());
		}

		cam_rot += 0.1 * {mouse_delta.x, -mouse_delta.y}; //mouse_delta.y
		cam_rot.y = math.clamp(cam_rot.y, -89, 89);
		camera_rotation(&my_camera, cam_rot.x, cam_rot.y);

		//////// Draw 3D ////////
		begin_mode_3D(my_camera);
		bind_shader(my_shader);
		
		//panic("unimplemented");

		unbind_shader(my_shader);
		end_mode_3D(my_camera);
		//////////////////////////

		end_frame(window);
	}

	destroy_window(&window);

	fmt.printf("Shutdown succesfull");
}
*/