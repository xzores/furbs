package odin_cef

import "core:c"

/// Implement this structure to handle events related to keyboard input. The functions of this structure will be called on the UI thread.
/// NOTE: This struct is allocated client-side.
Keyboard_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called before a keyboard event is sent to the renderer. |event| contains information about the keyboard event. |os_event| is the operating system
	/// event message, if any. Return true (1) if the event was handled or false
	/// (0) otherwise. If the event will be handled in on_key_event() as a
	/// keyboard shortcut set |is_keyboard_shortcut| to true (1) and return false
	/// (0).
	on_pre_key_event: proc "system" (self: ^Keyboard_handler, browser: ^Browser, event: ^Key_event, os_event: Event_handle, is_keyboard_shortcut: ^b32) -> b32,

	/// Called after the renderer and JavaScript in the page has had a chance to handle the event. |event| contains information about the keyboard event.
	/// |os_event| is the operating system event message, if any. Return true (1)
	/// if the keyboard event was handled or false (0) otherwise.
	on_key_event: proc "system" (self: ^Keyboard_handler, browser: ^Browser, event: ^Key_event, os_event: Event_handle) -> b32,
} 