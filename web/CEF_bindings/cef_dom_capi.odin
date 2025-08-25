package odin_cef

import "core:c"
// Structure to implement for visiting the DOM. Called on the render-process main thread.
// NOTE: This struct is allocated client-side.
Dom_visitor :: struct {
	// Base structure.
	base: base_ref_counted,

	// Execute DOM visit. |document| is a snapshot valid only for this call.
	visit: proc "system" (self: ^Dom_visitor, document: ^Dom_document),
}


// Structure representing a DOM document. Call only on the render-process main thread.
// NOTE: This struct is allocated DLL-side.
Dom_document :: struct {
	// Base structure.
	base: base_ref_counted,

	// Document type.
	get_type: proc "system" (self: ^Dom_document) -> Dom_document_type,

	// Root document node / BODY / HEAD.
	get_document: proc "system" (self: ^Dom_document) -> ^Dom_node,
	get_body:     proc "system" (self: ^Dom_document) -> ^Dom_node,
	get_head:     proc "system" (self: ^Dom_document) -> ^Dom_node,

	// Title (free result with cef_string_userfree_free).
	get_title: proc "system" (self: ^Dom_document) -> cef_string_userfree,

	// Element by ID.
	get_element_by_id: proc "system" (self: ^Dom_document, id: ^cef_string) -> ^Dom_node,

	// Node with keyboard focus.
	get_focused_node: proc "system" (self: ^Dom_document) -> ^Dom_node,

	// Selection presence and offsets.
	has_selection:              proc "system" (self: ^Dom_document) -> c.int,
	get_selection_start_offset: proc "system" (self: ^Dom_document) -> c.int,
	get_selection_end_offset:   proc "system" (self: ^Dom_document) -> c.int,

	// Selection as markup/text (free results with cef_string_userfree_free).
	get_selection_as_markup: proc "system" (self: ^Dom_document) -> cef_string_userfree,
	get_selection_as_text:   proc "system" (self: ^Dom_document) -> cef_string_userfree,

	// Base URL and resolve complete URL (free results with cef_string_userfree_free).
	get_base_url:     proc "system" (self: ^Dom_document) -> cef_string_userfree,
	get_complete_url: proc "system" (self: ^Dom_document, partialURL: ^cef_string) -> cef_string_userfree,
}


// Structure representing a DOM node. Call only on the render-process main thread.
// NOTE: This struct is allocated DLL-side.
Dom_node :: struct {
	// Base structure.
	base: base_ref_counted,

	// Node type and quick type checks.
	get_type:                 proc "system" (self: ^Dom_node) -> Dom_node_type,
	is_text:                  proc "system" (self: ^Dom_node) -> c.int,
	is_element:               proc "system" (self: ^Dom_node) -> c.int,
	is_editable:              proc "system" (self: ^Dom_node) -> c.int,
	is_form_control_element:  proc "system" (self: ^Dom_node) -> c.int,

	// Form control element type.
	get_form_control_element_type: proc "system" (self: ^Dom_node) -> Dom_form_control_type,

	// Identity compare.
	is_same: proc "system" (self: ^Dom_node, that: ^Dom_node) -> c.int,

	// Name / value (free results with cef_string_userfree_free).
	get_name:  proc "system" (self: ^Dom_node) -> cef_string_userfree,
	get_value: proc "system" (self: ^Dom_node) -> cef_string_userfree,

	// Set value (returns 1 on success).
	set_value: proc "system" (self: ^Dom_node, value: ^cef_string) -> c.int,

	// Node as markup (free result with cef_string_userfree_free).
	get_as_markup: proc "system" (self: ^Dom_node) -> cef_string_userfree,

	// Related document/relations.
	get_document:         proc "system" (self: ^Dom_node) -> ^Dom_document,
	get_parent:           proc "system" (self: ^Dom_node) -> ^Dom_node,
	get_previous_sibling: proc "system" (self: ^Dom_node) -> ^Dom_node,
	get_next_sibling:     proc "system" (self: ^Dom_node) -> ^Dom_node,

	// Children access.
	has_children:    proc "system" (self: ^Dom_node) -> c.int,
	get_first_child: proc "system" (self: ^Dom_node) -> ^Dom_node,
	get_last_child:  proc "system" (self: ^Dom_node) -> ^Dom_node,

	// Element-specific helpers.
	get_element_tag_name:   proc "system" (self: ^Dom_node) -> cef_string_userfree, // free with cef_string_userfree_free
	has_element_attributes: proc "system" (self: ^Dom_node) -> c.int,
	has_element_attribute:  proc "system" (self: ^Dom_node, attrName: ^cef_string) -> c.int,
	get_element_attribute:  proc "system" (self: ^Dom_node, attrName: ^cef_string) -> cef_string_userfree, // free with cef_string_userfree_free
	get_element_attributes: proc "system" (self: ^Dom_node, attrMap: string_map),
	set_element_attribute:  proc "system" (self: ^Dom_node, attrName: ^cef_string, value: ^cef_string) -> c.int,
	get_element_inner_text: proc "system" (self: ^Dom_node) -> cef_string_userfree, // free with cef_string_userfree_free

	// Element bounds in device pixels (use window.devicePixelRatio to convert).
	get_element_bounds: proc "system" (self: ^Dom_node) -> cef_rect,
}
