package odin_cef

import "core:c"

/// Implement this structure to handle events related to focus. The functions of this structure will be called on the UI thread.
/// NOTE: This struct is allocated client-side.
Focus_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when the browser component is about to loose focus. For instance, if focus was on the last HTML element and the user pressed the TAB key.
	/// |next| will be true (1) if the browser is giving focus to the next
	/// component and false (0) if the browser is giving focus to the previous
	/// component.
	on_take_focus: proc "system" (self: ^Focus_handler, browser: ^Browser, next: b32),

	/// Called when the browser component is requesting focus. |source| indicates where the focus request is originating from. Return false (0) to allow the
	/// focus to be set or true (1) to cancel setting the focus.
	on_set_focus: proc "system" (self: ^Focus_handler, browser: ^Browser, source: Focus_source) -> b32,

	/// Called when the browser component has received focus.
	on_got_focus: proc "system" (self: ^Focus_handler, browser: ^Browser),
} 