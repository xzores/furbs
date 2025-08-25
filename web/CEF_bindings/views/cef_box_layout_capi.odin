package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_box_layout_t :: struct {
	base: cef_layout_t,
	
	as_box_layout: proc "system" (self: ^cef_box_layout_t) -> ^cef_box_layout_t,
	set_horizontal: proc "system" (self: ^cef_box_layout_t, horizontal: b32),
	set_inside_border_horizontal: proc "system" (self: ^cef_box_layout_t, inside_border_horizontal: c.int),
	set_inside_border_vertical: proc "system" (self: ^cef_box_layout_t, inside_border_vertical: c.int),
	set_inside_border_insets: proc "system" (self: ^cef_box_layout_t, insets: ^cef_insets_t),
	set_between_child_spacing: proc "system" (self: ^cef_box_layout_t, spacing: c.int),
	set_cross_axis_alignment: proc "system" (self: ^cef_box_layout_t, alignment: cef_cross_axis_alignment_t),
	set_main_axis_alignment: proc "system" (self: ^cef_box_layout_t, alignment: cef_main_axis_alignment_t),
	set_flex_for_view: proc "system" (self: ^cef_box_layout_t, view: ^cef_view_t, flex: c.int),
	clear_flex_for_view: proc "system" (self: ^cef_box_layout_t, view: ^cef_view_t),
} 