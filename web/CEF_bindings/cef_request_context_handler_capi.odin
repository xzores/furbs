package odin_cef

import "core:c"

// Implement this structure to provide handler implementations. The handler instance will not be
// released until all objects related to the context have been destroyed.
// NOTE: This struct is allocated client-side.
Request_context_handler :: struct {
	// Base structure.
	base: base_ref_counted,

	// Called on the browser process UI thread immediately after the request context has been initialized.
	on_request_context_initialized: proc "system" (
		self: ^Request_context_handler,
		Request_context: ^Request_context,
	),

	// Called on the browser process IO thread before a resource request is initiated.
	// |browser| and |frame| are the request source (may be nil for service workers or cef_urlrequest).
	// |request| contents cannot be modified here.
	// |is_navigation|=1 if this is a navigation; |is_download|=1 if this is a download.
	// |request_initiator| is the origin (scheme + domain) that initiated the request.
	// Set *disable_default_handling=1 to disable default handling; then handle via
	// cef_resource_request_handler::GetResourceHandler or the request will be canceled.
	// Return nil to proceed with default handling, or return a cef_resource_request_handler to handle.
	// Not called if the browser client’s request_handler returns a non-nil
	// GetResourceRequestHandler for the same request (by request identifier).
	get_resource_request_handler: proc "system" (
		self: ^Request_context_handler,
		browser: ^Browser,
		frame: ^Frame,
		request: ^Request,
		is_navigation: c.int,
		is_download: c.int,
		request_initiator: ^cef_string,
		disable_default_handling: ^c.int,
	) -> ^Resource_request_handler,
}