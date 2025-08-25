package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_textfield_t :: struct {
	base: cef_view_t,
	
	as_textfield: proc "system" (self: ^cef_textfield_t) -> ^cef_textfield_t,
	set_password_input: proc "system" (self: ^cef_textfield_t, password_input: b32),
	is_password_input: proc "system" (self: ^cef_textfield_t) -> b32,
	set_read_only: proc "system" (self: ^cef_textfield_t, read_only: b32),
	is_read_only: proc "system" (self: ^cef_textfield_t) -> b32,
	get_text: proc "system" (self: ^cef_textfield_t) -> cef_string_userfree,
	set_text: proc "system" (self: ^cef_textfield_t, text: ^cef_string),
	append_text: proc "system" (self: ^cef_textfield_t, text: ^cef_string),
	insert_or_replace_text: proc "system" (self: ^cef_textfield_t, text: ^cef_string),
	has_selection: proc "system" (self: ^cef_textfield_t) -> b32,
	get_selected_text: proc "system" (self: ^cef_textfield_t) -> cef_string_userfree,
	select_all: proc "system" (self: ^cef_textfield_t, reverse: b32),
	clear_selection: proc "system" (self: ^cef_textfield_t),
	set_text_color: proc "system" (self: ^cef_textfield_t, color: cef_color),
	get_text_color: proc "system" (self: ^cef_textfield_t) -> cef_color,
	set_selection_text_color: proc "system" (self: ^cef_textfield_t, color: cef_color),
	get_selection_text_color: proc "system" (self: ^cef_textfield_t) -> cef_color,
	set_selection_background_color: proc "system" (self: ^cef_textfield_t, color: cef_color),
	get_selection_background_color: proc "system" (self: ^cef_textfield_t) -> cef_color,
	set_font_list: proc "system" (self: ^cef_textfield_t, font_list: ^cef_string),
	get_font_list: proc "system" (self: ^cef_textfield_t) -> cef_string_userfree,
	apply_text_color: proc "system" (self: ^cef_textfield_t, color: cef_color, range: ^cef_range),
	apply_text_style: proc "system" (self: ^cef_textfield_t, style: cef_text_style_t, add: b32, range: ^cef_range),
	is_command_enabled: proc "system" (self: ^cef_textfield_t, command_id: cef_textfield_commands_t) -> b32,
	execute_command: proc "system" (self: ^cef_textfield_t, command_id: cef_textfield_commands_t),
	clear_edit_history: proc "system" (self: ^cef_textfield_t),
	set_placeholder_text: proc "system" (self: ^cef_textfield_t, text: ^cef_string),
	get_placeholder_text: proc "system" (self: ^cef_textfield_t) -> cef_string_userfree,
	set_placeholder_text_color: proc "system" (self: ^cef_textfield_t, color: cef_color),
	set_accessible_name: proc "system" (self: ^cef_textfield_t, name: ^cef_string),
	set_bounds: proc "system" (self: ^cef_textfield_t, bounds: ^cef_rect),
	get_bounds: proc "system" (self: ^cef_textfield_t) -> cef_rect,
	get_bounds_in_screen: proc "system" (self: ^cef_textfield_t) -> cef_rect,
	set_size: proc "system" (self: ^cef_textfield_t, size: ^cef_size),
	get_size: proc "system" (self: ^cef_textfield_t) -> cef_size,
	set_position: proc "system" (self: ^cef_textfield_t, position: ^cef_point),
	get_position: proc "system" (self: ^cef_textfield_t) -> cef_point,
	set_insets: proc "system" (self: ^cef_textfield_t, insets: ^cef_insets_t),
	get_insets: proc "system" (self: ^cef_textfield_t) -> cef_insets_t,
	size_to_preferred_size: proc "system" (self: ^cef_textfield_t),
	layout: proc "system" (self: ^cef_textfield_t),
	add_child_view: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t),
	add_child_view_at: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t, index: c.int),
	reorder_child_view: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t, index: c.int),
	remove_child_view: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t),
	remove_all_child_views: proc "system" (self: ^cef_textfield_t),
	get_child_view_count: proc "system" (self: ^cef_textfield_t) -> c.size_t,
	get_child_view_at: proc "system" (self: ^cef_textfield_t, index: c.int) -> ^cef_view_t,
	get_child_view_by_id: proc "system" (self: ^cef_textfield_t, id: c.int) -> ^cef_view_t,
	set_child_view_insets: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t, insets: ^cef_insets_t),
	get_child_view_insets: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t) -> cef_insets_t,
	set_child_view_bounds: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t, bounds: ^cef_rect),
	get_child_view_bounds: proc "system" (self: ^cef_textfield_t, view: ^cef_view_t) -> cef_rect,
} 