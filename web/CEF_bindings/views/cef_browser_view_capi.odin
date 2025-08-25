package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

Browser_view_t :: struct {
	base: cef_view_t,
	
	as_browser_view: proc "system" (self: ^Browser_view_t) -> ^Browser_view_t,
	get_browser: proc "system" (self: ^Browser_view_t) -> ^Browser,
	get_chrome_toolbar_type: proc "system" (self: ^Browser_view_t) -> cef_chrome_toolbar_type_t,
	get_ui_scale_factor: proc "system" (self: ^Browser_view_t) -> f64,
	get_web_contents: proc "system" (self: ^Browser_view_t) -> ^cef_web_contents_t,
	get_dev_tools_contents: proc "system" (self: ^Browser_view_t) -> ^cef_web_contents_t,
	get_dev_tools_web_contents: proc "system" (self: ^Browser_view_t) -> ^cef_web_contents_t,
	get_web_contents: proc "system" (self: ^Browser_view_t) -> ^cef_web_contents_t,
	get_dev_tools_contents: proc "system" (self: ^Browser_view_t) -> ^cef_web_contents_t,
	get_dev_tools_web_contents: proc "system" (self: ^Browser_view_t) -> ^cef_web_contents_t,
} 