package jagpdf_example;


import "core:testing"
import jag ".."



@(test)
save_a_pdf :: proc(t : ^testing.T) {
    
	profile := jag.create_profile();
	defer jag.release(auto_cast profile);
	assert(profile != 0, "Failed to create profile")
	
	jag.profile_set(profile, "Title", "Sample PDF Document");
	
	document := jag.create_file("my_pdf_test", profile);	
	assert(document != 0, "Failed to create document");
	
	canvas := jag.Document_canvas_create(document);
	assert(canvas != 0, "Failed to create canvas");
	
	e := jag.canvas_circle(canvas, 0, 0, 100);
	assert(e == 0, "there was an error");
}
