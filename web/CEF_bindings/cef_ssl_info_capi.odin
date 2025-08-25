package odin_cef

import "core:c"

/// Structure representing SSL information.
/// NOTE: This struct is allocated DLL-side.
ssl_info :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns a bitmask containing any and all problems verifying the server
	/// certificate.
	get_cert_status: proc "system" (self: ^ssl_info) -> Cert_status,

	/// Returns the X.509 certificate.
	get_x509_certificate: proc "system" (self: ^ssl_info) -> ^X509_certificate,
}

/// Returns true (1) if the certificate status represents an error.
is_cert_status_error :: proc "system" (status: Cert_status) -> b32 