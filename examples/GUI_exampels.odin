package examples;

import "core:fmt"
import "core:testing"
import "core:math"
import "core:os"
import "core:bytes"
import "core:math/rand"

import "vendor:glfw"
import ma "vendor:miniaudio"

import "../render"
import "../gui"


/*
main :: proc () {
*/
@test
minimum_implementation_button :: proc(t : ^testing.T) {
	using render;

	window := init_window(600, 600, "Hello world", "res/shaders");
	my_font := load_font_from_file("some_font", "res/fonts/FirstTimeWriting.ttf");

	font_style : gui.Font_style = {
		font = my_font,
		font_size = 0.08, 	//this is in screen space, so big text.
		font_spacing = 0,	//
		font_color = {1,1,1,1},
	}
	
	my_style : gui.Style = gui.make_style(font_style, bg_color = {0.5, 0.5, 0.5, 1}, texture = load_texture_from_file("res/GUI/button.png"));

	my_style_hover := my_style;
	my_style_hover.bg_color = {1, 1, 1, 1};

	my_style_active := my_style_hover;
	my_style_active.texture = load_texture_from_file("res/GUI/button_active.png");

	my_theme := gui.init_theme();
	my_theme.default_style = my_style;
	my_theme.default_hover_style = my_style_hover;
	my_theme.default_active_style = my_style_active;
	
	gui.push_theme(my_theme);

	for !should_close(window) {
		
		begin_frame(window, {0.2,0.2,0.2,1});

		//////// Draw GUI ////////
		my_camera := get_pixel_space_camera();
		begin_mode_2D(my_camera, use_transparency = true);
		gui.begin();
		
		if gui.draw_button("I am a button", {.center_center, .center_center, [4]f32{0,0,0.4,0.1}} ) {
			fmt.printf("You clicked the button!\n");
		}

		gui.end();
		end_mode_2D(my_camera);

		end_frame(window);
	}
	
	gui.pop_theme(my_theme);

	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

/*
main :: proc () {
*/
//These exists helper functions to make you able to load an entire GUI from a file, the complication comes when extracting the return values.
//The valuse, like "clicked butten" must be given by the user. And so there is a GUI builder object.
@test
loading_style_from_file :: proc (t : ^testing.T) {
	using render;

	window := init_window(600, 600, "Hello world", "res/shaders");
	my_font := load_font_from_file("some_font", "res/fonts/FirstTimeWriting.ttf");

	font_style : gui.Font_style = {
		font = my_font,
		font_size = 0.08, 	//this is in screen space, so big text.
		font_spacing = 0,	//
		font_color = {1,1,1,1},
	}

	my_theme := gui.init_theme();
	my_theme.default_style = gui.load_style_from_filename("res/Themes/style01.style", font_style);
	my_theme.default_hover_style = gui.load_style_from_filename("res/Themes/style02.style", font_style);
	my_theme.default_active_style = gui.load_style_from_filename("res/Themes/style03.style", font_style);
	
	gui.push_theme(my_theme);

	for !should_close(window) {
		
		begin_frame(window, {0.2,0.2,0.2,1});

		//////// Draw GUI ////////
		my_camera := get_pixel_space_camera();
		begin_mode_2D(my_camera, use_transparency = true);
		gui.begin();
		
		if gui.draw_button("I am a button", {.center_center, .center_center, [4]f32{0,0,0.4,0.1}} ) {
			fmt.printf("You clicked the button!\n");
		}

		gui.end();
		end_mode_2D(my_camera);
		
		end_frame(window);
	}
	
	gui.pop_theme(my_theme);

	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

/*
main :: proc () {
*/
//It is also possaible to load en entire theme from a file.
@test
loading_a_theme :: proc (t : ^testing.T) {
	using render;

	window := init_window(600, 600, "Hello world", "res/shaders");
	my_font := load_font_from_file("some_font", "res/fonts/FirstTimeWriting.ttf");

	font_style : gui.Font_style = {
		font = my_font,
		font_size = 0.08, 	//this is in screen space, so big text.
		font_spacing = 0,	//
		font_color = {1,1,1,1},
	}
	
	my_theme := gui.load_theme_from_filename("res/Themes/theme01.theme", font_style);
		
	gui.push_theme(my_theme);

	checked : bool = false;

	for !should_close(window) {
		
		begin_frame(window, {0.2,0.2,0.2,1});

		//////// Draw GUI ////////
		my_camera := get_pixel_space_camera();
		begin_mode_2D(my_camera, use_transparency = true);
		gui.begin();
		
		gui.draw_label("Welcome to the jungle", {.top_center, .top_center, [4]f32{0,-0.1,0.7,0.1}});

		if gui.draw_button("Ready", {.center_center, .center_center, [4]f32{0,0,0.4,0.1}} ) {
			fmt.printf("You clicked the button!\n");
		}

		checked = gui.draw_checkbox(checked, {.top_right, .top_right, [4]f32{0,0,0.1,0.1}});

		gui.end();
		end_mode_2D(my_camera);

		end_frame(window);
	}
	
	gui.pop_theme(my_theme);

	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

/*
main :: proc () {
*/
//It is also possaible to load en entire theme from a file.
@test
menu_example :: proc (t : ^testing.T) {
	using render;

	window := init_window(600, 600, "Hello world", "res/shaders");
	my_font := load_font_from_file("some_font", "res/fonts/FirstTimeWriting.ttf");

	font_style : gui.Font_style = {
		font = my_font,
		font_size = 0.05, 	//this is in screen space, so big text.
		font_spacing = 0,	//
		font_color = {1,1,1,1},
	}
	
	my_theme := gui.load_theme_from_filename("res/Themes/theme01.theme", font_style);
	
	no_style := gui.make_style(font_style, bg_color = {0,0,0,0});
	grey_style := gui.make_style(font_style, bg_color = {0.3, 0.3, 0.3, 0.5});

	gui.push_theme(my_theme);

	checked : bool = false;
	slide_input_value : f32 = 0;

	p1 : gui.Destination = {self_anchor = .center_center, anchor = .center_center, rect = {0, 0, 0.7, 0.7}};
	panel1 := gui.init_panel(p1, scrollable_y = true);

	for !should_close(window) {
		
		begin_frame(window, {0.2,0.2,0.2,1});

		//////// Draw GUI ////////
		my_camera := get_pixel_space_camera();
		begin_mode_2D(my_camera, use_transparency = true);
		gui.begin();

		gui.push_panel(&panel1);
			
			gui.draw_rect(p1, grey_style);
			gui.draw_label("Welcome to the jungle", {.top_center, .top_center, [4]f32{0,-0.05,0.6,0.1}});

			if gui.draw_button("Ready", {.center_center, .center_center, [4]f32{0,0,0.4,0.1}} ) {
				fmt.printf("You clicked the button!\n");
			}

			checked = gui.draw_checkbox(checked, {.center_right, .center_right, [4]f32{-0.05,-0.2,0.1,0.1}});
			slide_input_value = gui.draw_slide_input(slide_input_value, 0, 5, {.bottom_center, .bottom_center, [4]f32{-0.05,-0.2,0.1,0.1}});

			gui.draw_label("Enable cheats:", {.center_left, .center_left, [4]f32{0.05,-0.2,0.3,0.1}}, no_style);

		gui.pop_panel(&panel1);

		gui.end();
		end_mode_2D(my_camera);

		end_frame(window);
	}
	
	gui.pop_theme(my_theme);

	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

//Here you can see how many layers of panels can create some cool effects.
//It is not possiable to have 2 scrollable panels on top of each other. The first panel will mask the scroll from the other panel.
//There is 1 thing you can do, you are able to have 1 x-scrollable and 1 y-scrollable on top of each other.
//main :: proc () {
panels_and_panels :: proc (t : ^testing.T) {
	using render;

	window := init_window(600, 600, "Hello world", "res/shaders");
	my_font := load_font_from_file("some_font", "res/fonts/FirstTimeWriting.ttf");

	font_style : gui.Font_style = {
		font = my_font,
		font_size = 0.05, 	//this is in screen space, so big text.
		font_spacing = 0,	//
		font_color = {1,1,1,1},
	}
	
	my_theme := gui.load_theme_from_filename("res/Themes/theme01.theme", font_style);
	
	no_style := gui.make_style(font_style, bg_color = {0,0,0,0});
	grey_style := gui.make_style(font_style, bg_color = {0.3, 0.3, 0.3, 0.5});

	loot_example := gui.load_style_from_filename("res/Themes/loot_example.style", font_style);

	gui.push_theme(my_theme);

	checked : bool = false;	

	p1 : gui.Destination = {self_anchor = .center_center, anchor = .center_center, rect = {0, 0, 0.7, 0.7}};
	p2 : gui.Destination = {self_anchor = .top_center, anchor = .top_center, rect = {0, -0.18, 0.6, 0.3}};
	p3 : gui.Destination = {self_anchor = .top_center, anchor = .top_center, rect = {0, -0.62, 0.6, 0.3}};
	p4 : gui.Destination = {self_anchor = .top_center, anchor = .top_center, rect = {0, -0.97, 0.6, 0.3}};
	p5 : gui.Destination = {self_anchor = .top_center, anchor = .top_center, rect = {0, -1.28, 0.6, 0.3}};

	panel1 : gui.Panel = gui.init_panel(p1, scrollable_y = true);
	panel2 : gui.Panel = gui.init_panel(p2, scrollable_x = true);
	panel3 : gui.Panel = gui.init_panel(p3, scrollable_x = true);
	panel4 : gui.Panel = gui.init_panel(p4, scrollable_x = true);
	panel5 : gui.Panel = gui.init_panel(p5, scrollable_x = true);

	for !should_close(window) {
		
		begin_frame(window, {0.2,0.2,0.2,1});
		
		//////// Draw GUI ////////
		my_camera := get_pixel_space_camera();
		begin_mode_2D(my_camera, use_transparency = true);
		gui.begin();

		gui.draw_rect(p1, grey_style); //draw a grey box around the panel
		gui.push_panel(&panel1);
			gui.draw_label("Loot table", {.top_center, .top_center, [4]f32{0,0,0.6,0.1}});
			
			gui.draw_rect(p2, grey_style); //draw a grey box around the panel
			gui.draw_label("Potions", {.top_left, .top_left, [4]f32{0,-0.11,0.4,0.05}});
			gui.push_panel(&panel2);
				gui.draw_rect({self_anchor = .center_left, anchor = .center_left, rect = {0, 0, 0.28, 0.25}}, loot_example);
				gui.draw_rect({self_anchor = .center_left, anchor = .center_left, rect = {0.28, 0, 0.25, 0.25}}, loot_example);
				gui.draw_rect({self_anchor = .center_left, anchor = .center_left, rect = {2*0.28, 0, 0.25, 0.25}}, loot_example);
			gui.pop_panel(&panel2);

		gui.pop_panel(&panel1);

		gui.end();
		end_mode_2D(my_camera);

		end_frame(window);
	}
	
	gui.pop_theme(my_theme);

	destroy_window(&window);
	fmt.printf("Shutdown succesfull");
}

/*
@test
Gui_crazy_showoff :: proc (t : ^testing.T) {
*/
//This does not use the simplified API, instead it uses an API that lets you have a little more controll.
//One would easyliy be able to manage these Element_containers in their own GUI manager.
main :: proc () {
	using render;

	///////// SOUND /////////

	Sound_context :: struct {
		hover_sound : ma.sound,
		hover_sound2 : ma.sound,
		active_sound : ma.sound,
		trigger_sound : ma.sound,
		bad_sound : ma.sound,
		detrigger_sound : ma.sound,
	}

	my_sound_context : Sound_context;
	
	result : ma.result;
    engine : ma.engine;
	
    result = ma.engine_init(nil, &engine);
    if (result != .SUCCESS) {
        panic("Failed to init engine");
    }

	defer ma.sound_uninit(&my_sound_context.trigger_sound);
    defer ma.engine_uninit(&engine);

	result = ma.sound_init_from_file(&engine, "res/sound/hover.wav", 0, nil, nil, &my_sound_context.hover_sound);
    if (result != .SUCCESS) {
        panic("Failed to init sound")
    }

	result = ma.sound_init_from_file(&engine, "res/sound/hover2.wav", 0, nil, nil, &my_sound_context.hover_sound2);
    if (result != .SUCCESS) {
        panic("Failed to init sound")
    }

	result = ma.sound_init_from_file(&engine, "res/sound/active.wav", 0, nil, nil, &my_sound_context.active_sound);
    if (result != .SUCCESS) {
        panic("Failed to init sound")
    }

	result = ma.sound_init_from_file(&engine, "res/sound/good_interaction.wav", 0, nil, nil, &my_sound_context.trigger_sound);
    if (result != .SUCCESS) {
        panic("Failed to init sound")
    }

	result = ma.sound_init_from_file(&engine, "res/sound/bad_interaction.wav", 0, nil, nil, &my_sound_context.bad_sound);
    if (result != .SUCCESS) {
        panic("Failed to init sound")
    }

	result = ma.sound_init_from_file(&engine, "res/sound/bad_interaction.wav", 0, nil, nil, &my_sound_context.detrigger_sound);
    if (result != .SUCCESS) {
        panic("Failed to init sound")
    }
	
	window := init_window(600, 600, "Hello world", "res/shaders");
	
	///////////////// SETUP STYLES /////////////////
	
	my_font := load_font_from_file("some_font", "res/fonts/FirstTimeWriting.ttf");
	
	my_button_texture := load_texture_from_file("res/GUI/button.png");
	my_button_active_texture := load_texture_from_file("res/GUI/button_active.png");

	my_slot_texture := load_texture_from_file("res/GUI/slot.png");
	my_slot_texture_active := load_texture_from_file("res/GUI/slot_active.png");
	
	my_line_texture := load_texture_from_file("res/GUI/line.png");
	
	my_check_texture := load_texture_from_file("res/GUI/checkbox.png");
	
	my_input_texture := load_texture_from_file("res/GUI/input_field.png");

	my_slider_texture := load_texture_from_file("res/GUI/slider.png");

	my_input_slider_texture := load_texture_from_file("res/GUI/input_slider.png");

	my_selector_texture := load_texture_from_file("res/GUI/selector.png");
	
	font_style : gui.Font_style = {
		font = my_font,
		font_size = 0.05, 	//this is in screen space, so big text.
		font_spacing = 0,	//
		font_color = {0,1,0,1},
	}

	my_style : gui.Style = gui.make_style(font_style, bg_color = {0.5, 0.5, 0.5, 1});
	my_style.texture = my_button_texture;
	my_style.line_texture = my_line_texture;
	my_style.line_width = 0.02;
	
	my_hover_style : gui.Style = my_style;
	my_hover_style.bg_color = {1, 1, 1, 1};

	my_active_style : gui.Style = my_style;
	my_active_style.bg_color = {1, 1, 1, 1};
	my_active_style.texture = my_button_active_texture;

	my_theme := gui.init_theme();
	my_theme.default_style = my_style;
	my_theme.default_hover_style = my_hover_style;
	my_theme.default_active_style = my_active_style;

	checkbox_style := my_style;
	checkbox_style.texture = my_check_texture;

	hover_checkbox_style := checkbox_style;
	hover_checkbox_style.bg_color = {1, 1, 1, 1};
	
	active_checkbox_style := checkbox_style;
	active_checkbox_style.bg_color = {1, 0.2, 0.2, 1};

	gui.add_style(&my_theme, gui.Checkbox, checkbox_style, hover_checkbox_style, active_checkbox_style);
	
	input_style := my_style;
	input_style.texture = my_input_texture;
	
	hover_input_style := input_style;
	hover_input_style.bg_color = {1, 1, 1, 1};

	active_input_style := input_style;
	active_input_style.front_color = {1, 0, 0, 1};

	gui.add_style(&my_theme, gui.Input_field, input_style, hover_input_style, active_input_style);

	slider_style := my_style;
	slider_style.texture = my_slider_texture;
	
	hover_slider_style := slider_style;
	hover_slider_style.bg_color = {1, 1, 1, 1};

	gui.add_style(&my_theme, gui.Slider, slider_style, hover_slider_style, hover_slider_style);
	
	input_slider_style := my_style;
	input_slider_style.texture = my_input_slider_texture;
	
	hover_input_slider_style := input_slider_style;
	hover_input_slider_style.bg_color = {1, 1, 1, 1};

	gui.add_style(&my_theme, gui.Slide_input, input_slider_style, hover_input_slider_style, hover_input_slider_style);

	selector_style := my_style;
	selector_style.texture = my_selector_texture;
	
	hover_selector_style := selector_style;
	hover_selector_style.bg_color = {1, 1, 1, 1};

	gui.add_style(&my_theme, gui.Selector, selector_style, hover_selector_style, hover_selector_style);

	my_slot_style : gui.Style = gui.make_style(font_style, bg_color = {0.5, 0.5, 0.5, 1});
	my_slot_style.texture = my_slot_texture;

	my_slot_style_hover := my_slot_style;
	my_slot_style_hover.bg_color = {1,1,1,1};

	my_slot_style_active := my_slot_style;
	my_slot_style_active.texture = my_slot_texture_active;
	my_slot_style_active.bg_color = {1,1,1,1};

	gui.add_style(&my_theme, gui.Slot, my_slot_style, my_slot_style_hover, my_slot_style_active);

	//END OF STYLE SETUP//

	show_elements : bool = true;
	button_clicked : bool;
	checkbox_checked : bool;
	slide_input_value, slider_value : f32;

	a_string_from_field : string;
	
	my_button : gui.Element_container = {
		element = gui.init_button("Click me", &button_clicked),
		dest = gui.Destination{
			anchor = .bottom_center,
			self_anchor = .bottom_center,
			rect = {0, 0.13, 0.2, 0.1}, //take up at max 50% and the width/height of the screen.
		},
		is_showing = &show_elements, //is_showing is allowed to be nil, this will always draw the element.
	}
	defer gui.destroy_element(&my_button);

	my_checkbox : gui.Element_container = {
		element = gui.init_checkbox(&checkbox_checked),
		dest = gui.Destination{
			rect = {-0.0, -0.0, 0.1, 0.1},
			anchor = .top_right,
			self_anchor = .top_right,
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_checkbox);

	my_slot_1 : gui.Element_container = {
		element = gui.init_slot(),
		dest = gui.Destination {
			rect = {-0.15, -0.15, 0.1, 0.1},
			anchor = .top_right,
			self_anchor = .top_right,
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_slot_1);

	my_slot_2 : gui.Element_container = {
		element = gui.init_slot(),
		dest = gui.Destination {
			rect = {0.0, -0.12, 0.1, 0.1},
			anchor = .top_center,
			self_anchor = .top_center,
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_slot_2);
	
	my_slide_input : gui.Element_container = {
		element = gui.init_slide_input(&slide_input_value, 5, 0),
		dest = gui.Destination{
			anchor = .bottom_left,
			self_anchor = .bottom_left,
			rect = {0.05, 0.05, 0.3, 0.1},
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_slide_input);

	my_slider : gui.Element_container = {
		element = gui.init_slider(&slider_value),
		dest = gui.Destination{
			anchor = .top_left,
			self_anchor = .top_left,
			rect = {0.00, -0.05, 0.3, 0.1},
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_slider);

	my_inputfield : gui.Element_container = {
		element = gui.init_input_field(&a_string_from_field),
		dest = gui.Destination{
			rect = {0.0, 0.00, 0.3, 0.1},
			anchor = .bottom_right,
			self_anchor = .bottom_right,
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_inputfield);

	selector_options : []string = {
		"Easy",
		"Medium",
		"Hard",
	}

	defer delete(selector_options); //Can be delete after init_selector as the selector copies the array.
	option : int = 0;

	my_selector : gui.Element_container = {
		element = gui.init_selector(selector_options, &option),
		dest = gui.Destination{
			rect = {0.0, 0.0, 0.3, 0.1},
			anchor = .top_center,
			self_anchor = .top_center,
		},
		is_showing = &show_elements,
	}
	defer gui.destroy_element(&my_selector);

	//The same GUI elemts are added to a panel, drawing the panel draw all the elements like the panel is a window.
	my_panel : gui.Panel = gui.init_panel(
		dest = gui.Destination{
			rect = {0.0, 0.0, 0.7, 0.5},
			anchor = .center_center,
			self_anchor = .center_center,
		}
	);
	
	//I want the panel to have a specific style. It is possiable to set a style on a single element container, this will override other styles.
	panel_style : gui.Style = gui.make_style(font_style, bg_color = {0.1, 0.1, 0.1, 0.6});
	my_rect : gui.Element_container = {
		element = gui.init_rect(),
		dest = gui.Destination{
			rect = {0.0, 0.0, 0.7, 0.5},
			anchor = .center_center,
			self_anchor = .center_center,
		},
		is_showing = &show_elements,
		style = panel_style,
		hover_style = panel_style,
		active_style = panel_style,
	}
	defer gui.destroy_element(&my_rect);
	
	gui.push_theme(my_theme);

	last_hover : bool;
	last_active : bool;
	last_trigger : bool;

	for !should_close(window) {
		begin_frame(window, {0.2,0.2,0.2,1});

		hover : bool;
		hover2 : bool;
		active : bool;
		trigger : bool;

		//////// Draw GUI ////////
		my_camera := get_pixel_space_camera();
		begin_mode_2D(my_camera, use_transparency = true);
		gui.begin();

		if h, a, t := gui.draw_element(&my_button); t | h | a {
			hover |= h;
			//active |= a;
			trigger |= t;
		}
		if h, a, t := gui.draw_element(&my_checkbox); t | h | a {
			hover |= h;
			//active |= a;
			trigger |= t;
		}

		if h, a, t := gui.draw_element(&my_selector); t | h | a {
			hover |= h;
			//active |= a;
			trigger |= t;
		}

		if h, a, t := gui.draw_element(&my_slide_input); t | h | a {
			hover2 |= h;
			active |= a;
		}

		if h, a, t := gui.draw_element(&my_slider); t | h | a {
			hover2 |= h;
			active |= a;
		}

		if h, a, t := gui.draw_element(&my_inputfield); t | h | a {
			hover2 |= h;
			trigger |= t;
		}
		
		if h, a, t := gui.draw_element(&my_slot_1); t | h | a {
			hover2 |= h;
		}

		if h, a, t := gui.draw_element(&my_slot_2); t | h | a {
			hover2 |= h;
		}
		
		gui.push_panel(&my_panel);
			gui.draw_element(&my_rect);

			if h, a, t := gui.draw_element(&my_button); t | h | a {
				hover |= h;
				//active |= a;
				trigger |= t;
			}
			if h, a, t := gui.draw_element(&my_checkbox); t | h | a {
				hover |= h;
				//active |= a;
				trigger |= t;
			}

			if h, a, t := gui.draw_element(&my_selector); t | h | a {
				hover |= h;
				//active |= a;
				trigger |= t;
			}

		gui.pop_panel(&my_panel);

		gui.end();
		end_mode_2D(my_camera);

		//////////////////////////

		if button_clicked {
			fmt.print("My button is clicked and will now vanish\n");
			fmt.printf("Your strings was : %v\n", a_string_from_field);
			fmt.printf("Your option was : %v\n", selector_options[option]);
			show_elements = false;
		}

		if hover && !last_hover && !active {
			ma.sound_start(&my_sound_context.hover_sound);
		}

		if hover2 && !last_hover && !active {
			ma.sound_start(&my_sound_context.hover_sound2);
		}
		
		if active && !last_active {
			ma.sound_start(&my_sound_context.active_sound);
		}
		
		if trigger {
			ma.sound_start(&my_sound_context.trigger_sound);
		}
		
		last_hover = hover | hover2;
		last_active = active;
		last_trigger = trigger;

		free_all(context.temp_allocator);
		
		end_frame(window);
	}

	gui.pop_theme(my_theme);

	destroy_window(&window);

	fmt.printf("Shutdown succesfull");
}