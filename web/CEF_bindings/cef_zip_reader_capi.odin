package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_zip_reader_t :: struct {
	base: base_ref_counted,
	
	move_to_next_file: proc "system" (self: ^cef_zip_reader_t) -> b32,
	move_to_file: proc "system" (self: ^cef_zip_reader_t, case_sensitive: b32, file_name: ^cef_string) -> b32,
	close: proc "system" (self: ^cef_zip_reader_t) -> b32,
	get_file_name: proc "system" (self: ^cef_zip_reader_t) -> cef_string_userfree,
	get_file_size: proc "system" (self: ^cef_zip_reader_t) -> i64,
	get_file_last_modified: proc "system" (self: ^cef_zip_reader_t) -> Time,
	open_file: proc "system" (self: ^cef_zip_reader_t, password: ^cef_string) -> b32,
	close_file: proc "system" (self: ^cef_zip_reader_t) -> b32,
	read_file: proc "system" (self: ^cef_zip_reader_t, buffer: rawptr, buffer_size: c.size_t) -> c.int,
	tell: proc "system" (self: ^cef_zip_reader_t) -> i64,
	eof: proc "system" (self: ^cef_zip_reader_t) -> b32,
}

@(default_calling_convention="system")
foreign lib {
	cef_zip_reader_create :: proc(stream: ^Stream_reader) -> ^cef_zip_reader_t ---
} 