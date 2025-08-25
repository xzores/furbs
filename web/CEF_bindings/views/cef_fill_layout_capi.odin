package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_fill_layout_t :: struct {
	base: cef_layout_t,
	
	as_fill_layout: proc "system" (self: ^cef_fill_layout_t) -> ^cef_fill_layout_t,
	set_main_axis_alignment: proc "system" (self: ^cef_fill_layout_t, alignment: cef_main_axis_alignment_t),
	set_cross_axis_alignment: proc "system" (self: ^cef_fill_layout_t, alignment: cef_cross_axis_alignment_t),
	set_inside_border_insets: proc "system" (self: ^cef_fill_layout_t, insets: ^cef_insets_t),
	set_minimum_size: proc "system" (self: ^cef_fill_layout_t, size: ^cef_size),
	set_maximum_size: proc "system" (self: ^cef_fill_layout_t, size: ^cef_size),
} 