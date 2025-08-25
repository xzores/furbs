package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Callback structure for cef_request_context_t::ResolveHost.
// NOTE: This struct is allocated client-side.
Resolve_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Called on the UI thread after ResolveHost completes.
	// |result| is the result code. |resolved_ips| is the list of resolved IPs or nil on failure.
	on_resolve_completed: proc "system" (self: ^Resolve_callback, result: cef_errorcode, resolved_ips: string_list),
}

// Implemented by the client to observe content and website setting changes and registered via
// cef_request_context_t::AddSettingObserver. Called on the browser process UI thread.
// NOTE: This struct is allocated client-side.
cef_setting_observer :: struct {
	// Base structure.
	base: base_ref_counted,

	// Called when a content or website setting has changed. Retrieve new values via
	// cef_request_context_t::GetContentSetting or GetWebsiteSetting.
	on_setting_changed: proc "system" (
		self: ^cef_setting_observer,
		requesting_url: ^cef_string,
		top_level_url: ^cef_string,
		content_type: Content_setting_types,
	),
}

// A request context provides request handling for a set of related Browser or URL request objects.
// See comments for process/model behavior. NOTE: This struct is allocated DLL-side.
Request_context :: struct {
	// Base structure.
	base: Preference_manager,

	// Returns 1 if this object points to the same context as |other|.
	is_same: proc "system" (self: ^Request_context, other: ^Request_context) -> c.int,

	// Returns 1 if this object shares the same storage as |other|.
	is_sharing_with: proc "system" (self: ^Request_context, other: ^Request_context) -> c.int,

	// Returns 1 if this is the global context (used by default when context arg is nil).
	is_global: proc "system" (self: ^Request_context) -> c.int,

	// Returns the handler for this context, if any.
	get_handler: proc "system" (self: ^Request_context) -> ^Request_context_handler,

	// Cache path for this object, or nil for incognito/in-memory cache. (free with cef_string_userfree_free)
	get_cache_path: proc "system" (self: ^Request_context) -> cef_string_userfree,

	// Cookie manager for this object. If |callback| non-nil, executed on UI thread after storage init.
	get_cookie_manager: proc "system" (self: ^Request_context, callback: ^Completion_callback) -> ^Cookie_manager,

	// Register a scheme handler factory for |scheme_name| and optional |domain_name|.
	// Returns 0 on error. May be called on any thread in the browser process.
	register_scheme_handler_factory: proc "system" (
		self: ^Request_context,
		scheme_name: ^cef_string,
		domain_name: ^cef_string,
		factory: ^Scheme_handler_factory,
	) -> c.int,

	// Clear all registered scheme handler factories. Returns 0 on error.
	clear_scheme_handler_factories: proc "system" (self: ^Request_context) -> c.int,

	// Clear all certificate exceptions added via on_certificate_error().
	// Recommend calling close_all_connections() as well. If |callback| non-nil it runs on UI thread after completion.
	clear_certificate_exceptions: proc "system" (self: ^Request_context, callback: ^Completion_callback),

	// Clear all HTTP auth credentials added via GetAuthCredentials. Optional |callback| on UI thread after completion.
	clear_http_auth_credentials: proc "system" (self: ^Request_context, callback: ^Completion_callback),

	// Clear all active/idle connections (useful before shutdown without cef_shutdown()). Optional |callback| on UI thread.
	close_all_connections: proc "system" (self: ^Request_context, callback: ^Completion_callback),

	// Resolve |origin| to IP addresses. |callback| executes on UI thread after completion.
	resolve_host: proc "system" (self: ^Request_context, origin: ^cef_string, callback: ^Resolve_callback),

	// MediaRouter for this context. If |callback| non-nil, executed asynchronously on UI thread after init.
	get_media_router: proc "system" (self: ^Request_context, callback: ^Completion_callback) -> ^Media_router,

	// Current value for |content_type| applying to the specified URLs (nil for default). Returns nil if none configured.
	// Must be called on the browser UI thread.
	get_website_setting: proc "system" (
		self: ^Request_context,
		requesting_url: ^cef_string,
		top_level_url: ^cef_string,
		content_type: Content_setting_types,
	) -> ^cef_value,

	// Set current value for |content_type| for the specified URLs in default scope.
	// If both URLs nil and context not incognito, sets default. Pass nil |value| to remove the default.
	// Use with care; see Chromium docs for security/stability implications.
	set_website_setting: proc "system" (
		self: ^Request_context,
		requesting_url: ^cef_string,
		top_level_url: ^cef_string,
		content_type: Content_setting_types,
		value: ^cef_value,
	),

	// Current value for |content_type| for the specified URLs (default if both nil).
	// Returns CEF_CONTENT_SETTING_VALUE_DEFAULT if none configured. UI thread only.
	get_content_setting: proc "system" (
		self: ^Request_context,
		requesting_url: ^cef_string,
		top_level_url: ^cef_string,
		content_type: Content_setting_types,
	) -> Content_setting_values,

	// Set current value for |content_type| for the specified URLs in default scope.
	// If both URLs nil and not incognito, sets default. Use DEFAULT to use the platform default.
	set_content_setting: proc "system" (
		self: ^Request_context,
		requesting_url: ^cef_string,
		top_level_url: ^cef_string,
		content_type: Content_setting_types,
		value: Content_setting_values,
	),

	// Set Chrome color scheme for all browsers sharing this context.
	// |variant| SYSTEM/LIGHT/DARK selects mode; other variants determine how |user_color| applies. 0 => default color.
	set_chrome_color_scheme: proc "system" (self: ^Request_context, variant: Color_variant, user_color: cef_color),

	// Get current Chrome color scheme mode (SYSTEM/LIGHT/DARK). UI thread only.
	get_chrome_color_scheme_mode: proc "system" (self: ^Request_context) -> Color_variant,

	// Get current Chrome color scheme color (or 0 for default). UI thread only.
	get_chrome_color_scheme_color: proc "system" (self: ^Request_context) -> cef_color,

	// Get current Chrome color scheme variant. UI thread only.
	get_chrome_color_scheme_variant: proc "system" (self: ^Request_context) -> Color_variant,

	// Add an observer for content/website setting changes. Observer remains until returned Registration is destroyed. UI thread only.
	add_setting_observer: proc "system" (self: ^Request_context, observer: ^cef_setting_observer) -> ^Registration,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Returns the global context object.
	request_context_get_global_context :: proc "system" () -> ^Request_context ---

	// Creates a new context object with the specified |settings| and optional |handler|.
	request_context_create_context :: proc "system" (settings: ^Request_context_settings, handler: ^Request_context_handler) -> ^Request_context ---

	// Creates a new context object that shares storage with |other| and uses an optional |handler|.
	// (Symbol name per header snippet.)
	request_context_cef_create_context_shared :: proc "system" (other: ^Request_context, handler: ^Request_context_handler) -> ^Request_context ---
}
