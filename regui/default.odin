package gui;

import render "../render"

default_appearance : Colored_appearance = {
	
	text_anchor = .center_center,
	text_size = 0.1,
	bold = false,
	italic = false,	
 	fonts = render.state.default_fonts,
	limit_by_width = true,
	limit_by_height = true,
	text_backdrop_offset = {0.002, -0.002},
	text_backdrop_color = {0,0,0,1},
	
	bg_color = {0.2, 0.2, 0.2, 0.7},
	mid_color = {0.6, 0.6, 0.6, 1},
	mid_margin = 0.02,
	front_color = {1,1,1,1},
	front_margin = 0.02,
	line_width = 0.01,
	line_margin = 0.01,
	
	additional_show = true,
	additional_color = {0.1, 0.1, 0.1, 0.5},
	additional_line_width = 0.001,
	additional_margin = 0.01,
	
	rounded = false,
}

default_hover_appearance : Colored_appearance = {
	
	text_anchor = .center_center,
	text_size = 0.1,
	bold = false,
	italic = false,	
 	fonts = render.state.default_fonts,
	limit_by_width = true,
	limit_by_height = true,
	text_backdrop_offset = {0.002, -0.002},
	text_backdrop_color = {0,0,0,1},
	
	bg_color = {0.3, 0.3, 0.3, 0.9},
	mid_color = {0.8, 0.8, 0.8, 1},
	mid_margin = 0.02,
	front_color = {1,1,1,1},
	front_margin = 0.01,
	line_width = 0.01,
	line_margin = 0.005,
	
	additional_show = true,
	additional_color = {0.1, 0.1, 0.1, 0.5},
	additional_line_width = 0.001,
	additional_margin = 0.01,
	
	rounded = false,
}

default_selected_appearance : Colored_appearance = {
	
	text_anchor = .center_center,
	text_size = 0.1,
	bold = false,
	italic = false,	
 	fonts = render.state.default_fonts,
	limit_by_width = true,
	limit_by_height = true,
	text_backdrop_offset = {0.002, -0.002},
	text_backdrop_color = {0,0,0,1},
	
	bg_color = {0.2, 0.2, 0.2, 0.9},
	mid_color = {0.9, 0.9, 0.9, 1},
	mid_margin = 0.02,
	front_color = {1,1,1,1},
	front_margin = 0.01,
	line_width = 0.01,
	line_margin = 0.0,
	
	additional_show = true,
	additional_color = {0.1, 0.1, 0.1, 0.5},
	additional_line_width = 0.001,
	additional_margin = 0.01,
	
	rounded = false,
}

default_active_appearance : Colored_appearance = {
	
	text_anchor = .center_center,
	text_size = 0.1,
	bold = false,
	italic = false,	
 	fonts = render.state.default_fonts,
	limit_by_width = true,
	limit_by_height = true,
	text_backdrop_offset = {0.002, -0.002},
	text_backdrop_color = {0,0,0,1},
	
	bg_color = {1, 1, 1, 1},
	mid_color = {1, 1, 1, 1},
	mid_margin = 0.02,
	front_color = {1,1,1,1},
	front_margin = 0.01,
	line_width = 0.01,
	line_margin = -0.01,
	
	additional_show = true,
	additional_color = {0.1, 0.1, 0.1, 0.5},
	additional_line_width = 0.001,
	additional_margin = 0.01,
	
	rounded = false,
}