package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_layout_t :: struct {
	base: base_ref_counted,
	
	as_layout: proc "system" (self: ^cef_layout_t) -> ^cef_layout_t,
	is_valid: proc "system" (self: ^cef_layout_t) -> b32,
	is_dirty: proc "system" (self: ^cef_layout_t) -> b32,
	invalidate_layout: proc "system" (self: ^cef_layout_t),
	set_bounds: proc "system" (self: ^cef_layout_t, bounds: ^cef_rect),
	get_bounds: proc "system" (self: ^cef_layout_t) -> cef_rect,
	get_bounds_in_screen: proc "system" (self: ^cef_layout_t) -> cef_rect,
	set_size: proc "system" (self: ^cef_layout_t, size: ^cef_size),
	get_size: proc "system" (self: ^cef_layout_t) -> cef_size,
	set_position: proc "system" (self: ^cef_layout_t, position: ^cef_point),
	get_position: proc "system" (self: ^cef_layout_t) -> cef_point,
	set_insets: proc "system" (self: ^cef_layout_t, insets: ^cef_insets_t),
	get_insets: proc "system" (self: ^cef_layout_t) -> cef_insets_t,
	size_to_preferred_size: proc "system" (self: ^cef_layout_t),
	layout: proc "system" (self: ^cef_layout_t),
	add_child_view: proc "system" (self: ^cef_layout_t, view: ^cef_view_t),
	add_child_view_at: proc "system" (self: ^cef_layout_t, view: ^cef_view_t, index: c.int),
	reorder_child_view: proc "system" (self: ^cef_layout_t, view: ^cef_view_t, index: c.int),
	remove_child_view: proc "system" (self: ^cef_layout_t, view: ^cef_view_t),
	remove_all_child_views: proc "system" (self: ^cef_layout_t),
	get_child_view_count: proc "system" (self: ^cef_layout_t) -> c.size_t,
	get_child_view_at: proc "system" (self: ^cef_layout_t, index: c.int) -> ^cef_view_t,
	get_child_view_by_id: proc "system" (self: ^cef_layout_t, id: c.int) -> ^cef_view_t,
	set_child_view_insets: proc "system" (self: ^cef_layout_t, view: ^cef_view_t, insets: ^cef_insets_t),
	get_child_view_insets: proc "system" (self: ^cef_layout_t, view: ^cef_view_t) -> cef_insets_t,
	set_child_view_bounds: proc "system" (self: ^cef_layout_t, view: ^cef_view_t, bounds: ^cef_rect),
	get_child_view_bounds: proc "system" (self: ^cef_layout_t, view: ^cef_view_t) -> cef_rect,
} 