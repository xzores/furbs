package odin_cef

import "core:c"

/// Structure representing the SSL information for a navigation entry.
/// NOTE: This struct is allocated DLL-side.
///
Ssl_status :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if the status is related to a secure SSL/TLS connection.
	is_secure_connection: proc "system" (self: ^Ssl_status) -> b32,

	/// Returns a bitmask containing any and all problems verifying the server certificate.
	get_cert_status: proc "system" (self: ^Ssl_status) -> Cert_status,

	/// Returns the SSL version used for the SSL connection.
	get_sslversion: proc "system" (self: ^Ssl_status) -> Ssl_version,

	/// Returns a bitmask containing the page security content status.
	get_content_status: proc "system" (self: ^Ssl_status) -> Ssl_content_status,

	/// Returns the X.509 certificate.
	get_x509_certificate: proc "system" (self: ^Ssl_status) -> ^X509_certificate,
} 