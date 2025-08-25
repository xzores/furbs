package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

Browser_view_delegate_t :: struct {
	base: cef_view_delegate_t,
	
	on_browser_created: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t, browser: ^Browser),
	on_browser_destroyed: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t, browser: ^Browser),
	get_delegate_for_popup: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t, settings: ^Browser_settings_t, client: ^Client, is_devtools: b32) -> ^Browser_view_delegate_t,
	on_popup_browser_view_created: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t, popup_browser_view: ^Browser_view_t, is_devtools: b32) -> b32,
	get_chrome_toolbar_type: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t) -> cef_chrome_toolbar_type_t,
	use_external_begin_frame: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t) -> b32,
	on_gesture_command: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t, gesture_command: cef_gesture_command_t) -> b32,
	get_browser_frame_util: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t) -> ^Browser_frame_util_t,
	on_browser_frame_created: proc "system" (self: ^Browser_view_delegate_t, browser_view: ^Browser_view_t, frame: ^Browser_frame_t),
} 
