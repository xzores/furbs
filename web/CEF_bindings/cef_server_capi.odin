package odin_cef

import "core:c"

/// Structure representing a server that supports HTTP and WebSocket requests. Server capacity is limited and is intended to handle only a small number of
/// simultaneous connections (e.g. for communicating between applications on
/// localhost). The functions of this structure are safe to call from any thread
/// in the brower process unless otherwise indicated.
/// NOTE: This struct is allocated DLL-side.
server :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns the task runner for the dedicated server thread.
	get_task_runner: proc "system" (self: ^server) -> ^task_runner,

	/// Stop the server and shut down the dedicated server thread. See server_handler::on_server_created documentation for a description of
	/// server lifespan.
	shutdown: proc "system" (self: ^server),

	/// Returns true (1) if the server is currently running and accepting incoming connections. See server_handler::on_server_created documentation for a
	/// description of server lifespan. This function must be called on the
	/// dedicated server thread.
	is_running: proc "system" (self: ^server) -> b32,

	/// Returns the server address including the port number.
	get_address: proc "system" (self: ^server) -> cef_string_userfree,

	/// Returns true (1) if the server currently has a connection. This function must be called on the dedicated server thread.
	has_connection: proc "system" (self: ^server) -> b32,

	/// Returns true (1) if |connection_id| represents a valid connection. This function must be called on the dedicated server thread.
	is_valid_connection: proc "system" (self: ^server, connection_id: c.int) -> b32,

	/// Send an HTTP 200 "OK" response to the connection identified by |connection_id|. |content_type| is the response content type (e.g.
	/// "text/html"), |data| is the response content, and |data_size| is the size
	/// of |data| in bytes. The contents of |data| will be copied. The connection
	/// will be closed automatically after the response is sent.
	send_http200_response: proc "system" (self: ^server, connection_id: c.int, content_type: ^cef_string, data: rawptr, data_size: c.size_t),

	/// Send an HTTP 404 "Not Found" response to the connection identified by |connection_id|. The connection will be closed automatically after the
	/// response is sent.
	send_http404_response: proc "system" (self: ^server, connection_id: c.int),

	/// Send an HTTP 500 "Internal Server Error" response to the connection identified by |connection_id|. |error_message| is the associated error
	/// message. The connection will be closed automatically after the response is
	/// sent.
	send_http500_response: proc "system" (self: ^server, connection_id: c.int, error_message: ^cef_string),

	/// Send a custom HTTP response to the connection identified by |connection_id|. |response_code| is the HTTP response code sent in the
	/// status line (e.g. 200), |content_type| is the response content type sent
	/// as the "Content-Type" header (e.g. "text/html"), |content_length| is the
	/// expected content length, and |extra_headers| is the map of extra response
	/// headers. If |content_length| is >= 0 then the "Content-Length" header will
	/// be sent. If |content_length| is 0 then no content is expected and the
	/// connection will be closed automatically after the response is sent. If
	/// |content_length| is < 0 then no "Content-Length" header will be sent and
	/// the client will continue reading until the connection is closed. Use the
	/// send_raw_data function to send the content, if applicable, and call
	/// close_connection after all content has been sent.
	send_http_response: proc "system" (self: ^server, connection_id: c.int, response_code: c.int, content_type: ^cef_string, content_length: i64, extra_headers: string_multimap),

	/// Send raw data directly to the connection identified by |connection_id|. |data| is the raw data and |data_size| is the size of |data| in bytes. The
	/// contents of |data| will be copied. No validation of |data| is performed
	/// internally so the client should be careful to send the amount indicated by
	/// the "Content-Length" header, if specified. See send_http_response
	/// documentation for intended usage.
	send_raw_data: proc "system" (self: ^server, connection_id: c.int, data: rawptr, data_size: c.size_t),

	/// Close the connection identified by |connection_id|. See send_http_response documentation for intended usage.
	close_connection: proc "system" (self: ^server, connection_id: c.int),

	/// Send a WebSocket message to the connection identified by |connection_id|. |data| is the response content and |data_size| is the size of |data| in
	/// bytes. The contents of |data| will be copied. See
	/// server_handler::on_web_socket_request documentation for intended usage.
	send_web_socket_message: proc "system" (self: ^server, connection_id: c.int, data: rawptr, data_size: c.size_t),
}

/// Create a new server that binds to |address| and |port|. |address| must be a valid IPv4 or IPv6 address (e.g. 127.0.0.1 or ::1) and |port| must be a port
/// number outside of the reserved range (e.g. between 1025 and 65535 on most
/// platforms). |backlog| is the maximum number of pending connections. A new
/// thread will be created for each CreateServer call (the "dedicated server
/// thread"). It is therefore recommended to use a different CreateServer call
/// for each Server instance.
/// The server will continue running until server::shutdown() is called, after which time server_handler::on_server_destroyed() will be called on the
/// dedicated server thread. If the server fails to start then
/// server_handler::on_server_destroyed() will be called immediately after
/// server_handler::on_server_created() returns.
/// This function may be called on any thread in the browser process. The server_handler functions will be called on the dedicated server thread.
///
server_create :: proc "system" (address: ^cef_string, port: u16, backlog: c.int, handler: ^server_handler)

/// Implement this structure to handle server events. The functions of this structure will be called on the dedicated server thread.
/// NOTE: This struct is allocated client-side.
server_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called when |server| is created. If the server was started successfully then server::is_running will return true (1). The server will
	/// continue running until server::shutdown is called, after which time
	/// on_server_destroyed will be called. If the server failed to start then
	/// on_server_destroyed will be called immediately after this function returns.
	on_server_created: proc "system" (self: ^server_handler, server: ^server),

	/// Called when |server| is destroyed. The server thread will be stopped after this function returns. The client should release any references to
	/// |server| when this function is called. See on_server_created documentation
	/// for a description of server lifespan.
	on_server_destroyed: proc "system" (self: ^server_handler, server: ^server),

	/// Called when a client connects to |server|. |connection_id| uniquely identifies the connection. Each call to this function will have a matching
	/// call to on_client_disconnected.
	on_client_connected: proc "system" (self: ^server_handler, server: ^server, connection_id: c.int),

	/// Called when a client disconnects from |server|. |connection_id| uniquely identifies the connection. The client should release any data associated
	/// with |connection_id| when this function is called and |connection_id|
	/// should no longer be passed to server functions. Disconnects can
	/// originate from either the client or the server. For example, the server
	/// will disconnect automatically after a server::send_http_xxx_response
	/// function is called.
	on_client_disconnected: proc "system" (self: ^server_handler, server: ^server, connection_id: c.int),

	/// Called when |server| receives an HTTP request. |connection_id| uniquely identifies the connection, |client_address| is the requesting IPv4 or IPv6
	/// client address including port number, and |request| contains the request
	/// contents (URL, function, headers and optional POST data). Call
	/// server functions either synchronously or asynchronusly to send a
	/// response.
	on_http_request: proc "system" (self: ^server_handler, server: ^server, connection_id: c.int, client_address: ^cef_string, request: ^Request),

	/// Called when |server| receives a WebSocket request. |connection_id| uniquely identifies the connection, |client_address| is the requesting
	/// IPv4 or IPv6 client address including port number, and |request| contains
	/// the request contents (URL, function, headers and optional POST data).
	/// Execute |callback| either synchronously or asynchronously to accept or
	/// decline the WebSocket connection. If the request is accepted then
	/// on_web_socket_connected will be called after the WebSocket has connected and
	/// incoming messages will be delivered to the on_web_socket_message callback. If
	/// the request is declined then the client will be disconnected and
	/// on_client_disconnected will be called. Call the
	/// server::send_web_socket_message function after receiving the
	/// on_web_socket_connected callback to respond with WebSocket messages.
	on_web_socket_request: proc "system" (self: ^server_handler, server: ^server, connection_id: c.int, client_address: ^cef_string, request: ^Request, callback: ^cef_callback),

	/// Called after the client has accepted the WebSocket connection for |server| and |connection_id| via the on_web_socket_request callback. See
	/// on_web_socket_request documentation for intended usage.
	on_web_socket_connected: proc "system" (self: ^server_handler, server: ^server, connection_id: c.int),

	/// Called when |server| receives an WebSocket message. |connection_id| uniquely identifies the connection, |data| is the message content and
	/// |data_size| is the size of |data| in bytes. Do not keep a reference to
	/// |data| outside of this function. See on_web_socket_request documentation for
	/// intended usage.
	on_web_socket_message: proc "system" (self: ^server_handler, server: ^server, connection_id: c.int, data: rawptr, data_size: c.size_t),
} 