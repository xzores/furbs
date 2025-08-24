package nulkear_bindings;

import "core:c"

import "core:strings"
import "core:fmt"

when ODIN_OS == .Darwin  {
	foreign import nuklear "libnuklear_64.a"
} else when ODIN_OS == .Windows {
	when ODIN_DEBUG {
		foreign import nuklear "libnuklear_64d.lib"
	}
	else {
		foreign import nuklear "libnuklear_64.lib"
	}
} else when ODIN_OS == .Linux {
	foreign import nuklear "libnuklear_64.a"
}

////////////////// THE library is compiled with the following falgs //////////////////
//NK_INCLUDE_FIXED_TYPES          | If defined it will include header `<stdint.h>` for fixed sized types otherwise nuklear tries to select the correct type. If that fails it will throw a compiler error and you have to select the correct types yourself.
//NK_INCLUDE_STANDARD_BOOL        | If defined it will include header `<stdbool.h>` for nk_bool otherwise nuklear defines nk_bool as int.
//NK_INCLUDE_COMMAND_USERDATA     | Defining this adds a userdata pointer into each command. Can be useful for example if you want to provide custom shaders depending on the used widget. Can be combined with the style structures.
//NK_BUTTON_TRIGGER_ON_RELEASE    | Different platforms require button clicks occurring either on buttons being pressed (up to down) or released (down to up). By default this library will react on buttons being pressed, but if you define this it will only trigger if a button is released.

/**
 * \brief Sets the currently passed userdata passed down into each draw command.
 *
 * \details
 * ```c
 * void nk_set_user_data(struct nk_context *ctx, nk_handle data);
 * ```
 *
 * \param[in] ctx Must point to a previously initialized `nk_context` struct
 * \param[in] data  Handle with either pointer or index to be passed into every draw commands
 */

//because of NK_INCLUDE_COMMAND_USERDATA
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	set_user_data :: proc(ctx : ^Context, handle : Handle) ---;
}

/* =============================================================================
*
*                                  INPUT
*
* =============================================================================*/

nk_keys :: enum u32 {
	NK_KEY_NONE,
	NK_KEY_SHIFT,
	NK_KEY_CTRL,
	NK_KEY_DEL,
	NK_KEY_ENTER,
	NK_KEY_TAB,
	NK_KEY_BACKSPACE,
	NK_KEY_COPY,
	NK_KEY_CUT,
	NK_KEY_PASTE,
	NK_KEY_UP,
	NK_KEY_DOWN,
	NK_KEY_LEFT,
	NK_KEY_RIGHT,
	// Shortcuts: text field
	NK_KEY_TEXT_INSERT_MODE,
	NK_KEY_TEXT_REPLACE_MODE,
	NK_KEY_TEXT_RESET_MODE,
	NK_KEY_TEXT_LINE_START,
	NK_KEY_TEXT_LINE_END,
	NK_KEY_TEXT_START,
	NK_KEY_TEXT_END,
	NK_KEY_TEXT_UNDO,
	NK_KEY_TEXT_REDO,
	NK_KEY_TEXT_SELECT_ALL,
	NK_KEY_TEXT_WORD_LEFT,
	NK_KEY_TEXT_WORD_RIGHT,
	// Shortcuts: scrollbar
	NK_KEY_SCROLL_START,
	NK_KEY_SCROLL_END,
	NK_KEY_SCROLL_DOWN,
	NK_KEY_SCROLL_UP,
}

nk_buttons :: enum u32 {
	NK_BUTTON_LEFT,
	NK_BUTTON_MIDDLE,
	NK_BUTTON_RIGHT,
	NK_BUTTON_DOUBLE,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	input_begin		:: proc(ctx: ^Context) ---;
	input_motion	:: proc(ctx: ^Context, x: c.int, y: c.int) ---;
	input_key		:: proc(ctx: ^Context, key: nk_keys, down: nk_bool) ---;
	input_button	:: proc(ctx: ^Context, btn: nk_buttons, x: c.int, y: c.int, down: nk_bool) ---;
	input_scroll	:: proc(ctx: ^Context, val: Vec2) ---;
	input_char		:: proc(ctx: ^Context, ch: c.char) ---;
	input_glyph		:: proc(ctx: ^Context, glyph: ^Glyph) ---;
	input_unicode	:: proc(ctx: ^Context, rune: nk_rune) ---;
	input_end		:: proc(ctx: ^Context) ---;
}


/** =============================================================================
*
*                                  WINDOW
*
* =============================================================================*/

/*
Panel_flags :: enum {
	NK_WINDOW_BORDER            = 1 << 0,
	NK_WINDOW_MOVABLE           = 1 << 1,
	NK_WINDOW_SCALABLE          = 1 << 2,
	NK_WINDOW_CLOSABLE          = 1 << 3,
	NK_WINDOW_MINIMIZABLE       = 1 << 4,
	NK_WINDOW_NO_SCROLLBAR      = 1 << 5,
	NK_WINDOW_TITLE             = 1 << 6,
	NK_WINDOW_SCROLL_AUTO_HIDE  = 1 << 7,
	NK_WINDOW_BACKGROUND        = 1 << 8,
	NK_WINDOW_SCALE_LEFT        = 1 << 9,
	NK_WINDOW_NO_INPUT          = 1 << 10
};
*/

//make lower case
Panel_flags_enum :: enum u32 {
	window_border 			= 0,
	window_movable			= 1,
	window_scaleable		= 2,
	window_closeable		= 3,
	window_minimizeable		= 4,
	window_no_scrollbar		= 5,
	window_title			= 6,
	window_scroll_auto_hide = 7,
	window_background 		= 8,
	window_scale_left 		= 9,
	window_no_input 		= 10,
}

Panel_flags :: bit_set[Panel_flags_enum];

Window_flags_enum :: enum u32 {
	window_border 				= 0,
	window_movable				= 1,
	window_scaleable			= 2,
	window_closeable			= 3,
	window_minimizeable			= 4,
	window_no_scrollbar			= 5,
	window_title				= 6,
	window_scroll_auto_hide 	= 7,
	window_background 			= 8,
	window_scale_left 			= 9,
	window_no_input 			= 10,
	window_private        		= 11,
	window_dynamic        		= window_private,
	window_rom		           	= 12,
	//Must be done by user window_not_interactive 		= cast(u32)window_rom | cast(u32)window_no_input,
	window_hidden         		= 13,
	window_closed        		= 14,
	window_minimized      		= 15,
	window_remove_rom	     	= 16,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	begin                          :: proc(ctx: ^Context, title: cstring, bounds: Rect, flags: Panel_flags) -> nk_bool ---
	begin_titled                  :: proc(ctx: ^Context, name: cstring, title: cstring, bounds: Rect, flags: Panel_flags) -> nk_bool ---
	end                            :: proc(ctx: ^Context) ---
	window_find                   :: proc(ctx: ^Context, name: cstring) -> ^Window ---
	window_get_bounds             :: proc(ctx: ^Context) -> Rect ---
	window_get_position           :: proc(ctx: ^Context) -> Vec2 ---
	window_get_size               :: proc(ctx: ^Context) -> Vec2 ---
	window_get_width              :: proc(ctx: ^Context) -> f32 ---
	window_get_height             :: proc(ctx: ^Context) -> f32 ---
	window_get_panel              :: proc(ctx: ^Context) -> ^Panel ---
	window_get_content_region     :: proc(ctx: ^Context) -> Rect ---
	window_get_content_region_min :: proc(ctx: ^Context) -> Vec2 ---
	window_get_content_region_max :: proc(ctx: ^Context) -> Vec2 ---
	window_get_content_region_size:: proc(ctx: ^Context) -> Vec2 ---
	window_get_canvas             :: proc(ctx: ^Context) -> ^Command_buffer ---
	window_get_scroll             :: proc(ctx: ^Context, offset_x: ^nk_uint, offset_y: ^nk_uint) ---
	window_has_focus              :: proc(ctx: ^Context) -> nk_bool ---
	window_is_hovered             :: proc(ctx: ^Context) -> nk_bool ---
	window_is_collapsed           :: proc(ctx: ^Context, name: cstring) -> nk_bool ---
	window_is_closed              :: proc(ctx: ^Context, name: cstring) -> nk_bool ---
	window_is_hidden              :: proc(ctx: ^Context, name: cstring) -> nk_bool ---
	window_is_active              :: proc(ctx: ^Context, name: cstring) -> nk_bool ---
	window_is_any_hovered         :: proc(ctx: ^Context) -> nk_bool ---
	item_is_any_active            :: proc(ctx: ^Context) -> nk_bool ---
	window_set_bounds             :: proc(ctx: ^Context, name: cstring, bounds: Rect) ---
	window_set_position           :: proc(ctx: ^Context, name: cstring, pos: Vec2) ---
	window_set_size               :: proc(ctx: ^Context, name: cstring, size: Vec2) ---
	window_set_focus              :: proc(ctx: ^Context, name: cstring) ---
	window_set_scroll             :: proc(ctx: ^Context, offset_x: nk_uint, offset_y: nk_uint) ---
	window_close                  :: proc(ctx: ^Context, name: cstring) ---
	window_collapse               :: proc(ctx: ^Context, name: cstring, state: nk_collapse_states) ---
	window_collapse_if            :: proc(ctx: ^Context, name: cstring, state: nk_collapse_states, cond: c.int) ---
	window_show                   :: proc(ctx: ^Context, name: cstring, state: nk_show_states) ---
	window_show_if                :: proc(ctx: ^Context, name: cstring, state: nk_show_states, cond: c.int) ---
	rule_horizontal               :: proc(ctx: ^Context, color: Color, rounding: nk_bool) ---
}



/** =============================================================================
*
*                                  DRAWING
*
* =============================================================================*/

nk_anti_aliasing :: enum u32 {
	NK_ANTI_ALIASING_OFF,
	NK_ANTI_ALIASING_ON,
}

nk_convert_result :: enum u32 {
	NK_CONVERT_SUCCESS				= 0,
	NK_CONVERT_INVALID_PARAM		= 1,
	NK_CONVERT_COMMAND_BUFFER_FULL	= 1 << 1,
	NK_CONVERT_VERTEX_BUFFER_FULL	= 1 << 2,
	NK_CONVERT_ELEMENT_BUFFER_FULL	= 1 << 3,
}

nk_draw_null_texture :: struct {
	texture	: Handle,	// texture handle to a texture with a white pixel
	uv		: Vec2,			// coordinates to a white pixel in the texture
}

/*
nk_convert_config :: struct {
	global_alpha			: f32,					// global alpha value
	line_AA					: nk_anti_aliasing,		// line anti-aliasing flag
	shape_AA				: nk_anti_aliasing,		// shape anti-aliasing flag
	circle_segment_count	: c.uint,				// number of segments used for circles
	arc_segment_count		: c.uint,				// number of segments used for arcs
	curve_segment_count		: c.uint,				// number of segments used for curves
	tex_null				: nk_draw_null_texture,	// handle to texture with a white pixel
	vertex_layout			: ^nk_draw_vertex_layout_element, // describes the vertex output format and packing
	vertex_size				: nk_size,				// sizeof one vertex for vertex packing
	vertex_alignment		: nk_size,				// vertex alignment
}
*/

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	_begin	:: proc(ctx: ^Context) -> ^nk_command ---;
	_next	:: proc(ctx: ^Context, cmd: ^nk_command) -> ^nk_command ---;
}

//#define nk_foreach(c, ctx) for((c) = nk__begin(ctx); (c) != 0; (c) = nk__next(ctx,c))



/* =============================================================================
*
*                                  LAYOUT
*
* =============================================================================*/

Widget_align :: enum {
	NK_WIDGET_ALIGN_LEFT        = 0x01,
	NK_WIDGET_ALIGN_CENTERED    = 0x02,
	NK_WIDGET_ALIGN_RIGHT       = 0x04,
	NK_WIDGET_ALIGN_TOP         = 0x08,
	NK_WIDGET_ALIGN_MIDDLE      = 0x10,
	NK_WIDGET_ALIGN_BOTTOM      = 0x20,
};

Widget_alignment :: enum {
	NK_WIDGET_LEFT        = auto_cast (Widget_align.NK_WIDGET_ALIGN_MIDDLE | Widget_align.NK_WIDGET_ALIGN_LEFT),
	NK_WIDGET_CENTERED    = auto_cast (Widget_align.NK_WIDGET_ALIGN_MIDDLE | Widget_align.NK_WIDGET_ALIGN_CENTERED),
	NK_WIDGET_RIGHT       = auto_cast (Widget_align.NK_WIDGET_ALIGN_MIDDLE | Widget_align.NK_WIDGET_ALIGN_RIGHT),
};

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	layout_set_min_row_height              :: proc(ctx: ^Context, height: f32) ---
	layout_reset_min_row_height           :: proc(ctx: ^Context) ---
	layout_widget_bounds                  :: proc(ctx: ^Context) -> Rect ---
	layout_ratio_from_pixel               :: proc(ctx: ^Context, pixel_width: f32) -> f32 ---
	layout_row_dynamic                    :: proc(ctx: ^Context, height: f32, cols: c.int) ---
	layout_row_static                     :: proc(ctx: ^Context, height: f32, item_width: c.int, cols: c.int) ---
	layout_row_begin                      :: proc(ctx: ^Context, fmt: nk_layout_format, row_height: f32, cols: c.int) ---
	layout_row_push                       :: proc(ctx: ^Context, value: f32) ---
	layout_row_end                        :: proc(ctx: ^Context) ---
	layout_row                            :: proc(ctx: ^Context, fmt: nk_layout_format, height: f32, cols: c.int, ratio: ^f32) ---
	layout_row_template_begin             :: proc(ctx: ^Context, row_height: f32) ---
	layout_row_template_push_dynamic      :: proc(ctx: ^Context) ---
	layout_row_template_push_variable     :: proc(ctx: ^Context, min_width: f32) ---
	layout_row_template_push_static       :: proc(ctx: ^Context, width: f32) ---
	layout_row_template_end               :: proc(ctx: ^Context) ---
	layout_space_begin                    :: proc(ctx: ^Context, fmt: nk_layout_format, height: f32, widget_count: c.int) ---
	layout_space_push                     :: proc(ctx: ^Context, bounds: Rect) ---
	layout_space_end                      :: proc(ctx: ^Context) ---
	layout_space_bounds                   :: proc(ctx: ^Context) -> Rect ---
	layout_space_to_screen                :: proc(ctx: ^Context, vec: Vec2) -> Vec2 ---
	layout_space_to_local                 :: proc(ctx: ^Context, vec: Vec2) -> Vec2 ---
	layout_space_rect_to_screen           :: proc(ctx: ^Context, bounds: Rect) -> Rect ---
	layout_space_rect_to_local            :: proc(ctx: ^Context, bounds: Rect) -> Rect ---
	spacer                                :: proc(ctx: ^Context) ---
}


/** =============================================================================
*
*                                  GROUP
*
* =============================================================================*/

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	group_begin                       :: proc(ctx: ^Context, title: cstring, flags: nk_flags) -> nk_bool ---
	group_begin_titled               :: proc(ctx: ^Context, name: cstring, title: cstring, flags: nk_flags) -> nk_bool ---
	group_end                         :: proc(ctx: ^Context) ---
	group_scrolled_offset_begin      :: proc(ctx: ^Context, x_offset: ^nk_uint, y_offset: ^nk_uint, title: cstring, flags: nk_flags) -> nk_bool ---
	group_scrolled_begin             :: proc(ctx: ^Context, off: ^Scroll, title: cstring, flags: nk_flags) -> nk_bool ---
	group_scrolled_end               :: proc(ctx: ^Context) ---
	group_get_scroll                 :: proc(ctx: ^Context, id: cstring, x_offset: ^nk_uint, y_offset: ^nk_uint) ---
	group_set_scroll                 :: proc(ctx: ^Context, id: cstring, x_offset: nk_uint, y_offset: nk_uint) ---
}




/** =============================================================================
*
*                                  TREE
*
* =============================================================================*/

tree_push :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: Collapse_states, dont_pass := #caller_location) -> nk_bool {
	hash := fmt.ctprintf("%v(%v)", dont_pass.file_path, dont_pass.line);
	hash_len := strlen(auto_cast hash);
	seed := dont_pass.line;
	return tree_push_hashed(ctx, typ, title, state, hash, hash_len, seed);
}

tree_push_id :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: Collapse_states, id: c.int, dont_pass := #caller_location) -> nk_bool {
	hash := fmt.ctprintf("%v(%v)", dont_pass.file_path, dont_pass.line);
	hash_len := strlen(auto_cast hash);
	return tree_push_hashed(ctx, typ, title, state, hash, hash_len, id);
}

tree_image_push :: proc(ctx: ^Context, typ: Tree_type, img: Image, title: cstring, state: Collapse_states, dont_pass := #caller_location) -> nk_bool {
	hash := fmt.ctprintf("%v(%v)", dont_pass.file_path, dont_pass.line);
	hash_len := strlen(auto_cast hash);
	seed := dont_pass.line;
	return tree_image_push_hashed(ctx, typ, img, title, state, hash, hash_len, seed);
}

tree_image_push_id :: proc(ctx: ^Context, typ: Tree_type, img: Image, title: cstring, state: Collapse_states, id: c.int, dont_pass := #caller_location) -> nk_bool {
	hash := fmt.ctprintf("%v(%v)", dont_pass.file_path, dont_pass.line);
	hash_len := strlen(auto_cast hash);
	return tree_image_push_hashed(ctx, typ, img, title, state, hash, hash_len, id);
}

tree_element_push :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: Collapse_states, selected: ^nk_bool, dont_pass := #caller_location) -> nk_bool {
	hash := fmt.ctprintf("%v(%v)", dont_pass.file_path, dont_pass.line);
	hash_len := strlen(auto_cast hash);
	seed := dont_pass.line;
	return tree_element_push_hashed(ctx, typ, title, state, selected, hash, hash_len, seed);
}

tree_element_push_id :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: Collapse_states, selected: ^nk_bool, id: c.int, dont_pass := #caller_location) -> nk_bool {
	hash := fmt.ctprintf("%v(%v)", dont_pass.file_path, dont_pass.line);
	hash_len := strlen(auto_cast hash);
	return tree_element_push_hashed(ctx, typ, title, state, selected, hash, hash_len, id);
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	tree_push_hashed                :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: Collapse_states, hash: cstring, len: c.int, seed: c.int) -> nk_bool ---;
	tree_image_push_hashed          :: proc(ctx: ^Context, typ: Tree_type, img: Image, title: cstring, state: Collapse_states, hash: cstring, len: c.int, seed: c.int) -> nk_bool ---;
	tree_pop                        :: proc(ctx: ^Context) ---;
	tree_state_push                 :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: ^Collapse_states) -> nk_bool ---;
	tree_state_image_push           :: proc(ctx: ^Context, typ: Tree_type, img: Image, title: cstring, state: ^Collapse_states) -> nk_bool ---;
	tree_state_pop                  :: proc(ctx: ^Context) ---;
	tree_element_push_hashed        :: proc(ctx: ^Context, typ: Tree_type, title: cstring, state: Collapse_states, selected: ^nk_bool, hash: cstring, len: c.int, seed: c.int) -> nk_bool ---;
	tree_element_image_push_hashed  :: proc(ctx: ^Context, typ: Tree_type, img: Image, title: cstring, state: Collapse_states, selected: ^nk_bool, hash: cstring, len: c.int, seed: c.int) -> nk_bool ---;
	tree_element_pop                :: proc(ctx: ^Context) ---;
}


/* =============================================================================
*
*                                  LIST VIEW
*
* ============================================================================= */

nk_list_view :: struct {
	begin, end, count: c.int,
	total_height: c.int,
	ctx: ^Context,
	scroll_pointer: ^nk_uint,
	scroll_value: nk_uint,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	list_view_begin :: proc(ctx: ^Context, out: ^nk_list_view, id: cstring, flags: nk_flags, row_height: c.int, row_count: c.int) -> nk_bool ---;
	list_view_end   :: proc(view: ^nk_list_view) ---;
}

/* =============================================================================
*
*                                  WIDGET
*
* ============================================================================= */


nk_widget_layout_states :: enum u32 {
	NK_WIDGET_INVALID,   // The widget cannot be seen and is completely out of view
	NK_WIDGET_VALID,     // The widget is completely inside the window and can be updated and drawn
	NK_WIDGET_ROM,       // The widget is partially visible and cannot be updated
	NK_WIDGET_DISABLED,  // The widget is manually disabled and acts like NK_WIDGET_ROM
}

nk_widget_states :: enum u32 {
	NK_WIDGET_STATE_MODIFIED    = 1 << 1,
	NK_WIDGET_STATE_INACTIVE    = 1 << 2, // widget is neither active nor hovered
	NK_WIDGET_STATE_ENTERED     = 1 << 3, // widget has been hovered on the current frame
	NK_WIDGET_STATE_HOVER       = 1 << 4, // widget is being hovered
	NK_WIDGET_STATE_ACTIVED     = 1 << 5, // widget is currently activated
	NK_WIDGET_STATE_LEFT        = 1 << 6, // widget is from this frame on not hovered anymore
	NK_WIDGET_STATE_HOVERED     = NK_WIDGET_STATE_HOVER|NK_WIDGET_STATE_MODIFIED, // widget is being hovered
	NK_WIDGET_STATE_ACTIVE      = NK_WIDGET_STATE_ACTIVED|NK_WIDGET_STATE_MODIFIED, // widget is currently activated
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	widget                :: proc(bounds: ^Rect, ctx: ^Context) -> nk_widget_layout_states ---;
	widget_fitting        :: proc(bounds: ^Rect, ctx: ^Context, size: Vec2) -> nk_widget_layout_states ---;
	widget_bounds         :: proc(ctx: ^Context) -> Rect ---;
	widget_position       :: proc(ctx: ^Context) -> Vec2 ---;
	widget_size           :: proc(ctx: ^Context) -> Vec2 ---;
	widget_width          :: proc(ctx: ^Context) -> f32 ---;
	widget_height         :: proc(ctx: ^Context) -> f32 ---;
	widget_is_hovered     :: proc(ctx: ^Context) -> nk_bool ---;
	widget_is_mouse_clicked :: proc(ctx: ^Context, btn: nk_buttons) -> nk_bool ---;
	widget_has_mouse_click_down :: proc(ctx: ^Context, btn: nk_buttons, down: nk_bool) -> nk_bool ---;
	spacing               :: proc(ctx: ^Context, cols: c.int) ---;
	widget_disable_begin  :: proc(ctx: ^Context) ---;
	widget_disable_end    :: proc(ctx: ^Context) ---;
}


/* =============================================================================
*
*                                  TEXT
*
* ============================================================================= */

Text_align :: enum u32 {
	NK_TEXT_ALIGN_LEFT		= 0x01,
	NK_TEXT_ALIGN_CENTERED	= 0x02,
	NK_TEXT_ALIGN_RIGHT		= 0x04,
	NK_TEXT_ALIGN_TOP		= 0x08,
	NK_TEXT_ALIGN_MIDDLE	= 0x10,
	NK_TEXT_ALIGN_BOTTOM	= 0x20,
}

Text_alignment :: enum u32 {
	TEXT_LEFT		= cast(u32)Text_align.NK_TEXT_ALIGN_MIDDLE | cast(u32)Text_align.NK_TEXT_ALIGN_LEFT,
	TEXT_CENTERED	= cast(u32)Text_align.NK_TEXT_ALIGN_MIDDLE | cast(u32)Text_align.NK_TEXT_ALIGN_CENTERED,
	TEXT_RIGHT		= cast(u32)Text_align.NK_TEXT_ALIGN_MIDDLE | cast(u32)Text_align.NK_TEXT_ALIGN_RIGHT,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	text					:: proc(ctx: ^Context, str: cstring, len: c.int, flags: nk_flags) ---;
	text_colored			:: proc(ctx: ^Context, str: cstring, len: c.int, flags: nk_flags, color: Color) ---;
	text_wrap				:: proc(ctx: ^Context, str: cstring, len: c.int) ---;
	text_wrap_colored		:: proc(ctx: ^Context, str: cstring, len: c.int, color: Color) ---;
	label					:: proc(ctx: ^Context, str: cstring, align: Text_alignment) ---;
	label_colored			:: proc(ctx: ^Context, str: cstring, align: nk_flags, color: Color) ---;
	label_wrap				:: proc(ctx: ^Context, str: cstring) ---;
	label_colored_wrap		:: proc(ctx: ^Context, str: cstring, color: Color) ---;
	image					:: proc(ctx: ^Context, img: Image) ---;
	image_color				:: proc(ctx: ^Context, img: Image, color: Color) ---;
}



/* =============================================================================
*
*                                  BUTTON
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	button_text					:: proc(ctx: ^Context, title: cstring, len: c.int) -> nk_bool ---;
	button_label				:: proc(ctx: ^Context, title: cstring) -> nk_bool ---;
	button_color				:: proc(ctx: ^Context, color: Color) -> nk_bool ---;
	button_symbol				:: proc(ctx: ^Context, symbol: Symbol_type) -> nk_bool ---;
	button_image				:: proc(ctx: ^Context, img: Image) -> nk_bool ---;
	button_symbol_label			:: proc(ctx: ^Context, symbol: Symbol_type, title: cstring, text_alignment: nk_flags) -> nk_bool ---;
	button_symbol_text			:: proc(ctx: ^Context, symbol: Symbol_type, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	button_image_label			:: proc(ctx: ^Context, img: Image, title: cstring, text_alignment: nk_flags) -> nk_bool ---;
	button_image_text			:: proc(ctx: ^Context, img: Image, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	button_text_styled			:: proc(ctx: ^Context, style: ^Style_button, title: cstring, len: c.int) -> nk_bool ---;
	button_label_styled			:: proc(ctx: ^Context, style: ^Style_button, title: cstring) -> nk_bool ---;
	button_symbol_styled		:: proc(ctx: ^Context, style: ^Style_button, symbol: Symbol_type) -> nk_bool ---;
	button_image_styled			:: proc(ctx: ^Context, style: ^Style_button, img: Image) -> nk_bool ---;
	button_symbol_text_styled	:: proc(ctx: ^Context, style: ^Style_button, symbol: Symbol_type, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	button_symbol_label_styled	:: proc(ctx: ^Context, style: ^Style_button, symbol: Symbol_type, title: cstring, align: nk_flags) -> nk_bool ---;
	button_image_label_styled	:: proc(ctx: ^Context, style: ^Style_button, img: Image, title: cstring, text_alignment: nk_flags) -> nk_bool ---;
	button_image_text_styled	:: proc(ctx: ^Context, style: ^Style_button, img: Image, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	button_set_behavior			:: proc(ctx: ^Context, behavior: Button_behavior) ---;
	button_push_behavior		:: proc(ctx: ^Context, behavior: Button_behavior) -> nk_bool ---;
	button_pop_behavior			:: proc(ctx: ^Context) -> nk_bool ---;
}

/* =============================================================================
*
*                                  CHECKBOX
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	check_label				:: proc(ctx: ^Context, label: cstring, active: nk_bool) -> nk_bool ---;
	check_text				:: proc(ctx: ^Context, text: cstring, len: c.int, active: nk_bool) -> nk_bool ---;
	check_text_align		:: proc(ctx: ^Context, text: cstring, len: c.int, active: nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
	check_flags_label		:: proc(ctx: ^Context, label: cstring, flags: c.uint, value: c.uint) -> c.uint ---;
	check_flags_text		:: proc(ctx: ^Context, text: cstring, len: c.int, flags: c.uint, value: c.uint) -> c.uint ---;
	checkbox_label			:: proc(ctx: ^Context, label: cstring, active: ^nk_bool) -> nk_bool ---;
	checkbox_label_align	:: proc(ctx: ^Context, label: cstring, active: ^nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
	checkbox_text			:: proc(ctx: ^Context, text: cstring, len: c.int, active: ^nk_bool) -> nk_bool ---;
	checkbox_text_align		:: proc(ctx: ^Context, text: cstring, len: c.int, active: ^nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
	checkbox_flags_label	:: proc(ctx: ^Context, label: cstring, flags: ^c.uint, value: c.uint) -> nk_bool ---;
	checkbox_flags_text		:: proc(ctx: ^Context, text: cstring, len: c.int, flags: ^c.uint, value: c.uint) -> nk_bool ---;
}

/* =============================================================================
*
*                                  RADIO BUTTON
*
* ============================================================================= */

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	radio_label			:: proc(ctx: ^Context, label: cstring, active: ^nk_bool) -> nk_bool ---;
	radio_label_align	:: proc(ctx: ^Context, label: cstring, active: ^nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
	radio_text			:: proc(ctx: ^Context, text: cstring, len: c.int, active: ^nk_bool) -> nk_bool ---;
	radio_text_align	:: proc(ctx: ^Context, text: cstring, len: c.int, active: ^nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
	option_label		:: proc(ctx: ^Context, label: cstring, active: nk_bool) -> nk_bool ---;
	option_label_align	:: proc(ctx: ^Context, label: cstring, active: nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
	option_text			:: proc(ctx: ^Context, text: cstring, len: c.int, active: nk_bool) -> nk_bool ---;
	option_text_align	:: proc(ctx: ^Context, text: cstring, len: c.int, is_active: nk_bool, widget_alignment: nk_flags, text_alignment: nk_flags) -> nk_bool ---;
}

/* =============================================================================
*
*                                  SELECTABLE
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	selectable_label			:: proc(ctx: ^Context, label: cstring, align: nk_flags, value: ^nk_bool) -> nk_bool ---;
	selectable_text				:: proc(ctx: ^Context, text: cstring, len: c.int, align: nk_flags, value: ^nk_bool) -> nk_bool ---;
	selectable_image_label		:: proc(ctx: ^Context, img: Image, label: cstring, align: nk_flags, value: ^nk_bool) -> nk_bool ---;
	selectable_image_text		:: proc(ctx: ^Context, img: Image, text: cstring, len: c.int, align: nk_flags, value: ^nk_bool) -> nk_bool ---;
	selectable_symbol_label		:: proc(ctx: ^Context, symbol: Symbol_type, label: cstring, align: nk_flags, value: ^nk_bool) -> nk_bool ---;
	selectable_symbol_text		:: proc(ctx: ^Context, symbol: Symbol_type, text: cstring, len: c.int, align: nk_flags, value: ^nk_bool) -> nk_bool ---;

	select_label				:: proc(ctx: ^Context, label: cstring, align: nk_flags, value: nk_bool) -> nk_bool ---;
	select_text					:: proc(ctx: ^Context, text: cstring, len: c.int, align: nk_flags, value: nk_bool) -> nk_bool ---;
	select_image_label			:: proc(ctx: ^Context, img: Image, label: cstring, align: nk_flags, value: nk_bool) -> nk_bool ---;
	select_image_text			:: proc(ctx: ^Context, img: Image, text: cstring, len: c.int, align: nk_flags, value: nk_bool) -> nk_bool ---;
	select_symbol_label			:: proc(ctx: ^Context, symbol: Symbol_type, label: cstring, align: nk_flags, value: nk_bool) -> nk_bool ---;
	select_symbol_text			:: proc(ctx: ^Context, symbol: Symbol_type, text: cstring, len: c.int, align: nk_flags, value: nk_bool) -> nk_bool ---;
}

/* =============================================================================
*
*                                  SLIDER
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	slide_float		:: proc(ctx: ^Context, min: f32, val: f32, max: f32, step: f32) -> f32 ---;
	slide_int		:: proc(ctx: ^Context, min: c.int, val: c.int, max: c.int, step: c.int) -> c.int ---;
	slider_float	:: proc(ctx: ^Context, min: f32, val: ^f32, max: f32, step: f32) -> nk_bool ---;
	slider_int		:: proc(ctx: ^Context, min: c.int, val: ^c.int, max: c.int, step: c.int) -> nk_bool ---;
}

/* =============================================================================
*
*                                   KNOB
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	knob_float	:: proc(ctx: ^Context, min: f32, val: ^f32, max: f32, step: f32, zero_direction: nk_heading, dead_zone_degrees: f32) -> nk_bool ---;
	knob_int	:: proc(ctx: ^Context, min: c.int, val: ^c.int, max: c.int, step: c.int, zero_direction: nk_heading, dead_zone_degrees: f32) -> nk_bool ---;
}

/* =============================================================================
*
*                                  PROGRESSBAR
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	progress	:: proc(ctx: ^Context, cur: ^nk_size, max: nk_size, modifiable: nk_bool) -> nk_bool ---;
	prog		:: proc(ctx: ^Context, cur: nk_size, max: nk_size, modifiable: nk_bool) -> nk_size ---;
}

/* =============================================================================
*
*                                  COLOR PICKER
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	color_picker	:: proc(ctx: ^Context, col: ColorF, fmt: nk_color_format) -> ColorF ---;
	color_pick		:: proc(ctx: ^Context, col: ^ColorF, fmt: nk_color_format) -> nk_bool ---;
}


/* =============================================================================
*
*                                  TEXT EDIT
*
* ============================================================================= */

nk_edit_flags :: enum u32 {
	NK_EDIT_DEFAULT					= 0,
	NK_EDIT_READ_ONLY				= 1 << 0,
	NK_EDIT_AUTO_SELECT				= 1 << 1,
	NK_EDIT_SIG_ENTER				= 1 << 2,
	NK_EDIT_ALLOW_TAB				= 1 << 3,
	NK_EDIT_NO_CURSOR				= 1 << 4,
	NK_EDIT_SELECTABLE				= 1 << 5,
	NK_EDIT_CLIPBOARD				= 1 << 6,
	NK_EDIT_CTRL_ENTER_NEWLINE		= 1 << 7,
	NK_EDIT_NO_HORIZONTAL_SCROLL	= 1 << 8,
	NK_EDIT_ALWAYS_INSERT_MODE		= 1 << 9,
	NK_EDIT_MULTILINE				= 1 << 10,
	NK_EDIT_GOTO_END_ON_ACTIVATE	= 1 << 11,
}

nk_edit_types :: enum u32 {
	NK_EDIT_SIMPLE	= cast(nk_flags)nk_edit_flags.NK_EDIT_ALWAYS_INSERT_MODE,
	NK_EDIT_FIELD	= cast(nk_flags)NK_EDIT_SIMPLE | cast(nk_flags)nk_edit_flags.NK_EDIT_SELECTABLE | cast(nk_flags)nk_edit_flags.NK_EDIT_CLIPBOARD,
	NK_EDIT_BOX		= cast(nk_flags)nk_edit_flags.NK_EDIT_ALWAYS_INSERT_MODE | cast(nk_flags)nk_edit_flags.NK_EDIT_SELECTABLE | cast(nk_flags)nk_edit_flags.NK_EDIT_MULTILINE | cast(nk_flags)nk_edit_flags.NK_EDIT_ALLOW_TAB | cast(nk_flags)nk_edit_flags.NK_EDIT_CLIPBOARD,
	NK_EDIT_EDITOR	= cast(nk_flags)nk_edit_flags.NK_EDIT_SELECTABLE | cast(nk_flags)nk_edit_flags.NK_EDIT_MULTILINE | cast(nk_flags)nk_edit_flags.NK_EDIT_ALLOW_TAB | cast(nk_flags)nk_edit_flags.NK_EDIT_CLIPBOARD,
}

nk_edit_events :: enum u32 {
	NK_EDIT_ACTIVE		= 1 << 0, // edit widget is currently being modified
	NK_EDIT_INACTIVE	= 1 << 1, // edit widget is not active and is not being modified
	NK_EDIT_ACTIVATED	= 1 << 2, // edit widget went from state inactive to state active
	NK_EDIT_DEACTIVATED	= 1 << 3, // edit widget went from state active to state inactive
	NK_EDIT_COMMITED	= 1 << 4, // edit widget has received an enter and lost focus
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	edit_string					:: proc(ctx: ^Context, flags: nk_flags, buffer: ^c.char, len: ^c.int, max: c.int, filter: nk_plugin_filter) -> nk_flags ---;
	edit_string_zero_terminated	:: proc(ctx: ^Context, flags: nk_flags, buffer: ^c.char, max: c.int, filter: nk_plugin_filter) -> nk_flags ---;
	edit_buffer					:: proc(ctx: ^Context, flags: nk_flags, edit: ^Text_edit, filter: nk_plugin_filter) -> nk_flags ---;
	edit_focus					:: proc(ctx: ^Context, flags: nk_flags) ---;
	edit_unfocus				:: proc(ctx: ^Context) ---;
}


/* =============================================================================
*
*                                  CHART
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	chart_begin				:: proc(ctx: ^Context, typ: nk_chart_type, num: c.int, min: f32, max: f32) -> nk_bool ---;
	chart_begin_colored		:: proc(ctx: ^Context, typ: nk_chart_type, color: Color, active: Color, num: c.int, min: f32, max: f32) -> nk_bool ---;
	chart_add_slot			:: proc(ctx: ^Context, typ: nk_chart_type, count: c.int, min_value: f32, max_value: f32) ---;
	chart_add_slot_colored	:: proc(ctx: ^Context, typ: nk_chart_type, color: Color, active: Color, count: c.int, min_value: f32, max_value: f32) ---;
	chart_push				:: proc(ctx: ^Context, value: f32) -> nk_flags ---;
	chart_push_slot			:: proc(ctx: ^Context, value: f32, slot: c.int) -> nk_flags ---;
	chart_end				:: proc(ctx: ^Context) ---;
	plot					:: proc(ctx: ^Context, typ: nk_chart_type, values: ^f32, count: c.int, offset: c.int) ---;
	plot_function			:: proc(ctx: ^Context, typ: nk_chart_type, userdata: rawptr, value_getter: proc(user: rawptr, index: c.int) -> f32, count: c.int, offset: c.int) ---;
}

/* =============================================================================
*
*                                  POPUP
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	// POPUP
	popup_begin			:: proc(ctx: ^Context, typ: nk_popup_type, title: cstring, flags: nk_flags, bounds: Rect) -> nk_bool ---;
	popup_close			:: proc(ctx: ^Context) ---;
	popup_end			:: proc(ctx: ^Context) ---;
	popup_get_scroll	:: proc(ctx: ^Context, offset_x: ^nk_uint, offset_y: ^nk_uint) ---;
	popup_set_scroll	:: proc(ctx: ^Context, offset_x: nk_uint, offset_y: nk_uint) ---;

}

/* =============================================================================
*
*                                  COMBOBOX
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	// COMBOBOX
	combo					:: proc(ctx: ^Context, items: ^^cstring, count: c.int, selected: c.int, item_height: c.int, size: Vec2) -> c.int ---;
	combo_separator			:: proc(ctx: ^Context, items: cstring, separator: c.int, selected: c.int, count: c.int, item_height: c.int, size: Vec2) -> c.int ---;
	combo_string			:: proc(ctx: ^Context, items: cstring, selected: c.int, count: c.int, item_height: c.int, size: Vec2) -> c.int ---;
	combo_callback			:: proc(ctx: ^Context, item_getter: proc(userdata: rawptr, index: c.int, out: ^^cstring), userdata: rawptr, selected: c.int, count: c.int, item_height: c.int, size: Vec2) -> c.int ---;
	combobox				:: proc(ctx: ^Context, items: ^^cstring, count: c.int, selected: ^c.int, item_height: c.int, size: Vec2) ---;
	combobox_string			:: proc(ctx: ^Context, items: cstring, selected: ^c.int, count: c.int, item_height: c.int, size: Vec2) ---;
	combobox_separator		:: proc(ctx: ^Context, items: cstring, separator: c.int, selected: ^c.int, count: c.int, item_height: c.int, size: Vec2) ---;
	combobox_callback		:: proc(ctx: ^Context, item_getter: proc(userdata: rawptr, index: c.int, out: ^^cstring), userdata: rawptr, selected: ^c.int, count: c.int, item_height: c.int, size: Vec2) ---;
}

/* =============================================================================
*
*                                  ABSTRACT COMBOBOX
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	combo_begin_text			:: proc(ctx: ^Context, selected: cstring, len: c.int, size: Vec2) -> nk_bool ---;
	combo_begin_label			:: proc(ctx: ^Context, selected: cstring, size: Vec2) -> nk_bool ---;
	combo_begin_color			:: proc(ctx: ^Context, color: Color, size: Vec2) -> nk_bool ---;
	combo_begin_symbol			:: proc(ctx: ^Context, symbol: Symbol_type, size: Vec2) -> nk_bool ---;
	combo_begin_symbol_label		:: proc(ctx: ^Context, selected: cstring, symbol: Symbol_type, size: Vec2) -> nk_bool ---;
	combo_begin_symbol_text		:: proc(ctx: ^Context, selected: cstring, len: c.int, symbol: Symbol_type, size: Vec2) -> nk_bool ---;
	combo_begin_image			:: proc(ctx: ^Context, img: Image, size: Vec2) -> nk_bool ---;
	combo_begin_image_label		:: proc(ctx: ^Context, selected: cstring, img: Image, size: Vec2) -> nk_bool ---;
	combo_begin_image_text		:: proc(ctx: ^Context, selected: cstring, len: c.int, img: Image, size: Vec2) -> nk_bool ---;
	combo_item_label				:: proc(ctx: ^Context, label: cstring, alignment: nk_flags) -> nk_bool ---;
	combo_item_text				:: proc(ctx: ^Context, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	combo_item_image_label		:: proc(ctx: ^Context, img: Image, label: cstring, alignment: nk_flags) -> nk_bool ---;
	combo_item_image_text		:: proc(ctx: ^Context, img: Image, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	combo_item_symbol_label		:: proc(ctx: ^Context, symbol: Symbol_type, label: cstring, alignment: nk_flags) -> nk_bool ---;
	combo_item_symbol_text		:: proc(ctx: ^Context, symbol: Symbol_type, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	combo_close					:: proc(ctx: ^Context) ---;
	combo_end					:: proc(ctx: ^Context) ---;
}

/* =============================================================================
*
*                                  CONTEXTUAL
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	contextual_begin				:: proc(ctx: ^Context, flags: nk_flags, size: Vec2, trigger_bounds: Rect) -> nk_bool ---;
	contextual_item_text			:: proc(ctx: ^Context, text: cstring, len: c.int, align: nk_flags) -> nk_bool ---;
	contextual_item_label			:: proc(ctx: ^Context, label: cstring, align: nk_flags) -> nk_bool ---;
	contextual_item_image_label		:: proc(ctx: ^Context, img: Image, label: cstring, alignment: nk_flags) -> nk_bool ---;
	contextual_item_image_text		:: proc(ctx: ^Context, img: Image, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	contextual_item_symbol_label	:: proc(ctx: ^Context, symbol: Symbol_type, label: cstring, alignment: nk_flags) -> nk_bool ---;
	contextual_item_symbol_text		:: proc(ctx: ^Context, symbol: Symbol_type, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	contextual_close				:: proc(ctx: ^Context) ---;
	contextual_end					:: proc(ctx: ^Context) ---;
}

/* =============================================================================
*
*                                  TOOLTIP
*
* ============================================================================= */

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	tooltip				:: proc(ctx: ^Context, text: cstring) ---;
	tooltip_begin		:: proc(ctx: ^Context, width: f32) -> nk_bool ---;
	tooltip_end			:: proc(ctx: ^Context) ---;
}

/* =============================================================================
*
*                                  MENU
*
* ============================================================================= */

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	menubar_begin					:: proc(ctx: ^Context) ---;
	menubar_end						:: proc(ctx: ^Context) ---;
	menu_begin_text					:: proc(ctx: ^Context, title: cstring, title_len: c.int, align: nk_flags, size: Vec2) -> nk_bool ---;
	menu_begin_label				:: proc(ctx: ^Context, label: cstring, align: nk_flags, size: Vec2) -> nk_bool ---;
	menu_begin_image				:: proc(ctx: ^Context, label: cstring, img: Image, size: Vec2) -> nk_bool ---;
	menu_begin_image_text			:: proc(ctx: ^Context, label: cstring, len: c.int, align: nk_flags, img: Image, size: Vec2) -> nk_bool ---;
	menu_begin_image_label			:: proc(ctx: ^Context, label: cstring, align: nk_flags, img: Image, size: Vec2) -> nk_bool ---;
	menu_begin_symbol				:: proc(ctx: ^Context, label: cstring, symbol: Symbol_type, size: Vec2) -> nk_bool ---;
	menu_begin_symbol_text			:: proc(ctx: ^Context, label: cstring, len: c.int, align: nk_flags, symbol: Symbol_type, size: Vec2) -> nk_bool ---;
	menu_begin_symbol_label			:: proc(ctx: ^Context, label: cstring, align: nk_flags, symbol: Symbol_type, size: Vec2) -> nk_bool ---;
	menu_item_text					:: proc(ctx: ^Context, text: cstring, len: c.int, align: nk_flags) -> nk_bool ---;
	menu_item_label					:: proc(ctx: ^Context, label: cstring, alignment: nk_flags) -> nk_bool ---;
	menu_item_image_label			:: proc(ctx: ^Context, img: Image, label: cstring, alignment: nk_flags) -> nk_bool ---;
	menu_item_image_text			:: proc(ctx: ^Context, img: Image, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	menu_item_symbol_text			:: proc(ctx: ^Context, symbol: Symbol_type, text: cstring, len: c.int, alignment: nk_flags) -> nk_bool ---;
	menu_item_symbol_label			:: proc(ctx: ^Context, symbol: Symbol_type, label: cstring, alignment: nk_flags) -> nk_bool ---;
	menu_close						:: proc(ctx: ^Context) ---;
	menu_end						:: proc(ctx: ^Context) ---;
}

/* =============================================================================
*
*                                  STYLE
*
* ============================================================================= */

WIDGET_DISABLED_FACTOR :: 0.5

Style_colors :: enum u32 {
	COLOR_TEXT,
	COLOR_WINDOW,
	COLOR_HEADER,
	COLOR_BORDER,
	COLOR_BUTTON,
	COLOR_BUTTON_HOVER,
	COLOR_BUTTON_ACTIVE,
	COLOR_TOGGLE,
	COLOR_TOGGLE_HOVER,
	COLOR_TOGGLE_CURSOR,
	COLOR_SELECT,
	COLOR_SELECT_ACTIVE,
	COLOR_SLIDER,
	COLOR_SLIDER_CURSOR,
	COLOR_SLIDER_CURSOR_HOVER,
	COLOR_SLIDER_CURSOR_ACTIVE,
	COLOR_PROPERTY,
	COLOR_EDIT,
	COLOR_EDIT_CURSOR,
	COLOR_COMBO,
	COLOR_CHART,
	COLOR_CHART_COLOR,
	COLOR_CHART_COLOR_HIGHLIGHT,
	COLOR_SCROLLBAR,
	COLOR_SCROLLBAR_CURSOR,
	COLOR_SCROLLBAR_CURSOR_HOVER,
	COLOR_SCROLLBAR_CURSOR_ACTIVE,
	COLOR_TAB_HEADER,
	COLOR_KNOB,
	COLOR_KNOB_CURSOR,
	COLOR_KNOB_CURSOR_HOVER,
	COLOR_KNOB_CURSOR_ACTIVE,
};

Style_cursor :: enum u32 {
	CURSOR_ARROW,
	CURSOR_TEXT,
	CURSOR_MOVE,
	CURSOR_RESIZE_VERTICAL,
	CURSOR_RESIZE_HORIZONTAL,
	CURSOR_RESIZE_TOP_LEFT_DOWN_RIGHT,
	CURSOR_RESIZE_TOP_RIGHT_DOWN_LEFT,
};

Color :: [4]u8;
ColorF :: [4]f32;

Vec2 :: struct {x,y : f32};
Vec2i :: struct {x, y : c.short};
Rect :: struct {x,y,w,h : f32};
Recti :: struct {x,y,w,h : c.short};

NK_UTF_SIZE :: 4 /**< describes the number of bytes a glyph consists of*/
Glyph :: [NK_UTF_SIZE]c.char;

Handle :: struct #raw_union {
	ptr : rawptr,
	id : c.int,
}

Image :: struct {
	handle : Handle,
	w, h : nk_ushort,
	region : [4]nk_ushort,
};

Nine_slice :: struct {
	img : Image,
	l, t, r, b : nk_ushort,
};

Cursor :: struct {
	img : Image,
	size, offset : Vec2,
};

Scroll :: struct {
	x, y : nk_uint,
};

nk_heading         :: enum u32 {
	NK_UP,
	NK_RIGHT, 
	NK_DOWN, 
	NK_LEFT
};

Button_behavior :: enum u32 {
	NK_BUTTON_DEFAULT, 
	NK_BUTTON_REPEATER
};

nk_modify          :: enum u32 {
	NK_FIXED = auto_cast NK_FLASE_TRUE.nk_false,
	NK_MODIFIABLE = auto_cast NK_FLASE_TRUE.nk_true,
};

nk_orientation     :: enum u32 {
	NK_VERTICAL,
	NK_HORIZONTAL
};
	
nk_collapse_states :: enum u32 {
	NK_MINIMIZED = auto_cast NK_FLASE_TRUE.nk_false,
	NK_MAXIMIZED = auto_cast NK_FLASE_TRUE.nk_true,
};
	
nk_show_states     :: enum u32 {
	NK_HIDDEN = auto_cast NK_FLASE_TRUE.nk_false,
	NK_SHOWN = auto_cast NK_FLASE_TRUE.nk_true
};
	
nk_chart_type      :: enum u32 {
	NK_CHART_LINES, 
	NK_CHART_COLUMN, 
};

nk_chart_event     :: enum u32 {
	NK_CHART_HOVERING = 0x01,
	NK_CHART_CLICKED = 0x02
};

nk_color_format    :: enum u32 {
	NK_RGB, NK_RGBA
};

nk_popup_type      :: enum u32 {
	NK_POPUP_STATIC,
	NK_POPUP_DYNAMIC
};
	
nk_layout_format   :: enum u32 {
	NK_DYNAMIC, 
	NK_STATIC
};

Tree_type       :: enum u32 {
	NK_TREE_NODE,
	NK_TREE_TAB
};

nk_plugin_alloc :: #type proc "c" (h: Handle, old: rawptr, size: nk_size) -> rawptr
nk_plugin_free :: #type proc "c"  (h: Handle, old: rawptr)
nk_plugin_filter :: #type proc "c" (edit: ^Text_edit, unicode: nk_rune) -> nk_bool
nk_plugin_paste :: #type proc "c" (h: Handle, edit: ^Text_edit)
nk_plugin_copy :: #type proc "c" (h: Handle, str: ^c.char, len: c.int)

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	style_default             :: proc(ctx: ^Context) ---
	style_from_table          :: proc(ctx: ^Context, table: ^Color) ---
	style_load_cursor         :: proc(ctx: ^Context, cursor: Style_cursor, data: ^Cursor) ---
	style_load_all_cursors    :: proc(ctx: ^Context, cursors: ^Cursor) ---
	style_get_color_by_name   :: proc(name: Style_colors) -> cstring ---
	style_set_font            :: proc(ctx: ^Context, font: User_font) ---
	style_set_cursor          :: proc(ctx: ^Context, cursor: Style_cursor) -> bool ---
	style_show_cursor         :: proc(ctx: ^Context) ---
	style_hide_cursor         :: proc(ctx: ^Context) ---
	
	style_push_font           :: proc(ctx: ^Context, font: User_font) -> bool ---
	style_push_float          :: proc(ctx: ^Context, ptr: ^f32, val: f32) -> bool ---
	style_push_vec2           :: proc(ctx: ^Context, ptr: ^Vec2, val: Vec2) -> bool ---
	style_push_style_item     :: proc(ctx: ^Context, ptr: ^Style_item, val: Style_item) -> bool ---
	style_push_flags          :: proc(ctx: ^Context, ptr: ^nk_flags, val: nk_flags) -> bool ---
	style_push_color          :: proc(ctx: ^Context, ptr: ^Color, val: Color) -> bool ---

	style_pop_font            :: proc(ctx: ^Context) -> bool ---
	style_pop_float           :: proc(ctx: ^Context) -> bool ---
	style_pop_vec2            :: proc(ctx: ^Context) -> bool ---
	style_pop_style_item      :: proc(ctx: ^Context) -> bool ---
	style_pop_flags           :: proc(ctx: ^Context) -> bool ---
	style_pop_color           :: proc(ctx: ^Context) -> bool ---
	
	/* =============================================================================
	*
	*                                  COLOR
	*
	* ============================================================================= */
	rgb              :: proc(r: c.int, g: c.int, b: c.int) -> Color ---
	rgb_iv           :: proc(rgb: ^int) -> Color ---
	rgb_bv           :: proc(rgb: ^u8) -> Color ---
	rgb_f            :: proc(r: f32, g: f32, b: f32) -> Color ---
	rgb_fv           :: proc(rgb: ^f32) -> Color ---
	rgb_cf           :: proc(c: ColorF) -> Color ---
	rgb_hex          :: proc(rgb: cstring) -> Color ---
	rgb_factor       :: proc(col: Color, factor: f32) -> Color ---

	rgba             :: proc(r: c.int, g: c.int, b: c.int, a: c.int) -> Color ---
	rgba_u32         :: proc(v: u32) -> Color ---
	rgba_iv          :: proc(rgba: ^int) -> Color ---
	rgba_bv          :: proc(rgba: ^u8) -> Color ---
	rgba_f           :: proc(r: f32, g: f32, b: f32, a: f32) -> Color ---
	rgba_fv          :: proc(rgba: ^f32) -> Color ---
	rgba_cf          :: proc(c: ColorF) -> Color ---
	rgba_hex         :: proc(rgb: cstring) -> Color ---

	hsva_colorf      :: proc(h: f32, s: f32, v: f32, a: f32) -> ColorF ---
	hsva_colorfv     :: proc(c: ^f32) -> ColorF ---
	colorf_hsva_f    :: proc(out_h, out_s, out_v, out_a: ^f32, input: ColorF) ---
	colorf_hsva_fv   :: proc(hsva: ^f32, input: ColorF) ---

	hsv              :: proc(h: c.int, s: c.int, v: c.int) -> Color ---
	hsv_iv           :: proc(hsv: ^int) -> Color ---
	hsv_bv           :: proc(hsv: ^u8) -> Color ---
	hsv_f            :: proc(h: f32, s: f32, v: f32) -> Color ---
	hsv_fv           :: proc(hsv: ^f32) -> Color ---

	hsva             :: proc(h: c.int, s: c.int, v: c.int, a: c.int) -> Color ---
	hsva_iv          :: proc(hsva: ^int) -> Color ---
	hsva_bv          :: proc(hsva: ^u8) -> Color ---
	hsva_f           :: proc(h: f32, s: f32, v: f32, a: f32) -> Color ---
	hsva_fv          :: proc(hsva: ^f32) -> Color ---
	
	/* color (conversion nuklear --> user) */
	color_f        :: proc(r, g, b, a: ^f32, c: Color) ---
	color_fv       :: proc(rgba_out: ^f32, c: Color) ---
	color_cf       :: proc(c: Color) -> ColorF ---
	color_d        :: proc(r, g, b, a: ^f64, c: Color) ---
	color_dv       :: proc(rgba_out: ^f64, c: Color) ---

	color_u32      :: proc(c: Color) -> u32 ---
	color_hex_rgba :: proc(output: ^u8, c: Color) ---
	color_hex_rgb  :: proc(output: ^u8, c: Color) ---

	color_hsv_i    :: proc(out_h, out_s, out_v: ^int, c: Color) ---
	color_hsv_b    :: proc(out_h, out_s, out_v: ^u8, c: Color) ---
	color_hsv_iv   :: proc(hsv_out: ^int, c: Color) ---
	color_hsv_bv   :: proc(hsv_out: ^u8, c: Color) ---
	color_hsv_f    :: proc(out_h, out_s, out_v: ^f32, c: Color) ---
	color_hsv_fv   :: proc(hsv_out: ^f32, c: Color) ---

	color_hsva_i   :: proc(h, s, v, a: ^int, c: Color) ---
	color_hsva_b   :: proc(h, s, v, a: ^u8, c: Color) ---
	color_hsva_iv  :: proc(hsva_out: ^int, c: Color) ---
	color_hsva_bv  :: proc(hsva_out: ^u8, c: Color) ---
	color_hsva_f   :: proc(out_h, out_s, out_v, out_a: ^f32, c: Color) ---
	color_hsva_fv  :: proc(hsva_out: ^f32, c: Color) ---

	
	/* =============================================================================
	*
	*                                  IMAGE
	*
	* ============================================================================= */
	handle_ptr           :: proc(p: rawptr) -> Handle ---
	handle_id            :: proc(id: c.int) -> Handle ---

	image_handle         :: proc(h: Handle) -> Image ---
	image_ptr            :: proc(p: rawptr) -> Image ---
	image_id             :: proc(id: c.int) -> Image ---

	image_is_subimage    :: proc(img: ^Image) -> bool ---

	subimage_ptr         :: proc(p: rawptr, w, h: u16, sub_region: Rect) -> Image ---
	subimage_id          :: proc(id: c.int, w, h: u16, sub_region: Rect) -> Image ---
	subimage_handle      :: proc(handle : Handle, w : u16, h : u16, sub_region: Rect) -> Image ---

	
	/* =============================================================================
	*
	*                                  9-SLICE
	*
	* ============================================================================= */
	nine_slice_handle :: proc(h: Handle, l, t, r, b: u16) -> Nine_slice ---
	nine_slice_ptr    :: proc(p: rawptr, l, t, r, b: u16) -> Nine_slice ---
	nine_slice_id     :: proc(id: c.int, l, t, r, b: u16) -> Nine_slice ---

	nine_slice_is_sub9slice :: proc(img: ^Nine_slice) -> c.int ---

	sub9slice_ptr    :: proc(p: rawptr, w, h: u16, sub_region: Rect, l, t, r, b: u16) -> Nine_slice ---
	sub9slice_id     :: proc(id: c.int, w, h: u16, sub_region: Rect, l, t, r, b: u16) -> Nine_slice ---
	sub9slice_handle :: proc(handle : Handle, w : u16, h: u16, sub_region: Rect, l, t, r, b: u16) -> Nine_slice ---

	
	/* =============================================================================
	*
	*                                  MATH
	*
	* ============================================================================= */
	murmur_hash :: proc(key: rawptr, len: c.int, seed: nk_hash) -> nk_hash ---
	
	triangle_from_direction :: proc(result: ^Vec2, r: Rect, pad_x, pad_y: f32, dir: nk_heading) ---

	vec2   :: proc(x, y: f32) -> Vec2 ---
	vec2i  :: proc(x, y: c.int) -> Vec2 ---
	vec2v  :: proc(xy: ^f32) -> Vec2 ---
	vec2iv :: proc(xy: ^int) -> Vec2 ---

	get_null_rect :: proc() -> Rect ---

	rect   :: proc(x, y, w, h: f32) -> Rect ---
	recti  :: proc(x, y, w, h: c.int) -> Rect ---
	recta  :: proc(pos, size: Vec2) -> Rect ---
	rectv  :: proc(xywh: ^f32) -> Rect ---
	rectiv :: proc(xywh: ^int) -> Rect ---

	rect_pos  :: proc(r: Rect) -> Vec2 ---
	rect_size :: proc(r: Rect) -> Vec2 ---

	
	/* =============================================================================
	*
	*                                  STRING
	*
	* ============================================================================= */
	strlen :: proc(str: ^c.char) -> c.int ---
	stricmp :: proc(s1, s2: ^c.char) -> c.int ---
	stricmpn :: proc(s1, s2: ^c.char, n: c.int) -> c.int ---
	strtoi :: proc(str: ^c.char, endptr: ^^c.char) -> c.int ---
	strtof :: proc(str: ^c.char, endptr: ^^c.char) -> f32 ---

	// nk_strtod only if not defined
	strtod :: proc(str: ^c.char, endptr: ^^c.char) -> f64 ---

	strfilter :: proc(text, regexp: ^c.char) -> c.int ---
	strmatch_fuzzy_string :: proc(str, pattern: ^c.char, out_score: ^c.int) -> c.int ---
	strmatch_fuzzy_text :: proc(txt: ^c.char, txt_len: c.int, pattern: ^c.char, out_score: ^int) -> c.int ---


	/* =============================================================================
	*
	*                                  UTF-8
	*
	* ============================================================================= */
	utf_decode :: proc(src: ^c.char, unicode: ^nk_rune, byte_len: c.int) -> c.int ---
	utf_encode :: proc(codepoint: nk_rune, dst: ^c.char, byte_len: c.int) -> c.int ---
	utf_len :: proc(src: ^c.char, byte_len: c.int) -> c.int ---
	utf_at :: proc(buffer: ^c.char, length: c.int, index: c.int, unicode: ^nk_rune, len: ^int) -> ^c.char ---
}



/* ===============================================================
*
*                          FONT
*
* ===============================================================*/

User_font_glyph :: struct {} // Fallback for when glyphs are not included

NK_INCLUDE_VERTEX_BUFFER_OUTPUT :: false;
NK_INCLUDE_SOFTWARE_FONT :: false;

when NK_INCLUDE_VERTEX_BUFFER_OUTPUT || NK_INCLUDE_SOFTWARE_FONT {
	User_font_glyph :: struct {
		uv:       [2]Vec2,
		offset:   Vec2,
		width:    f32,
		height:   f32,
		xadvance: f32,
	}
}

Text_width_f :: #type proc "c" (handle: Handle, h: f32, str: cstring, len: c.int) -> f32
Query_font_glyph_f :: #type proc "c" (handle: Handle, font_height: f32, glyph: ^User_font_glyph, codepoint: nk_rune, next_codepoint: nk_rune);

User_font :: struct {
	userdata : Handle,    /**!< user provided font handle */
	height : f32,          /**!< max height of the font */
	width : Text_width_f, /**!< font string width in pixel callback */
};



/*
/* =============================================================================
*
*                                  STYLE
*
* ============================================================================= */

NK_WIDGET_DISABLED_FACTOR :: 0.5

Style_colors :: enum u32 {
	NK_COLOR_TEXT,
	NK_COLOR_WINDOW,
	NK_COLOR_HEADER,
	NK_COLOR_BORDER,
	NK_COLOR_BUTTON,
	NK_COLOR_BUTTON_HOVER,
	NK_COLOR_BUTTON_ACTIVE,
	NK_COLOR_TOGGLE,
	NK_COLOR_TOGGLE_HOVER,
	NK_COLOR_TOGGLE_CURSOR,
	NK_COLOR_SELECT,
	NK_COLOR_SELECT_ACTIVE,
	NK_COLOR_SLIDER,
	NK_COLOR_SLIDER_CURSOR,
	NK_COLOR_SLIDER_CURSOR_HOVER,
	NK_COLOR_SLIDER_CURSOR_ACTIVE,
	NK_COLOR_PROPERTY,
	NK_COLOR_EDIT,
	NK_COLOR_EDIT_CURSOR,
	NK_COLOR_COMBO,
	NK_COLOR_CHART,
	NK_COLOR_CHART_COLOR,
	NK_COLOR_CHART_COLOR_HIGHLIGHT,
	NK_COLOR_SCROLLBAR,
	NK_COLOR_SCROLLBAR_CURSOR,
	NK_COLOR_SCROLLBAR_CURSOR_HOVER,
	NK_COLOR_SCROLLBAR_CURSOR_ACTIVE,
	NK_COLOR_TAB_HEADER,
	NK_COLOR_KNOB,
	NK_COLOR_KNOB_CURSOR,
	NK_COLOR_KNOB_CURSOR_HOVER,
	NK_COLOR_KNOB_CURSOR_ACTIVE,
}

StyleCursor :: enum u32 {
	NK_CURSOR_ARROW,
	NK_CURSOR_TEXT,
	NK_CURSOR_MOVE,
	NK_CURSOR_RESIZE_VERTICAL,
	NK_CURSOR_RESIZE_HORIZONTAL,
	NK_CURSOR_RESIZE_TOP_LEFT_DOWN_RIGHT,
	NK_CURSOR_RESIZE_TOP_RIGHT_DOWN_LEFT,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	style_default				:: proc(ctx: ^Context) ---;
	style_from_table			:: proc(ctx: ^Context, table: ^Color) ---;
	style_load_cursor			:: proc(ctx: ^Context, cursor: StyleCursor, data: ^Cursor) ---;
	style_load_all_cursors		:: proc(ctx: ^Context, cursors: ^Cursor) ---;
	style_get_color_by_name		:: proc(name: Style_colors) -> cstring ---;
	style_set_font				:: proc(ctx: ^Context, font: User_font) ---;
	style_set_cursor			:: proc(ctx: ^Context, cursor: StyleCursor) -> nk_bool ---;
	style_show_cursor			:: proc(ctx: ^Context) ---;
	style_hide_cursor			:: proc(ctx: ^Context) ---;

	style_push_font				:: proc(ctx: ^Context, font: User_font) -> nk_bool ---;
	style_push_float			:: proc(ctx: ^Context, ptr: ^f32, val: f32) -> nk_bool ---;
	style_push_vec2				:: proc(ctx: ^Context, ptr: ^Vec2, val: Vec2) -> nk_bool ---;
	style_push_style_item		:: proc(ctx: ^Context, ptr: ^Style_item, val: Style_item) -> nk_bool ---;
	style_push_flags			:: proc(ctx: ^Context, ptr: ^nk_flags, val: nk_flags) -> nk_bool ---;
	style_push_color			:: proc(ctx: ^Context, ptr: ^Color, val: Color) -> nk_bool ---;

	style_pop_font				:: proc(ctx: ^Context) -> nk_bool ---;
	style_pop_float				:: proc(ctx: ^Context) -> nk_bool ---;
	style_pop_vec2				:: proc(ctx: ^Context) -> nk_bool ---;
	style_pop_style_item		:: proc(ctx: ^Context) -> nk_bool ---;
	style_pop_flags				:: proc(ctx: ^Context) -> nk_bool ---;
	style_pop_color				:: proc(ctx: ^Context) -> nk_bool ---;
}

/* =============================================================================
*
*                                  COLOR
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	rgb				:: proc(r: c.int, g: c.int, b: c.int) -> Color ---;
	rgb_iv			:: proc(rgb: ^c.int) -> Color ---;
	rgb_bv			:: proc(rgb: ^nk_byte) -> Color ---;
	rgb_f			:: proc(r: f32, g: f32, b: f32) -> Color ---;
	rgb_fv			:: proc(rgb: ^f32) -> Color ---;
	rgb_cf			:: proc(c: ColorF) -> Color ---;
	rgb_hex			:: proc(rgb: cstring) -> Color ---;
	rgb_factor		:: proc(col: Color, factor: f32) -> Color ---;

	rgba			:: proc(r: c.int, g: c.int, b: c.int, a: c.int) -> Color ---;
	rgba_u32		:: proc(v: nk_uint) -> Color ---;
	rgba_iv			:: proc(rgba: ^c.int) -> Color ---;
	rgba_bv			:: proc(rgba: ^nk_byte) -> Color ---;
	rgba_f			:: proc(r: f32, g: f32, b: f32, a: f32) -> Color ---;
	rgba_fv			:: proc(rgba: ^f32) -> Color ---;
	rgba_cf			:: proc(c: ColorF) -> Color ---;
	rgba_hex		:: proc(rgb: cstring) -> Color ---;

	hsva_colorf		:: proc(h: f32, s: f32, v: f32, a: f32) -> ColorF ---;
	hsva_colorfv	:: proc(c: ^f32) -> ColorF ---;
	colorf_hsva_f	:: proc(out_h, out_s, out_v, out_a: ^f32, input: ColorF) ---;
	colorf_hsva_fv	:: proc(hsva: ^f32, input: ColorF) ---;

	hsv				:: proc(h: c.int, s: c.int, v: c.int) -> Color ---;
	hsv_iv			:: proc(hsv: ^c.int) -> Color ---;
	hsv_bv			:: proc(hsv: ^nk_byte) -> Color ---;
	hsv_f			:: proc(h: f32, s: f32, v: f32) -> Color ---;
	hsv_fv			:: proc(hsv: ^f32) -> Color ---;

	hsva			:: proc(h: c.int, s: c.int, v: c.int, a: c.int) -> Color ---;
	hsva_iv			:: proc(hsva: ^c.int) -> Color ---;
	hsva_bv			:: proc(hsva: ^nk_byte) -> Color ---;
	hsva_f			:: proc(h: f32, s: f32, v: f32, a: f32) -> Color ---;
	hsva_fv			:: proc(hsva: ^f32) -> Color ---;

	color_f			:: proc(r, g, b, a: ^f32, c: Color) ---;
	color_fv		:: proc(rgba_out: ^f32, c: Color) ---;
	color_cf		:: proc(c: Color) -> ColorF ---;
	color_d			:: proc(r, g, b, a: ^f64, c: Color) ---;
	color_dv		:: proc(rgba_out: ^f64, c: Color) ---;

	color_u32		:: proc(c: Color) -> nk_uint ---;
	color_hex_rgba	:: proc(output: ^c.char, c: Color) ---;
	color_hex_rgb	:: proc(output: ^c.char, c: Color) ---;

	color_hsv_i		:: proc(out_h, out_s, out_v: ^c.int, c: Color) ---;
	color_hsv_b		:: proc(out_h, out_s, out_v: ^nk_byte, c: Color) ---;
	color_hsv_iv	:: proc(hsv_out: ^c.int, c: Color) ---;
	color_hsv_bv	:: proc(hsv_out: ^nk_byte, c: Color) ---;
	color_hsv_f		:: proc(out_h, out_s, out_v: ^f32, c: Color) ---;
	color_hsv_fv	:: proc(hsv_out: ^f32, c: Color) ---;

	color_hsva_i	:: proc(h, s, v, a: ^c.int, c: Color) ---;
	color_hsva_b	:: proc(h, s, v, a: ^nk_byte, c: Color) ---;
	color_hsva_iv	:: proc(hsva_out: ^c.int, c: Color) ---;
	color_hsva_bv	:: proc(hsva_out: ^nk_byte, c: Color) ---;
	color_hsva_f	:: proc(out_h, out_s, out_v, out_a: ^f32, c: Color) ---;
	color_hsva_fv	:: proc(hsva_out: ^f32, c: Color) ---;
}

/* =============================================================================
*
*                                  IMAGE
*
* ============================================================================= */

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	handle_ptr			:: proc(p: rawptr) -> Handle ---;
	handle_id			:: proc(id: c.int) -> Handle ---;
	image_handle		:: proc(h: Handle) -> Image ---;
	image_ptr			:: proc(p: rawptr) -> Image ---;
	image_id			:: proc(id: c.int) -> Image ---;
	image_is_subimage	:: proc(img: ^Image) -> nk_bool ---;
	subimage_ptr		:: proc(p: rawptr, w: nk_ushort, h: nk_ushort, sub_region: Rect) -> Image ---;
	subimage_id			:: proc(id: c.int, w: nk_ushort, h: nk_ushort, sub_region: Rect) -> Image ---;
	subimage_handle		:: proc(handle: Handle, w: nk_ushort, h: nk_ushort, sub_region: Rect) -> Image ---;
}

/* =============================================================================
*
*                                  9-SLICE
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	nine_slice_handle		:: proc(h: Handle, l, t, r, b: nk_ushort) -> Nine_slice ---;
	nine_slice_ptr			:: proc(p: rawptr, l, t, r, b: nk_ushort) -> Nine_slice ---;
	nine_slice_id			:: proc(id: c.int, l, t, r, b: nk_ushort) -> Nine_slice ---;
	nine_slice_is_sub9slice	:: proc(img: ^Nine_slice) -> c.int ---;
	sub9slice_ptr			:: proc(p: rawptr, w, h: nk_ushort, sub_region: Rect, l, t, r, b: nk_ushort) -> Nine_slice ---;
	sub9slice_id			:: proc(id: c.int, w, h: nk_ushort, sub_region: Rect, l, t, r, b: nk_ushort) -> Nine_slice ---;
	sub9slice_handle		:: proc(h: Handle, w, h_: nk_ushort, sub_region: Rect, l, t, r, b: nk_ushort) -> Nine_slice ---;
}

/* =============================================================================
*
*                                  MATH
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	murmur_hash					:: proc(key: rawptr, len: c.int, seed: nk_hash) -> nk_hash ---;
	triangle_from_direction		:: proc(result: ^Vec2, r: Rect, pad_x: f32, pad_y: f32, dir: nk_heading) ---;

	vec2						:: proc(x: f32, y: f32) -> Vec2 ---;
	vec2i						:: proc(x: c.int, y: c.int) -> Vec2 ---;
	vec2v						:: proc(xy: ^f32) -> Vec2 ---;
	vec2iv						:: proc(xy: ^int) -> Vec2 ---;

	get_null_rect				:: proc() -> Rect ---;
	rect						:: proc(x: f32, y: f32, w: f32, h: f32) -> Rect ---;
	recti						:: proc(x: c.int, y: c.int, w: c.int, h: c.int) -> Rect ---;
	recta						:: proc(pos: Vec2, size: Vec2) -> Rect ---;
	rectv						:: proc(xywh: ^f32) -> Rect ---;
	rectiv						:: proc(xywh: ^int) -> Rect ---;
	rect_pos					:: proc(r: Rect) -> Vec2 ---;
	rect_size					:: proc(r: Rect) -> Vec2 ---;
}

/* =============================================================================
*
*                                  STRING
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	strlen						:: proc(str: ^c.char) -> c.int ---;
	stricmp						:: proc(s1: ^c.char, s2: ^c.char) -> c.int ---;
	stricmpn					:: proc(s1: ^c.char, s2: ^c.char, n: c.int) -> c.int ---;
	strtoi						:: proc(str: ^c.char, endptr: ^^c.char) -> c.int ---;
	strtof						:: proc(str: ^c.char, endptr: ^^c.char) -> f32 ---;
	strtod						:: proc(str: ^c.char, endptr: ^^c.char) -> f64 ---;
	strfilter					:: proc(text: ^c.char, regexp: ^c.char) -> c.int ---;
	strmatch_fuzzy_string		:: proc(str: ^c.char, pattern: ^c.char, out_score: ^c.int) -> c.int ---;
	strmatch_fuzzy_text			:: proc(txt: ^c.char, txt_len: c.int, pattern: ^c.char, out_score: ^c.int) -> c.int ---;
}

/* =============================================================================
*
*                                  UTF-8
*
* ============================================================================= */
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	utf_decode	:: proc(src: ^c.char, unicode: ^nk_rune, byte_len: c.int) -> c.int ---;
	utf_encode	:: proc(codepoint: nk_rune, dst: ^c.char, byte_len: c.int) -> c.int ---;
	utf_len		:: proc(src: ^c.char, byte_len: c.int) -> c.int ---;
	utf_at		:: proc(buffer: ^c.char, length: c.int, index: c.int, unicode: ^nk_rune, len: ^c.int) -> ^c.char ---;
}

*/


/* ===============================================================
*
*                          FONT
*
* ===============================================================*/
/**


Text_width_f :: #type proc "c" (handle: Handle, h: f32, str: cstring, len: c.int) -> f32
Query_font_glyph_f :: #type proc "c" (handle: Handle, font_height: f32, glyph: ^User_font_glyph, codepoint: nk_rune, next_codepoint: nk_rune)

User_font :: struct {
	userdata	: Handle,	// user provided font handle
	height		: f32,		// max height of the font
	width		: Text_width_f, // font string width in pixel callback
}

*/

/** ==============================================================
*
*                          MEMORY BUFFER
*
* ===============================================================*/
Memory_status :: struct {
	memory : rawptr,
	type : u32,
	size : nk_size,
	allocated : nk_size,
	needed : nk_size,
	calls : nk_size,
};

Allocation_type :: enum u32 {
	NK_BUFFER_FIXED,
	NK_BUFFER_DYNAMIC
};

NK_BUFFER_MAX :: len(Buffer_allocation_type);
Buffer_allocation_type :: enum u32 {
	NK_BUFFER_FRONT,
	NK_BUFFER_BACK,
};

Buffer_marker :: struct {
	active : nk_bool,
	offset : nk_size,
};

Memory :: struct {
	ptr : rawptr,
	size : nk_size,
};

Buffer :: struct {
	marker : [NK_BUFFER_MAX]Buffer_marker, 	/**!< buffer marker to free a buffer to a certain offset */
	pool : Allocator,						/**!< allocator callback for dynamic buffers */
	type : Allocation_type, 				/**!< memory management type */
	memory : Memory,						/**!< memory and size of the current memory block */
	grow_factor : f32,						/**!< growing factor for dynamic memory management */
	allocated : nk_size,					/**!< total amount of memory allocated */
	needed : nk_size,						/**!< totally consumed memory given that enough memory is present */
	calls : nk_size,						/**!< number of allocation calls */
	size : nk_size,							/**!< current size of the buffer */
};

nk_buffer_init 			:: #type proc "c" (buf: ^Buffer, alloc: ^Allocator, size: nk_size)
nk_buffer_init_fixed 	:: #type proc "c" (buf: ^Buffer, memory: rawptr, size: nk_size)
nk_buffer_info 			:: #type proc "c" (info: ^Memory_status, buf: ^Buffer)
nk_buffer_push 			:: #type proc "c" (buf: ^Buffer, typ: Memory_status, memory: rawptr, size: nk_size, align: nk_size)
nk_buffer_mark 			:: #type proc "c" (buf: ^Buffer, typ: Memory_status)
nk_buffer_reset 		:: #type proc "c" (buf: ^Buffer, typ: Memory_status)
nk_buffer_clear 		:: #type proc "c" (buf: ^Buffer)
nk_buffer_free 			:: #type proc "c" (buf: ^Buffer)
nk_buffer_memory 		:: #type proc "c" (buf: ^Buffer) -> rawptr
nk_buffer_memory_const 	:: #type proc "c" (buf: ^Buffer) -> rawptr
nk_buffer_total 		:: #type proc "c" (buf: ^Buffer) -> nk_size


/** ==============================================================
*
*                          STRING
*
* ===============================================================*/
/**  Basic string buffer which is only used in context with the text editor
*  to manage and manipulate dynamic or fixed size string content. This is _NOT_
*  the default string handling method. The only instance you should have any contact
*  with this API is if you c.interact with an `nk_text_edit` object inside one of the
*  copy and paste functions and even there only for more advanced cases. */
nk_str :: struct {
	buffer : Buffer,
	len : c.int, /**!< in codepoints/runes/glyphs */
};

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	str_init					:: proc(str: ^nk_str, alloc: ^Allocator, size: nk_size) ---;
	str_init_fixed				:: proc(str: ^nk_str, memory: rawptr, size: nk_size) ---;
	str_clear					:: proc(str: ^nk_str) ---;
	str_free					:: proc(str: ^nk_str) ---;

	str_append_text_char		:: proc(str: ^nk_str, text: cstring, len: c.int) -> c.int ---;
	str_append_str_char			:: proc(str: ^nk_str, text: cstring) -> c.int ---;
	str_append_text_utf8		:: proc(str: ^nk_str, text: cstring, len: c.int) -> c.int ---;
	str_append_str_utf8			:: proc(str: ^nk_str, text: cstring) -> c.int ---;
	str_append_text_runes		:: proc(str: ^nk_str, runes: ^nk_rune, len: c.int) -> c.int ---;
	str_append_str_runes		:: proc(str: ^nk_str, runes: ^nk_rune) -> c.int ---;

	str_insert_at_char			:: proc(str: ^nk_str, pos: c.int, text: cstring, len: c.int) -> c.int ---;
	str_insert_at_rune			:: proc(str: ^nk_str, pos: c.int, text: cstring, len: c.int) -> c.int ---;

	str_insert_text_char		:: proc(str: ^nk_str, pos: c.int, text: cstring, len: c.int) -> c.int ---;
	str_insert_str_char			:: proc(str: ^nk_str, pos: c.int, text: cstring) -> c.int ---;
	str_insert_text_utf8		:: proc(str: ^nk_str, pos: c.int, text: cstring, len: c.int) -> c.int ---;
	str_insert_str_utf8			:: proc(str: ^nk_str, pos: c.int, text: cstring) -> c.int ---;
	str_insert_text_runes		:: proc(str: ^nk_str, pos: c.int, runes: ^nk_rune, len: c.int) -> c.int ---;
	str_insert_str_runes		:: proc(str: ^nk_str, pos: c.int, runes: ^nk_rune) -> c.int ---;
	
	str_remove_chars			:: proc(str: ^nk_str, len: c.int) ---;
	str_remove_runes			:: proc(str: ^nk_str, len: c.int) ---;
	str_delete_chars			:: proc(str: ^nk_str, pos: c.int, len: c.int) ---;
	str_delete_runes			:: proc(str: ^nk_str, pos: c.int, len: c.int) ---;

	str_at_char					:: proc(str: ^nk_str, pos: c.int) -> cstring ---;
	str_at_rune					:: proc(str: ^nk_str, pos: c.int, unicode: ^nk_rune, len: ^c.int) -> cstring ---;
	str_rune_at					:: proc(str: ^nk_str, pos: c.int) -> nk_rune ---;
	str_at_char_const			:: proc(str: ^nk_str, pos: c.int) -> cstring ---;
	str_at_const				:: proc(str: ^nk_str, pos: c.int, unicode: ^nk_rune, len: ^c.int) -> cstring ---;

	str_get						:: proc(str: ^nk_str) -> cstring ---;
	str_get_const				:: proc(str: ^nk_str) -> cstring ---;
	str_len						:: proc(str: ^nk_str) -> c.int ---;
	str_len_char				:: proc(str: ^nk_str) -> c.int ---;
}


/**===============================================================
*
*                      TEXT EDITOR
*
* ===============================================================*/
Clipboard :: struct {
	userdata : Handle,
	paste : nk_plugin_paste,
	copy : nk_plugin_copy,
};

Text_undo_record :: struct {
_where : c.int,
insert_length : c.short,
delete_length : c.short,
char_storage : c.short,
};

NK_TEXTEDIT_UNDOSTATECOUNT :: 99
NK_TEXTEDIT_UNDOCHARCOUNT :: 999

Text_undo_state :: struct {
	undo_rec        : [NK_TEXTEDIT_UNDOSTATECOUNT]Text_undo_record,
	undo_char       : [NK_TEXTEDIT_UNDOCHARCOUNT]nk_rune,
	undo_point      : c.short,
	redo_point      : c.short,
	undo_char_point : c.short,
	redo_char_point : c.short,
}

Text_edit_type :: enum u32 {
	NK_TEXT_EDIT_SINGLE_LINE,
	NK_TEXT_EDIT_MULTI_LINE,
};

Text_edit_mode :: enum u32 {
	NK_TEXT_EDIT_MODE_VIEW,
	NK_TEXT_EDIT_MODE_INSERT,
	NK_TEXT_EDIT_MODE_REPLACE,
};

Text_edit :: struct {
	clip                  : Clipboard,
	string                : nk_str,
	filter                : nk_plugin_filter,
	scrollbar             : Vec2,

	cursor                : c.int,
	select_start          : c.int,
	select_end            : c.int,
	mode                  : u8,
	cursor_at_end_of_line : u8,
	initialized           : u8,
	has_preferred_x       : u8,
	single_line           : u8,
	active                : u8,
	padding1              : u8,
	preferred_x           : f32,
	undo                  : Text_undo_state,
}



@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	/** filter function */
	filter_default :: proc 	(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	filter_ascii :: proc 	(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	filter_float :: proc 	(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	filter_decimal :: proc 	(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	filter_hex :: proc 		(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	filter_oct :: proc 		(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	filter_binary :: proc 	(te : ^Text_edit,	unicode : nk_rune) -> nk_bool ---
	
	/** text editor */
	nk_textedit_init             :: proc(edit: ^Text_edit, alloc: ^Allocator, size: nk_size) ---
	nk_textedit_init_fixed       :: proc(edit: ^Text_edit, memory: rawptr, size: nk_size) ---
	nk_textedit_free             :: proc(edit: ^Text_edit) ---
	nk_textedit_text             :: proc(edit: ^Text_edit, text: cstring, total_len: c.int) ---
	nk_textedit_delete           :: proc(edit: ^Text_edit, _where: c.int, len: c.int) ---
	nk_textedit_delete_selection :: proc(edit: ^Text_edit) ---
	nk_textedit_select_all       :: proc(edit: ^Text_edit) ---
	nk_textedit_cut              :: proc(edit: ^Text_edit) -> nk_bool ---
	nk_textedit_paste            :: proc(edit: ^Text_edit, text: cstring, len: c.int) -> nk_bool ---
	nk_textedit_undo             :: proc(edit: ^Text_edit) ---
	nk_textedit_redo             :: proc(edit: ^Text_edit) ---
}



/* ===============================================================
*
*                          DRAWING
*
* ===============================================================*/


nk_command_type :: enum u32 {
	NK_COMMAND_NOP,
	NK_COMMAND_SCISSOR,
	NK_COMMAND_LINE,
	NK_COMMAND_CURVE,
	NK_COMMAND_RECT,
	NK_COMMAND_RECT_FILLED,
	NK_COMMAND_RECT_MULTI_COLOR,
	NK_COMMAND_CIRCLE,
	NK_COMMAND_CIRCLE_FILLED,
	NK_COMMAND_ARC,
	NK_COMMAND_ARC_FILLED,
	NK_COMMAND_TRIANGLE,
	NK_COMMAND_TRIANGLE_FILLED,
	NK_COMMAND_POLYGON,
	NK_COMMAND_POLYGON_FILLED,
	NK_COMMAND_POLYLINE,
	NK_COMMAND_TEXT,
	NK_COMMAND_IMAGE,
	NK_COMMAND_CUSTOM,
}

nk_command :: struct {
	typ: nk_command_type,
	next: nk_size,
	userdata: Handle, //because of NK_INCLUDE_COMMAND_USERDATA
}

nk_command_scissor :: struct {
	header: nk_command,
	x, y: c.short,
	w, h: nk_ushort,
}

nk_command_line :: struct {
	header: nk_command,
	line_thickness: nk_ushort,
	begin: Vec2i,
	end: Vec2i,
	color: Color,
}

nk_command_curve :: struct {
	header: nk_command,
	line_thickness: nk_ushort,
	begin: Vec2i,
	end: Vec2i,
	ctrl: [2]Vec2i,
	color: Color,
}

nk_command_rect :: struct {
	header: nk_command,
	rounding: nk_ushort,
	line_thickness: nk_ushort,
	x, y: c.short,
	w, h: nk_ushort,
	color: Color,
}

nk_command_rect_filled :: struct {
	header: nk_command,
	rounding: nk_ushort,
	x, y: c.short,
	w, h: nk_ushort,
	color: Color,
}

nk_command_rect_multi_color :: struct {
	header: nk_command,
	x, y: c.short,
	w, h: nk_ushort,
	left: Color,
	top: Color,
	bottom: Color,
	right: Color,
}

nk_command_triangle :: struct {
	header: nk_command,
	line_thickness: nk_ushort,
	a: Vec2i,
	b: Vec2i,
	c: Vec2i,
	color: Color,
}

nk_command_triangle_filled :: struct {
	header: nk_command,
	a: Vec2i,
	b: Vec2i,
	c: Vec2i,
	color: Color,
}

nk_command_circle :: struct {
	header: nk_command,
	x, y: c.short,
	line_thickness: nk_ushort,
	w, h: nk_ushort,
	color: Color,
}

nk_command_circle_filled :: struct {
	header: nk_command,
	x, y: c.short,
	w, h: nk_ushort,
	color: Color,
}

nk_command_arc :: struct {
	header: nk_command,
	cx, cy: c.short,
	r: nk_ushort,
	line_thickness: nk_ushort,
	a: [2]f32,
	color: Color,
}

nk_command_arc_filled :: struct {
	header: nk_command,
	cx, cy: c.short,
	r: nk_ushort,
	a: [2]f32,
	color: Color,
}

nk_command_polygon :: struct {
	header: nk_command,
	color: Color,
	line_thickness: nk_ushort,
	point_count: nk_ushort,
	points: [1]Vec2i, // flexible array, use pointer or slice in actual usage
}

nk_command_polygon_filled :: struct {
	header: nk_command,
	color: Color,
	point_count: nk_ushort,
	points: [1]Vec2i, // flexible array, use pointer or slice in actual usage
}

nk_command_polyline :: struct {
	header: nk_command,
	color: Color,
	line_thickness: nk_ushort,
	point_count: nk_ushort,
	points: [1]Vec2i, // flexible array, use pointer or slice in actual usage
}

nk_command_image :: struct {
	header: nk_command,
	x, y: c.short,
	w, h: nk_ushort,
	img: Image,
	col: Color,
}

nk_command_custom_callback :: #type proc "c" (canvas: rawptr, x: c.short, y: c.short, w: nk_ushort, h: nk_ushort, callback_data: Handle)

nk_command_custom :: struct {
	header: nk_command,
	x, y: c.short,
	w, h: nk_ushort,
	callback_data: Handle,
	callback: nk_command_custom_callback,
}

nk_command_text :: struct {
	header: nk_command,
	font: ^User_font,
	background: Color,
	foreground: Color,
	x, y: c.short,
	w, h: nk_ushort,
	height: f32,
	length: c.int,
	string: [2]c.char, // flexible array, use pointer or slice in actual usage
}

nk_command_clipping :: enum u32 {
	NK_CLIPPING_OFF = 0,
	NK_CLIPPING_ON = 1,
}

Command_buffer :: struct {
	base: ^Buffer,
	clip: Rect,
	use_clipping: c.int,
	userdata: Handle,
	begin, end, last: nk_size,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	// Shape outlines
	stroke_line			:: proc(b: ^Command_buffer, x0, y0, x1, y1: f32, line_thickness: f32, color: Color) ---;
	stroke_curve		:: proc(b: ^Command_buffer, x0, y0, c0x, c0y, c1x, c1y, x1, y1: f32, line_thickness: f32, color: Color) ---;
	stroke_rect			:: proc(b: ^Command_buffer, rect: Rect, rounding: f32, line_thickness: f32, color: Color) ---;
	stroke_circle		:: proc(b: ^Command_buffer, rect: Rect, line_thickness: f32, color: Color) ---;
	stroke_arc			:: proc(b: ^Command_buffer, cx, cy, radius, a_min, a_max, line_thickness: f32, color: Color) ---;
	stroke_triangle		:: proc(b: ^Command_buffer, x0, y0, x1, y1, x2, y2: f32, line_thickness: f32, color: Color) ---;
	stroke_polyline		:: proc(b: ^Command_buffer, points: ^f32, point_count: c.int, line_thickness: f32, color: Color) ---;
	stroke_polygon		:: proc(b: ^Command_buffer, points: ^f32, point_count: c.int, line_thickness: f32, color: Color) ---;

	// Filled shapes
	fill_rect				:: proc(b: ^Command_buffer, rect: Rect, rounding: f32, color: Color) ---;
	fill_rect_multi_color	:: proc(b: ^Command_buffer, rect: Rect, left: Color, top: Color, right: Color, bottom: Color) ---;
	fill_circle				:: proc(b: ^Command_buffer, rect: Rect, color: Color) ---;
	fill_arc				:: proc(b: ^Command_buffer, cx, cy, radius, a_min, a_max: f32, color: Color) ---;
	fill_triangle			:: proc(b: ^Command_buffer, x0, y0, x1, y1, x2, y2: f32, color: Color) ---;
	fill_polygon			:: proc(b: ^Command_buffer, points: ^f32, point_count: c.int, color: Color) ---;

	// Misc
	draw_image			:: proc(b: ^Command_buffer, rect: Rect, img: ^Image, color: Color) ---;
	draw_nine_slice		:: proc(b: ^Command_buffer, rect: Rect, slice: ^Nine_slice, color: Color) ---;
	draw_text			:: proc(b: ^Command_buffer, rect: Rect, text: cstring, len: c.int, font: ^User_font, background: Color, foreground: Color) ---;
	push_scissor		:: proc(b: ^Command_buffer, rect: Rect) ---;
	push_custom			:: proc(b: ^Command_buffer, rect: Rect, callback: nk_command_custom_callback, usr: Handle) ---;
}



/* ===============================================================
*
*                          INPUT
*
* ===============================================================*/

NK_BUTTON_MAX :: len(nk_buttons)
NK_KEY_MAX :: len(nk_keys)
NK_INPUT_MAX :: 16

nk_mouse_button :: struct {
	down:      nk_bool,
	clicked:   nk_uint,
	clicked_pos: Vec2,
}

nk_mouse :: struct {
	buttons:    [NK_BUTTON_MAX]nk_mouse_button,
	pos:        Vec2,
	down_pos: 	Vec2, //Because of NK_BUTTON_TRIGGER_ON_RELEASE
	prev:       Vec2,
	delta:      Vec2,
	scroll_delta: Vec2,
	grab:       u8,
	grabbed:    u8,
	ungrab:     u8,
	// If you use NK_BUTTON_TRIGGER_ON_RELEASE, add:
	// down_pos: Vec2,
}

nk_key :: struct {
	down:    nk_bool,
	clicked: nk_uint,
}

nk_keyboard :: struct {
	keys:     [NK_KEY_MAX]nk_key,
	text:     [NK_INPUT_MAX]c.char,
	text_len: c.int,
}

Input :: struct {
	keyboard: nk_keyboard,
	mouse:    nk_mouse,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	input_has_mouse_click					:: proc(input: ^Input, btn: nk_buttons) -> nk_bool ---;
	input_has_mouse_click_in_rect			:: proc(input: ^Input, btn: nk_buttons, rect: Rect) -> nk_bool ---;
	input_has_mouse_click_in_button_rect	:: proc(input: ^Input, btn: nk_buttons, rect: Rect) -> nk_bool ---;
	input_has_mouse_click_down_in_rect		:: proc(input: ^Input, btn: nk_buttons, rect: Rect, down: nk_bool) -> nk_bool ---;
	input_is_mouse_click_in_rect			:: proc(input: ^Input, btn: nk_buttons, rect: Rect) -> nk_bool ---;
	input_is_mouse_click_down_in_rect		:: proc(input: ^Input, btn: nk_buttons, rect: Rect, down: nk_bool) -> nk_bool ---;
	input_any_mouse_click_in_rect			:: proc(input: ^Input, rect: Rect) -> nk_bool ---;
	input_is_mouse_prev_hovering_rect		:: proc(input: ^Input, rect: Rect) -> nk_bool ---;
	input_is_mouse_hovering_rect			:: proc(input: ^Input, rect: Rect) -> nk_bool ---;
	input_mouse_clicked						:: proc(input: ^Input, btn: nk_buttons, rect: Rect) -> nk_bool ---;
	input_is_mouse_down						:: proc(input: ^Input, btn: nk_buttons) -> nk_bool ---;
	input_is_mouse_pressed					:: proc(input: ^Input, btn: nk_buttons) -> nk_bool ---;
	input_is_mouse_released					:: proc(input: ^Input, btn: nk_buttons) -> nk_bool ---;
	input_is_key_pressed					:: proc(input: ^Input, key: nk_keys) -> nk_bool ---;
	input_is_key_released					:: proc(input: ^Input, key: nk_keys) -> nk_bool ---;
	input_is_key_down						:: proc(input: ^Input, key: nk_keys) -> nk_bool ---;
}


/* ===============================================================
*
*                          DRAW LIST
*
* ===============================================================*/
//not defined  NK_INCLUDE_VERTEX_BUFFER_OUTPUT


/* ===============================================================
*
*                          GUI
*
* ===============================================================*/
Style_item_type :: enum u32 {
	Style_item_COLOR,
	Style_item_IMAGE,
	Style_item_NINE_SLICE,
}

Style_item_data :: struct #raw_union {
	color: Color,
	image: Image,
	slice: Nine_slice,
}

Style_item :: struct {
	type: Style_item_type,
	data: Style_item_data,
}

Style_text :: struct {
	color: Color,
	padding: Vec2,
	color_factor: f32,
	disabled_factor: f32,
}

Style_button :: struct {
	// background
	normal:      Style_item,
	hover:       Style_item,
	active:      Style_item,
	border_color: Color,
	color_factor_background: f32,

	// text
	text_background: Color,
	text_normal:     Color,
	text_hover:      Color,
	text_active:     Color,
	text_alignment:  Text_alignment,
	color_factor_text: f32,

	// properties
	border:        f32,
	rounding:      f32,
	padding:       Vec2,
	image_padding: Vec2,
	touch_padding: Vec2,
	disabled_factor: f32,

	// optional user callbacks
	userdata: Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

Style_toggle :: struct {
	// background
	normal:        Style_item,
	hover:         Style_item,
	active:        Style_item,
	border_color:  Color,

	// cursor
	cursor_normal: Style_item,
	cursor_hover:  Style_item,

	// text
	text_normal:     Color,
	text_hover:      Color,
	text_active:     Color,
	text_background: Color,
	text_alignment:  Text_alignment,

	// properties
	padding:       Vec2,
	touch_padding: Vec2,
	spacing:       f32,
	border:        f32,
	color_factor:  f32,
	disabled_factor: f32,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

Style_selectable :: struct {
	// background (inactive)
	normal:         Style_item,
	hover:          Style_item,
	pressed:        Style_item,

	// background (active)
	normal_active:  Style_item,
	hover_active:   Style_item,
	pressed_active: Style_item,

	// text color (inactive)
	text_normal:    Color,
	text_hover:     Color,
	text_pressed:   Color,

	// text color (active)
	text_normal_active:    Color,
	text_hover_active:     Color,
	text_pressed_active:   Color,
	text_background:       Color,
	text_alignment:        nk_flags,

	// properties
	rounding:      f32,
	padding:       Vec2,
	touch_padding: Vec2,
	image_padding: Vec2,
	color_factor:  f32,
	disabled_factor: f32,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

nk_style_slider :: struct {
	// background
	normal:      Style_item,
	hover:       Style_item,
	active:      Style_item,
	border_color: Color,

	// background bar
	bar_normal:  Color,
	bar_hover:   Color,
	bar_active:  Color,
	bar_filled:  Color,

	// cursor
	cursor_normal: Style_item,
	cursor_hover:  Style_item,
	cursor_active: Style_item,

	// properties
	border:      f32,
	rounding:    f32,
	bar_height:  f32,
	padding:     Vec2,
	spacing:     Vec2,
	cursor_size: Vec2,
	color_factor: f32,
	disabled_factor: f32,

	// optional buttons
	show_buttons: b32,
	inc_button:   Style_button,
	dec_button:   Style_button,
	inc_symbol:   Symbol_type,
	dec_symbol:   Symbol_type,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

nk_style_knob :: struct {
	// background
	normal:         Style_item,
	hover:          Style_item,
	active:         Style_item,
	border_color:   Color,

	// knob
	knob_normal:        Color,
	knob_hover:         Color,
	knob_active:        Color,
	knob_border_color:  Color,

	// cursor
	cursor_normal:  Color,
	cursor_hover:   Color,
	cursor_active:  Color,

	// properties
	border:        f32,
	knob_border:   f32,
	padding:       Vec2,
	spacing:       Vec2,
	cursor_width:  f32,
	color_factor:  f32,
	disabled_factor: f32,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

nk_style_progress :: struct {
	// background
	normal:      Style_item,
	hover:       Style_item,
	active:      Style_item,
	border_color: Color,

	// cursor
	cursor_normal:      Style_item,
	cursor_hover:       Style_item,
	cursor_active:      Style_item,
	cursor_border_color: Color,

	// properties
	rounding:        f32,
	border:          f32,
	cursor_border:   f32,
	cursor_rounding: f32,
	padding:         Vec2,
	color_factor:    f32,
	disabled_factor: f32,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

nk_style_scrollbar :: struct {
	// background
	normal:         Style_item,
	hover:          Style_item,
	active:         Style_item,
	border_color:   Color,

	// cursor
	cursor_normal:      Style_item,
	cursor_hover:       Style_item,
	cursor_active:      Style_item,
	cursor_border_color: Color,

	// properties
	border:          f32,
	rounding:        f32,
	border_cursor:   f32,
	rounding_cursor: f32,
	padding:         Vec2,
	color_factor:    f32,
	disabled_factor: f32,

	// optional buttons
	show_buttons:    b32,
	inc_button:      Style_button,
	dec_button:      Style_button,
	inc_symbol:      Symbol_type,
	dec_symbol:      Symbol_type,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

nk_style_edit :: struct {
	// background
	normal:      Style_item,
	hover:       Style_item,
	active:      Style_item,
	border_color: Color,
	scrollbar:   nk_style_scrollbar,

	// cursor
	cursor_normal:      Color,
	cursor_hover:       Color,
	cursor_text_normal: Color,
	cursor_text_hover:  Color,

	// text (unselected)
	text_normal:    Color,
	text_hover:     Color,
	text_active:    Color,

	// text (selected)
	selected_normal:        Color,
	selected_hover:         Color,
	selected_text_normal:   Color,
	selected_text_hover:    Color,

	// properties
	border:         f32,
	rounding:       f32,
	cursor_size:    f32,
	scrollbar_size: Vec2,
	padding:        Vec2,
	row_padding:    f32,
	color_factor:   f32,
	disabled_factor: f32,
}

nk_style_property :: struct {
	// background
	normal:      Style_item,
	hover:       Style_item,
	active:      Style_item,
	border_color: Color,

	// text
	label_normal: Color,
	label_hover:  Color,
	label_active: Color,

	// symbols
	sym_left:  Symbol_type,
	sym_right: Symbol_type,

	// properties
	border:        f32,
	rounding:      f32,
	padding:       Vec2,
	color_factor:  f32,
	disabled_factor: f32,

	edit:       nk_style_edit,
	inc_button: Style_button,
	dec_button: Style_button,

	// optional user callbacks
	userdata:   Handle,
	draw_begin: proc(b: ^Command_buffer, userdata: Handle),
	draw_end:   proc(b: ^Command_buffer, userdata: Handle),
}

nk_style_chart :: struct {
	// colors
	background:     Style_item,
	border_color:   Color,
	selected_color: Color,
	color:          Color,

	// properties
	border:        f32,
	rounding:      f32,
	padding:       Vec2,
	color_factor:  f32,
	disabled_factor: f32,
	show_markers:  nk_bool,
}

nk_style_combo :: struct {
	// background
	normal:      Style_item,
	hover:       Style_item,
	active:      Style_item,
	border_color: Color,

	// label
	label_normal: Color,
	label_hover:  Color,
	label_active: Color,

	// symbol
	symbol_normal: Color,
	symbol_hover:  Color,
	symbol_active: Color,

	// button
	button:      Style_button,
	sym_normal:  Symbol_type,
	sym_hover:   Symbol_type,
	sym_active:  Symbol_type,

	// properties
	border:           f32,
	rounding:         f32,
	content_padding:  Vec2,
	button_padding:   Vec2,
	spacing:          Vec2,
	color_factor:     f32,
	disabled_factor:  f32,
}

nk_style_tab :: struct {
	// background
	background:   Style_item,
	border_color: Color,
	text:         Color,

	// button
	tab_maximize_button:   Style_button,
	tab_minimize_button:   Style_button,
	node_maximize_button:  Style_button,
	node_minimize_button:  Style_button,
	sym_minimize:          Symbol_type,
	sym_maximize:          Symbol_type,

	// properties
	border:        f32,
	rounding:      f32,
	indent:        f32,
	padding:       Vec2,
	spacing:       Vec2,
	color_factor:  f32,
	disabled_factor: f32,
}

nk_style_header_align :: enum u32 {
	HEADER_LEFT,
	HEADER_RIGHT,
}

nk_style_window_header :: struct {
	// background
	normal: Style_item,
	hover:  Style_item,
	active: Style_item,

	// button
	close_button:    Style_button,
	minimize_button: Style_button,
	close_symbol:    Symbol_type,
	minimize_symbol: Symbol_type,
	maximize_symbol: Symbol_type,

	// title
	label_normal: Color,
	label_hover:  Color,
	label_active: Color,

	// properties
	align:        nk_style_header_align,
	padding:      Vec2,
	label_padding: Vec2,
	spacing:      Vec2,
}

nk_style_window :: struct {
	header:              nk_style_window_header,
	fixed_background:    Style_item,
	background:          Color,

	border_color:        Color,
	popup_border_color:  Color,
	combo_border_color:  Color,
	contextual_border_color: Color,
	menu_border_color:   Color,
	group_border_color:  Color,
	tooltip_border_color: Color,
	scaler:              Style_item,

	border:              f32,
	combo_border:        f32,
	contextual_border:   f32,
	menu_border:         f32,
	group_border:        f32,
	tooltip_border:      f32,
	popup_border:        f32,
	min_row_height_padding: f32,

	rounding:           f32,
	spacing:            Vec2,
	scrollbar_size:     Vec2,
	min_size:           Vec2,

	padding:            Vec2,
	group_padding:      Vec2,
	popup_padding:      Vec2,
	combo_padding:      Vec2,
	contextual_padding: Vec2,
	menu_padding:       Vec2,
	tooltip_padding:    Vec2,
}

NK_CURSOR_COUNT :: len(Style_cursor);

Style :: struct {
	font:           ^User_font,
	cursors:        [NK_CURSOR_COUNT]^Cursor,
	cursor_active:  ^Cursor,
	cursor_last:    ^Cursor,
	cursor_visible: c.int,

	text:           Style_text,
	button:         Style_button,
	contextual_button: Style_button,
	menu_button:    Style_button,
	option:         Style_toggle,
	checkbox:       Style_toggle,
	selectable:     Style_selectable,
	slider:         nk_style_slider,
	knob:           nk_style_knob,
	progress:       nk_style_progress,
	property:       nk_style_property,
	edit:           nk_style_edit,
	chart:          nk_style_chart,
	scrollh:        nk_style_scrollbar,
	scrollv:        nk_style_scrollbar,
	tab:            nk_style_tab,
	combo:          nk_style_combo,
	window:         nk_style_window,
}

@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	style_item_color      :: proc(col: Color) -> Style_item ---;
	style_item_image      :: proc(img: Image) -> Style_item ---;
	style_item_nine_slice :: proc(slice: Nine_slice) -> Style_item ---;
	style_item_hide       :: proc() -> Style_item ---;
}


/*==============================================================
*                          PANEL
* =============================================================*/
NK_MAX_LAYOUT_ROW_TEMPLATE_COLUMNS :: 16
NK_CHART_MAX_SLOT :: 4

Panel_type :: enum u32 {
	NK_PANEL_NONE       = 0,
	NK_PANEL_WINDOW     = 1 << 0,
	NK_PANEL_GROUP      = 1 << 1,
	NK_PANEL_POPUP      = 1 << 2,
	NK_PANEL_CONTEXTUAL = 1 << 4,
	NK_PANEL_COMBO      = 1 << 5,
	NK_PANEL_MENU       = 1 << 6,
	NK_PANEL_TOOLTIP    = 1 << 7,
}

Panel_set :: enum u32 {
	NK_PANEL_SET_NONBLOCK = auto_cast (Panel_type.NK_PANEL_CONTEXTUAL | Panel_type.NK_PANEL_COMBO | Panel_type.NK_PANEL_MENU | Panel_type.NK_PANEL_TOOLTIP),
	NK_PANEL_SET_POPUP    = NK_PANEL_SET_NONBLOCK | auto_cast (Panel_type.NK_PANEL_POPUP),
	NK_PANEL_SET_SUB      = NK_PANEL_SET_POPUP | auto_cast (Panel_type.NK_PANEL_GROUP),
}

Chart_slot :: struct {
	typ: nk_chart_type,
	color: Color,
	highlight: Color,
	min, max, range: f32,
	count: c.int,
	last: Vec2,
	index: c.int,
	show_markers: nk_bool,
}

Chart :: struct {
	slot: c.int,
	x, y, w, h: f32,
	slots: [NK_CHART_MAX_SLOT]Chart_slot,
}

Panel_row_layout_type :: enum u32 {
	NK_LAYOUT_DYNAMIC_FIXED = 0,
	NK_LAYOUT_DYNAMIC_ROW,
	NK_LAYOUT_DYNAMIC_FREE,
	NK_LAYOUT_DYNAMIC,
	NK_LAYOUT_STATIC_FIXED,
	NK_LAYOUT_STATIC_ROW,
	NK_LAYOUT_STATIC_FREE,
	NK_LAYOUT_STATIC,
	NK_LAYOUT_TEMPLATE,
	NK_LAYOUT_COUNT,
}

Row_layout :: struct {
	typ: Panel_row_layout_type,
	index: c.int,
	height: f32,
	min_height: f32,
	columns: c.int,
	ratio: ^f32,
	item_width: f32,
	item_height: f32,
	item_offset: f32,
	filled: f32,
	item: Rect,
	tree_depth: c.int,
	templates: [NK_MAX_LAYOUT_ROW_TEMPLATE_COLUMNS]f32,
}

Popup_buffer :: struct {
	begin: nk_size,
	parent: nk_size,
	last: nk_size,
	end: nk_size,
	active: nk_bool,
}

Menu_state :: struct {
	x, y, w, h: f32,
	offset: Scroll,
}

Panel :: struct {
	typ: Panel_type,
	flags: nk_flags,
	bounds: Rect,
	offset_x: ^nk_uint,
	offset_y: ^nk_uint,
	at_x, at_y, max_x: f32,
	footer_height: f32,
	header_height: f32,
	border: f32,
	has_scrolling: u32,
	clip: Rect,
	menu: Menu_state,
	row: Row_layout,
	chart: Chart,
	buffer: ^Command_buffer,
	parent: ^Panel,
}

/*==============================================================
*                          WINDOW
* =============================================================*/

NK_WINDOW_MAX_NAME :: 64 

Popup_state :: struct {
	win:         ^Window,
	type:        Panel_type,
	buf:         Popup_buffer,
	name:        nk_hash,
	active:      nk_bool,
	combo_count: c.uint,
	con_count:   c.uint,
	con_old:     c.uint,
	active_con:  c.uint,
	header:      Rect,
}

Edit_state :: struct {
	name:         nk_hash,
	seq:          c.uint,
	old:          c.uint,
	active:       c.int,
	prev:         c.int,
	cursor:       c.int,
	sel_start:    c.int,
	sel_end:      c.int,
	scrollbar:    Scroll,
	mode:         u8,
	single_line:  u8,
}

NK_MAX_NUMBER_BUFFER :: 64

Property_state :: struct {
	active:       c.int,
	prev:         c.int,
	buffer:       [NK_MAX_NUMBER_BUFFER]u8,
	length:       c.int,
	cursor:       c.int,
	select_start: c.int,
	select_end:   c.int,
	name:         nk_hash,
	seq:          c.uint,
	old:          c.uint,
	state:        c.int,
}

Window :: struct {
	seq:                    c.uint,
	name:                   nk_hash,
	name_string:            [NK_WINDOW_MAX_NAME]u8,
	flags:                  nk_flags,

	bounds:                 Rect,
	scrollbar:              Scroll,
	buffer:                 Command_buffer,
	layout:                 ^Panel,
	scrollbar_hiding_timer: f32,

	property:               Property_state,
	popup:                  Popup_state,
	edit:                   Edit_state,
	scrolled:               c.uint,
	widgets_disabled:       nk_bool,

	tables:                 ^Table,
	table_count:            c.uint,

	next:                   ^Window,
	prev:                   ^Window,
	parent:                 ^Window,
}



/*==============================================================
*                          STACK
* =============================================================*/
/**
* \page Stack
* # Stack
* The style modifier stack can be used to temporarily change a
* property inside `nk_style`. For example if you want a special
* red button you can temporarily push the old button color onto a stack
* draw the button with a red color and then you just pop the old color
* back from the stack:
*
*     nk_style_push_style_item(ctx, &ctx->style.button.normal, Style_item_color(nk_rgb(255,0,0)));
*     nk_style_push_style_item(ctx, &ctx->style.button.hover, Style_item_color(nk_rgb(255,0,0)));
*     nk_style_push_style_item(ctx, &ctx->style.button.active, Style_item_color(nk_rgb(255,0,0)));
*     nk_style_push_vec2(ctx, &cx->style.button.padding, nk_vec2(2,2));
*
*     nk_button(...);
*
*     nk_style_pop_style_item(ctx);
*     nk_style_pop_style_item(ctx);
*     nk_style_pop_style_item(ctx);
*     nk_style_pop_vec2(ctx);
*
* Nuklear has a stack for style_items, float properties, vector properties,
* flags, colors, fonts and for button_behavior. Each has it's own fixed size stack
* which can be changed at compile time.
*/

NK_BUTTON_BEHAVIOR_STACK_SIZE :: 8
NK_FONT_STACK_SIZE           :: 8
Style_item_STACK_SIZE     :: 16
NK_FLOAT_STACK_SIZE          :: 32
NK_VECTOR_STACK_SIZE         :: 16
NK_FLAGS_STACK_SIZE          :: 32
NK_COLOR_STACK_SIZE          :: 32

// Stack element structs
Config_stack_style_item_element :: struct {
	address: ^Style_item,
	old_value: Style_item,
}
Config_stack_float_element :: struct {
	address: ^f32,
	old_value: f32,
}
Config_stack_vec2_element :: struct {
	address: ^Vec2,
	old_value: Vec2,
}
Config_stack_flags_element :: struct {
	address: ^nk_flags,
	old_value: nk_flags,
}
Config_stack_color_element :: struct {
	address: ^Color,
	old_value: Color,
}
Config_stack_user_font_element :: struct {
	address: ^User_font,
	old_value: User_font,
}
Config_stack_button_behavior_element :: struct {
	address: ^Button_behavior,
	old_value: Button_behavior,
}

// Stack structs
Config_stack_style_item :: struct {
	head: c.int,
	elements: [Style_item_STACK_SIZE]Config_stack_style_item_element,
}
Config_stack_float :: struct {
	head: c.int,
	elements: [NK_FLOAT_STACK_SIZE]Config_stack_float_element,
}
Config_stack_vec2 :: struct {
	head: c.int,
	elements: [NK_VECTOR_STACK_SIZE]Config_stack_vec2_element,
}
Config_stack_flags :: struct {
	head: c.int,
	elements: [NK_FLAGS_STACK_SIZE]Config_stack_flags_element,
}
Config_stack_color :: struct {
	head: c.int,
	elements: [NK_COLOR_STACK_SIZE]Config_stack_color_element,
}
Config_stack_user_font :: struct {
	head: c.int,
	elements: [NK_FONT_STACK_SIZE]Config_stack_user_font_element,
}
Config_stack_button_behavior :: struct {
	head: c.int,
	elements: [NK_BUTTON_BEHAVIOR_STACK_SIZE]Config_stack_button_behavior_element,
}

// Aggregate configuration stacks struct
Configuration_stacks :: struct {
	style_items:      Config_stack_style_item,
	floats:           Config_stack_float,
	vectors:          Config_stack_vec2,
	flags:            Config_stack_flags,
	colors:           Config_stack_color,
	fonts:            Config_stack_user_font,
	button_behaviors: Config_stack_button_behavior,
}

/*==============================================================
*                          CONTEXT
* =============================================================*/
//NK_VALUE_PAGE_CAPACITY :: (((NK_MAX(sizeof(struct Window),sizeof(struct nk_panel)) / sizeof(nk_uint))) / 2);
NK_VALUE_PAGE_CAPACITY :: (max(cast(int)size_of(Window), size_of(Panel)) / size_of(nk_uint)) / 2;

Table :: struct {
	seq:  c.uint,
	size: c.uint,
	keys: [NK_VALUE_PAGE_CAPACITY]nk_hash,
	values: [NK_VALUE_PAGE_CAPACITY]nk_uint,
	next, prev: ^Table,
}

Page_data :: struct #raw_union {
	tbl: Table,
	pan: Panel,
	win: Window,
}

Page_element :: struct {
	data: Page_data,
	next, prev: ^Page_element,
}

Page :: struct {
	size: c.uint,
	next: ^Page,
	win: [1]Page_element,
}

Pool :: struct {
	alloc: Allocator,
	type: Allocation_type,
	page_count: c.uint,
	pages: ^Page,
	freelist: ^Page_element,
	capacity: c.uint,
	size: nk_size,
	cap: nk_size,
}

Context :: struct {
	input:         Input,
	style:         Style,
	memory:        Buffer,
	clip:          Clipboard,
	last_widget_state: nk_flags,
	button_behavior: Button_behavior,
	stacks:        Configuration_stacks,
	delta_time_seconds: f32,

    userdata : Handle,
	
	// single shared text editor instance
	text_edit:     Text_edit,
	overlay:       Command_buffer,

	build:         c.int,
	use_pool:      c.int,
	pool:          Pool,
	begin:         ^Window,
	end:           ^Window,
	active:        ^Window,
	current:       ^Window,
	freelist:      ^Page_element,
	count:         u32,
	seq:           u32,
}

INT8 :: c.int8_t;
UINT8 :: c.uint8_t;
INT16 :: c.int16_t;
UINT16 :: c.uint16_t;
INT32 :: c.int32_t;
UINT32 :: c.uint32_t;
SIZE_TYPE :: c.uintptr_t;
POINTER_TYPE :: c.uintptr_t;
BOOL :: c.bool;

nk_uchar 	:: UINT8;
nk_byte 	:: UINT8;
nk_ushort 	:: UINT16;
nk_uint 	:: UINT32;
nk_size 	:: SIZE_TYPE;
nk_ptr 		:: POINTER_TYPE;
nk_bool 	:: BOOL;

nk_hash :: nk_uint;
nk_flags :: nk_uint;
nk_rune :: nk_uint;

Allocator :: struct {
	userdata : Handle,
	alloc : nk_plugin_alloc,
	free : nk_plugin_free,
};

NK_FLASE_TRUE :: enum u32 {
	nk_false,
	nk_true
};

Symbol_type :: enum u32 {
	SYMBOL_NONE,
	SYMBOL_X,
	SYMBOL_UNDERSCORE,
	SYMBOL_CIRCLE_SOLID,
	SYMBOL_CIRCLE_OUTLINE,
	SYMBOL_RECT_SOLID,
	SYMBOL_RECT_OUTLINE,
	SYMBOL_TRIANGLE_UP,
	SYMBOL_TRIANGLE_DOWN,
	SYMBOL_TRIANGLE_LEFT,
	SYMBOL_TRIANGLE_RIGHT,
	SYMBOL_PLUS,
	SYMBOL_MINUS,
	SYMBOL_TRIANGLE_UP_OUTLINE,
	SYMBOL_TRIANGLE_DOWN_OUTLINE,
	SYMBOL_TRIANGLE_LEFT_OUTLINE,
	SYMBOL_TRIANGLE_RIGHT_OUTLINE,
};

Collapse_states :: enum u32 {
	NK_MINIMIZED = auto_cast NK_FLASE_TRUE.nk_false,
	NK_MAXIMIZED = auto_cast NK_FLASE_TRUE.nk_true
};

//THe init stuff
@(default_calling_convention="c", link_prefix="nk_")
foreign nuklear {
	
	/**
	* # nk_init_fixed
	* Initializes a `Context` struct from single fixed size memory block
	* Should be used if you want complete control over nuklear's memory management.
	* Especially recommended for system with little memory or systems with virtual memory.
	* For the later case you can just allocate for example 16MB of virtual memory
	* and only the required amount of memory will actually be committed.
	*
	* ```c
	* nk_bool nk_init_fixed(struct Context *ctx, void *memory, nk_size size, const struct nk_user_font *font);
	* ```
	*
	* !!! Warning
	*     make sure the passed memory block is aligned correctly for `nk_draw_commands`.
	*
	* Parameter   | Description
	* ------------|--------------------------------------------------------------
	* \param[in] ctx     | Must point to an either stack or heap allocated `Context` struct
	* \param[in] memory  | Must point to a previously allocated memory block
	* \param[in] size    | Must contain the total size of memory
	* \param[in] font    | Must point to a previously initialized font handle for more info look at font documentation
	*
	* \returns either `false(0)` on failure or `true(1)` on success.
	*/
	init_fixed :: proc(ctx: ^Context, memory: rawptr, size: nk_size, font: ^User_font) -> nk_bool ---;

	/**
	* # nk_init
	* Initializes a `Context` struct with memory allocation callbacks for nuklear to allocate
	* memory from. Used c.internally for `nk_init_default` and provides a kitchen sink allocation
	* c.interface to nuklear. Can be useful for cases like monitoring memory consumption.
	*
	* ```c
	* nk_bool nk_init(struct Context *ctx, const struct nk_allocator *alloc, const struct nk_user_font *font);
	* ```
	*
	* Parameter   | Description
	* ------------|---------------------------------------------------------------
	* \param[in] ctx     | Must point to an either stack or heap allocated `Context` struct
	* \param[in] alloc   | Must point to a previously allocated memory allocator
	* \param[in] font    | Must point to a previously initialized font handle for more info look at font documentation
	*
	* \returns either `false(0)` on failure or `true(1)` on success.
	*/
	init :: proc(ctx: ^Context, alloc: ^Allocator, font: ^User_font) -> bool ---;

	/**
	* \brief Initializes a `Context` struct from two different either fixed or growing buffers.
	*
	* \details
	* The first buffer is for allocating draw commands while the second buffer is
	* used for allocating windows, panels and state tables.
	*
	* ```c
	* nk_bool nk_init_custom(struct Context *ctx, struct nk_buffer *cmds, struct nk_buffer *pool, const struct nk_user_font *font);
	* ```
	*
	* \param[in] ctx    Must point to an either stack or heap allocated `Context` struct
	* \param[in] cmds   Must point to a previously initialized memory buffer either fixed or dynamic to store draw commands c.into
	* \param[in] pool   Must point to a previously initialized memory buffer either fixed or dynamic to store windows, panels and tables
	* \param[in] font   Must point to a previously initialized font handle for more info look at font documentation
	*
	* \returns either `false(0)` on failure or `true(1)` on success.
	*/
	init_custom :: proc(ctx: ^Context, cmds: ^Buffer, pool: ^Buffer, font: ^User_font) -> bool ---

	/**
	* \brief Resets the context state at the end of the frame.
	*
	* \details
	* This includes mostly garbage collector tasks like removing windows or table
	* not called and therefore used anymore.
	*
	* ```c
	* void nk_clear(struct Context *ctx);
	* ```
	*
	* \param[in] ctx  Must point to a previously initialized `Context` struct
	*/
	clear :: proc(ctx: ^Context) ---

	/**
	* \brief Frees all memory allocated by nuklear; Not needed if context was initialized with `nk_init_fixed`.
	*
	* \details
	* ```c
	* void nk_free(struct Context *ctx);
	* ```
	*
	* \param[in] ctx  Must point to a previously initialized `Context` struct
	*/
	free :: proc(ctx: ^Context) ---
	
}


/*
_nk_init_fixed
_nk_init
_nk_init_custom
_nk_clear
_nk_free
_nk_input_begin
_nk_input_motion
_nk_input_key
_nk_input_button
_nk_input_scroll
_nk_input_char
_nk_input_glyph
_nk_input_unicode
_nk_input_end
_nk__begin
_nk__next
_nk_begin
_nk_begin_titled
_nk_end
_nk_window_find
_nk_window_get_bounds
_nk_window_get_position
_nk_window_get_size
_nk_window_get_width
_nk_window_get_height
_nk_window_get_panel
_nk_window_get_content_region
_nk_window_get_content_region_min
_nk_window_get_content_region_max
_nk_window_get_content_region_size
_nk_window_get_canvas
_nk_window_get_scroll
_nk_window_has_focus
_nk_window_is_hovered
_nk_window_is_collapsed
_nk_window_is_closed
_nk_window_is_hidden
_nk_window_is_active
_nk_window_is_any_hovered
_nk_item_is_any_active
_nk_window_set_bounds
_nk_window_set_position
_nk_window_set_size
_nk_window_set_focus
_nk_window_set_scroll
_nk_window_close
_nk_window_collapse
_nk_window_collapse_if
_nk_window_show
_nk_window_show_if
_nk_rule_horizontal
_nk_layout_set_min_row_height
_nk_layout_reset_min_row_height
_nk_layout_widget_bounds
_nk_layout_ratio_from_pixel
_nk_layout_row_dynamic
_nk_layout_row_static
_nk_layout_row_begin
_nk_layout_row_push
_nk_layout_row_end
_nk_layout_row
_nk_layout_row_template_begin
_nk_layout_row_template_push_dynamic
_nk_layout_row_template_push_variable
_nk_layout_row_template_push_static
_nk_layout_row_template_end
_nk_layout_space_begin
_nk_layout_space_push
_nk_layout_space_end
_nk_layout_space_bounds
_nk_layout_space_to_screen
_nk_layout_space_to_local
_nk_layout_space_rect_to_screen
_nk_layout_space_rect_to_local
_nk_spacer
_nk_group_begin
_nk_group_begin_titled
_nk_group_end
_nk_group_scrolled_offset_begin
_nk_group_scrolled_begin
_nk_group_scrolled_end
_nk_group_get_scroll
_nk_group_set_scroll
_nk_tree_push_hashed
_nk_tree_image_push_hashed
_nk_tree_pop
_nk_tree_state_push
_nk_tree_state_image_push
_nk_tree_state_pop
_nk_tree_element_push_hashed
_nk_tree_element_image_push_hashed
_nk_tree_element_pop
_nk_list_view_begin
_nk_list_view_end
_nk_widget
_nk_widget_fitting
_nk_widget_bounds
_nk_widget_position
_nk_widget_size
_nk_widget_width
_nk_widget_height
_nk_widget_is_hovered
_nk_widget_is_mouse_clicked
_nk_widget_has_mouse_click_down
_nk_spacing
_nk_widget_disable_begin
_nk_widget_disable_end
_nk_text
_nk_text_colored
_nk_text_wrap
_nk_text_wrap_colored
_nk_label
_nk_label_colored
_nk_label_wrap
_nk_label_colored_wrap
_nk_image
_nk_image_color
_nk_button_text
_nk_button_label
_nk_button_color
_nk_button_symbol
_nk_button_image
_nk_button_symbol_label
_nk_button_symbol_text
_nk_button_image_label
_nk_button_image_text
_nk_button_text_styled
_nk_button_label_styled
_nk_button_symbol_styled
_nk_button_image_styled
_nk_button_symbol_text_styled
_nk_button_symbol_label_styled
_nk_button_image_label_styled
_nk_button_image_text_styled
_nk_button_set_behavior
_nk_button_push_behavior
_nk_button_pop_behavior
_nk_check_label
_nk_check_text
_nk_check_text_align
_nk_check_flags_label
_nk_check_flags_text
_nk_checkbox_label
_nk_checkbox_label_align
_nk_checkbox_text
_nk_checkbox_text_align
_nk_checkbox_flags_label
_nk_checkbox_flags_text
_nk_radio_label
_nk_radio_label_align
_nk_radio_text
_nk_radio_text_align
_nk_option_label
_nk_option_label_align
_nk_option_text
_nk_option_text_align
_nk_selectable_label
_nk_selectable_text
_nk_selectable_image_label
_nk_selectable_image_text
_nk_selectable_symbol_label
_nk_selectable_symbol_text
_nk_select_label
_nk_select_text
_nk_select_image_label
_nk_select_image_text
_nk_select_symbol_label
_nk_select_symbol_text
_nk_slide_float
_nk_slide_int
_nk_slider_float
_nk_slider_int
_nk_knob_float
_nk_knob_int
_nk_progress
_nk_prog
_nk_color_picker
_nk_color_pick
_nk_property_int
_nk_property_float
_nk_property_double
_nk_propertyi
_nk_propertyf
_nk_propertyd
_nk_edit_string
_nk_edit_string_zero_terminated
_nk_edit_buffer
_nk_edit_focus
_nk_edit_unfocus
_nk_chart_begin
_nk_chart_begin_colored
_nk_chart_add_slot
_nk_chart_add_slot_colored
_nk_chart_push
_nk_chart_push_slot
_nk_chart_end
_nk_plot
_nk_plot_function
_nk_popup_begin
_nk_popup_close
_nk_popup_end
_nk_popup_get_scroll
_nk_popup_set_scroll
_nk_combo
_nk_combo_separator
_nk_combo_string
_nk_combo_callback
_nk_combobox
_nk_combobox_string
_nk_combobox_separator
_nk_combobox_callback
_nk_combo_begin_text
_nk_combo_begin_label
_nk_combo_begin_color
_nk_combo_begin_symbol
_nk_combo_begin_symbol_label
_nk_combo_begin_symbol_text
_nk_combo_begin_image
_nk_combo_begin_image_label
_nk_combo_begin_image_text
_nk_combo_item_label
_nk_combo_item_text
_nk_combo_item_image_label
_nk_combo_item_image_text
_nk_combo_item_symbol_label
_nk_combo_item_symbol_text
_nk_combo_close
_nk_combo_end
_nk_contextual_begin
_nk_contextual_item_text
_nk_contextual_item_label
_nk_contextual_item_image_label
_nk_contextual_item_image_text
_nk_contextual_item_symbol_label
_nk_contextual_item_symbol_text
_nk_contextual_close
_nk_contextual_end
_nk_tooltip
_nk_tooltip_begin
_nk_tooltip_end
_nk_menubar_begin
_nk_menubar_end
_nk_menu_begin_text
_nk_menu_begin_label
_nk_menu_begin_image
_nk_menu_begin_image_text
_nk_menu_begin_image_label
_nk_menu_begin_symbol
_nk_menu_begin_symbol_text
_nk_menu_begin_symbol_label
_nk_menu_item_text
_nk_menu_item_label
_nk_menu_item_image_label
_nk_menu_item_image_text
_nk_menu_item_symbol_text
_nk_menu_item_symbol_label
_nk_menu_close
_nk_menu_end
_nk_style_default
_nk_style_from_table
_nk_style_load_cursor
_nk_style_load_all_cursors
_nk_style_get_color_by_name
_nk_style_set_font
_nk_style_set_cursor
_nk_style_show_cursor
_nk_style_hide_cursor
_nk_style_push_font
_nk_style_push_float
_nk_style_push_vec2
_nk_style_push_style_item
_nk_style_push_flags
_nk_style_push_color
_nk_style_pop_font
_nk_style_pop_float
_nk_style_pop_vec2
_nk_style_pop_style_item
_nk_style_pop_flags
_nk_style_pop_color
_nk_rgb
_nk_rgb_iv
_nk_rgb_bv
_nk_rgb_f
_nk_rgb_fv
_nk_rgb_cf
_nk_rgb_hex
_nk_rgb_factor
_nk_rgba
_nk_rgba_u32
_nk_rgba_iv
_nk_rgba_bv
_nk_rgba_f
_nk_rgba_fv
_nk_rgba_cf
_nk_rgba_hex
_nk_hsva_colorf
_nk_hsva_colorfv
_nk_colorf_hsva_f
_nk_colorf_hsva_fv
_nk_hsv
_nk_hsv_iv
_nk_hsv_bv
_nk_hsv_f
_nk_hsv_fv
_nk_hsva
_nk_hsva_iv
_nk_hsva_bv
_nk_hsva_f
_nk_hsva_fv
_nk_color_f
_nk_color_fv
_nk_color_cf
_nk_color_d
_nk_color_dv
_nk_color_u32
_nk_color_hex_rgba
_nk_color_hex_rgb
_nk_color_hsv_i
_nk_color_hsv_b
_nk_color_hsv_iv
_nk_color_hsv_bv
_nk_color_hsv_f
_nk_color_hsv_fv
_nk_color_hsva_i
_nk_color_hsva_b
_nk_color_hsva_iv
_nk_color_hsva_bv
_nk_color_hsva_f
_nk_color_hsva_fv
_nk_handle_ptr
_nk_handle_id
_nk_image_handle
_nk_image_ptr
_nk_image_id
_nk_image_is_subimage
_nk_subimage_ptr
_nk_subimage_id
_nk_subimage_handle
_nk_nine_slice_handle
_nk_nine_slice_ptr
_nk_nine_slice_id
_nk_nine_slice_is_sub9slice
_nk_sub9slice_ptr
_nk_sub9slice_id
_nk_sub9slice_handle
_nk_murmur_hash
_nk_triangle_from_direction
_nk_vec2
_nk_vec2i
_nk_vec2v
_nk_vec2iv
_nk_get_null_rect
_nk_rect
_nk_recti
_nk_recta
_nk_rectv
_nk_rectiv
_nk_rect_pos
_nk_rect_size
_nk_strlen
_nk_stricmp
_nk_stricmpn
_nk_strtoi
_nk_strtof
_nk_strtod
_nk_strfilter
_nk_strmatch_fuzzy_string
_nk_strmatch_fuzzy_text
_nk_utf_decode
_nk_utf_encode
_nk_utf_len
_nk_utf_at
_nk_buffer_init
_nk_buffer_init_fixed
_nk_buffer_info
_nk_buffer_push
_nk_buffer_mark
_nk_buffer_reset
_nk_buffer_clear
_nk_buffer_free
_nk_buffer_memory
_nk_buffer_memory_const
_nk_buffer_total
_nk_str_init
_nk_str_init_fixed
_nk_str_clear
_nk_str_free
_nk_str_append_text_char
_nk_str_append_str_char
_nk_str_append_text_utf8
_nk_str_append_str_utf8
_nk_str_append_text_runes
_nk_str_append_str_runes
_nk_str_insert_at_char
_nk_str_insert_at_rune
_nk_str_insert_text_char
_nk_str_insert_str_char
_nk_str_insert_text_utf8
_nk_str_insert_str_utf8
_nk_str_insert_text_runes
_nk_str_insert_str_runes
_nk_str_remove_chars
_nk_str_remove_runes
_nk_str_delete_chars
_nk_str_delete_runes
_nk_str_at_char
_nk_str_at_rune
_nk_str_rune_at
_nk_str_at_char_const
_nk_str_at_const
_nk_str_get
_nk_str_get_const
_nk_str_len
_nk_str_len_char
_nk_filter_default
_nk_filter_ascii
_nk_filter_float
_nk_filter_decimal
_nk_filter_hex
_nk_filter_oct
_nk_filter_binary
_nk_textedit_init
_nk_textedit_init_fixed
_nk_textedit_free
_nk_textedit_text
_nk_textedit_delete
_nk_textedit_delete_selection
_nk_textedit_select_all
_nk_textedit_cut
_nk_textedit_paste
_nk_textedit_undo
_nk_textedit_redo
_nk_stroke_line
_nk_stroke_curve
_nk_stroke_rect
_nk_stroke_circle
_nk_stroke_arc
_nk_stroke_triangle
_nk_stroke_polyline
_nk_stroke_polygon
_nk_fill_rect
_nk_fill_rect_multi_color
_nk_fill_circle
_nk_fill_arc
_nk_fill_triangle
_nk_fill_polygon
_nk_draw_image
_nk_draw_nine_slice
_nk_draw_text
_nk_push_scissor
_nk_push_custom
_nk_input_has_mouse_click
_nk_input_has_mouse_click_in_rect
_nk_input_has_mouse_click_in_button_rect
_nk_input_has_mouse_click_down_in_rect
_nk_input_is_mouse_click_in_rect
_nk_input_is_mouse_click_down_in_rect
_nk_input_any_mouse_click_in_rect
_nk_input_is_mouse_prev_hovering_rect
_nk_input_is_mouse_hovering_rect
_nk_input_mouse_clicked
_nk_input_is_mouse_down
_nk_input_is_mouse_pressed
_nk_input_is_mouse_released
_nk_input_is_key_pressed
_nk_input_is_key_released
_nk_input_is_key_down
_Style_item_color
_Style_item_image
_Style_item_nine_slice
_Style_item_hide
*/