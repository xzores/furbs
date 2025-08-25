package odin_cef

import "core:c"

/// Callback structure used for asynchronous continuation of JavaScript dialog requests.
/// NOTE: This struct is allocated DLL-side.
jsdialog_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Continue the JS dialog request. Set |success| to true (1) if the OK button was pressed. The |user_input| value should be specified for prompt
	/// dialogs.
	cont: proc "system" (self: ^jsdialog_callback, success: b32, user_input: ^cef_string),
}

/// Implement this structure to handle events related to JavaScript dialogs. The functions of this structure will be called on the UI thread.
/// NOTE: This struct is allocated client-side.
Jsdialog_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called to run a JavaScript dialog. If |origin_url| is non-NULL it can be
	/// passed to the format_url_for_security_display function to retrieve a secure
	/// and user-friendly display string. The |default_prompt_text| value will be
	/// specified for prompt dialogs only. Set |suppress_message| to true (1) and
	/// return false (0) to suppress the message (suppressing messages is
	/// preferable to immediately executing the callback as this is used to detect
	/// presumably malicious behavior like spamming alert messages in
	/// onbeforeunload). Set |suppress_message| to false (0) and return false (0)
	/// to use the default implementation (the default implementation will show
	/// one modal dialog at a time and suppress any additional dialog requests
	/// until the displayed dialog is dismissed). Return true (1) if the
	/// application will use a custom dialog or if the callback has been executed
	/// immediately. Custom dialogs may be either modal or modeless. If a custom
	/// dialog is used the application must execute |callback| once the custom
	/// dialog is dismissed.
	on_jsdialog: proc "system" (self: ^Jsdialog_handler, browser: ^Browser, origin_url: ^cef_string, dialog_type: Jsdialog_type, message_text: ^cef_string, default_prompt_text: ^cef_string, callback: ^jsdialog_callback, suppress_message: ^b32) -> b32,

	/// Called to run a dialog asking the user if they want to leave a page.
	/// Return false (0) to use the default dialog implementation. Return true (1)
	/// if the application will use a custom dialog or if the callback has been
	/// executed immediately. Custom dialogs may be either modal or modeless. If a
	/// custom dialog is used the application must execute |callback| once the
	/// custom dialog is dismissed.
	on_before_unload_dialog: proc "system" (self: ^Jsdialog_handler, browser: ^Browser, message_text: ^cef_string, is_reload: b32, callback: ^jsdialog_callback) -> b32,

	/// Called to cancel any pending dialogs and reset any saved dialog state.
	/// Will be called due to events like page navigation irregardless of whether
	/// any dialogs are currently pending.
	on_reset_dialog_state: proc "system" (self: ^Jsdialog_handler, browser: ^Browser),

	/// Called when the dialog is closed.
	on_dialog_closed: proc "system" (self: ^Jsdialog_handler, browser: ^Browser),
} 