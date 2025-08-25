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
	cef_add_cross_origin_whitelist_entry :: proc(source_origin: ^cef_string, target_protocol: ^cef_string, target_domain: ^cef_string, allow_target_subdomains: b32) -> b32 ---
	cef_remove_cross_origin_whitelist_entry :: proc(source_origin: ^cef_string, target_protocol: ^cef_string, target_domain: ^cef_string, allow_target_subdomains: b32) -> b32 ---
	cef_clear_cross_origin_whitelist :: proc() -> b32 ---
} 