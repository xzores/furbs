package vrtql_websockets

import "core:c"

//------------------------------------------------------------------------------
// Version and Limits
//------------------------------------------------------------------------------
URL_VERSION :: "0.2.1"

URL_PROTOCOL_MAX_LENGTH :: 32
URL_HOSTNAME_MAX_LENGTH :: 128
URL_TLD_MAX_LENGTH :: 16
URL_AUTH_MAX_LENGTH :: 32

//------------------------------------------------------------------------------
// URL Data
//------------------------------------------------------------------------------
Url_data :: struct {
	href:     cstring,
	protocol: cstring,
	host:     cstring,
	auth:     cstring,
	hostname: cstring,
	pathname: cstring,
	search:   cstring,
	path:     cstring,
	hash:     cstring,
	query:    cstring,
	port:     cstring,
}

//------------------------------------------------------------------------------
// Foreign Imports
//------------------------------------------------------------------------------
@(link_prefix="url_", default_calling_convention="c")
foreign url {
	parse          :: proc(url: cstring) -> ^Url_data ---
	get_protocol   :: proc(url: cstring) -> cstring ---
	get_auth       :: proc(url: cstring) -> cstring ---
	get_hostname   :: proc(url: cstring) -> cstring ---
	get_host       :: proc(url: cstring) -> cstring ---
	get_pathname   :: proc(url: cstring) -> cstring ---
	get_path       :: proc(url: cstring) -> cstring ---
	get_search     :: proc(url: cstring) -> cstring ---
	get_query      :: proc(url: cstring) -> cstring ---
	get_hash       :: proc(url: cstring) -> cstring ---
	get_port       :: proc(url: cstring) -> cstring ---

	free           :: proc(data: ^Url_data) ---

	is_protocol    :: proc(str: cstring) -> bool ---
	is_ssh         :: proc(str: cstring) -> bool ---

	inspect        :: proc(url: cstring) ---
	data_inspect   :: proc(data: ^Url_data) ---
}
