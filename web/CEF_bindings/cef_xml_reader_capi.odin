package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

cef_xml_reader_t :: struct {
	base: base_ref_counted,
	move_to_next_node: proc "system" (self: ^cef_xml_reader_t) -> b32,
	close: proc "system" (self: ^cef_xml_reader_t) -> b32,
	has_error: proc "system" (self: ^cef_xml_reader_t) -> b32,
	get_error: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_type: proc "system" (self: ^cef_xml_reader_t) -> Xml_node_type,
	get_depth: proc "system" (self: ^cef_xml_reader_t) -> c.int,
	get_local_name: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_prefix: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_qualified_name: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_namespace_uri: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_base_uri: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_xml_lang: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	is_empty_element: proc "system" (self: ^cef_xml_reader_t) -> b32,
	has_value: proc "system" (self: ^cef_xml_reader_t) -> b32,
	get_value: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	has_attributes: proc "system" (self: ^cef_xml_reader_t) -> b32,
	get_attribute_count: proc "system" (self: ^cef_xml_reader_t) -> c.size_t,
	get_attribute_byindex: proc "system" (self: ^cef_xml_reader_t, index: c.size_t, qualified_name: ^cef_string, value: ^cef_string) -> b32,
	get_attribute_byqname: proc "system" (self: ^cef_xml_reader_t, qualified_name: ^cef_string, value: ^cef_string) -> b32,
	get_attribute_bylname: proc "system" (self: ^cef_xml_reader_t, local_name: ^cef_string, namespace_uri: ^cef_string, value: ^cef_string) -> b32,
	get_inner_xml: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_outer_xml: proc "system" (self: ^cef_xml_reader_t) -> cef_string_userfree,
	get_line_number: proc "system" (self: ^cef_xml_reader_t) -> c.int,
	move_to_attribute_byindex: proc "system" (self: ^cef_xml_reader_t, index: c.int) -> b32,
	move_to_attribute_byqname: proc "system" (self: ^cef_xml_reader_t, qualified_name: ^cef_string) -> b32,
	move_to_attribute_bylname: proc "system" (self: ^cef_xml_reader_t, local_name: ^cef_string, namespace_uri: ^cef_string) -> b32,
	move_to_first_attribute: proc "system" (self: ^cef_xml_reader_t) -> b32,
	move_to_next_attribute: proc "system" (self: ^cef_xml_reader_t) -> b32,
	move_to_carrying_element: proc "system" (self: ^cef_xml_reader_t) -> b32,
}

@(default_calling_convention="system")
foreign lib {
	cef_xml_reader_create :: proc(stream: ^Stream_reader, encoding_type: Xml_encoding_type, uri: ^cef_string) -> ^cef_xml_reader_t ---
} 