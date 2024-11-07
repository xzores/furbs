package libharu_examples;

import "base:runtime"

import "core:fmt"
import "core:log"
import "core:mem"
import "core:testing"
import "core:time"

import haru ".."
import "../../../utils"

haru_logger : runtime.Logger;
haru_allocator : runtime.Allocator;

error_function : haru.Error_Handler : proc "c" (error_no : haru.STATUS, detail_no : haru.STATUS, user_data : rawptr) {
	context = runtime.default_context();
	context.logger = haru_logger;
	context.allocator = haru_allocator;
	
	log.errorf("Recived haru error, error code: %v(%v), detail no: %v", cast(haru.error_code)error_no, error_no, detail_no);
}

alloc_function : haru.Alloc_Func : proc "c" (size : haru.UINT) -> rawptr {
	context = runtime.default_context();
	context.logger = haru_logger;
	context.allocator = haru_allocator;
	
	ptr, err := mem.alloc(auto_cast size, allocator = haru_allocator);
	assert(err == nil, "Failed to allocate");
	return ptr;
}

free_function : haru.Free_Func : proc "c" (ptr : rawptr) {
	context = runtime.default_context();
	context.logger = haru_logger;
	context.allocator = haru_allocator;
	
	free(ptr, haru_allocator);
}

@(test)
create_a_pdf_page :: proc(t : ^testing.T) {
	
	haru_allocator = context.allocator;
	haru_logger = context.logger;
	defer haru_allocator = {};
	
	pdf := haru.NewEx(error_function, alloc_function, free_function, 2024 * 1024, nil);
	assert(pdf != nil, "failed to create pdf handle");
	defer haru.Free(pdf);
	
	// Set up a page with A4 dimensions
	page := haru.AddPage(pdf);
	haru.Page_SetSize(page, .A4, .PORTRAIT);
	
	// Set font and font size
	font := haru.GetFont(pdf, "Helvetica", nil);
	haru.Page_SetFontAndSize(page, font, 24);
	
	// Place the text at a specific position
	haru.Page_BeginText(page);
	haru.Page_TextOut(page, 50, haru.Page_GetHeight(page) - 100, "This is my word"); // Coordinates for top margin
	haru.Page_EndText(page);
	
	// Save the PDF document
	haru.SaveToFile(pdf, "create_a_pdf_page.pdf");
	
}

@(test)
create_a_pdf_figure :: proc(t : ^testing.T) {
	
	haru_allocator = context.allocator;
	haru_logger = context.logger;
	defer haru_allocator = {};
	
	s : haru.STATUS;
	
	pdf := haru.NewEx(error_function, alloc_function, free_function, 2024 * 1024, nil);
	assert(pdf != nil, "failed to create pdf handle");
	defer haru.Free(pdf);
	
	page := haru.AddPage(pdf);
	assert(page != nil, "Failed to create page")

	s = haru.Page_SetWidth(page, 500);
	fmt.assertf(s == 0, "failed, error : %v", s);
	s = haru.Page_SetHeight(page, 500);
	fmt.assertf(s == 0, "failed, error : %v", s);
	
	// Start drawing on the "canvas" (the page)
	s = haru.Page_MoveTo(page, 100, 100);
	fmt.assertf(s == 0, "failed, error : %v", s);
	s = haru.Page_LineTo(page, 400, 400);
	fmt.assertf(s == 0, "failed, error : %v", s);
	s = haru.Page_LineTo(page, 400, 100);
	fmt.assertf(s == 0, "failed, error : %v", s);
	s = haru.Page_Stroke(page);
	fmt.assertf(s == 0, "failed, error : %v", s);
		
	// Draw an arc
    x_center : f32 = 250.0
    y_center : f32 = 250.0
    radius : f32 = 50.0
    angle1 : f32 = 0.0    // Start angle in radians
    angle2 : f32 = 180 // End angle in radians (90 degrees)
	
    // Draw the arc
    s = haru.Page_Arc(page, x_center, y_center, radius, angle1, angle2)
	fmt.assertf(s == 0, "failed, error : %v", s);
	
    // Set the line width and color for the arc
    s = haru.Page_SetLineWidth(page, 2.0)  // Set line width to 2 points
	fmt.assertf(s == 0, "failed, error : %v", s);
    s = haru.Page_SetRGBStroke(page, 0.0, 0.0, 0.0) // Set stroke color to black
	fmt.assertf(s == 0, "failed, error : %v", s);
	
	s = haru.Page_Stroke(page);
	fmt.assertf(s == 0, "failed, error : %v", s);
		
	// Save the PDF document
	s = haru.SaveToFile(pdf, "create_a_pdf_figure.pdf");
	fmt.assertf(s == 0, "failed, error : %v", s);
	
	time.sleep(1);
}

