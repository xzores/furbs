package odin_cef

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

import "core:c"

/// Implement this structure to provide handler implementations. Methods will be called by the process and/or thread indicated.
/// NOTE: This struct is allocated client-side.
App :: struct {
	/// Base structure.
	base: base_ref_counted,
	
	/// Provides an opportunity to view and/or modify command-line arguments before processing by CEF and Chromium. The |process_type| value will be
	/// NULL for the browser process. Do not keep a reference to the
	/// Command_line object passed to this function. The
	/// cef_settings.command_line_args_disabled value can be used to start with
	/// an NULL command-line object. Any values specified in CefSettings that
	/// equate to command-line arguments will be set before this function is
	/// called. Be cautious when using this function to modify command-line
	/// arguments for non-browser processes as this may result in undefined
	/// behavior including crashes.
	on_before_command_line_processing: proc "stdcall" (self: ^App, process_type: ^cef_string, Command_line: ^Command_line),

	/// Provides an opportunity to register custom schemes. Do not keep a reference to the |registrar| object. This function is called on the main
	/// thread for each process and the registered schemes should be the same
	/// across all processes.
	on_register_custom_schemes: proc "stdcall" (self: ^App, registrar: ^Scheme_registrar),

	/// Return the handler for resource bundle events. If no handler is returned resources will be loaded from pack files. This function is called by the
	/// browser and render processes on multiple threads.
	get_resource_bundle_handler: proc "stdcall" (self: ^App) -> ^Resource_bundle_handler,

	/// Return the handler for functionality specific to the browser process. This function is called on multiple threads in the browser process.
	get_browser_process_handler: proc "stdcall" (self: ^App) -> ^Browser_process_handler,

	/// Return the handler for functionality specific to the render process. This function is called on the render process main thread.
	get_render_process_handler: proc "stdcall" (self: ^App) -> ^Render_process_handler,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// This function should be called from the application entry point function to execute a secondary process. It can be used to run secondary processes from
	/// the browser client executable (default behavior) or from a separate
	/// executable specified by the cef_settings.browser_subprocess_path value. If
	/// called for the browser process (identified by no "type" command-line value)
	/// it will return immediately with a value of -1. If called for a recognized
	/// secondary process it will block until the process should exit and then
	/// return the process exit code. The |application| parameter may be NULL. The
	/// |windows_sandbox_info| parameter is only used on Windows and may be NULL
	/// (see cef_sandbox_win.h for details).
	execute_process :: proc "system" (args: ^Main_args, application: ^App, windows_sandbox_info: rawptr) -> c.int ---

	/// This function should be called on the main application thread to initialize the CEF browser process. The |application| parameter may be NULL. Returns
	/// true (1) if initialization succeeds. Returns false (0) if initialization
	/// fails or if early exit is desired (for example, due to process singleton
	/// relaunch behavior). If this function returns false (0) then the application
	/// should exit immediately without calling any other CEF functions except,
	/// optionally, get_exit_code. The |windows_sandbox_info| parameter is only
	/// used on Windows and may be NULL (see cef_sandbox_win.h for details).
	initialize :: proc "system" (args: ^Main_args, settings: ^Settings, application: ^App, windows_sandbox_info: rawptr) -> c.int ---

	/// This function can optionally be called on the main application thread after initialize to retrieve the initialization exit code. When initialize
	/// returns true (1) the exit code will be 0 (RESULT_CODE_NORMAL_EXIT).
	/// Otherwise, see resultcode_t for possible exit code values including
	/// browser process initialization errors and normal early exit conditions (such
	/// as RESULT_CODE_NORMAL_EXIT_PROCESS_NOTIFIED for process singleton
	/// relaunch behavior).
	get_exit_code :: proc "system" () -> c.int ---

	/// This function should be called on the main application thread to shut down the CEF browser process before the application exits. Do not call any other
	/// CEF functions after calling this function.
	shutdown :: proc "system" () ---

	/// Perform a single iteration of CEF message loop processing. This function is provided for cases where the CEF message loop must be integrated into an
	/// existing application message loop. Use of this function is not recommended
	/// for most users; use either the run_message_loop() function or
	/// cef_settings.multi_threaded_message_loop if possible. When using this
	/// function care must be taken to balance performance against excessive CPU
	/// usage. It is recommended to enable the cef_settings.external_message_pump
	/// option when using this function so that
	/// Browser_process_handler::on_schedule_message_pump_work() callbacks can
	/// facilitate the scheduling process. This function should only be called on
	/// the main application thread and only if initialize() is called with a
	/// cef_settings.multi_threaded_message_loop value of false (0). This function
	/// will not block.
	do_message_loop_work :: proc "system" () ---

	/// Run the CEF message loop. Use this function instead of an application- provided message loop to get the best balance between performance and CPU
	/// usage. This function should only be called on the main application thread
	/// and only if initialize() is called with a
	/// cef_settings.multi_threaded_message_loop value of false (0). This function
	/// will block until a quit message is received by the system.
	run_message_loop :: proc "system" () ---

	/// Quit the CEF message loop that was started by calling run_message_loop(). This function should only be called on the main
	/// application thread and only if run_message_loop() was used.
	quit_message_loop :: proc "system" () ---
}