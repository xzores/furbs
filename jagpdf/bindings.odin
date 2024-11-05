package jagpdf

/*

THIS SHOULD NOT BE USED, IT ONLY SUPPORTS 32 BIT ON WINDOWS... SADLY I FOUND THIS OUT AFTER CREATING THE BINDINGS.....

*/


when ODIN_OS == .Windows {
    foreign import lib "jagpdf/lib/jagpdf-1.4.lib"
} else when ODIN_OS == .Linux {
    foreign import lib "fastnoise/lib/jagpdf-1.4.so"
} else when ODIN_OS == .Darwin {
    foreign import lib "fastnoise/lib/jagpdf-1.4.dylib"
}

/* ==== enums ==== */
Color_space_type :: enum i32 {
  CS_DEVICE_RGB=1,
  CS_DEVICE_CMYK=2,
  CS_DEVICE_GRAY=4,
  CS_CIELAB=16,
  CS_CALGRAY=32,
  CS_CALRGB=64,
  CS_INDEXED=128,
  CS_ICCBASED=256
};

Image_format :: enum i32 {
  IMAGE_FORMAT_AUTO=0,
  IMAGE_FORMAT_NATIVE=1,
  IMAGE_FORMAT_PNG=2,
  IMAGE_FORMAT_JPEG=3
};

Line_cap_style :: enum i32 {
  LINE_CAP_BUTT=0,
  LINE_CAP_ROUND=1,
  LINE_CAP_SQUARE=2
};

Line_join_style :: enum i32 {
  LINE_JOIN_MITER=0,
  LINE_JOIN_ROUND=1,
  LINE_JOIN_BEVEL=2
};

Rendering_intent_type :: enum i32 {
  RI_ABSOLUTE_COLORIMETRIC=0,
  RI_RELATIVE_COLORIMETRIC=1,
  RI_SATURATION=2,
  RI_PERCEPTUAL=3
};

/* other typedefs */
ColorSpace 	:: u32;
Pattern 	:: u32;
ImageMaskID :: u32;
Destination :: u32;
Function 	:: u32;

Error	:: distinct i32;

/* ==== Handles ==== */
Canvas :: distinct i32;
Document :: distinct i32;
DocumentOutline :: distinct i32;
Font :: distinct i32;
Image :: distinct i32;
ImageDef :: distinct i32;
ImageMask :: distinct i32;
Page :: distinct i32;
Profile :: distinct i32;

Double :: f64;
Ulong :: u64;
Uint :: u32;
Int :: i32;
Byte :: b8;
Operation :: cstring; //Maybe 

Stream_out_write_func :: #type proc "c" (custom_data : rawptr, data : rawptr, size : Ulong) -> Int;
Stream_out_close_func :: #type proc "c" (custom_data : rawptr) -> Int;

StreamOut :: struct {
    write : Stream_out_write_func,
    close : Stream_out_close_func,
    custom_data : rawptr,
};

@(default_calling_convention="c", link_prefix="jag_")
foreign lib {
	
	/* ==== from prologue ==== */
	release :: proc (obj : i32) ---;
	addref :: proc (obj : i32) ---;

	/* params can be 0 */
	last_error_msg :: proc (code : ^Error) -> cstring ---;

	error_msg :: proc () -> cstring ---;
	error_code :: proc () -> Error ---;
	error_reset :: proc () ---;
	
	/* ==== free functions ==== */
	create_file :: proc (file_path : cstring, profile : Profile) -> Document ---;
	create_stream :: proc (stream : ^StreamOut, profile : Profile) -> Document ---;
	create_profile :: proc () -> Profile ---;
	create_profile_from_file :: proc (fname : cstring) -> Profile ---;
	create_profile_from_string :: proc (str : cstring) -> Profile ---;
	version :: proc () -> Ulong ---;
	
	/* ==== methods ===== */
    Document_canvas_create :: proc (hobj : Document) -> Canvas ---;
    Page_canvas :: proc (hobj : Page) -> Canvas ---;
    Font_family_name :: proc (hobj : Font) -> cstring ---;
    
	Document_color_space_load :: proc (hobj : Document, spec : cstring) -> ColorSpace ---;
    Document_destination_define :: proc (hobj : Document, dest : cstring) -> Destination ---;
    Document_destination_reserve :: proc (hobj : Document) -> Destination ---;
    Document_outline :: proc (hobj : Document) -> DocumentOutline ---;
	
    Font_advance :: proc (hobj : Font, txt_u : cstring) -> Double ---;
    Font_ascender :: proc (hobj : Font) -> Double ---;
    Font_bbox_xmax :: proc (hobj : Font) -> Double ---;
    Font_bbox_xmin :: proc (hobj : Font) -> Double ---;
    Font_bbox_ymax :: proc (hobj : Font) -> Double ---;
    Font_bbox_ymin :: proc (hobj : Font) -> Double ---;
    Font_descender :: proc (hobj : Font) -> Double ---;
    Font_glyph_width :: proc (hobj : Font, glyph_index : u16) -> Double ---;
    Font_height :: proc (hobj : Font) -> Double ---;
    Font_size :: proc (hobj : Font) -> Double ---;
    
	Image_dpi_x :: proc (hobj : Image) -> Double ---;
    Image_dpi_y :: proc (hobj : Image) -> Double ---;
	
	Document_font_load :: proc (hobj : Document, fspec : cstring) -> Font ---;
	Document_function_2_load :: proc (hobj : Document, fun : cstring) -> Function ---;
	Document_function_3_load :: proc (hobj : Document, fun : cstring, array_in : ^Function, length : Ulong) -> Function ---;
	Document_function_4_load :: proc (hobj : Document, fun : cstring) -> Function ---;
	Document_image_load :: proc (hobj : Document, image : ImageDef) -> Image ---;
	Document_image_load_file :: proc (hobj : Document, image_file_path : cstring, image_format : Image_format) -> Image ---;
	Document_image_definition :: proc (hobj : Document) -> ImageDef ---;
	Document_define_image_mask :: proc (hobj : Document) -> ImageMask ---;
	Document_register_image_mask :: proc (hobj : Document, image_mask : ImageMask) -> ImageMaskID ---;
	Document_page_number :: proc (hobj : Document) -> Int ---;
	Document_version :: proc (hobj : Document) -> Int ---;
	
	font_is_bold :: proc (hobj : Font) -> Int ---;
	font_is_italic :: proc (hobj : Font) -> Int ---;
	
	Document_page :: proc (hobj : Document) -> Page ---;
	document_shading_pattern_load :: proc (hobj : Document, pattern : cstring, color_space : ColorSpace, func : Function) -> Pattern ---;
	document_shading_pattern_load_n :: proc (hobj : Document, pattern : cstring, cs : ColorSpace, array_in : ^Function, length : Uint) -> Pattern ---;
	document_tiling_pattern_load :: proc (hobj : Document, pattern : cstring, canvas : Canvas) -> Pattern ---;
	
	image_bits_per_component :: proc (hobj : Image) -> Ulong ---;
	image_height :: proc (hobj : Image) -> Ulong ---;
	image_width :: proc (hobj : Image) -> Ulong ---;
	
	canvas_alpha :: proc (hobj : Canvas, op : Operation, alpha : Double) -> Error ---;
	canvas_alpha_is_shape :: proc (hobj : Canvas, bool_val : Int) -> Error ---;
	canvas_arc :: proc (hobj : Canvas, cx : Double, cy : Double, rx : Double, ry : Double, start_angle : Double, sweep_angle : Double) -> Error ---;
	canvas_arc_to :: proc (hobj : Canvas, x : Double, y : Double, rx : Double, ry : Double, angle : Double, large_arc_flag : Int, sweep_flag : Int) -> Error ---;
	canvas_bezier_to :: proc (hobj : Canvas, x1 : Double, y1 : Double, x2 : Double, y2 : Double, x3 : Double, y3 : Double) -> Error ---;
	canvas_bezier_to_1st_ctrlpt :: proc (hobj : Canvas, x1 : Double, y1 : Double, x3 : Double, y3 : Double) -> Error ---;
	canvas_bezier_to_2nd_ctrlpt :: proc (hobj : Canvas, x2 : Double, y2 : Double, x3 : Double, y3 : Double) -> Error ---;
	canvas_circle :: proc (hobj : Canvas, x : Double, y : Double, radius : Double) -> Error ---;
	canvas_color1 :: proc (hobj : Canvas, op : Operation, ch1 : Double) -> Error ---;
	canvas_color3 :: proc (hobj : Canvas, op : Operation, ch1 : Double, ch2 : Double, ch3 : Double) -> Error ---;
	canvas_color4 :: proc (hobj : Canvas, op : Operation, ch1 : Double, ch2 : Double, ch3 : Double, ch4 : Double) -> Error ---;
	canvas_color_space :: proc (hobj : Canvas, op : Operation, cs : ColorSpace) -> Error ---;
	canvas_color_space_pattern :: proc (hobj : Canvas, op : Operation) -> Error ---;
	canvas_color_space_pattern_uncolored :: proc (hobj : Canvas, op : Operation, cs : ColorSpace) -> Error ---;
	canvas_image :: proc (hobj : Canvas, img : Image, x : Double, y : Double) -> Error ---;
	canvas_line_cap :: proc (hobj : Canvas, style : Line_cap_style) -> Error ---;
	canvas_line_dash :: proc (hobj : Canvas, array_in : ^Uint, length : Uint, phase : Uint) -> Error ---;
	canvas_line_join :: proc (hobj : Canvas, style : Line_join_style) -> Error ---;
	canvas_line_miter_limit :: proc (hobj : Canvas, limit : Double) -> Error ---;
	canvas_line_to :: proc (hobj : Canvas, x : Double, y : Double) -> Error ---;
	canvas_line_width :: proc (hobj : Canvas, width : Double) -> Error ---;
	canvas_move_to :: proc (hobj : Canvas, x : Double, y : Double) -> Error ---;
	
	canvas_path_close :: proc (hobj : Canvas) -> Error ---;
	canvas_path_paint :: proc (hobj : Canvas, cmd : cstring) -> Error ---;
	canvas_pattern :: proc (hobj : Canvas, op : Operation, patt : Pattern) -> Error ---; // 'f' or 's'
	canvas_pattern1 :: proc (hobj : Canvas, op : Operation, patt : Pattern, ch1 : Double) -> Error ---; // 'f' or 's'
	canvas_pattern3 :: proc (hobj : Canvas, op : Operation, patt : Pattern, ch1 : Double, ch2 : Double, ch3 : Double) -> Error ---; // 'f' or 's'
	canvas_pattern4 :: proc (hobj : Canvas, op : Operation, patt : Pattern, ch1 : Double, ch2 : Double, ch3 : Double, ch4 : Double) -> Error ---; // 'f' or 's'
	canvas_rectangle :: proc (hobj : Canvas, x : Double, y : Double, width : Double, height : Double) -> Error ---;
	canvas_rotate :: proc (hobj : Canvas, alpha : Double) -> Error ---;
	canvas_scale :: proc (hobj : Canvas, sx : Double, sy : Double) -> Error ---;
	canvas_scaled_image :: proc (hobj : Canvas, image : Image, x : Double, y : Double, sx : Double, sy : Double) -> Error ---;
	canvas_shading_apply :: proc (hobj : Canvas, pattern : Pattern) -> Error ---;
	canvas_skew :: proc (hobj : Canvas, alpha : Double, beta : Double) -> Error ---;
	canvas_state_restore :: proc (hobj : Canvas) -> Error ---;
	canvas_state_save :: proc (hobj : Canvas) -> Error ---;
	canvas_text :: proc (hobj : Canvas, txt_u : cstring) -> Error ---;
	canvas_text_character_spacing :: proc (hobj : Canvas, spacing : Double) -> Error ---;
	
	canvas_text_end :: proc (hobj : Canvas) -> Error ---;
	canvas_text_font :: proc (hobj : Canvas, font : Font) -> Error ---;
	canvas_text_glyphs :: proc (hobj : Canvas, x : Double, y : Double, array_in : ^u16, length : Ulong) -> Error ---;
	canvas_text_glyphs_o :: proc (hobj : Canvas, x : Double, y : Double, array_in : ^u16, length : Ulong, offsets : ^Double, offsets_length : Ulong, positions : ^Int, positions_length : Ulong) -> Error ---;
	canvas_text_horizontal_scaling :: proc (hobj : Canvas, scaling : Double) -> Error ---;
	canvas_text_o :: proc (hobj : Canvas, txt_u : cstring, offsets : ^Double, offsets_length : Ulong, positions : ^Int, positions_length : Ulong) -> Error ---;
	canvas_text_r :: proc (hobj : Canvas, start : cstring, end : cstring) -> Error ---;
	canvas_text_rendering_mode :: proc (hobj : Canvas, mode : cstring) -> Error ---;
	canvas_text_rise :: proc (hobj : Canvas, rise : Double) -> Error ---;
	canvas_text_ro :: proc (hobj : Canvas, start : cstring, end : cstring, offsets : ^Double, offsets_length : Ulong, positions : ^Int, positions_length : Ulong) -> Error ---;
	canvas_text_simple :: proc (hobj : Canvas, x : Double, y : Double, txt_u : cstring) -> Error ---;
	canvas_text_simple_o :: proc (hobj : Canvas, x : Double, y : Double, txt_u : cstring, offsets : ^Double, offsets_length : Ulong, positions : ^Int, positions_length : Ulong) -> Error ---;
	canvas_text_simple_r :: proc (hobj : Canvas, x : Double, y : Double, start : cstring, end : cstring) -> Error ---;
	canvas_text_simple_ro :: proc (hobj : Canvas, x : Double, y : Double, start : cstring, end : cstring, offsets : ^Double, offsets_length : Ulong, positions : ^Int, positions_length : Ulong) -> Error ---;
	canvas_text_start :: proc (hobj : Canvas, x : Double, y : Double) -> Error ---;
	canvas_text_translate_line :: proc (hobj : Canvas, tx : Double, ty : Double) -> Error ---;
	
	canvas_transform :: proc (hobj : Canvas, a : Double, b : Double, c : Double, d : Double, e : Double, f : Double) -> Error ---;
	canvas_translate :: proc (hobj : Canvas, tx : Double, ty : Double) -> Error ---;
	
	document_outline_color :: proc (hobj : DocumentOutline, red : Double, green : Double, blue : Double) -> Error ---;
	document_outline_item :: proc (hobj : DocumentOutline, title : cstring) -> Error ---;
	document_outline_item_destination :: proc (hobj : DocumentOutline, title : cstring, dest : cstring) -> Error ---;
	document_outline_item_destination_obj :: proc (hobj : DocumentOutline, title : cstring, dest : Destination) -> Error ---;
	document_outline_level_down :: proc (hobj : DocumentOutline) -> Error ---;
	document_outline_level_up :: proc (hobj : DocumentOutline) -> Error ---;
	document_outline_state_restore :: proc (hobj : DocumentOutline) -> Error ---;
	document_outline_state_save :: proc (hobj : DocumentOutline) -> Error ---;
	document_outline_style :: proc (hobj : DocumentOutline, val : Int) -> Error ---;
	document_destination_define_reserved :: proc (hobj : Document, id : Destination, dest : cstring) -> Error ---;
	
	document_finalize :: proc (hobj : Document) -> Error ---;
	document_page_end :: proc (hobj : Document) -> Error ---;
	document_page_start :: proc (hobj : Document, width : Double, height : Double) -> Error ---;
		
	imageDef_alternate_for_printing :: proc (hobj : ImageDef, image : Image) -> Error ---;
	imageDef_bits_per_component :: proc (hobj : ImageDef, bpc : Uint) -> Error ---;
	imageDef_color_key_mask :: proc (hobj : ImageDef, array_in : ^Uint, length : Uint) -> Error ---;
	imageDef_color_space :: proc (hobj : ImageDef, cs : ColorSpace) -> Error ---;
	imageDef_data :: proc (hobj : ImageDef, array_in : ^Byte, length : Uint) -> Error ---;
	imageDef_decode :: proc (hobj : ImageDef, array_in : ^Double, length : Uint) -> Error ---;
	imageDef_dimensions :: proc (hobj : ImageDef, width : Uint, height : Uint) -> Error ---;
	imageDef_dpi :: proc (hobj : ImageDef, xdpi : Double, ydpi : Double) -> Error ---;
	imageDef_file_name :: proc (hobj : ImageDef, file_name : cstring) -> Error ---;
	imageDef_format :: proc (hobj : ImageDef, format : Image_format) -> Error ---;
	imageDef_gamma :: proc (hobj : ImageDef, val : Double) -> Error ---;
	imageDef_image_mask :: proc (hobj : ImageDef, image_mask : ImageMaskID) -> Error ---;
	imageDef_interpolate :: proc (hobj : ImageDef, flag : Int) -> Error ---;
	imageDef_rendering_intent :: proc (hobj : ImageDef, intent : Rendering_intent_type) -> Error ---;
	imageMask_bit_depth :: proc (hobj : ImageMask, bps : Uint) -> Error ---;
	imageMask_data :: proc (hobj : ImageMask, array_in : ^Byte, length : Uint) -> Error ---;
	imageMask_decode :: proc (hobj : ImageMask, lbound : Double, ubound : Double) -> Error ---;
	imageMask_dimensions :: proc (hobj : ImageMask, width : Uint, height : Uint) -> Error ---;
	imageMask_file_name :: proc (hobj : ImageMask, file_name : cstring) -> Error ---;
	imageMask_interpolate :: proc (hobj : ImageMask, val : Int) -> Error ---;
	imageMask_matte :: proc (hobj : ImageMask, array_in : ^Double, length : Uint) -> Error ---;
	
	page_annotation_goto :: proc (hobj : Page, x : Double, y : Double, width : Double, height : Double, dest : cstring, style : ^Byte) -> Error ---; //Style must be 0, or nil idk
	page_annotation_goto_obj :: proc (hobj : Page, x : Double, y : Double, width : Double, height : Double, dest : Destination, style : cstring) -> Error ---;
	page_annotation_uri :: proc (hobj : Page, x : Double, y : Double, width : Double, height : Double, uri : cstring, style : cstring) -> Error ---;
	
	profile_save_to_file :: proc (hobj : Profile, fname : cstring) -> Error ---;
	profile_set :: proc (hobj : Profile, option : Operation, value : cstring) -> Error ---;

}