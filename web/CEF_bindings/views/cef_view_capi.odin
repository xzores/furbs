package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_view_t :: struct {
	base: base_ref_counted,
	
	as_browser_view: proc "system" (self: ^cef_view_t) -> ^Browser_view_t,
	as_button: proc "system" (self: ^cef_view_t) -> ^cef_button_t,
	as_panel: proc "system" (self: ^cef_view_t) -> ^cef_panel_t,
	as_scroll_view: proc "system" (self: ^cef_view_t) -> ^cef_scroll_view_t,
	as_textfield: proc "system" (self: ^cef_view_t) -> ^cef_textfield_t,
	get_type_string: proc "system" (self: ^cef_view_t) -> cef_string_userfree,
	to_string: proc "system" (self: ^cef_view_t, include_children: c.int) -> cef_string_userfree,
	is_valid: proc "system" (self: ^cef_view_t) -> b32,
	is_attached: proc "system" (self: ^cef_view_t) -> b32,
	is_same: proc "system" (self: ^cef_view_t, that: ^cef_view_t) -> b32,
	get_delegate: proc "system" (self: ^cef_view_t) -> ^cef_view_delegate_t,
	get_window: proc "system" (self: ^cef_view_t) -> ^cef_window_t,
	get_id: proc "system" (self: ^cef_view_t) -> c.int,
	set_id: proc "system" (self: ^cef_view_t, id: c.int),
	get_group_id: proc "system" (self: ^cef_view_t) -> c.int,
	set_group_id: proc "system" (self: ^cef_view_t, group_id: c.int),
	get_parent_view: proc "system" (self: ^cef_view_t) -> ^cef_view_t,
	get_view_for_id: proc "system" (self: ^cef_view_t, id: c.int) -> ^cef_view_t,
	set_bounds: proc "system" (self: ^cef_view_t, bounds: ^cef_rect),
	get_bounds: proc "system" (self: ^cef_view_t) -> cef_rect,
	get_bounds_in_screen: proc "system" (self: ^cef_view_t) -> cef_rect,
	set_size: proc "system" (self: ^cef_view_t, size: ^cef_size),
	get_size: proc "system" (self: ^cef_view_t) -> cef_size,
	set_position: proc "system" (self: ^cef_view_t, position: ^cef_point),
	get_position: proc "system" (self: ^cef_view_t) -> cef_point,
	set_insets: proc "system" (self: ^cef_view_t, insets: ^cef_insets_t),
	get_insets: proc "system" (self: ^cef_view_t) -> cef_insets_t,
	get_preferred_size: proc "system" (self: ^cef_view_t) -> cef_size,
	size_to_preferred_size: proc "system" (self: ^cef_view_t),
	get_minimum_size: proc "system" (self: ^cef_view_t) -> cef_size,
	get_maximum_size: proc "system" (self: ^cef_view_t) -> cef_size,
	get_height_for_width: proc "system" (self: ^cef_view_t, width: c.int) -> c.int,
	invalidate_layout: proc "system" (self: ^cef_view_t),
	set_visible: proc "system" (self: ^cef_view_t, visible: b32),
	is_visible: proc "system" (self: ^cef_view_t) -> b32,
	is_drawn: proc "system" (self: ^cef_view_t) -> b32,
	set_enabled: proc "system" (self: ^cef_view_t, enabled: b32),
	is_enabled: proc "system" (self: ^cef_view_t) -> b32,
	set_focusable: proc "system" (self: ^cef_view_t, focusable: b32),
	is_focusable: proc "system" (self: ^cef_view_t) -> b32,
	is_accessibility_focusable: proc "system" (self: ^cef_view_t) -> b32,
	has_focus: proc "system" (self: ^cef_view_t) -> b32,
	request_focus: proc "system" (self: ^cef_view_t),
	set_background_color: proc "system" (self: ^cef_view_t, color: cef_color),
	get_background_color: proc "system" (self: ^cef_view_t) -> cef_color,
	get_theme_color: proc "system" (self: ^cef_view_t, color_id: c.int) -> cef_color,
	convert_point_to_screen: proc "system" (self: ^cef_view_t, point: ^cef_point) -> b32,
	convert_point_from_screen: proc "system" (self: ^cef_view_t, point: ^cef_point) -> b32,
	convert_point_to_window: proc "system" (self: ^cef_view_t, point: ^cef_point) -> b32,
	convert_point_from_window: proc "system" (self: ^cef_view_t, point: ^cef_point) -> b32,
	convert_point_to_view: proc "system" (self: ^cef_view_t, view: ^cef_view_t, point: ^cef_point) -> b32,
	convert_point_from_view: proc "system" (self: ^cef_view_t, view: ^cef_view_t, point: ^cef_point) -> b32,
} 