package furbs_web;

import "core:reflect"
import "core:thread"
import "core:time"
import "core:fmt"
import "core:c"
import "core:log"
import "core:mem"
import "core:os"
import "core:sync"
import "core:path/filepath"
import "core:dynlib"
import "core:sys/windows"
import "core:unicode/utf16"

import "base:intrinsics"
import "base:runtime"

import cef "CEF_bindings"

//setup the hash, required in newer versions of CEF
//Must be called before anything else
api_hash_setup :: proc () {
	res := cef.api_hash(cef.CEF_API_VERSION_13900, 0);
	assert(res == cef.CEF_API_HASH_13900, "The hash does not match the platform");
	log.infof("CEF returned api version %v", cef.api_version());
}

//call this before initilizing cef.
pre_init_cef :: proc (app : ^cef.App) -> (args : cef.Main_args, is_main : bool) {

	log.infof("Starting thread %v", os.current_thread_id());
	// 1) Get hInstance and exe dir
	hinstance := windows.GetModuleHandleW(nil);
	if hinstance == nil {
		check_windows_error("Failed to get module handle");
	}

	// 2) Main args
	args = { hinstance };
	
	increment(app);
	code := cef.execute_process(&args, app, nil);
	if (code >= 0) {
		//this is a child process
		is_main = false;
		return;
	}
	else if code == -1 {
		//we are the browser (main)
		log.infof("Starting browser thread...");
		when ODIN_WINDOWS_SUBSYSTEM == .Windows && ODIN_DEBUG {
			if !windows.AllocConsole() {
				check_windows_error("Failed to create console");
			}
		}
		is_main = true;
	}

	return;
}


@(private)
cef_allocator : mem.Allocator;
set_allocator :: proc (alloc := context.allocator) {
	cef_allocator = alloc;
	log.debugf("setting allocator : %v", alloc)
}

get_cef_allocator :: proc () -> mem.Allocator {
	return cef_allocator;
}

@(private)
cef_logger : log.Logger;
//sets the cef logger
set_logger :: proc (logger := context.logger) {
	cef_logger = logger;
}

restore_context :: proc () -> runtime.Context {
	ctx := runtime.default_context();
	ctx.logger = cef_logger;
	ctx.allocator = cef_allocator;

	return ctx;
}

to_cef_str :: proc (str : string, loc := #caller_location) -> cef.cef_string {
	if str == "" {
		return {};
	}
	str16 := make([]u16, len(str) + 2, context.temp_allocator, loc);
	str16_len := utf16.encode_string(str16, str);
	res : cef.cef_string;
	code := cef.cef_string_utf16_set(raw_data(str16), auto_cast str16_len, &res, 1);
	assert(code != 0, "failed to set the CEF string????");

	return res;
}

to_cef_str_ptr :: proc (str : string, alloc := context.allocator, loc := #caller_location) -> ^cef.cef_string {
	if str == "" {
		return {};
	}
	str16 := make([]u16, len(str) + 2, context.temp_allocator, loc);
	str16_len := utf16.encode_string(str16, str);
	res := new(cef.cef_string, alloc);
	code := cef.cef_string_utf16_set(raw_data(str16), auto_cast str16_len, res, 1);
	assert(code != 0, "failed to set the CEF string????");

	return res;
}

from_cef_str :: proc (s: cef.cef_string, loc := #caller_location) -> string {
	if s.str == nil || s.length == 0 {
		return "";
	}

	src   := s.str
	slen  := s.length
	
	buf := make([]u8, slen * 2, loc = loc)
	written := utf16.decode_to_utf8(buf, src[:slen]);
	
	// Build an Odin string from the bytes (no extra copy).
	return string(buf[:written])
}

destroy_cef_string :: proc (str : cef.cef_string) {
	str := str;
	cef.cef_string_utf16_clear(&str);
}

destroy_cef_string_ptr :: proc (str : ^cef.cef_string) {
	cef.cef_string_utf16_clear(str);
}

utf16_str :: proc (str : string, alloc := context.allocator) -> []u16 {
	class_name_w := make([]u16, len(str) + 2, alloc);
	utf16.encode_string(class_name_w, str);
	return class_name_w
}

//CEF application
On_before_command_line_processing :: #type proc "system" (self: ^cef.App, process_type: ^cef.cef_string, Command_line: ^cef.Command_line);
On_register_custom_schemes :: #type proc "system" (self: ^cef.App, registrar: ^cef.Scheme_registrar);
Get_resource_bundle_handler :: #type proc "system" (self: ^cef.App) -> ^cef.Resource_bundle_handler
Get_browser_process_handler :: #type proc "system" (self: ^cef.App) -> ^cef.Browser_process_handler
Get_render_process_handler :: #type proc "system" (self: ^cef.App) -> ^cef.Render_process_handler;

make_application :: proc (on_cmd_process : On_before_command_line_processing,
							on_reg_schemes : On_register_custom_schemes,
							get_resource_bundle_handler : Get_resource_bundle_handler,
							get_browser_process_handler : Get_browser_process_handler,
							get_render_process_handler : Get_render_process_handler, loc := #caller_location) -> ^cef.App {
	app := alloc_cef_object(cef.App, nil, loc = loc);

	assert(reflect.struct_field_by_name(cef.App, "base").offset == 0);

	app.on_before_command_line_processing = on_cmd_process;
	app.on_register_custom_schemes = on_reg_schemes;
	app.get_resource_bundle_handler = get_resource_bundle_handler;
	app.get_browser_process_handler = get_browser_process_handler;
	app.get_render_process_handler = get_render_process_handler;
	
	return app;
}

release_application :: proc (app : ^cef.App) {
	log.debugf("releasing application");
	release(auto_cast app);
}

// CEF settings
make_cef_settings :: proc(
	no_sandbox: bool = true,
	multi_threaded_message_loop: bool = true,
	external_message_pump: bool = false,
	windowless_rendering_enabled: bool = false,
	command_line_args_disabled: bool = false,
	cache_path: string = "",
	root_cache_path: string = "",
	persist_session_cookies: bool = false,
	user_agent: string = "",
	user_agent_product: string = "",
	locale: string = "en-US",
	log_file: string = "cef.log",
	log_severity: cef.Log_severity = cef.Log_severity.LOGSEVERITY_INFO,
	javascript_flags: string = "",
	resources_dir_path: string = "",
	locales_dir_path: string = "",
	remote_debugging_port: int = 0,
	uncaught_exception_stack_size: int = 0,
	background_color: cef.cef_color = 0xFFFFFFFF, // opaque white
	accept_language_list: string = "en-US",
	cookieable_schemes_list: string = "",
	cookieable_schemes_exclude_defaults: bool = false,
	chrome_policy_id: string = "",
	chrome_app_icon_id: int = 0,
	disable_signal_handlers: bool = false,
	browser_subprocess_path: string = "",
	framework_dir_path: string = "",
	main_bundle_path: string = "",
	loc := #caller_location) -> cef.Settings {
	cef_settings := cef.Settings {
		// Size of this structure.
		size = size_of(cef.Settings),

		// Set to true (1) to disable the sandbox for sub-processes.
		no_sandbox = c.int(no_sandbox),

		// The path to a separate executable that will be launched for sub-processes.
		browser_subprocess_path = to_cef_str(browser_subprocess_path, loc),

		// The path to the CEF framework directory on macOS.
		framework_dir_path = to_cef_str(framework_dir_path, loc),

		// The path to the main bundle on macOS.
		main_bundle_path = to_cef_str(main_bundle_path, loc),

		// Run browser process message loop in a separate thread.
		multi_threaded_message_loop = c.int(multi_threaded_message_loop),

		// Use external message pump scheduling.
		external_message_pump = c.int(external_message_pump),

		// Enable windowless (off-screen) rendering.
		windowless_rendering_enabled = c.int(windowless_rendering_enabled),

		// Disable command-line argument configuration.
		command_line_args_disabled = c.int(command_line_args_disabled),

		// Directory for global browser cache (empty = incognito).
		cache_path = to_cef_str(cache_path, loc),

		// Root directory for installation-specific data.
		root_cache_path = to_cef_str(root_cache_path, loc),

		// Persist session cookies (requires cache_path).
		persist_session_cookies = c.int(persist_session_cookies),

		// Custom User-Agent string.
		user_agent = to_cef_str(user_agent, loc),

		// Product portion of default User-Agent.
		user_agent_product = to_cef_str(user_agent_product, loc),

		// Locale string passed to WebKit ("en-US" default).
		locale = to_cef_str(locale, loc),

		// Path to debug log file.
		log_file = to_cef_str(log_file, loc),

		// Log severity threshold.
		Log_severity = log_severity,

		// Custom JS engine flags.
		javascript_flags = to_cef_str(javascript_flags, loc),

		// Fully qualified path for resources directory.
		resources_dir_path = to_cef_str(resources_dir_path, loc),

		// Fully qualified path for locales directory.
		locales_dir_path = to_cef_str(locales_dir_path, loc),

		// Remote debugging port (0 = disabled).
		remote_debugging_port = c.int(remote_debugging_port),

		// Number of stack trace frames for uncaught exceptions.
		uncaught_exception_stack_size = c.int(uncaught_exception_stack_size),

		// Background color before page load.
		background_color = background_color,

		// "Accept-Language" HTTP header value.
		accept_language_list = to_cef_str(accept_language_list, loc),

		// Custom cookieable schemes list.
		cookieable_schemes_list = to_cef_str(cookieable_schemes_list, loc),
		cookieable_schemes_exclude_defaults = c.int(cookieable_schemes_exclude_defaults),

		// Chrome policy management ID.
		chrome_policy_id = to_cef_str(chrome_policy_id, loc),

		// Icon resource ID for default Chrome windows (Windows only).
		chrome_app_icon_id = c.int(chrome_app_icon_id),

		// Disable signal handlers (POSIX).
		disable_signal_handlers = c.int(disable_signal_handlers),
	}

	return cef_settings
}

destroy_cef_settings :: proc (settings : cef.Settings) {

	destroy_cef_string(settings.browser_subprocess_path);
	destroy_cef_string(settings.framework_dir_path);
	destroy_cef_string(settings.main_bundle_path);
	destroy_cef_string(settings.cache_path);
	destroy_cef_string(settings.root_cache_path);
	destroy_cef_string(settings.user_agent);
	destroy_cef_string(settings.user_agent_product);
	destroy_cef_string(settings.locale);
	destroy_cef_string(settings.log_file);
	destroy_cef_string(settings.javascript_flags);
	destroy_cef_string(settings.resources_dir_path);
	destroy_cef_string(settings.locales_dir_path);
	destroy_cef_string(settings.accept_language_list);
	destroy_cef_string(settings.cookieable_schemes_list);
	destroy_cef_string(settings.chrome_policy_id);
}


Os_window_handle :: union {
	windows.HWND,
}

// decorations_off: true -> no frame/caption (borderless). false -> normal decorated window.
// add a boolean to toggle decorations
make_os_window :: proc (
    hinstance: windows.HMODULE, window_name_str: string, class_name_str: string,
    window_callback: windows.WNDPROC, l_param_data: rawptr, decorations_off: bool
) -> Os_window_handle {
    ex_style :: 0
    style : u32 : windows.CS_HREDRAW | windows.CS_VREDRAW

    class_name := utf16_str(class_name_str, context.temp_allocator)
    window_name := utf16_str(window_name_str, context.temp_allocator)
	
    wcex: windows.WNDCLASSEXW
    wcex.cbSize = size_of(windows.WNDCLASSEXW)
    wcex.style = style
    wcex.lpfnWndProc = window_callback
    wcex.hInstance = auto_cast hinstance
    wcex.lpszClassName = auto_cast raw_data(class_name)
    if windows.RegisterClassExW(&wcex) == 0 { check_windows_error("failed to register class") }

    win_style: u32 = windows.WS_CLIPCHILDREN | windows.WS_CLIPSIBLINGS | windows.WS_VISIBLE

    // defaults
    x, y, w, h: i32
    x = windows.CW_USEDEFAULT
    y = windows.CW_USEDEFAULT
    w = windows.CW_USEDEFAULT
    h = windows.CW_USEDEFAULT

    if decorations_off {
        win_style |= windows.WS_POPUP
        // CW_USEDEFAULT yields 0x0 for WS_POPUP; set a size and center it
        w = 1280
        h = 800
        sw := windows.GetSystemMetrics(windows.SM_CXSCREEN)
        sh := windows.GetSystemMetrics(windows.SM_CYSCREEN)
        x = (sw - w) / 2
        y = (sh - h) / 2
        // ex_style |= windows.WS_EX_APPWINDOW // uncomment if you want a taskbar button
    } else {
        win_style |= windows.WS_OVERLAPPEDWINDOW
    }

    browser_window := windows.CreateWindowExW(
        ex_style, wcex.lpszClassName, auto_cast raw_data(window_name), win_style,
        x, y, w, h, nil, nil, auto_cast hinstance, l_param_data)
    if browser_window == nil { check_windows_error("failed to create window") }

    if !windows.ShowWindow(browser_window, windows.SW_SHOWDEFAULT) { /* not an error: returns previous visibility */ }
    if !windows.UpdateWindow(browser_window) { check_windows_error("failed to update window") }

    return browser_window
}
