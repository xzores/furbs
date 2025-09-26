package vrtql_websockets

import "core:c"

//------------------------------------------------------------------------------
// Error handling
//------------------------------------------------------------------------------
Vws_error_code :: enum u32 {
	success    = 0,
	timeout    = 1 << 1,
	warn       = 1 << 2,
	socket     = 1 << 3,
	send       = 1 << 4,
	recv       = 1 << 5,
	sys        = 1 << 6,
	rt         = 1 << 7,
	mem        = 1 << 8,
	fatal      = 1 << 9,
}

Vws_trace_level :: enum u32 {
	off         = 0,
	application = 1,
	module      = 2,
	service     = 3,
	protocol    = 4,
	thread      = 5,
	tcpip       = 6,
	lock        = 7,
	memory      = 8,
	all         = 9,
}

Vws_error_value :: struct {
	code: u64,
	text: ^u8,
}

// external SSL context
vws_ssl_ctx: ^SSL_CTX

//------------------------------------------------------------------------------
// Tracing
//------------------------------------------------------------------------------
Vws_log_level :: enum u32 {
	debug,
	info,
	warn,
	error,
	level_count,
}

//Vws_trace_cb        : #type proc(level: Vws_log_level, fmt: cstring, ..)
Vws_malloc_cb       : #type proc(size: c.size_t) -> rawptr
Vws_free_cb         : #type proc(memory: rawptr)
Vws_malloc_error_cb : #type proc(size: c.size_t) -> rawptr
Vws_calloc_cb       : #type proc(nmemb: c.size_t, size: c.size_t) -> rawptr
Vws_calloc_error_cb : #type proc(nmemb: c.size_t, size: c.size_t) -> rawptr
Vws_realloc_cb      : #type proc(ptr: rawptr, size: c.size_t) -> rawptr
Vws_realloc_error_cb: #type proc(ptr: rawptr, size: c.size_t) -> rawptr
Vws_strdup_cb       : #type proc(ptr: cstring) -> rawptr
Vws_strdup_error_cb : #type proc(ptr: cstring) -> rawptr
Vws_error_submit_cb : #type proc(code: c.int, message: cstring, ..) -> c.int
Vws_error_process_cb: #type proc(code: c.int, message: cstring) -> c.int
Vws_error_clear_cb  : #type proc()

Vws_env :: struct {
	malloc: Vws_malloc_cb,
	malloc_error: Vws_malloc_error_cb,
	calloc: Vws_calloc_cb,
	calloc_error: Vws_calloc_error_cb,
	realloc: Vws_realloc_cb,
	realloc_error: Vws_realloc_error_cb,
	strdup: Vws_strdup_cb,
	strdup_error: Vws_strdup_error_cb,
	free: Vws_free_cb,
	error: Vws_error_submit_cb,
	process_error: Vws_error_process_cb,
	clear_error: Vws_error_clear_cb,
	success: Vws_error_clear_cb,
	e: Vws_error_value,
	trace: Vws_trace_cb,
	tracelevel: u8,
	state: u64,
	sslbuf: [4096]u8,
}

// global thread-local environment
vws: Vws_env

//------------------------------------------------------------------------------
// Buffers
//------------------------------------------------------------------------------
Vws_buffer :: struct {
	data: ^u8,
	allocated: c.size_t,
	size: c.size_t,
}

//------------------------------------------------------------------------------
// Maps
//------------------------------------------------------------------------------
Vws_value :: struct {
	data: rawptr,
	size: c.size_t,
}

Vws_kvp :: struct {
	key: cstring,
	value: Vws_value,
}

Vws_kvs_comp_fn : #type proc(a: rawptr, b: rawptr) -> c.int

Vws_kvs :: struct {
	array: ^Vws_kvp,
	used: c.size_t,
	size: c.size_t,
	cmp: Vws_kvs_comp_fn,
}

//------------------------------------------------------------------------------
// URLs
//------------------------------------------------------------------------------
Vws_url :: struct {
	scheme: ^u8,
	host: ^u8,
	port: ^u8,
	path: ^u8,
	query: ^u8,
	fragment: ^u8,
}

//------------------------------------------------------------------------------
// Foreign imports
//------------------------------------------------------------------------------
@(link_prefix="vws_", default_calling_convention="c")
foreign vws {
	// trace
	//trace         :: proc(level: Vws_log_level, format: cstring, ..) ---
	trace_lock    :: proc() ---
	trace_unlock  :: proc() ---

	// buffers
	buffer_new     :: proc() -> ^Vws_buffer ---
	buffer_free    :: proc(buffer: ^Vws_buffer) ---
	buffer_clear   :: proc(buffer: ^Vws_buffer) ---
	//buffer_printf  :: proc(buffer: ^Vws_buffer, format: cstring, ..) ---
	buffer_append  :: proc(buffer: ^Vws_buffer, data: ^u8, size: c.size_t) ---
	buffer_drain   :: proc(buffer: ^Vws_buffer, size: c.size_t) ---

	// maps
	map_get     :: proc(map: ^sc_map_str, key: cstring) -> cstring ---
	map_set     :: proc(map: ^sc_map_str, key: cstring, value: cstring) ---
	map_remove  :: proc(map: ^sc_map_str, key: cstring) ---
	map_clear   :: proc(map: ^sc_map_str) ---

	// kvs
	kvs_new           :: proc(size: c.size_t, case_sensitive: bool) -> ^Vws_kvs ---
	kvs_free          :: proc(m: ^Vws_kvs) ---
	kvs_clear         :: proc(m: ^Vws_kvs) ---
	kvs_size          :: proc(m: ^Vws_kvs) -> c.size_t ---
	kvs_set           :: proc(m: ^Vws_kvs, key: cstring, data: rawptr, size: c.size_t) ---
	kvs_get           :: proc(m: ^Vws_kvs, key: cstring) -> ^Vws_value ---
	kvs_set_cstring   :: proc(m: ^Vws_kvs, key: cstring, value: cstring) ---
	kvs_get_cstring   :: proc(m: ^Vws_kvs, key: cstring) -> cstring ---
	kvs_remove        :: proc(m: ^Vws_kvs, key: cstring) -> c.int ---

	// url
	url_parse :: proc(url: cstring) -> Vws_url ---
	url_build :: proc(parts: ^Vws_url) -> cstring ---
	url_new   :: proc() -> Vws_url ---
	url_free  :: proc(parts: Vws_url) ---

	// utilities
	msleep        :: proc(ms: c.uint) ---
	is_flag       :: proc(flags: ^u64, flag: u64) -> u8 ---
	set_flag      :: proc(flags: ^u64, flag: u64) ---
	clear_flag    :: proc(flags: ^u64, flag: u64) ---
	generate_uuid :: proc() -> cstring ---
	base64_encode :: proc(data: ^u8, size: c.size_t) -> cstring ---
	base64_decode :: proc(data: cstring, size: ^c.size_t) -> ^u8 ---
	file_path     :: proc(root: cstring, filename: cstring) -> cstring ---
	cstr_to_long  :: proc(str: cstring, value: ^c.long) -> bool ---
	cleanup       :: proc() ---
}
