package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

Response_filter_status :: enum c.int {
	RESPONSE_FILTER_DONE = 0,
	RESPONSE_FILTER_NEED_MORE_DATA = 1,
	RESPONSE_FILTER_ERROR = 2,
}

Response_filter :: struct {
	base: base_ref_counted,
	
	init_filter: proc "system" (self: ^Response_filter) -> b32,
	filter: proc "system" (self: ^Response_filter, data_in: rawptr, data_in_size: c.size_t, data_in_read: ^c.size_t, data_out: rawptr, data_out_size: c.size_t, data_out_written: ^c.size_t) -> Response_filter_status,
} 