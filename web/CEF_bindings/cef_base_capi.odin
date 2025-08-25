package odin_cef

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

import "core:c"

/// All ref-counted framework structures must include this structure first.
base_ref_counted :: struct {
	/// Size of the data structure.
	size: c.size_t,

	/// Called to increment the reference count for the object. Should be called for every new copy of a pointer to a given object.
	add_ref: proc "system" (self: ^base_ref_counted),

	/// Called to decrement the reference count for the object. If the reference count falls to 0 the object should self-delete. Returns true (1) if the
	/// resulting reference count is 0.
	release: proc "system" (self: ^base_ref_counted) -> b32,

	/// Returns true (1) if the current reference count is 1.
	has_one_ref: proc "system" (self: ^base_ref_counted) -> b32,

	/// Returns true (1) if the current reference count is at least 1.
	has_at_least_one_ref: proc "system" (self: ^base_ref_counted) -> b32,
}

/// All scoped framework structures must include this structure first.
base_scoped :: struct {
	/// Size of the data structure.
	size: c.size_t,

	/// Called to delete this object. May be NULL if the object is not owned.
	del: proc "system" (self: ^base_scoped),
} 

