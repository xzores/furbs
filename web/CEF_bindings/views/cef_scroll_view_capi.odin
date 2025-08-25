package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_scroll_view_t :: struct {
	base: cef_view_t,
	
	as_scroll_view: proc "system" (self: ^cef_scroll_view_t) -> ^cef_scroll_view_t,
	set_content_view: proc "system" (self: ^cef_scroll_view_t, view: ^cef_view_t),
	get_content_view: proc "system" (self: ^cef_scroll_view_t) -> ^cef_view_t,
	get_visible_content_rect: proc "system" (self: ^cef_scroll_view_t) -> cef_rect,
	get_chrome_scrollbar_mode: proc "system" (self: ^cef_scroll_view_t) -> cef_scrollbar_mode_t,
	set_chrome_scrollbar_mode: proc "system" (self: ^cef_scroll_view_t, mode: cef_scrollbar_mode_t),
	get_minimum_preferred_size: proc "system" (self: ^cef_scroll_view_t) -> cef_size,
	get_maximum_preferred_size: proc "system" (self: ^cef_scroll_view_t) -> cef_size,
	calculate_preferred_size: proc "system" (self: ^cef_scroll_view_t) -> cef_size,
	layout: proc "system" (self: ^cef_scroll_view_t),
} 