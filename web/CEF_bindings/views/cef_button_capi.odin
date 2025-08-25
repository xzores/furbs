package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_button_t :: struct {
	base: cef_view_t,
	
	as_button: proc "system" (self: ^cef_button_t) -> ^cef_button_t,
	set_state: proc "system" (self: ^cef_button_t, state: cef_button_state_t),
	get_state: proc "system" (self: ^cef_button_t) -> cef_button_state_t,
	set_ink_drop_enabled: proc "system" (self: ^cef_button_t, enabled: b32),
	set_text: proc "system" (self: ^cef_button_t, text: ^cef_string),
	get_text: proc "system" (self: ^cef_button_t) -> cef_string_userfree,
	set_text_color: proc "system" (self: ^cef_button_t, for_state: cef_button_state_t, color: cef_color),
	set_enabled_text_colors: proc "system" (self: ^cef_button_t, disabled: cef_color, enabled: cef_color),
	set_text_color_disabled: proc "system" (self: ^cef_button_t, color: cef_color),
	set_text_color_enabled: proc "system" (self: ^cef_button_t, color: cef_color),
	set_background_color: proc "system" (self: ^cef_button_t, for_state: cef_button_state_t, color: cef_color),
	set_enabled_background_colors: proc "system" (self: ^cef_button_t, disabled: cef_color, enabled: cef_color),
	set_background_color_disabled: proc "system" (self: ^cef_button_t, color: cef_color),
	set_background_color_enabled: proc "system" (self: ^cef_button_t, color: cef_color),
	get_text_color: proc "system" (self: ^cef_button_t, for_state: cef_button_state_t) -> cef_color,
	get_background_color: proc "system" (self: ^cef_button_t, for_state: cef_button_state_t) -> cef_color,
	set_font_list: proc "system" (self: ^cef_button_t, font_list: ^cef_string),
	set_horizontal_alignment: proc "system" (self: ^cef_button_t, alignment: Horizontal_alignment_t),
	set_minimum_size: proc "system" (self: ^cef_button_t, size: ^cef_size),
	set_maximum_size: proc "system" (self: ^cef_button_t, size: ^cef_size),
	set_is_focusable: proc "system" (self: ^cef_button_t, focusable: b32),
	set_accessibility_focusable: proc "system" (self: ^cef_button_t, focusable: b32),
	set_draw_strings_disabled: proc "system" (self: ^cef_button_t, disabled: b32),
	set_button_text: proc "system" (self: ^cef_button_t, text: ^cef_string),
	get_button_text: proc "system" (self: ^cef_button_t) -> cef_string_userfree,
	set_button_state: proc "system" (self: ^cef_button_t, state: cef_button_state_t),
	get_button_state: proc "system" (self: ^cef_button_t) -> cef_button_state_t,
	set_ink_drop_enabled: proc "system" (self: ^cef_button_t, enabled: b32),
} 