package cef_internal;

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "../CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "../CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "../CEF/Release/libcef.dylib"
}

/// CEF string type definitions. Whoever allocates `str` must provide an
/// appropriate `dtor` that frees the string in the same memory space.
/// When reusing an existing string, call `dtor` for the old value before
/// assigning new `str`/`dtor` values. Static strings will have a nil `dtor`.
cef_string_wide :: struct {
	str:   ^c.wchar_t,
	length: c.size_t,
	dtor:  proc "system" (str: ^c.wchar_t),
}

cef_string_utf8 :: struct {
	str:   ^u8,
	length: c.size_t,
	dtor:  proc "system" (str: ^u8),
}

cef_string_utf16 :: struct {
	str:   ^u16,
	length: c.size_t,
	dtor:  proc "system" (str: ^u16),
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Set string values. If `copy` is 1 the value will be copied.
	string_wide_set  :: proc (src: ^c.wchar_t, src_len: c.size_t, output: ^cef_string_wide,  copy: c.int) -> c.int ---
	string_utf8_set  :: proc (src: ^u8,         src_len: c.size_t, output: ^cef_string_utf8,  copy: c.int) -> c.int ---
	string_utf16_set :: proc (src: ^u16,        src_len: c.size_t, output: ^cef_string_utf16, copy: c.int) -> c.int ---

	// Clear string values (does not free the struct itself).
	string_wide_clear  :: proc (str: ^cef_string_wide)  ---
	string_utf8_clear  :: proc (str: ^cef_string_utf8)  ---
	string_utf16_clear :: proc (str: ^cef_string_utf16) ---

	// strcmp-style comparisons.
	string_wide_cmp  :: proc (str1: ^cef_string_wide,  str2: ^cef_string_wide)  -> c.int ---
	string_utf8_cmp  :: proc (str1: ^cef_string_utf8,  str2: ^cef_string_utf8)  -> c.int ---
	string_utf16_cmp :: proc (str1: ^cef_string_utf16, str2: ^cef_string_utf16) -> c.int ---

	// Conversions between UTF-8/16 and wide.
	string_wide_to_utf8  :: proc (src: ^c.wchar_t, src_len: c.size_t, output: ^cef_string_utf8)  -> c.int ---
	string_utf8_to_wide  :: proc (src: ^u8,        src_len: c.size_t, output: ^cef_string_wide)  -> c.int ---
	string_wide_to_utf16 :: proc (src: ^c.wchar_t, src_len: c.size_t, output: ^cef_string_utf16) -> c.int ---
	string_utf16_to_wide :: proc (src: ^u16,       src_len: c.size_t, output: ^cef_string_wide)  -> c.int ---
	string_utf8_to_utf16 :: proc (src: ^u8,        src_len: c.size_t, output: ^cef_string_utf16) -> c.int ---
	string_utf16_to_utf8 :: proc (src: ^u16,       src_len: c.size_t, output: ^cef_string_utf8)  -> c.int ---

	// ASCII helpers (for known-ASCII literals).
	string_ascii_to_wide  :: proc (src: ^u8,  src_len: c.size_t, output: ^cef_string_wide)  -> c.int ---
	string_ascii_to_utf16 :: proc (src: ^u8,  src_len: c.size_t, output: ^cef_string_utf16) -> c.int ---

	// Userfree alloc/free (caller must free).
	string_userfree_wide_alloc  :: proc () -> ^cef_string_wide  ---
	string_userfree_utf8_alloc  :: proc () -> ^cef_string_utf8  ---
	string_userfree_utf16_alloc :: proc () -> ^cef_string_utf16 ---

	string_userfree_wide_free  :: proc (str: ^cef_string_wide)  ---
	string_userfree_utf8_free  :: proc (str: ^cef_string_utf8)  ---
	string_userfree_utf16_free :: proc (str: ^cef_string_utf16) ---

	// UTF-16 case conversion using current ICU locale.
	string_utf16_to_lower :: proc (src: ^u16, src_len: c.size_t, output: ^cef_string_utf16) -> c.int ---
	string_utf16_to_upper :: proc (src: ^u16, src_len: c.size_t, output: ^cef_string_utf16) -> c.int ---
}

// Convenience “macros” as inline helpers (Odin doesn’t use C macros).
string_wide_copy  :: proc (src: ^c.wchar_t, src_len: c.size_t, output: ^cef_string_wide)  -> c.int { return string_wide_set(src,  src_len, output, c.int(1)) }
string_utf8_copy  :: proc (src: ^u8,        src_len: c.size_t, output: ^cef_string_utf8)  -> c.int { return string_utf8_set(src,  src_len, output, c.int(1)) }
string_utf16_copy :: proc (src: ^u16,       src_len: c.size_t, output: ^cef_string_utf16) -> c.int { return string_utf16_set(src, src_len, output, c.int(1)) }

// Userfree pointer aliases (mirroring C typedefs).
cef_string_userfree_wide  :: ^cef_string_wide;
cef_string_userfree_utf8  :: ^cef_string_utf8;
cef_string_userfree_utf16 :: ^cef_string_utf16;
