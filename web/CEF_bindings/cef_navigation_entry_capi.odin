package odin_cef

import "core:c"

// Structure used to represent an entry in navigation history.
// NOTE: This struct is allocated DLL-side.
Navigation_entry :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if this object is valid. Do not call other functions if 0.
	is_valid: proc "system" (self: ^Navigation_entry) -> c.int,

	// Returns the actual URL of the page (may be data: or similar). Use get_display_url for a display-friendly version.
	// Result must be freed with cef_string_userfree_free().
	get_url: proc "system" (self: ^Navigation_entry) -> cef_string_userfree,

	// Returns a display-friendly version of the URL.
	// Result must be freed with cef_string_userfree_free().
	get_display_url: proc "system" (self: ^Navigation_entry) -> cef_string_userfree,

	// Returns the original URL entered by the user before any redirects.
	// Result must be freed with cef_string_userfree_free().
	get_original_url: proc "system" (self: ^Navigation_entry) -> cef_string_userfree,

	// Returns the title set by the page (may be NULL).
	// Result must be freed with cef_string_userfree_free().
	get_title: proc "system" (self: ^Navigation_entry) -> cef_string_userfree,

	// Returns the transition type indicating how the user navigated to this page.
	get_transition_type: proc "system" (self: ^Navigation_entry) -> Transition_type,

	// Returns 1 if this navigation includes POST data.
	has_post_data: proc "system" (self: ^Navigation_entry) -> c.int,

	// Returns the time of the last known successful navigation completion (0 if not completed yet).
	get_completion_time: proc "system" (self: ^Navigation_entry) -> Basetime,

	// Returns the HTTP status code for the last known successful navigation response (0 if not received yet).
	get_http_status_code: proc "system" (self: ^Navigation_entry) -> c.int,
	
	// Returns the SSL information for this navigation entry.
	get_Ssl_status: proc "system" (self: ^Navigation_entry) -> ^Ssl_status,
}
