package libharu_wrappers;

//Rect is x, y, width, height
push_clipping_region :: proc (page : Page, rect : [4]f32) {
	
	// Save the current graphics state before clipping
	page_g_save(page);
	
	// Draw the rectangle for clipping and activate the clip
	page_rectangle(page, rect.x, rect.y, rect.z, rect.w);
	page_clip(page);
	page_end_path(page);
}

//Rect is x, y, width, height
pop_clipping_region :: proc (page : Page) {
	page_g_restore(page);
}

draw_lines :: proc (doc : Doc, page : Page, lines : [][2][2]f32, thickness : f32, color : [4]f32, loc := #caller_location) {
	
	assert(len(lines) != 0, "lenth of points is zero!", loc);
	
	// Save the current graphics state before transparency
	page_g_save(page);
	
	page_set_line_width(page, thickness)  // Set line width to 2 points
	page_set_rgb_stroke(page, color.x, color.y, color.z) // Set stroke color to black
	
	//For transparency
	ext_gstate := create_ext_gstate(doc);
	ext_gstate_set_alpha_stroke(ext_gstate, color.a);
	ext_gstate_set_alpha_fill(ext_gstate, color.a);
	page_set_ext_gstate(page, ext_gstate);
	
	for l in lines {
		page_move_to(page, l[0].x, l[0].y);
		page_line_to(page, l[0].x, l[0].y);
		page_line_to(page, l[1].x, l[1].y);
		page_stroke(page);
	}
	
	//stop transparency
	page_g_restore(page);
}

draw_connected_points :: proc (doc : Doc, page : Page, points : [][2]f32, thickness : f32, color : [4]f32, loc := #caller_location) {
	
	assert(len(points) != 0, "lenth of points is zero!", loc);
	
	// Save the current graphics state before transparency
	page_g_save(page);
	
	page_set_line_width(page, thickness)  // Set line width to 2 points
	page_set_rgb_stroke(page, color.x, color.y, color.z) // Set stroke color to black
	
	//For transparency
	ext_gstate := create_ext_gstate(doc);
	ext_gstate_set_alpha_stroke(ext_gstate, color.a);
	ext_gstate_set_alpha_fill(ext_gstate, color.a);
	page_set_ext_gstate(page, ext_gstate);
	
	p0 := points[0]
	page_move_to(page, p0.x, p0.y);
	
	for p in points[1:] {
		page_line_to(page, p.x, p.y);
	}
	
	page_stroke(page);
	page_g_restore(page);	
}
