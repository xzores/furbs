package render;

import "core:os"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:math/linalg"
import "core:log"

import fs "vendor:fontstash"

Font :: distinct int;

Fonts :: struct {
	normal : Font,
	bold : Font,
	italic : Font,
	italic_bold : Font,
}

@(private)
init_text :: proc () {

	fs.Init(&state.font_context, 1, 1, .BOTTOMLEFT);	//TODO 1,1 for w and h is might not be the best idea, what should we do instead?

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

	font_norm_data 	:= #load("font/LinLibertine_R.ttf", []u8);
	font_RB_data 	:= #load("font/LinLibertine_RB.ttf", []u8);
	font_RI_data 	:= #load("font/LinLibertine_RI.ttf", []u8);
	font_RBI_data 	:= #load("font/LinLibertine_RBI.ttf", []u8);
	font_norm 		:= cast(Font) fs.AddFontMem(&state.font_context, "LinLibertine_R", font_norm_data, false);
	font_RB 		:= cast(Font) fs.AddFontMem(&state.font_context, "LinLibertine_RB", font_RB_data, false);
	font_RI 		:= cast(Font) fs.AddFontMem(&state.font_context, "LinLibertine_RI", font_RI_data, false);
	font_RBI 		:= cast(Font) fs.AddFontMem(&state.font_context, "LinLibertine_RBI", font_RBI_data, false);
	
	state.default_fonts = Fonts {
		normal 		= font_norm,
		bold 		= font_RB,
		italic 		= font_RI,
		italic_bold = font_RBI,
	};

	instance_desc : Instance_data_desc = {
		data_type 	= Default_instance_data,
		data_points = 1,
		usage 		= .dynamic_upload, //TODO maybe dynamic upload is better here?
	};

	verts, indices := generate_quad({1,1,1}, {0,0,0}, true);
	defer delete(verts);
	defer delete_indices(indices);
	state.char_mesh = make_mesh_single(verts, indices, .static_use, .triangles, instance_desc);
}

@(private)
destroy_text :: proc () {

	state.default_fonts = {};

	fs.Destroy(&state.font_context); state.font_context = {};

	destroy_mesh_single(&state.char_mesh); state.char_mesh = {};
	destroy_texture_2D(&state.font_texture)
}

@(require_results)
load_font_from_path :: proc(font_name : string, path : string) -> Font {
	return auto_cast fs.AddFontPath(&state.font_context, font_name, path);
}

@(require_results)
load_font_from_memory :: proc(font_name : string, data : []u8) -> Font {

	data_cpy := slice.clone(data);

	return auto_cast fs.AddFontMem(&state.font_context, font_name, data_cpy, false);
}

@(require_results)
get_text_dimensions :: proc(text : string, font : Font, size : f32, spacing : f32) -> [2]f32 {
	
	fs.SetFont(&state.font_context, auto_cast font);
	fs.SetSize(&state.font_context, size);
	fs.SetSpacing(&state.font_context, spacing);
	
	bounds : [4]f32;
	fs.TextBounds(&state.font_context, text, 0, 0, &bounds);

	return bounds.zw;
}

@(require_results)
get_max_text_height :: proc(font : Font, size : f32) -> f32 {
	
	fs.SetFont(&state.font_context, auto_cast font);
	fs.SetSize(&state.font_context, size);

	min, max := fs.LineBounds(&state.font_context, 0);
	return max + min;
}

@(require_results)
get_text_bounds :: proc(text : string, position : [2]f32, font : Font, size : f32, spacing : f32 = 0) -> (bounds : [4]f32) {
	
	fs.SetFont(&state.font_context, auto_cast font);
	fs.SetSize(&state.font_context, size);
	fs.SetSpacing(&state.font_context, spacing);

	fs.TextBounds(&state.font_context, text, 0, 0, &bounds);
	bounds.xy = position;

	return;
}

font_tex_desc :: Texture_desc {
	wrapmode = .clamp_to_border,
	filtermode = .nearest,
	mipmaps = false,
	format	= .uncompressed_R8,
}

get_draw_instance_data :: proc (text : string, position : [2]f32, size : f32, spacing : f32 = 0, font : Font) -> (instance_data : [dynamic]Default_instance_data) {
	using state;
	
	fs.SetFont(&font_context, auto_cast font);
	fs.SetSize(&font_context, size);
	fs.SetSpacing(&font_context, spacing);
	//fs.SetAlignHorizontal(&font_context, .LEFT);
	//fs.SetAlignVertical(&font_context, .BASELINE);

	//TODO there seem to be a bug in fontstash that makes it so it only shows letter that can fit in the uploaded texture (it does not resize on the first upload).
	it : fs.TextIter = fs.TextIterInit(&font_context, position.x, position.y, text);
	dirtyRect : [4]f32;
	quad : fs.Quad;
	
	_ensure_shapes_loaded();

	instance_data = make([dynamic]Default_instance_data, 0, len(text));
	
	should_reupload : bool = false;

	for fs.TextIterNext(&font_context, &it, &quad) {

		//This is weird
		pos : linalg.Vector3f32 = {quad.x1 + (quad.x0 - quad.x1)/2, quad.y0 + (quad.y1 - quad.y0)/2, 0}; 	//this is position of single quad
		scale : linalg.Vector3f32 = {(quad.x1 - quad.x0), (quad.y1 - quad.y0), 0};							//scale of the quad
		
		//using quad;
		//texcoords : [4][2]f32 = {{s1, t0}, {s0, t0}, {s1, t1}, {s0, t1}};
		append(&instance_data, Default_instance_data { //These are apply for all 4 verticies.
			instance_position 	= pos,
			instance_scale 		= scale,
			instance_texcoord	= {quad.s0, quad.t0, quad.s1, quad.t1},
		});
	}

	for fs.ValidateTexture(&font_context, &dirtyRect) {
		should_reupload = true;
	}
	
	if should_reupload {
		//Upload texture again.
		
		//TODO bad slow way, reupload instead (and subBufferData if there is no resize)
		//If the texture is there then unload it.
		if font_texture != {} {
			destroy_texture_2D(&font_texture);
		}
		
		assert(len(font_context.textureData) != 0, "font_context.textureData length is 0")
		
		font_texture = make_texture_2D_desc(font_tex_desc, auto_cast font_context.width, auto_cast font_context.height, .uncompressed_R8, font_context.textureData);
		log.infof("Reuploaded font texture, new size is %v, %v", font_context.width, font_context.height);
	}

	return;
}

//Has its own pipeline call outisde of a pipeline, but inside a target.
draw_text_simple :: proc (text : string, position : [2]f32, size : f32, spacing : f32 = 0, color : [4]f32 = {1,1,1,1},
							font : Font = state.default_fonts.normal, shader := state.default_text_shader, loc := #caller_location) {
	assert(shader != nil, "shader may not be nil", loc);
	assert(state.current_pipeline == {}, "A pipeline is already bound, text must be drawn outside of pipeline begin/end.", loc);
	assert(state.current_target != nil, "A render target is not bound.", loc);
	
	instance_data : [dynamic]Default_instance_data = get_draw_instance_data(text, position, size, spacing, font);
	defer delete(instance_data);

	pipeline := make_pipeline(shader, .blend, false, false, .fill, culling = .back_cull);
	defer destroy_pipeline(pipeline);
	
	if i_data, ok := state.char_mesh.instance_data.?; ok {
		if i_data.data_points < len(text) {
			resize_mesh_instance_single(&state.char_mesh, len(text));
			log.infof("Resized text instance data. New length : %v", len(text));
		}
	}
	else {
		panic("!?!?!");
	}
	
	upload_instance_data_single(&state.char_mesh, 0, instance_data[:]);
	
	cam := get_pixel_space_camera(state.current_target);

	begin_pipeline(pipeline, cam);
	set_uniform(shader, .color_diffuse, color);
	set_texture(.texture_diffuse, state.font_texture);
	draw_mesh_instanced(&state.char_mesh, len(instance_data));
	end_pipeline();
}

draw_text_ex :: proc (text : string, position : [2]f32, size : f32, bold, italic : bool, spacing : f32 = 0,
							color : [4]f32 = {0,0,0,0}, font : Fonts = state.default_fonts, shader := state.default_shader, loc := #caller_location) {



}