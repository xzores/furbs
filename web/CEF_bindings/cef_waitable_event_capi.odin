package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_waitable_event_t :: struct {
	base: base_ref_counted,
	
	reset: proc "system" (self: ^cef_waitable_event_t),
	signal: proc "system" (self: ^cef_waitable_event_t),
	is_signaled: proc "system" (self: ^cef_waitable_event_t) -> b32,
	wait: proc "system" (self: ^cef_waitable_event_t) -> b32,
}

@(default_calling_convention="system")
foreign lib {
	cef_waitable_event_create :: proc(automatic_reset: b32, initially_signaled: b32) -> ^cef_waitable_event_t ---
} 