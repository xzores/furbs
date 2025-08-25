package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

/// Structure used to represent a frame in the browser window. When used in the
/// browser process the functions of this structure may be called on any thread
/// unless otherwise indicated in the comments. When used in the render process
/// the functions of this structure may only be called on the main thread.
///
/// NOTE: This struct is allocated DLL-side.
Frame :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// True if this object is currently attached to a valid frame.
	is_valid: proc "system" (self: ^Frame) -> c.int,

	/// Execute undo in this frame.
	undo: proc "system" (self: ^Frame),

	/// Execute redo in this frame.
	redo: proc "system" (self: ^Frame),

	/// Execute cut in this frame.
	cut: proc "system" (self: ^Frame),

	/// Execute copy in this frame.
	copy: proc "system" (self: ^Frame),

	/// Execute paste in this frame.
	paste: proc "system" (self: ^Frame),

	/// Execute paste and match style in this frame.
	paste_and_match_style: proc "system" (self: ^Frame),

	/// Execute delete in this frame.
	del: proc "system" (self: ^Frame),

	/// Execute select all in this frame.
	select_all: proc "system" (self: ^Frame),

	/// Save this frame's HTML source to a temporary file and open it in the
	/// default text viewing application. This function can only be called from
	/// the browser process.
	view_source: proc "system" (self: ^Frame),

	/// Retrieve this frame's HTML source as a string sent to the specified
	/// visitor.
	get_source: proc "system" (self: ^Frame, visitor: ^string_visitor),

	/// Retrieve this frame's display text as a string sent to the specified
	/// visitor.
	get_text: proc "system" (self: ^Frame, visitor: ^string_visitor),

	/// Load the request represented by the |request| object.
	/// WARNING: This function will fail with "bad IPC message" reason INVALID_INITIATOR_ORIGIN (213) unless you first navigate to the request
	/// origin using some other mechanism (LoadURL, link click, etc).
	load_request: proc "system" (self: ^Frame, request: ^Request),

	/// Load the specified |url|.
	load_url: proc "system" (self: ^Frame, url: ^cef_string),

	/// Execute a string of JavaScript code in this frame. The |script_url|
	/// parameter is the URL where the script in question can be found, if any.
	/// The renderer may request this URL to show the developer the source of the
	/// error.	The |start_line| parameter is the base line number to use for
	/// error reporting.
	execute_java_script: proc "system" (self: ^Frame, code: ^cef_string, script_url: ^cef_string, start_line: c.int),

	/// Returns true (1) if this is the main (top-level) frame.
	is_main: proc "system" (self: ^Frame) -> c.int,

	/// Returns true (1) if this is the focused frame.
	is_focused: proc "system" (self: ^Frame) -> c.int,

	/// Returns the name for this frame. If the frame has an assigned name (for
	/// example, set via the iframe "name" attribute) then that value will be
	/// returned. Otherwise a unique name will be constructed based on the frame
	/// parent hierarchy. The main (top-level) frame will always have an NULL name
	/// value.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_name: proc "system" (self: ^Frame) -> cef_string_userfree,

	/// Returns the globally unique identifier for this frame or NULL if the
	/// underlying frame does not yet exist.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_identifier: proc "system" (self: ^Frame) -> cef_string_userfree,

	/// Returns the parent of this frame or NULL if this is the main (top-level)
	/// frame.
	get_parent: proc "system" (self: ^Frame) -> ^Frame,

	/// Returns the URL currently loaded in this frame.
	// The resulting string must be freed by calling cef_string_userfree_free().
	get_url: proc "system" (self: ^Frame) -> cef_string_userfree,

	/// Returns the browser that this frame belongs to.
		get_browser: proc "system" (self: ^Frame) -> ^Browser,

	/// Get the V8 context associated with the frame. This function can only be
	/// called from the render process.
	get_V8_context: proc "system" (self: ^Frame) -> ^V8_context,

	/// Visit the DOM document. This function can only be called from the render
	/// process.
	visit_dom: proc "system" (self: ^Frame, visitor: ^Dom_visitor),

	/// Create a new URL request that will be treated as originating from this
	/// frame and the associated browser. Use cef_urlrequest_t::Create instead if
	/// you do not want the request to have this association, in which case it may
	/// be handled differently (see documentation on that function). A request
	/// created with this function may only originate from the browser process,
	/// and will behave as follows:
	///	 - It may be intercepted by the client via CefResourceRequestHandler or
	///	 CefSchemeHandlerFactory.
	///	 - POST data may only contain a single element of type PDE_TYPE_FILE or
	///	 PDE_TYPE_BYTES.
	/// The |request| object will be marked as read-only after calling this function.
	create_urlrequest: proc "system" (self: ^Frame, request: ^Request, client: ^Url_request_client) -> ^Url_request,

	/// Send a message to the specified |target_process|. Ownership of the message
	/// contents will be transferred and the |message| reference will be
	/// invalidated. Message delivery is not guaranteed in all cases (for example,
	/// if the browser is closing, navigating, or if the target process crashes).
	/// Send an ACK message back from the target process if confirmation is
	/// required.
	send_process_message: proc "system" (self: ^Frame, target_process: cef_process_id, message: ^Process_message),
} 