package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_panel_delegate_t :: struct {
	base: cef_view_delegate_t,
	
	on_panel_bounds_changed: proc "system" (self: ^cef_panel_delegate_t, panel: ^cef_panel_t),
} 