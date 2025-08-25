package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

// Structure that wraps other data value types. Complex types (binary, dictionary and list)
// will be referenced but not owned by this object. Can be used on any process and thread.
// NOTE: This struct is allocated DLL-side.
cef_value :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if the underlying data is valid (always true for simple types). For complex types
	// the data may become invalid if owned by another object that is modified/destroyed. This
	// value object can be re-used via Set*() even if data is invalid.
	is_valid: proc "system" (self: ^cef_value) -> c.int,

	// Returns 1 if the underlying data is owned by another object.
	is_owned: proc "system" (self: ^cef_value) -> c.int,

	// Returns 1 if the underlying data is read-only (some APIs expose read-only objects).
	is_read_only: proc "system" (self: ^cef_value) -> c.int,

	// Returns 1 if this and |that| share the same underlying data (mutations affect both).
	is_same: proc "system" (self: ^cef_value, that: ^cef_value) -> c.int,

	// Returns 1 if this and |that| have equivalent values (not necessarily the same object).
	is_equal: proc "system" (self: ^cef_value, that: ^cef_value) -> c.int,

	// Returns a copy of this object; underlying data is also copied.
	copy: proc "system" (self: ^cef_value) -> ^cef_value,

	// Returns the underlying value type.
	get_type: proc "system" (self: ^cef_value) -> cef_value,

	// Returns the underlying value as bool (1/0).
	get_bool: proc "system" (self: ^cef_value) -> c.int,

	// Returns the underlying value as int.
	get_int: proc "system" (self: ^cef_value) -> c.int,

	// Returns the underlying value as double.
	get_double: proc "system" (self: ^cef_value) -> f64,

	// Returns the underlying value as string. Result must be freed with cef_string_userfree_free().
	get_string: proc "system" (self: ^cef_value) -> cef_string_userfree,

	// Returns the underlying value as binary. Reference may become invalid if ownership changes.
	// To maintain a reference after assigning to a container, pass this object to set_value()
	// instead of using set_binary() with the returned reference.
	get_binary: proc "system" (self: ^cef_value) -> ^cef_binary_value,

	// Returns the underlying value as dictionary. See note above regarding ownership.
	get_dictionary: proc "system" (self: ^cef_value) -> ^cef_dictionary_value,

	// Returns the underlying value as list. See note above regarding ownership.
	get_list: proc "system" (self: ^cef_value) -> ^cef_list_value,

	// Sets the value to null. Returns 1 on success.
	set_null: proc "system" (self: ^cef_value) -> c.int,

	// Sets the value as bool. Returns 1 on success.
	set_bool: proc "system" (self: ^cef_value, value: c.int) -> c.int,

	// Sets the value as int. Returns 1 on success.
	set_int: proc "system" (self: ^cef_value, value: c.int) -> c.int,

	// Sets the value as double. Returns 1 on success.
	set_double: proc "system" (self: ^cef_value, value: f64) -> c.int,

	// Sets the value as string. Returns 1 on success.
	set_string: proc "system" (self: ^cef_value, value: ^cef_string) -> c.int,

	// Sets the value as binary. Keeps a reference to |value|; ownership unchanged. Returns 1 on success.
	set_binary: proc "system" (self: ^cef_value, value: ^cef_binary_value) -> c.int,

	// Sets the value as dictionary. Keeps a reference to |value|; ownership unchanged. Returns 1 on success.
	set_dictionary: proc "system" (self: ^cef_value, value: ^cef_dictionary_value) -> c.int,

	// Sets the value as list. Keeps a reference to |value|; ownership unchanged. Returns 1 on success.
	set_list: proc "system" (self: ^cef_value, value: ^cef_list_value) -> c.int,
}

// Structure representing a binary value. Can be used on any process and thread.
// NOTE: This struct is allocated DLL-side.
cef_binary_value :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if this object is valid. May become invalid if owned by another object
	// (e.g., list/dictionary) that is later modified or destroyed. Do not call other
	// functions if this returns 0.
	is_valid: proc "system" (self: ^cef_binary_value) -> c.int,

	// Returns 1 if this object is currently owned by another object.
	is_owned: proc "system" (self: ^cef_binary_value) -> c.int,

	// Returns 1 if this and |that| have the same underlying data.
	is_same: proc "system" (self: ^cef_binary_value, that: ^cef_binary_value) -> c.int,

	// Returns 1 if this and |that| have an equivalent underlying value (not necessarily the same object).
	is_equal: proc "system" (self: ^cef_binary_value, that: ^cef_binary_value) -> c.int,

	// Returns a copy of this object; data is also copied.
	copy: proc "system" (self: ^cef_binary_value) -> ^cef_binary_value,

	// Returns pointer to the start of the memory block. Valid while the cef_binary_value is alive.
	get_raw_data: proc "system" (self: ^cef_binary_value) -> rawptr,

	// Returns the data size.
	get_size: proc "system" (self: ^cef_binary_value) -> c.size_t,

	// Read up to |buffer_size| bytes into |buffer| starting at |data_offset|. Returns number of bytes read.
	get_data: proc "system" (self: ^cef_binary_value, buffer: rawptr, buffer_size: c.size_t, data_offset: c.size_t) -> c.size_t,
}

// Structure representing a dictionary value. Can be used on any process and thread.
// NOTE: This struct is allocated DLL-side.
cef_dictionary_value :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if this object is valid. May become invalid if owned by another object
	// (e.g., list/dictionary) that is later modified or destroyed. Do not call other
	// functions if this returns 0.
	is_valid: proc "system" (self: ^cef_dictionary_value) -> c.int,

	// Returns 1 if this object is currently owned by another object.
	is_owned: proc "system" (self: ^cef_dictionary_value) -> c.int,

	// Returns 1 if values are read-only (some APIs expose read-only objects).
	is_read_only: proc "system" (self: ^cef_dictionary_value) -> c.int,

	// Returns 1 if this and |that| share the same underlying data (mutations affect both).
	is_same: proc "system" (self: ^cef_dictionary_value, that: ^cef_dictionary_value) -> c.int,

	// Returns 1 if this and |that| have equivalent values (not necessarily the same object).
	is_equal: proc "system" (self: ^cef_dictionary_value, that: ^cef_dictionary_value) -> c.int,

	// Returns a writable copy. If exclude_empty_children is 1, NULL dictionaries/lists are excluded.
	copy: proc "system" (self: ^cef_dictionary_value, exclude_empty_children: c.int) -> ^cef_dictionary_value,

	// Number of values.
	get_size: proc "system" (self: ^cef_dictionary_value) -> c.size_t,

	// Removes all values. Returns 1 on success.
	clear: proc "system" (self: ^cef_dictionary_value) -> c.int,

	// Returns 1 if a value exists for |key|.
	has_key: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> c.int,

	// Reads all keys into |keys|.
	get_keys: proc "system" (self: ^cef_dictionary_value, keys: string_list) -> c.int,

	// Removes the value at |key|. Returns 1 on success.
	remove: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> c.int,

	// Returns the value type at |key|.
	get_type: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> cef_value_type,

	// Returns the value at |key|. Simple types copy data; complex types (binary/dict/list) reference existing data.
	get_value: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> ^cef_value,

	// Returns the value at |key| as bool.
	get_bool: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> c.int,

	// Returns the value at |key| as int.
	get_int: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> c.int,

	// Returns the value at |key| as double.
	get_double: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> f64,

	// Returns the value at |key| as string. Result must be freed with cef_string_userfree_free().
	get_string: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> cef_string_userfree,

	// Returns the value at |key| as binary (references existing data).
	get_binary: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> ^cef_binary_value,

	// Returns the value at |key| as dictionary (references existing data; mutations modify this object).
	get_dictionary: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> ^cef_dictionary_value,

	// Returns the value at |key| as list (references existing data; mutations modify this object).
	get_list: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> ^cef_list_value,

	// Sets the value at |key|. Returns 1 on success. Simple data is copied; complex data is referenced.
	set_value: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: ^cef_value) -> c.int,

	// Sets null at |key|. Returns 1 on success.
	set_null: proc "system" (self: ^cef_dictionary_value, key: ^cef_string) -> c.int,

	// Sets bool at |key|. Returns 1 on success.
	set_bool: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: c.int) -> c.int,

	// Sets int at |key|. Returns 1 on success.
	set_int: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: c.int) -> c.int,

	// Sets double at |key|. Returns 1 on success.
	set_double: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: f64) -> c.int,

	// Sets string at |key|. Returns 1 on success.
	set_string: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: ^cef_string) -> c.int,

	// Sets binary at |key|. If |value| owned by another object it will be copied; otherwise ownership is transferred and |value| reference is invalidated. Returns 1 on success.
	set_binary: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: ^cef_binary_value) -> c.int,

	// Sets dictionary at |key|. Same ownership semantics as set_binary. Returns 1 on success.
	set_dictionary: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: ^cef_dictionary_value) -> c.int,

	// Sets list at |key|. Same ownership semantics as set_binary. Returns 1 on success.
	set_list: proc "system" (self: ^cef_dictionary_value, key: ^cef_string, value: ^cef_list_value) -> c.int,
}

// Structure representing a list value. Can be used on any process and thread.
// NOTE: This struct is allocated DLL-side.
cef_list_value :: struct {
	// Base structure.
	base: base_ref_counted,

	// Returns 1 if this object is valid. May become invalid if owned by another object
	// (e.g., list/dictionary) that is later modified or destroyed. Do not call other
	// functions if this returns 0.
	is_valid:	proc "system" (self: ^cef_list_value) -> c.int,

	// Returns 1 if this object is currently owned by another object.
	is_owned:	proc "system" (self: ^cef_list_value) -> c.int,

	// Returns 1 if the values of this object are read-only (some APIs expose read-only objects).
	is_read_only: proc "system" (self: ^cef_list_value) -> c.int,

	// Returns 1 if this and |that| share the same underlying data (mutations affect both).
	is_same:	 proc "system" (self: ^cef_list_value, that: ^cef_list_value) -> c.int,

	// Returns 1 if this and |that| have equivalent values (not necessarily the same object).
	is_equal:	proc "system" (self: ^cef_list_value, that: ^cef_list_value) -> c.int,

	// Returns a writable copy of this object.
	copy:		proc "system" (self: ^cef_list_value) -> ^cef_list_value,

	// Sets the number of values. New slots default to null. Returns 1 on success.
	set_size:	proc "system" (self: ^cef_list_value, size: c.size_t) -> c.int,

	// Number of values.
	get_size:	proc "system" (self: ^cef_list_value) -> c.size_t,

	// Removes all values. Returns 1 on success.
	clear:		 proc "system" (self: ^cef_list_value) -> c.int,

	// Removes the value at |index|.
	remove:		proc "system" (self: ^cef_list_value, index: c.size_t) -> c.int,

	// Returns the value type at |index|.
	get_type:	proc "system" (self: ^cef_list_value, index: c.size_t) -> cef_value_type,

	// Returns the value at |index|. Simple types copy data; complex types reference existing data.
	get_value:	 proc "system" (self: ^cef_list_value, index: c.size_t) -> ^cef_value,

	// Returns the value at |index| as bool.
	get_bool:	proc "system" (self: ^cef_list_value, index: c.size_t) -> c.int,

	// Returns the value at |index| as int.
	get_int:	 proc "system" (self: ^cef_list_value, index: c.size_t) -> c.int,

	// Returns the value at |index| as double.
	get_double:	proc "system" (self: ^cef_list_value, index: c.size_t) -> f64,

	// Returns the value at |index| as string. Result must be freed with cef_string_userfree_free().
	get_string:	proc "system" (self: ^cef_list_value, index: c.size_t) -> cef_string_userfree,

	// Returns the value at |index| as binary (references existing data).
	get_binary:	proc "system" (self: ^cef_list_value, index: c.size_t) -> ^cef_binary_value,

	// Returns the value at |index| as dictionary (references existing data; mutations modify this object).
	get_dictionary: proc "system" (self: ^cef_list_value, index: c.size_t) -> ^cef_dictionary_value,

	// Returns the value at |index| as list (references existing data; mutations modify this object).
	get_list:	proc "system" (self: ^cef_list_value, index: c.size_t) -> ^cef_list_value,

	// Sets the value at |index|. Returns 1 on success. Simple data is copied; complex data is referenced.
	set_value:	 proc "system" (self: ^cef_list_value, index: c.size_t, value: ^cef_value) -> c.int,

	// Sets null at |index|. Returns 1 on success.
	set_null:	proc "system" (self: ^cef_list_value, index: c.size_t) -> c.int,

	// Sets bool at |index|. Returns 1 on success.
	set_bool:	proc "system" (self: ^cef_list_value, index: c.size_t, value: c.int) -> c.int,

	// Sets int at |index|. Returns 1 on success.
	set_int:	 proc "system" (self: ^cef_list_value, index: c.size_t, value: c.int) -> c.int,

	// Sets double at |index|. Returns 1 on success.
	set_double:	proc "system" (self: ^cef_list_value, index: c.size_t, value: f64) -> c.int,

	// Sets string at |index|. Returns 1 on success.
	set_string:	proc "system" (self: ^cef_list_value, index: c.size_t, value: ^cef_string) -> c.int,

	// Sets binary at |index|. If |value| owned by another object it is copied; otherwise ownership is transferred and the |value| reference is invalidated. Returns 1 on success.
	set_binary:	proc "system" (self: ^cef_list_value, index: c.size_t, value: ^cef_binary_value) -> c.int,

	// Sets dictionary at |index|. Same ownership semantics as set_binary. Returns 1 on success.
	set_dictionary: proc "system" (self: ^cef_list_value, index: c.size_t, value: ^cef_dictionary_value) -> c.int,

	// Sets list at |index|. Same ownership semantics as set_binary. Returns 1 on success.
	set_list:	proc "system" (self: ^cef_list_value, index: c.size_t, value: ^cef_list_value) -> c.int,
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Creates a new object.
	value_create :: proc "system" () -> ^cef_value ---

	/// Creates a new object that is not owned by any other object.
	dictionary_value_create :: proc "system" () -> ^cef_dictionary_value ---

	/// Creates a new object that is not owned by any other object. The specified |data| will be copied.
	binary_value_create :: proc "system" (data: rawptr, data_size: c.size_t) -> ^cef_binary_value ---

	/// Creates a new object that is not owned by any other object.
	list_value_create :: proc "system" () -> ^cef_list_value ---
}
