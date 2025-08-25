package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_menu_button_t :: struct {
	base: cef_label_button_t,
	
	as_menu_button: proc "system" (self: ^cef_menu_button_t) -> ^cef_menu_button_t,
	show_menu: proc "system" (self: ^cef_menu_button_t, menu_model: ^Menu_model, screen_point: ^cef_point, anchor_position: cef_menu_anchor_position_t),
	trigger_menu: proc "system" (self: ^cef_menu_button_t),
	set_ink_drop_enabled: proc "system" (self: ^cef_menu_button_t, enabled: b32),
	set_focus_painter: proc "system" (self: ^cef_menu_button_t, painter: ^cef_view_t),
	set_horizontal_alignment: proc "system" (self: ^cef_menu_button_t, alignment: Horizontal_alignment_t),
	set_minimum_size: proc "system" (self: ^cef_menu_button_t, size: ^cef_size),
	set_maximum_size: proc "system" (self: ^cef_menu_button_t, size: ^cef_size),
	set_is_focusable: proc "system" (self: ^cef_menu_button_t, focusable: b32),
	set_accessibility_focusable: proc "system" (self: ^cef_menu_button_t, focusable: b32),
	set_draw_strings_disabled: proc "system" (self: ^cef_menu_button_t, disabled: b32),
} 