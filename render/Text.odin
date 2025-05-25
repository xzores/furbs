package render;

import "core:os"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:math/linalg"
import "core:log"

import fs "../fontstash"

Font :: fs.Font;

Fonts :: struct {
	normal : Font,
	bold : Font,
	italic : Font,
	italic_bold : Font,
}

font_norm_data 	:= #load("font/LinLibertine_R.ttf", []u8);
font_RB_data 	:= #load("font/LinLibertine_RB.ttf", []u8);
font_RI_data 	:= #load("font/LinLibertine_RI.ttf", []u8);
font_RBI_data 	:= #load("font/LinLibertine_RBI.ttf", []u8);

@(private)
text_init :: proc (loc := #caller_location) {
	

	state.font_context = fs.font_init(8192, loc = loc);	//TODO 1,1 for w and h is might not be the best idea, what should we do instead?

	//If we want fontstash to handle loading the font
	//my_font_index := AddFontPath(font_context, name: string, path: string);

	//If we want to handle loading the font
	//AddFontMem();
	
	//Fallback font
	//AddFallbackFont(ctx: ^FontContext, base, fallback: int);

	//GetFontByName //Return the index by passing a name.

	//PushState
	//PopState

	//SetSize
	//SetColor
	//SetSpacing
	//SetBlur
	//SetFont

	//I don't think states are needed
	//BeginState
	//EndState

	//To get the text width or bound
	//TextBounds
	
	//How tall can a single line be?
	//LineBounds

	//Needs to be check, so that we can update the texture on the GPU ValidateTexture
	//ValidateTexture //when the is x then font_context.textureData should be reuploaded with the size of font_context.width and  font_context.height
	//font_context.textureData is properly stored as a single channel and so our textures should support that first.

	//ExpandAtlas
	//ResetAtlas

	//When we draw
	//TextIterInit
	//for //
	//TextIterNext

	//Destroy(&font_context);
	
	font_norm 		:= cast(Font) fs.add_font_mem_single(&state.font_context, font_norm_data, false, loc = loc);
	font_RB 		:= cast(Font) fs.add_font_mem_single(&state.font_context, font_RB_data, false, loc = loc);
	font_RI 		:= cast(Font) fs.add_font_mem_single(&state.font_context, font_RI_data, false, loc = loc);
	font_RBI 		:= cast(Font) fs.add_font_mem_single(&state.font_context, font_RBI_data, false, loc = loc);
	
	state.default_fonts = Fonts {
		normal 		= font_norm,
		bold 		= font_RB,
		italic 		= font_RI,
		italic_bold = font_RBI,
	};
	
	log.info("Default fonts loaded");
	
	instance_desc : Instance_data_desc = {
		data_type 	= Default_instance_data,
		data_points = 1,
		usage 		= .dynamic_upload, //TODO maybe dynamic upload is better here?
	};

	verts, indices := generate_quad({1,1,1}, {0,0,0}, true);
	defer delete(verts);
	defer indices_delete(indices);
	state.char_mesh = mesh_make_single(verts, indices, .static_use, .triangles, instance_desc, "Text Quad", loc);
	
	state.font_texture = texture2D_make(false, .repeat, .nearest, .R8, 1, 1, .no_upload, nil, label = "Text texture");
	
	log.info("Text initialized!");
}

@(private)
text_destroy :: proc () {

	state.default_fonts = {};
	
	fs.font_destroy(&state.font_context); state.font_context = {};

	mesh_destroy_single(&state.char_mesh); state.char_mesh = {};
	texture2D_destroy(state.font_texture); state.font_texture = {};
}

get_default_fonts :: proc (loc := #caller_location) -> Fonts {
	assert(state.default_fonts != {}, "No fonts loaded", loc);
	return state.default_fonts;
}

@(require_results)
load_font_from_path :: proc(path : string) -> Font {
	return auto_cast fs.add_font_path_single(&state.font_context, path);
}

@(require_results)
load_font_from_memory :: proc(data : []u8) -> Font {
	data_cpy := slice.clone(data);
	return auto_cast fs.add_font_mem_single(&state.font_context, data_cpy, true);
}

@(require_results)
text_get_dimensions :: proc(text : string, size : f32, font : Font = state.default_fonts.normal) -> [2]f32 {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(false, size);
	
	return fs.get_text_bounds(&state.font_context, text).zw;
}

@(require_results)
text_get_lowest_point :: proc(text : string, size : f32, font : Font = state.default_fonts.normal) -> f32 {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(false, size);
	
	return fs.get_lowest_point(&font_context);
}

@(require_results)
text_get_ascender :: proc(font : Font, size : f32, use_EM := false) -> f32 {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(use_EM, size);
	
	return fs.get_ascent(&state.font_context);
}

@(require_results)
text_get_descender :: proc(font : Font, size : f32, use_EM := false) -> f32 {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(use_EM, size);
	
	return fs.get_descent(&state.font_context);
}

@(require_results)
text_get_max_height :: proc(font : Font, size : f32, use_EM := false) -> f32 {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(use_EM, size);
	
	return fs.get_max_height(&state.font_context);
}

@(require_results)
text_get_size_from_max_height :: proc(font : Font, max_height : f32) -> f32 {
	using state;
	
	cur_max := text_get_max_height(font, 1000);
	
	return cur_max / max_height / 1000;
}

@(require_results)
text_get_bounds :: proc(text : string, size : f32, font : Font = state.default_fonts.normal) -> (bounds : [4]f32) {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(false, size);
	
	return fs.get_text_bounds(&state.font_context, text);
}

@(require_results)
text_get_visible_bounds :: proc(text : string, size : f32, font : Font = state.default_fonts.normal) -> (bounds : [4]f32) {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(false, size);
	
	return fs.get_visible_text_bounds(&state.font_context, text);
}

text_get_pixel_EM_ratio :: proc (size : f32, font : Font = state.default_fonts.normal) -> f32 {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	pix := text_get_max_height (font, size, false);
	
	em := text_get_max_height (font, size, true);
	
	return em / pix;
}

//Hint you can make an outline with a backdrop.
Text_backdrop :: struct {
	color : [4]f32,
	offset : [2]f32,
}

//Has its own pipeline call outisde of a pipeline, but inside a target.
//This will be drawn in pixel space.
text_draw_simple :: proc (text : string, position : [2]f32, size : f32, color : [4]f32 = {1,1,1,1}, backdrop : Text_backdrop = {},
							font : Font = state.default_fonts.normal, rotation : f32 = 0, shader := state.default_text_shader, camera : Maybe(Camera) = nil, flip_y := false, loc := #caller_location) {
	
	assert(shader != nil, "shader may not be nil", loc);
	assert(state.current_pipeline == {}, "A pipeline is already bound, text must be drawn outside of pipeline begin/end.", loc);
	assert(state.current_target != nil, "A render target is not bound.", loc);
	
	instance_data : [dynamic]Default_instance_data = text_get_draw_instance_data(text, position, size, rotation, flip_y, font);
	defer delete(instance_data);
	
	pipeline := pipeline_make(shader, .blend, false, false, .fill, culling = .no_cull);
	defer pipeline_destroy(pipeline);
	
	if i_data, ok := state.char_mesh.instance_data.?; ok {
		if i_data.data_points < len(text) {
			mesh_resize_instance_single(&state.char_mesh, len(text));
		}
	}
	else {
		panic("!?!?!");
	}
	
	cam : Camera = camera_get_pixel_space(state.current_target); 
	
	if c, ok := camera.?; ok {
		cam = c;
	}
	
	pipeline_begin(pipeline, cam);
	set_texture(.texture_diffuse, state.font_texture);
	
	if backdrop.offset != {0,0} {
		//Reuse the instance_data and make the backdrop from that.
		backdrop_data := make([]Default_instance_data, len(instance_data));
		defer delete(backdrop_data);
		
		for data, i in instance_data {
			b : Default_instance_data = {
				instance_position 		= data.instance_position + {backdrop.offset.x, backdrop.offset.y, 0},
				instance_scale 			= data.instance_scale,
				instance_rotation 		= data.instance_rotation,
				instance_tex_pos_scale 	= data.instance_tex_pos_scale,
			}
			backdrop_data[i] = b;
		}
		
		upload_instance_data_single(&state.char_mesh, 0, backdrop_data);
		mesh_draw_instanced(&state.char_mesh, len(backdrop_data), backdrop.color);
	}
	
	upload_instance_data_single(&state.char_mesh, 0, instance_data[:]);
	mesh_draw_instanced(&state.char_mesh, len(instance_data), color);
	
	pipeline_end();
}

text_draw :: proc (text : string, position : [2]f32, size : f32, bold, italic : bool, color : [4]f32 = {0,0,0,1}, backdrop : Text_backdrop = {}, font : Fonts = state.default_fonts, rotation : f32 = 0, shader := state.default_text_shader, camera : Maybe(Camera) = nil, flip_y : bool = false, loc := #caller_location) {
	stored := store_pipeline();
	defer restore_pipeline(stored);
	//TODO WE SHOULD ALSO STORE THE TEXTURE!
	font := text_get_font_from_fonts(bold, italic, font);
	text_draw_simple(text, position, size, color, backdrop, font, rotation, shader, camera, flip_y, loc);
}

font_tex_desc :: Texture_desc {
	wrapmode = .clamp_to_border,
	filtermode = .nearest,
	mipmaps = false,
	format	= .R8,
}

//used internally
@require_results
text_get_draw_instance_data :: proc (text : string, position : [2]f32, size : f32, rotation : f32, flip_y : bool, font : Font) -> (instance_data : [dynamic]Default_instance_data) {
	using state;
	
	fs.push_font(&font_context, font);
	defer fs.pop_font(&font_context);
	
	_set_font_size(false, size);
	iter := fs.make_font_iter(&font_context, text);
	defer fs.destroy_font_iter(iter);
	
	if new_size, ok := fs.requires_reupload(&font_context); ok {
		log.logf(.Debug, "reuploading font texture : %v\n", new_size);
		texture2D_destroy(state.font_texture);
		state.font_texture = texture2D_make(false, .repeat, .nearest, .R8, new_size.x, new_size.y, .R8, fs.get_bitmap(&font_context), label = "Text texture");
	}
	
	rect, done := fs.get_next_quad_upload(&font_context);
	for !done {
		//Here the atlas data is extracted from the atlas, alternatively the entire atlas can be uploaded.
		extracted_data := make([]u8, rect.z * rect.w);
		defer delete(extracted_data);
		
		dims := fs.get_bitmap_dimension(&font_context);
		fs.copy_pixels(1, dims.x, dims.y, rect.x, rect.y, fs.get_bitmap(&font_context), rect.z, rect.w, 0, 0, extracted_data, rect.z, rect.w);
		texture2D_upload_data(&state.font_texture, .R8, {rect.x, rect.y}, rect.zw, extracted_data);
		
		rect, done = fs.get_next_quad_upload(&font_context);
	}
	
	instance_data = make([dynamic]Default_instance_data);
	
	for q, coords in fs.font_iter_next(&font_context, &iter) {
		
		rot_mat := linalg.matrix2_rotate_f32(rotation / 180 * math.PI);
		pos := rot_mat * q.xy;
		
		if flip_y {
			append(&instance_data, Default_instance_data {
				//What should be here?
				instance_position 	= {position.x + pos.x, position.y - pos.y + size, 0},
				instance_scale 		= {q.z, q.w, 1},
				instance_rotation 	= {0, 0, rotation}, //Euler rotation
				instance_tex_pos_scale 	= {coords.x, coords.y + coords.w, coords.z, -coords.w},
			});
		}
		else {
			append(&instance_data, Default_instance_data {
				instance_position 	= {position.x + pos.x, position.y + pos.y, 0},
				instance_scale 		= {q.z, q.w, 1},
				instance_rotation 	= {0, 0, rotation}, //Euler rotation
				instance_tex_pos_scale 	= coords,
			});
		}
	}
	
	if i_data, ok := char_mesh.instance_data.?; ok {
		if i_data.data_points < len(instance_data) {
			mesh_resize_instance_single(&char_mesh, len(instance_data));
		}
	}
	else {
		panic("!?!?!");
	}
	
	return;
}

//Internal_use 
text_get_font_from_fonts :: proc (bold, italic : bool, font : Fonts = state.default_fonts) -> Font {

	if bold && italic {
		return font.italic_bold;
	} 
	else if bold {
		return font.bold;
	} 
	else if italic {
		return font.italic;
	}
	else {
		return font.normal;
	}
}

//Internal_use 
_set_font_size :: proc (use_em_size : bool, size : f32) {
	
	if use_em_size {
		fs.set_em_size(&state.font_context, size);
	}
	else {
		fs.set_max_height_size(&state.font_context, size);
	}
}