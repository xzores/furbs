package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Supports discovery of and communication with media devices on the local network
// via the Cast and DIAL protocols. May be called on any browser process thread.
// NOTE: This struct is allocated DLL-side.
Media_router :: struct {
	// Base structure.
	base: base_ref_counted,

	// Add an observer for MediaRouter events. Stays registered until the returned Registration is destroyed.
	add_observer: proc "system" (self: ^Media_router, observer: ^Media_observer) -> ^Registration,

	// Return a MediaSource for the specified media source URN (e.g. "cast:<appId>?clientId=<clientId>").
	get_source: proc "system" (self: ^Media_router, urn: ^cef_string) -> ^Media_source,

	// Trigger async calls to Media_observer.on_sinks for all observers.
	notify_current_sinks: proc "system" (self: ^Media_router),

	// Create a new route between |source| and |sink|. |callback| executes on success or failure.
	// On success also triggers Media_observer.on_routes for all observers.
	create_route: proc "system" (self: ^Media_router, source: ^Media_source, sink: ^Media_sink, callback: ^Media_route_create_callback),

	// Trigger async calls to Media_observer.on_routes for all observers.
	notify_current_routes: proc "system" (self: ^Media_router),
}


/// Returns the MediaRouter for the global request context. If |callback| is non-NULL it
/// will run asynchronously on the UI thread after the manager's storage is initialized.
/// Equivalent to request_context_get_global_context()->get_media_router().
@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	media_router_get_global :: proc "system" (callback: ^Completion_callback) -> ^Media_router ---
}


/// Implemented by the client to observe MediaRouter events. Called on the browser UI thread.
/// NOTE: This struct is allocated client-side.
Media_observer :: struct {
	// Base structure.
	base: base_ref_counted,

	// The list of available media sinks changed or notify_current_sinks was called.
	on_sinks: proc "system" (self: ^Media_observer, sinksCount: c.size_t, sinks: ^^Media_sink),

	// The list of available media routes changed or notify_current_routes was called.
	on_routes: proc "system" (self: ^Media_observer, routesCount: c.size_t, routes: ^^Media_route),

	// The connection state of |route| changed.
	on_route_state_changed: proc "system" (self: ^Media_observer, route: ^Media_route, state: Media_route_connection_state),

	// A message was received over |route|. |message| valid only for the scope of this callback.
	on_route_message_received: proc "system" (self: ^Media_observer, route: ^Media_route, message: rawptr, message_size: c.size_t),
}


/// Represents the route between a media source and sink. May be called on any browser
/// process thread unless otherwise indicated. NOTE: Allocated DLL-side.
Media_route :: struct {
	// Base structure.
	base: base_ref_counted,

	// Return the ID for this route. (Free with cef_string_userfree_free)
	get_id: proc "system" (self: ^Media_route) -> cef_string_userfree,

	// Return the source associated with this route.
	get_source: proc "system" (self: ^Media_route) -> ^Media_source,

	// Return the sink associated with this route.
	get_sink: proc "system" (self: ^Media_route) -> ^Media_sink,

	// Send a message over this route. |message| will be copied if necessary.
	send_route_message: proc "system" (self: ^Media_route, message: rawptr, message_size: c.size_t),

	// Terminate this route. Triggers Media_observer.on_routes on all observers.
	terminate: proc "system" (self: ^Media_route),
}


/// Callback for Media_router.create_route. Called on the browser UI thread.
/// NOTE: This struct is allocated client-side.
Media_route_create_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Executed when route creation finishes. |route| is NULL on failure.
	on_media_route_create_finished: proc "system" (
		self: ^Media_route_create_callback,
		result: Media_route_create_result,
		error: ^cef_string,
		route: ^Media_route,
	),
}


/// Represents a sink to which media can be routed. May be called on any browser
/// process thread unless otherwise indicated. NOTE: Allocated DLL-side.
Media_sink :: struct {
	// Base structure.
	base: base_ref_counted,

	// Return the sink ID. (Free with cef_string_userfree_free)
	get_id: proc "system" (self: ^Media_sink) -> cef_string_userfree,

	// Return the sink name. (Free with cef_string_userfree_free)
	get_name: proc "system" (self: ^Media_sink) -> cef_string_userfree,

	// Return the icon type for this sink.
	get_icon_type: proc "system" (self: ^Media_sink) -> Media_sink_icon_type,

	// Asynchronously retrieve device info.
	get_device_info: proc "system" (self: ^Media_sink, callback: ^Media_sink_device_info_callback),

	// True if this sink accepts content via Cast.
	is_cast_sink: proc "system" (self: ^Media_sink) -> c.int,

	// True if this sink accepts content via DIAL.
	is_dial_sink: proc "system" (self: ^Media_sink) -> c.int,

	// True if this sink is compatible with |source|.
	is_compatible_with: proc "system" (self: ^Media_sink, source: ^Media_source) -> c.int,
}


/// Callback for Media_sink.get_device_info. Called on the browser UI thread.
/// NOTE: This struct is allocated client-side.
Media_sink_device_info_callback :: struct {
	// Base structure.
	base: base_ref_counted,

	// Executed asynchronously once device information has been retrieved.
	on_media_sink_device_info: proc "system" (self: ^Media_sink_device_info_callback, device_info: ^Media_sink_device_info),
}


/// Represents a source from which media can be routed. May be called on any browser
/// process thread unless otherwise indicated. NOTE: Allocated DLL-side.
Media_source :: struct {
	// Base structure.
	base: base_ref_counted,

	// Return the ID (media source URN or URL). (Free with cef_string_userfree_free)
	get_id: proc "system" (self: ^Media_source) -> cef_string_userfree,

	// True if this source outputs content via Cast.
	is_cast_source: proc "system" (self: ^Media_source) -> c.int,

	// True if this source outputs content via DIAL.
	is_dial_source: proc "system" (self: ^Media_source) -> c.int,
}
