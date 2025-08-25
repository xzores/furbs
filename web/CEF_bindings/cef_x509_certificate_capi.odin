package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import cef "cef.dll"
} else {
	foreign import cef "libcef.so"
}

cef_x509_cert_principal_t :: struct {
	base: base_ref_counted,
	
	get_display_name: proc "system" (self: ^cef_x509_cert_principal_t) -> cef_string_userfree,
	get_common_name: proc "system" (self: ^cef_x509_cert_principal_t) -> cef_string_userfree,
	get_locality_name: proc "system" (self: ^cef_x509_cert_principal_t) -> cef_string_userfree,
	get_state_or_province_name: proc "system" (self: ^cef_x509_cert_principal_t) -> cef_string_userfree,
	get_country_name: proc "system" (self: ^cef_x509_cert_principal_t) -> cef_string_userfree,
	get_organization_names: proc "system" (self: ^cef_x509_cert_principal_t, names: string_list),
	get_organization_unit_names: proc "system" (self: ^cef_x509_cert_principal_t, names: string_list),
}

X509_certificate :: struct {
	base: base_ref_counted,
	
	get_subject: proc "system" (self: ^X509_certificate) -> ^cef_x509_cert_principal_t,
	get_issuer: proc "system" (self: ^X509_certificate) -> ^cef_x509_cert_principal_t,
	get_serial_number: proc "system" (self: ^X509_certificate) -> ^cef_binary_value,
	get_valid_start: proc "system" (self: ^X509_certificate) -> Basetime,
	get_valid_expiry: proc "system" (self: ^X509_certificate) -> Basetime,
	get_derencoded: proc "system" (self: ^X509_certificate) -> ^cef_binary_value,
	get_pemencoded: proc "system" (self: ^X509_certificate) -> ^cef_binary_value,
	get_issuer_chain_size: proc "system" (self: ^X509_certificate) -> c.size_t,
	get_derencoded_issuer_chain: proc "system" (self: ^X509_certificate, chain_count: ^c.size_t, chain: ^^cef_binary_value),
	get_pemencoded_issuer_chain: proc "system" (self: ^X509_certificate, chain_count: ^c.size_t, chain: ^^cef_binary_value),
} 