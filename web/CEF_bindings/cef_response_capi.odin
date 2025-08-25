package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Structure used to represent a web response. Methods may be called on any thread.
// NOTE: This struct is allocated DLL-side.
Response :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if this object is read-only.
	is_read_only: proc "system" (self: ^Response) -> c.int,
	
	// Get/Set response error code (ERR_NONE if no error).
	get_error: proc "system" (self: ^Response) -> cef_errorcode,
	set_error: proc "system" (self: ^Response, error: cef_errorcode),

	// Get/Set response status code.
	get_status: proc "system" (self: ^Response) -> c.int,
	set_status: proc "system" (self: ^Response, status: c.int),

	// Get/Set response status text. (get_* result must be freed with cef_string_userfree_free)
	get_status_text: proc "system" (self: ^Response) -> cef_string_userfree,
	set_status_text: proc "system" (self: ^Response, statusText: ^cef_string),

	// Get/Set response mime type. (get_* result must be freed with cef_string_userfree_free)
	get_mime_type: proc "system" (self: ^Response) -> cef_string_userfree,
	set_mime_type: proc "system" (self: ^Response, mimeType: ^cef_string),

	// Get/Set response charset. (get_* result must be freed with cef_string_userfree_free)
	get_charset: proc "system" (self: ^Response) -> cef_string_userfree,
	set_charset: proc "system" (self: ^Response, charset: ^cef_string),

	// Get header by name. (result must be freed with cef_string_userfree_free)
	get_header_by_name: proc "system" (self: ^Response, name: ^cef_string) -> cef_string_userfree,

	// Set header |name| to |value|. If |overwrite|=1 existing values are replaced; if 0 they are not overwritten.
	set_header_by_name: proc "system" (self: ^Response, name: ^cef_string, value: ^cef_string, overwrite: c.int),

	// Get/Set all response header fields.
	get_header_map: proc "system" (self: ^Response, headerMap: string_multimap),
	set_header_map: proc "system" (self: ^Response, headerMap: string_multimap),

	// Get/Set the resolved URL after redirects or HSTS changes. (get_* result must be freed with cef_string_userfree_free)
	get_url: proc "system" (self: ^Response) -> cef_string_userfree,
	set_url: proc "system" (self: ^Response, url: ^cef_string),
}
