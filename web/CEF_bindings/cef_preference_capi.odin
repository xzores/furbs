package odin_cef

import "core:c"

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

CEF_HAS_API_13401 :: true; //TODO i think this is right

// Manages custom preference registrations. (Allocated DLL-side.)
Preference_registrar :: struct {
	base: base_scoped,

	// Register a preference with |name| and |default_value|. Returns true (1) on success.
	// Must be called from Browser_process_handler.on_register_custom_preferences.
	add_preference: proc "system" (
		self: ^Preference_registrar,
		name: ^cef_string,
		default_value: ^cef_value,
	) -> c.int,
}

// Observe preference changes. Registered via Preference_manager.add_preference_observer.
// (Allocated client-side.)
when CEF_HAS_API_13401 {
	Preference_observer :: struct {
		base: base_ref_counted,

		// Called when a preference has changed.
		on_preference_changed: proc "system" (
			self: ^Preference_observer,
			name: ^cef_string,
		)
	}
}

// Manage access to preferences. (Allocated DLL-side.)
Preference_manager :: struct {
	base: base_ref_counted,

	// Returns true (1) if a preference named |name| exists. UI thread.
	has_preference: proc "system" (self: ^Preference_manager, name: ^cef_string) -> c.int,

	// Get the value for preference |name| (copy). Returns NULL if it doesn't exist. UI thread.
	get_preference: proc "system" (self: ^Preference_manager, name: ^cef_string) -> ^cef_value,

	// Get all preferences as a dictionary (copy). If |include_defaults| is true (1) include defaults. UI thread.
	get_all_preferences: proc "system" (self: ^Preference_manager, include_defaults: c.int) -> ^cef_dictionary_value,

	// Returns true (1) if preference |name| can be modified via set_preference. UI thread.
	can_set_preference: proc "system" (self: ^Preference_manager, name: ^cef_string) -> c.int,

	// Set |value| for preference |name|. If |value| is NULL restore default. UI thread.
	// On failure returns false (0) and populates |error|.
	set_preference: proc "system" (
		self: ^Preference_manager,
		name: ^cef_string,
		value: ^cef_value,
		error: ^cef_string,
	) -> c.int,

	/* TODO
	// Added in 13401+
	when CEF_HAS_API_13401 {
		// Add an observer for preference changes. If |name| is NULL observe all. UI thread.
		add_preference_observer: proc "system" (
			self: ^Preference_manager,
			name: ^cef_string,
			observer: ^Preference_observer,
		) -> ^registration,
	}
	*/
}

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	// Variations helpers (13401+). UI thread.
	when CEF_HAS_API_13401 {
		preference_manager_get_chrome_variations_as_switches :: proc "system" (switches: string_list) ---
		preference_manager_get_chrome_variations_as_strings  :: proc "system" (strings:  string_list) ---
	}

	// Returns the global preference manager object.
	preference_manager_get_global :: proc "system" () -> ^Preference_manager ---
}
