package render;

import "core:os"
import "core:fmt"
import "core:math"
import "core:slice"
import "core:math/linalg"

import fs "vendor:fontstash"

/*
something_setup :: proc () {
	
	Init(&font_context, w, h: int, loc: QuadLocation);

	//If we want fontstash to handle loading the font
	my_font_index := AddFontPath(font_context, name: string, path: string);

	//If we want to handle loading the font
	AddFontMem();

	//Fallback font
	AddFallbackFont(ctx: ^FontContext, base, fallback: int);

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
	TextBounds
	
	//How tall can a single line be?
	LineBounds

	//Needs to be check, so that we can update the texture on the GPU ValidateTexture
	ValidateTexture //when the is x then font_context.textureData should be reuploaded with the size of font_context.width and  font_context.height
	//font_context.textureData is properly stored as a single channel and so our textures should support that first.

	ExpandAtlas
	ResetAtlas

	//When we draw
	TextIterInit
	for //
	TextIterNext

	Destroy(&font_context);
}
*/

Font :: distinct int;

load_font_from_file :: proc(using s : ^Render_state($U,$A), font_name : string, path : string) -> Font {
	return auto_cast fs.AddFontPath(&font_context, font_name, path);
}

load_font_from_memory :: proc(using s : ^Render_state($U,$A), font_name : string, data : []u8) -> Font {

	data_cpy := slice.clone(data);

	return auto_cast fs.AddFontMem(&font_context, font_name, data_cpy, true);
}

get_text_dimensions :: proc(using s : ^Render_state($U,$A), text : string, font : Font, size : f32, spacing : f32) -> [2]f32 {
	
	fs.SetFont(&font_context, auto_cast font);
	fs.SetSize(&font_context, size);
	fs.SetSpacing(&font_context, spacing);
	
	bounds : [4]f32;
	fs.TextBounds(&font_context, text, 0, 0, &bounds);

	return bounds.zw;
}

get_max_text_height :: proc(using s : ^Render_state($U,$A), font : Font, size : f32) -> f32 {
	
	fs.SetFont(&font_context, auto_cast font);
	fs.SetSize(&font_context, size);

	min, max := fs.LineBounds(&font_context, 0);
	return max + min;
}

get_text_bounds :: proc(using s : ^Render_state($U,$A), text : string, position : [2]f32, font : Font, size : f32, spacing : f32 = 0) -> (bounds : [4]f32) {
	
	fs.SetFont(&font_context, auto_cast font);
	fs.SetSize(&font_context, size);
	fs.SetSpacing(&font_context, spacing);

	fs.TextBounds(&font_context, text, 0, 0, &bounds);
	bounds.xy = position;

	return;
}

draw_text :: proc (using s : ^Render_state($U,$A), text : string, position : [2]f32, font : Font, size : f32, spacing : f32, color : [4]f32, shader : Shader(U, A), loc := #caller_location) {
	
	shader := shader;

	assert(false, "TODO");
	if shader.id == 0 {
		fmt.printf("loading default text shader\n");
		text_shader = get_default_text_shader();
		shader = text_shader;
	}
	
	fs.SetFont(&font_context, auto_cast font);
	fs.SetSize(&font_context, size);
	fs.SetSpacing(&font_context, spacing);
	//fs.SetAlignHorizontal(&font_context, .LEFT);
	//fs.SetAlignVertical(&font_context, .BASELINE);

	bind_shader(shader);
	place_uniform(shader, .col_diffuse, color);
	place_uniform(shader, .texture_diffuse, font_texture);
	
	it : fs.TextIter = fs.TextIterInit(&font_context, position.x, position.y, text);
	dirtyRect : [4]f32;
	quad : fs.Quad;
	
	_ensure_shapes_loaded();

	for fs.TextIterNext(&font_context, &it, &quad) {
		
		if fs.ValidateTexture(&font_context, &dirtyRect) {
			//Upload texture again.
			
			//TODO bad slow way, reupload instead (and subBufferData if there is no resize)
			if is_texture_ready(font_texture) {
				unload_texture(&font_texture);
			}
			
			assert(len(font_context.textureData) != 0, "font_context.textureData length is 0")
			
			font_texture = load_texture_from_raw_bytes(font_context.textureData, auto_cast font_context.width, auto_cast font_context.height, .uncompressed_R8);
			fmt.printf("Reuploaded font texture, new size is %v, %v\n", font_context.width, font_context.height);
		}
		
		//This is weird
		pos : linalg.Vector3f32 = {quad.x1 + (quad.x0 - quad.x1)/2, quad.y0 + (quad.y1 - quad.y0)/2, 0};
		scale : linalg.Vector3f32 = {(quad.x0 - quad.x1), (quad.y1 - quad.y0), 0};

		transform := linalg.matrix4_from_trs_f32(pos, 0, scale);
		
		using quad;
		texcoords : [4][2]f32 = {{s1, t0}, {s0, t0}, {s1, t1}, {s0, t1}};
		place_uniform(shader, .texcoords, texcoords[:]);
		draw_mesh_single(shader, shape_quad, transform);
	}
	
	unbind_shader(shader);
}


