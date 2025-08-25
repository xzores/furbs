package odin_cef

import "core:c"

// Implement this structure to handle browser process callbacks. Called on the browser process main thread unless noted.
// NOTE: This struct is allocated client-side.
Browser_process_handler :: struct {
	// Base structure.
	base: base_ref_counted,

	// Register custom preferences prior to global and request context initialization.
	// - For CEF_PREFERENCES_TYPE_GLOBAL: accessible via preference_manager.GetGlobalPreferences after OnContextInitialized (registered once at startup; see cef_settings.cache_path).
	// - For CEF_PREFERENCES_TYPE_REQUEST_CONTEXT: accessible via Request_context after OnRequestContextInitialized (registered for each new request context; intended—but not required—to be consistent across contexts; see cef_request_context_settings.cache_path).
	// Do not keep a reference to |registrar|. Called on the browser UI thread.
	on_register_custom_preferences: proc "system" (
		self: ^Browser_process_handler,
		type: Preferences_type,
		registrar: ^Preference_registrar,
	),

	// Called on the browser process UI thread immediately after the CEF context has been initialized.
	on_context_initialized: proc "system" (self: ^Browser_process_handler),

	// Called before a child process is launched.
	// UI thread for renderer; IO thread for GPU. May modify |command_line| (do not keep a reference).
	on_before_child_process_launch: proc "system" (
		self: ^Browser_process_handler,
		command_line: ^Command_line,
	),

	// App-specific behavior when an already-running app is relaunched with the same CefSettings.root_cache_path.
	// |command_line| is read-only; do not keep a reference. Return 1 if handled, 0 for default (which creates a new default-styled Chrome window).
	// See notes about process singleton lock and checking cef_initialize() return value for early exit.
	on_already_running_app_relaunch: proc "system" (
		self: ^Browser_process_handler,
		command_line: ^Command_line,
		current_directory: ^cef_string,
	) -> c.int,

	// Called from any thread when work is scheduled for the browser UI thread.
	// Used with cef_settings.external_message_pump and cef_do_message_loop_work().
	// Schedule cef_do_message_loop_work() on the UI thread after |delay_ms| (<=0 => soon; >0 => after delay, cancel any pending).
	on_schedule_message_pump_work: proc "system" (
		self: ^Browser_process_handler,
		delay_ms: c.int64_t,
	),

	// Default client for a newly created browser window (Chrome style UI window creation).
	// Return nil to leave the browser unmanaged (no callbacks; app shutdown blocked until manually closed).
	get_default_client: proc "system" (self: ^Browser_process_handler) -> ^Client,

	// Default handler for a new user/incognito profile (Chrome style UI window creation).
	// Return nil to leave the request context unmanaged (no callbacks).
	get_default_request_context_handler: proc "system" (
		self: ^Browser_process_handler,
	) -> ^Request_context_handler,
}
