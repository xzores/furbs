package odin_cef

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

import "core:c"

//THESE Are fixed here in these bindings
// Added July 09, 2025.
CEF_API_VERSION_13900 :: 13900

when ODIN_OS == .Windows {
	CEF_API_HASH_13900 :: "707508ab72072116ce0500e3d2bdd9f34b2d5cd8"
}
when ODIN_OS == .Darwin {
	CEF_API_HASH_13900 :: "9b3ef316d9a3f554899c36139cfccb17767ca254"
}
when ODIN_OS == .Linux {
	CEF_API_HASH_13900 :: "fd0b7f8ab5869224972340454690a42e91939488"
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Configure the CEF API version and return an API hash string owned by the library.
	// |version| should be CEF_API_VERSION (ignored after first call).
	// |entry| selects which hash to return:
	//   0 - CEF_API_HASH_PLATFORM
	//   1 - CEF_API_HASH_UNIVERSAL (deprecated, same as PLATFORM)
	//   2 - CEF_COMMIT_HASH (from cef_version.h)
	api_hash    :: proc (version: c.int, entry: c.int) -> cstring ---;

	// Returns the CEF API version configured by the first call to cef_api_hash().
	api_version :: proc () -> c.int ---;
}
