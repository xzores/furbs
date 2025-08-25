package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Creates a directory (and parents if needed). Returns 1 on success or if it already exists.
	// Directory is readable only by the current user. Not allowed on browser UI/IO threads.
	create_directory :: proc "system" (full_path: ^cef_string) -> c.int ---

	// Get the system temporary directory.
	// WARNING: Prefer the temp-directory variants below which set safer permissions.
	get_temp_directory :: proc "system" (temp_dir: ^cef_string) -> c.int ---

	// Creates a new temp directory. On Windows, if |prefix| is provided the name is "prefixyyyy".
	// Returns 1 on success and sets |new_temp_path|. Readable only by current user.
	// Not allowed on browser UI/IO threads.
	create_new_temp_directory :: proc "system" (prefix: ^cef_string, new_temp_path: ^cef_string) -> c.int ---

	// Creates a temp directory inside |base_dir| with a unique name based on |prefix|.
	// Returns 1 on success and sets |new_dir|. Readable only by current user.
	// Not allowed on browser UI/IO threads.
	create_temp_directory_in_directory :: proc "system" (base_dir: ^cef_string, prefix: ^cef_string, new_dir: ^cef_string) -> c.int ---

	// Returns 1 if the given path exists and is a directory.
	// Not allowed on browser UI/IO threads.
	directory_exists :: proc "system" (path: ^cef_string) -> c.int ---

	// Deletes |path| (file or directory). If directory, all contents are deleted.
	// If |recursive|=1, also deletes subdirectories (like "rm -rf"). On POSIX, a symlink deletion
	// removes only the link. Returns 1 on success or if |path| does not exist.
	// Not allowed on browser UI/IO threads.
	delete_file :: proc "system" (path: ^cef_string, recursive: c.int) -> c.int ---

	// Zips the contents of |src_dir| into |dest_file|. If |include_hidden_files|=1, includes dotfiles.
	// Returns 1 on success. Not allowed on browser UI/IO threads.
	zip_directory :: proc "system" (src_dir: ^cef_string, dest_file: ^cef_string, include_hidden_files: c.int) -> c.int ---

	// Loads the existing Chrome "Certificate Revocation Lists" (CRLSets) file.
	// Call in the browser process after context initialization.
	load_crlsets_file :: proc "system" (path: ^cef_string) ---
}
