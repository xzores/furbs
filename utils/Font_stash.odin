package utils;

//////////////////////////////////////////////////////////////////////////////////////
//	Written by Jakob Furbo Enevoldsen, as an alternative to the original fontstash	//
//				This work is devoteted to the public domain 2024					//
///////////////////////////////////////////////////////////////////////////////////////

//This can load a truetype format and will manange the image data
//It is able to resize the backing texture on demand.
//It requries to user to upload the texture to the GPU before use.
//Use font_iter_next to draw each character.
//(0,0) is placed at the lower left of the image, positive x is right and positive y is up.
//It it able to handle multiple fonts.

/*
Font Metrics Overview, below is a description of each key font metric:

Origin:
    - In typography, the origin of a glyph is the point at the base of a character. For Latin fonts, this is usually on the baseline at the start of the horizontal advance width.
    - The origin is a reference point from which the glyph's xMin, yMin, xMax, and yMax are calculated, and it is used to position the glyph within a line of text.

Baseline:
    - The line upon which most letters "sit." This is a fundamental line where the letters are aligned.

Ascender:
    - The distance from the baseline to the top of the highest ascender (the upper part of lowercase letters like 'b' and 'd').
    - It determines the maximum height of letters within the font.

Descender:
    - The distance from the baseline to the bottom of the lowest descender (the lower part of lowercase letters like 'p' and 'q').
    - It is typically a negative value as it extends below the baseline.
	
xMin, yMin, xMax, yMax:
    - These values define the bounding box for each glyph in the font, which are the minimal and maximal coordinates used by the glyph.
    - xMin and yMin define the leftmost and bottommost points of the glyph bounding box, respectively.
    - xMax and yMax define the rightmost and topmost points of the glyph bounding box, respectively.
    - These metrics are crucial for understanding how much space a glyph will occupy and for handling glyph positioning in various typesetting and rendering processes.
	
X-height:
    - The height of the lowercase letters, typically exemplified by the letter 'x'.
	
Cap Height:
    - The height of a capital letter measured from the baseline. 
    - This metric is particularly important for aligning the top of capital letters across different fonts and styles.

Line Spacing:
    - The vertical spacing between lines of text, measured from baseline to baseline.
	- This is not provided by the library and should be manged by the user.
	
Line Gap:
    - The additional space, typically vertical, that is part of the leading (line spacing) but not included in the ascent and descent measurements.
    - This is often used to create additional spacing between lines beyond that which would be defined by the ascent and descent alone.
	- Specifies the distance from one lines Descender to the nexts Ascender, closely related to Line Spacing.
	- The line gap provided by the ttf format can be fetched using get_line_gap.

Advance Width:
    - The horizontal space that a character occupies when set in a line of text, including the character itself and any space before the next character starts.

Left Bearing:
    - The horizontal space between the character's origin (where it would naturally sit on the baseline) and the beginning of the character's actual visible area.
    - This typically influences how characters are spaced relative to each other, especially noticeable in characters like 'A' where a significant left bearing might be present.

Right Bearing:
    - The space between the end of the character’s visible area and where the next character's origin begins.
    - This helps to determine how tightly characters can be spaced without overlapping their visible areas.

Kerning:
    - The process of adjusting the spacing between characters in a proportional font, usually to achieve a visually pleasing result.
    - Kerning adjusts the space based on character pairs, which means that the spacing can vary between different pairings to account for their unique shapes.
	- This is managed by the library, kerning is defined by the true_type_format file.
	
EM Square:
	- A conceptual square whose height is typically the point size of the font. All glyph outlines are defined relative to the em square, providing a reference scale for measuring and designing characters.
	- The em square size is a common unit for defining various metrics and proportions within a font.
*/

import "core:os" //For loading files
import "core:path/filepath"
import "core:reflect"
import "core:strings"
import "core:unicode/utf8"
import tt "vendor:stb/truetype"

import "vendor:fontstash"

//because I have to free stuff allocated in stb, which dont work well with the odin context allocator.
import "core:mem" 
import "base:runtime"
import "core:c/libc"

import "core:fmt" //temp

//A font is just a "pointer" or reference to a charactor set, owned by a Font_context
//See font_init and add_font_**
Font :: distinct int;

//The context returned by font_init, add fonts to it with add_font
Font_context :: struct {
	scale : f32,
	font_stack : [dynamic]Font, //The current font
	
	uploaded_size : i32,
	quads_to_upload : [dynamic][4]i32,
	
	atlas : Client_atlas, //Client refers to the fact that the pixels are stored client side (CPU)
	fonts : map[Font]tt.fontinfo,
	glyphs : map[Glyph]Atlas_handle, //This is a bit stupid as the map transfers from Glyph->Atlas_index->AtlasPosition, instead of Glyph->AtlasPosition
}

//The text iter is made to itterate a string and return the information needed to draw the correct charactor.
Font_iter :: struct {
	runes : []rune,
	current_index : int, //This is the byte index
	last_rune : rune,
	x_offset : f32,
}

//Interal use
Glyph :: struct {
	codepoint : rune,
	size : f32,
	font : Font,
}

//Internal use
_font_index :: struct{
	font_info_index : int, //index the array
	sub_font : int				
}

//Information about a font, sadly it is all strings
//It is not recommended to do string compares as there seems to be no formal specification of the exact contents of the strings.
//It seems subfamily might be ok for string comparisions.
Font_info :: struct {
	copyright : string,
	family : string,
	subfamily : string,
	identifier : string,
	name : string,
	version_str : string,
	post_script : string,
	trademark : string,
	manufacturer : string,
	designer : string,
	description : string,
	vendor_url : string,
	designer_url : string,
	license_description : string,
	license_url : string,
	typographic_family_name : string,
	typographic_subfamily_name : string,
	compatible_name_mac : string,
	sample_text : string,
	post_script_cid : string,
}

//Init the library, font_init is allowed to be called more then once, but you likely only want a single instance.
//You likely want to set max_texture_size to be the GPU limit of a 2D texture size.
font_init :: proc(max_texture_size : i32, loc := #caller_location) -> (ctx : Font_context) {
	
	ctx = Font_context {
		scale = 0,
		uploaded_size = 0,
		atlas = client_atlas_make(1, 1, 512, max_texture_size, 1),
		font_stack = make([dynamic]Font),
		fonts = make(map[Font]tt.fontinfo),
		glyphs = make(map[Glyph]Atlas_handle),
	};
	
	return;
}

//Destroy the context
font_destroy :: proc(ctx: ^Font_context) {
	delete(ctx.font_stack);
	delete(ctx.fonts);
	delete(ctx.glyphs);
	client_atlas_destroy(ctx.atlas);
}

//This will load a font, the font file must only contain one font, some font files can contain multiple fonts, to load multiple font see add_font_path_multi
//This is well suited for loading tff files, and not so much for otf, as otf can include multiple fonts.
add_font_path_single :: proc (ctx: ^Font_context, path : string, loc := #caller_location) -> Font {
	data, ok := os.read_entire_file_from_filename(path, loc = loc);
	defer delete(data);
	assert(ok, "failed to load file", loc);
	return add_font_mem_single(ctx, data, loc = loc);
};

//This will load a font, the font file must only contain one font, some font files can contain multiple fonts, to load multiple font see add_font_mem_multi
//This is well suited for loading tff files, and not so much for otf, as otf can include multiple fonts.
add_font_mem_single :: proc (ctx: ^Font_context, data : []u8, loc := #caller_location) -> (res : Font) {
	
	font_cnt := tt.GetNumberOfFonts(&data[0]);
	assert(font_cnt == 1, "add_font_path_single can only load files containing a single font, for loading multiple fonts, use add_font_path_multi or add_font_mem_multi", loc = loc);
	
	offset := tt.GetFontOffsetForIndex(&data[0], 0);
	
	fi : tt.fontinfo;
	ok := tt.InitFont(&fi, &data[0], offset);
	assert(bool(ok), "tt failed to load font, is the font valid?", loc = loc);
	
	fmt.printf("loaded font : %#v\n", fi);
	
	//now add the font
	index := cast(Font)len(ctx.fonts);
	ctx.fonts[index] = fi;
	
	return index;
};

//This will load a font file containing a single or multiple fonts, the fonts will be return in a map where the name of the font matches the font entry.
//Ex : {"Arial" = 0, "Arial Bold" = 1}
//The name extractions is sketchy, please report bug if you find any.
//The filename is used as the name if no name is found
//Hint: you could pass the temp_allocator in alloc, and not have to free the result.
add_font_path_multi :: proc (ctx: ^Font_context, path : string, alloc := context.allocator, loc := #caller_location) ->  map[string]Font {
	context.allocator = alloc;
	
	name := filepath.stem(path);
	defer delete(name);
	
	data, ok := os.read_entire_file_from_filename(path, loc = loc);
	defer delete(data);
	assert(ok, "failed to load file", loc);
	return add_font_mem_multi(ctx, data, alloc, name, loc = loc);
};

//This will load a font file containing a single or multiple fonts, the fonts will be return in a map where the name of the font matches the font entry.
//Ex : {"Arial" = 0, "Arial Bold" = 1}
//The name extractions is sketchy, please report bug if you find any.
//"unknown" is used as the name if no name is found. (you can change it)
//Hint: you could pass the temp_allocator in alloc, and not have to free the result.
add_font_mem_multi :: proc (ctx: ^Font_context, data : []u8, alloc := context.allocator, fallback_name := "unknown", loc := #caller_location) -> (res : map[string]Font) {
	context.allocator = alloc;
	
	font_cnt := tt.GetNumberOfFonts(&data[0]);
	
	res = make(map[string]Font);
	
	for i : i32 = 0; i < font_cnt; i+=1 {
		offset := tt.GetFontOffsetForIndex(&data[0], i);
		
		fi : tt.fontinfo;
		
		ok := tt.InitFont(&fi, &data[0], offset);
		assert(bool(ok), "tt failed to load font, is the font valid?", loc = loc);
		
		//now add the font
		index := cast(Font)len(ctx.fonts);
		ctx.fonts[index] = fi;
		
		font_name : string = _get_font_field(&fi, 4);
		
		if font_name == "" {
			font_name = strings.clone(fallback_name);
		}
		
		assert(!(font_name in res), "font is already added, this is an internal error contact devs", loc = loc); //This failes if there is a single file with multiple font, but no names for them.
		res[font_name] = index;
	}
	
	return;
};

add_font_single :: proc { add_font_path_single, add_font_mem_single }
add_font_multi :: proc { add_font_path_multi, add_font_mem_multi }

//Hint: you could pass the temp_allocator in alloc, and not have to free the result.
//For ttf formats this is empty, it only works with otf formats.
//This can be an expensive function
get_font_info :: proc (ctx: ^Font_context, font : Font, alloc := context.allocator) -> Font_info {
	context.allocator = alloc;
	
	fi := &ctx.fonts[font];
	
	info : Font_info;
	
	for field, i in reflect.struct_fields_zipped(Font_info) {
		assert(field.type == type_info_of(string));
		ptr := field.offset + uintptr(&info);
		val := transmute(^string)ptr;
		val^ = _get_font_field(fi, i);
	}
	
	return info;
}

//Destroy the font info created by get_font_info
destroy_font_info :: proc (info : Font_info) {
	
	info := info;
	
	for field, i in reflect.struct_fields_zipped(Font_info) {
		assert(field.type == type_info_of(string));
		ptr := field.offset + uintptr(&info);
		val := transmute(^string)ptr;
		delete(val^);
	}
}

//This will make future calls use the given font, the fonts are implemented as a stack, if it cannot find the glyph in the top font, it will repeatiatly try the font below.
push_font :: proc (ctx: ^Font_context, font : Font, loc := #caller_location) {
	append(&ctx.font_stack, font);
}

//Pop the top font.
pop_font :: proc (ctx: ^Font_context,loc := #caller_location) {
	assert(len(ctx.font_stack) != 0, "You popped one to many fonts there Buddy!", loc);
	pop(&ctx.font_stack);
}

//requires_reupload and get_next_quad_upload must be called before calling font_iter_next and after calling make_font_iter
make_font_iter :: proc (ctx: ^Font_context, text : string) -> Font_iter {
	
	top := ctx.font_stack[len(ctx.font_stack)-1]; //The top font
	fi := ctx.fonts[top];
	
	for r in text {
		
		glyph : Glyph = {
			codepoint = r,
			size = ctx.scale,
			font = top,
		}
		
		if !(glyph in ctx.glyphs) {
			_load_glyph(ctx, glyph);
		}
	}
	
	iter : Font_iter = {
		runes = utf8.string_to_runes(text),
		current_index = 0,
	}
	
	return iter;
};

//A reupload encompasses a resize of the texture, this means you create a new texture with the given size.
requires_reupload :: proc (using ctx: ^Font_context) -> (required : bool, new_size : [2]i32) {
	
	if atlas.size != uploaded_size {
		uploaded_size = atlas.size;
		return true, atlas.size
	}
	
	return false, atlas.size;
}

//Repeatatly call this untill done is true, this tell you what part of the texture should be uploaded to the gpu.
//To get the texture, call get_texture
get_next_quad_upload :: proc (ctx: ^Font_context) -> (quad : [4]i32, done : bool) {
	quad = pop(&ctx.quads_to_upload);
	return quad, len(ctx.quads_to_upload) == 0;
}

//Use this to draw the quads
//requires_reupload and get_next_quad_upload must be called before calling font_iter_next and after calling make_font_iter
//This will allow you to first specify the glyphs needed whereafter they can be uploaded and then used/drawn by font_iter_next
font_iter_next :: proc (ctx: ^Font_context, iter : ^Font_iter, loc := #caller_location) -> (quad : [4]i32) {
	assert(ctx.atlas.size == ctx.uploaded_size, "You must do requires_reupload before calling font_iter_next", loc = loc);
	assert(len(ctx.quads_to_upload) == 0, "You must do get_next_quad_upload until there are no more upload required before calling font_iter_next", loc = loc);
	
	cur_rune  := iter.runes[iter.current_index];
	iter.current_index += 1;
	
	//Get kerning
	
	iter.last_rune = cur_rune;
	
	//Get kerning
	
	//iter.x_offset += something;
	
	return 
};

//Used to destroy the font_iter from make_font_iter
destroy_font_iter :: proc (iter : Font_iter) {
	delete(iter.runes);
}

//clears the texture, removings any old rasterized font glyphs.
clear_atlas :: proc () {
	panic("TODO");
}

//Set the size of the EM square size, which is the traditoinal way to set the size, but it is a little abstract instead set_max_height_size can be used.
//Units in pixels
set_em_size :: proc(ctx: ^Font_context, size: f32) {
	top := ctx.font_stack[len(ctx.font_stack)-1];
	ctx.scale = tt.ScaleForMappingEmToPixels(&ctx.fonts[top], size);
}

//Set the size of the glyphs ymax height, all charactors will vertically fit inside the size given.
//This effectively the cap height + the size of the descender.
//Units in pixels
set_max_height_size :: proc(ctx: ^Font_context, size: f32) {
	top := ctx.font_stack[len(ctx.font_stack)-1];
	ctx.scale = tt.ScaleForPixelHeight(&ctx.fonts[top], size);
}

//////////////////// get non-specifc character information ////////////////////

//Get ascent, descent, line_gap for the current text size and font.
get_vertical_metrics :: proc(ctx: ^Font_context) -> (ascent, descent, line_gap : f32) {
	top := ctx.font_stack[len(ctx.font_stack)-1]; //The top font
	fi := ctx.fonts[top];
	
	ascent_i, descent_i, line_gap_i : i32;
	
	tt.GetFontVMetrics(&fi, &ascent_i, &descent_i, &line_gap_i);
	
	return ctx.scale * f32(ascent_i), ctx.scale * f32(descent_i), ctx.scale * f32(line_gap_i);
}

//Units in pixels, get line gap for the current size and font.
get_ascent :: proc(ctx: ^Font_context) -> f32 {
	ascent, _, _ := get_vertical_metrics(ctx);
	return ascent;
}

//Units in pixels, get line gap for the current size and font.
get_descent :: proc(ctx: ^Font_context) -> f32 {
	_, descent, _ := get_vertical_metrics(ctx);
	return descent;
}

//Units in pixels, get line gap for the current size and font.
get_line_gap :: proc(ctx: ^Font_context) -> f32 {
	_, _, gap := get_vertical_metrics(ctx);
	return gap;
}

//Returns ymax for the current text size and font.
get_bounds :: proc (ctx: ^Font_context) -> (x_min, y_min, x_max, y_max : f32) {
	top := ctx.font_stack[len(ctx.font_stack)-1]; //The top font
	fi := ctx.fonts[top];
	
	x0, y0, x1, y1 : i32;
	tt.GetFontBoundingBox(&fi, &x0, &y0, &x1, &y1);
	return ctx.scale * f32(x0), ctx.scale * f32(y0), ctx.scale * f32(x1), ctx.scale * f32(y1);
}

//Total max height in pixels for any character at the current text size and font.
get_max_height :: proc (ctx: ^Font_context) -> f32 {
	x_min, y_min, x_max, y_max := get_bounds(ctx);
	return y_max - y_min;
}

//////////////////// get specifc character/string information ////////////////////

/*
//x_offset, y_offset, width and height in pixels, this will not include the desender and ascender.
//It will meassure the distance to the cap height or x-height if only lower case characters is used.
//It will not include the Left Bearing and Right Bearing.
get_inner_text_bounds :: proc(ctx: ^Font_context, text : string) -> [4]f32 {
	tt.FindGlyphIndex();
}

//x_offset, y_offset, width and height in pixels.
//Same as get_inner_text_bounds but includes the desender.
get_visible_text_bounds :: proc(ctx: ^Font_context, text : string) -> [4]f32 {
	
}

//x_offset, y_offset, width and height in pixels.
//This includes everything. x_offset and y_offset will always be (0,0)
get_outer_text_bounds :: proc(ctx: ^Font_context, text : string) -> [4]f32 {
	
}

// as above, but takes one or more glyph indices for greater efficiency
GetGlyphHMetrics    :: proc(info: ^fontinfo, glyph_index: c.int, advanceWidth, leftSideBearing: ^c.int) ---
GetGlyphKernAdvance :: proc(info: ^fontinfo, glyph1, glyph2: c.int) -> c.int ---
GetGlyphBox         :: proc(info: ^fontinfo, glyph_index: c.int, x0, y0, x1, y1: ^c.int) -> c.int ---


set_spacing :: proc(ctx: ^FontContext, spacing: f32) {

}

set_align_horizontal :: proc(ctx: ^FontContext, ah: AlignHorizontal) {

}

set_align_vertical :: proc(ctx: ^FontContext, av: AlignVertical) {

}

//What would this do?
set_blur :: proc(ctx: ^FontContext, blur: f32) {

}
*/

//Internal use
_load_glyph :: proc (using ctx: ^Font_context, glyph : Glyph) -> (success : bool) {

	//This is not too nice, as we have to allocate space for the result 
	//and then copy the result to the atlas, I dont think there is a work around with stb_truetype. 
	/*verts : [^]tt.vertex;
	num_verts := tt.GetGlyphShape(fi, tt_glyph, &verts);
	bitmap_
	tt.Rasterize(, 0.35, verts, num_verts, 1, 1, 0, 0, 0, 0, false, nil);
	tt.FreeShape(fi, verts);
	*/
	
	//Find the glyph
	fi := &ctx.fonts[glyph.font];
	tt_glyph := tt.FindGlyphIndex(fi, glyph.codepoint);
	if tt.IsGlyphEmpty(fi, tt_glyph) {
		return false; //We could not load it
	}
	
	//Razterize
	ix0, iy0, ix1, iy1: i32;
	tt.GetGlyphBitmapBox(fi, tt_glyph, ctx.scale, ctx.scale, &ix0, &iy0, &ix1, &iy1);
	width := ix1-ix0;
	height := iy1-iy0;
	result := make([]u8, width * height);
	tt.MakeGlyphBitmap(fi, &result[0], width, height, width, ctx.scale, ctx.scale, tt_glyph); //TODO we can razterize directly into the atlas instead. 
	//TODO Use client_atlas_add_no_data
	
	//Add to atlas
	handle, quad, ok := client_atlas_add(&atlas, {width, height}, result);
	
	if do_clear, _ := requires_reupload(ctx); do_clear {
		clear(&quads_to_upload);
	}
	
	if !ok {
		return false;
	}
	
	glyphs[glyph] = handle;
	append(&quads_to_upload, quad);
	
	return true;
}

//Internal use
_get_glyph :: proc (using ctx: ^Font_context, glyph : Glyph) -> [4]i32 {
	assert(glyph in ctx.glyphs, "glyph not found");
	atlas_handle : Atlas_handle = ctx.glyphs[glyph];
	return client_atlas_get_coords(ctx.atlas, atlas_handle);
}

//Internal use
_get_font_field :: proc (fi : ^tt.fontinfo, #any_int field_index : i32) -> string {
	
	platform : tt.PLATFORM_ID = .PLATFORM_ID_MAC;
	lang : i32 = tt.MAC_LANG_ENGLISH; //tt.UNICODE_EID_UNICODE_1_0 = 0 and tt.MAC_LANG_ENGLISH = 0
	
	name_length : i32 = 0;
	
	field_c : cstring = nil;
	
	//Search for the encoding in MAC
	for e in 0..=4 {	
		field_c = tt.GetFontNameString(fi, &name_length, platform, i32(e), lang, field_index);
		if name_length != 0 {
			break;
		}
	}
	
	if name_length == 0 {
		platform = .PLATFORM_ID_MICROSOFT; lang = tt.MS_LANG_ENGLISH;

		//Search for the encoding in MS 
		for e in 0..=4 {	
			field_c = tt.GetFontNameString(fi, &name_length, platform, i32(e), lang, field_index);
			if name_length != 0 {
				break;
			}
		}
	}
	
	if name_length == 0 {
		platform = .PLATFORM_ID_UNICODE; lang = tt.MS_LANG_ENGLISH;

		//Search for the encoding in MS 
		for e in 0..=4 {	
			field_c = tt.GetFontNameString(fi, &name_length, platform, i32(e), lang, field_index);
			if name_length != 0 {
				break;
			}
		}
	}
	
	if name_length == 0 {
		return "";
	}
	
	field := strings.clone_from_cstring_bounded(field_c, int(name_length));
	
	return field;
}