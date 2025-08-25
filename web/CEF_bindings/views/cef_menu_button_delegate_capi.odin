package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_menu_button_delegate_t :: struct {
	base: cef_button_delegate_t,
	
	on_menu_button_pressed: proc "system" (self: ^cef_menu_button_delegate_t, menu_button: ^cef_menu_button_t),
	get_menu_model: proc "system" (self: ^cef_menu_button_delegate_t, menu_button: ^cef_menu_button_t) -> ^Menu_model,
} 