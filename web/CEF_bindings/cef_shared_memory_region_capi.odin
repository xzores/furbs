package odin_cef

import "core:c"

/// Structure that wraps platform-dependent share memory region mapping.
/// NOTE: This struct is allocated DLL-side.
shared_memory_region :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if the mapping is valid.
	is_valid: proc "system" (self: ^shared_memory_region) -> b32,

	/// Returns the size of the mapping in bytes. Returns 0 for invalid instances.
	size: proc "system" (self: ^shared_memory_region) -> c.size_t,

	/// Returns the pointer to the memory. Returns nullptr for invalid instances. The returned pointer is only valid for the life span of this object.
	memory: proc "system" (self: ^shared_memory_region) -> rawptr,
} 