package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_textfield_delegate_t :: struct {
	base: cef_view_delegate_t,
	
	on_key_event: proc "system" (self: ^cef_textfield_delegate_t, textfield: ^cef_textfield_t, event: ^cef_key_event_t) -> b32,
	on_after_user_action: proc "system" (self: ^cef_textfield_delegate_t, textfield: ^cef_textfield_t),
	on_textfield_focused: proc "system" (self: ^cef_textfield_delegate_t, textfield: ^cef_textfield_t),
	on_textfield_blurred: proc "system" (self: ^cef_textfield_delegate_t, textfield: ^cef_textfield_t),
} 