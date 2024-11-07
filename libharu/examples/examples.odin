package libharu_examples;

import "base:runtime"

import "core:fmt"
import "core:log"
import "core:mem"
import "core:testing"
import "core:time"

import haru ".."
import "../../utils"

@(test)
create_a_pdf_page :: proc(t : ^testing.T) {
	
	haru.init();
	defer haru.destroy();
	
	pdf := haru.new();
	assert(pdf != nil, "failed to create pdf handle");
	defer haru.free(pdf);
	
	// Set up a page with A4 dimensions
	page := haru.add_page(pdf);
	haru.page_set_size(page, .A4, .PORTRAIT);
	
	// Set font and font size
	font := haru.get_font(pdf, "Helvetica", "StandardEncoding");
	haru.page_set_font_and_size(page, font, 24);
	
	// Place the text at a specific position
	haru.page_begin_text(page);
	haru.page_text_out(page, 50, haru.page_get_height(page) - 100, "This is my word"); // Coordinates for top margin
	haru.page_end_text(page);
	
	// Save the PDF document
	haru.save_to_file(pdf, "create_a_pdf_page.pdf");
}

@(test)
create_a_pdf_figure :: proc(t : ^testing.T) {

	haru.init();
	defer haru.destroy();	
	
	pdf := haru.new();
	assert(pdf != nil, "failed to create pdf handle");
	defer haru.free(pdf);
	
	page := haru.add_page(pdf);
	assert(page != nil, "Failed to create page")

	haru.page_set_width(page, 500);
	haru.page_set_height(page, 500);
	
	// Start drawing on the "canvas" (the page)
	haru.page_move_to(page, 100, 100);
	haru.page_line_to(page, 400, 400);
	haru.page_line_to(page, 400, 100);
	haru.page_stroke(page);
		
	// Draw an arc
	x_center : f32 = 250.0
	y_center : f32 = 250.0
	radius : f32 = 50.0
	angle1 : f32 = 0.0    // Start angle in radians
	angle2 : f32 = 180 // End angle in radians (90 degrees)
	
	// Set the line width and color for the arc
	haru.page_set_line_width(page, 2.0)  // Set line width to 2 points
	haru.page_set_rgb_stroke(page, 0.0, 0.0, 0.0) // Set stroke color to black
	
	// Draw the arc
	haru.page_arc(page, x_center, y_center, radius, angle1, angle2)
	
	haru.page_stroke(page);
		
	// Save the PDF document
	haru.save_to_file(pdf, "create_a_pdf_figure.pdf");
	
	time.sleep(1);
}
