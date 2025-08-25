package odin_cef

import "core:c"

/// Generic callback structure used for managing the lifespan of a registration.
/// NOTE: This struct is allocated DLL-side.
Registration :: struct {
	base: base_ref_counted,
} 
