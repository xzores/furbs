package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

@(default_calling_convention="system")
foreign lib {
	cef_crash_reporting_enabled :: proc() -> b32 ---
	cef_set_crash_key_value :: proc(key: ^cef_string, value: ^cef_string) ---
} 