package odin_cef

when ODIN_OS == .Windows {
	foreign import lib "CEF/Release/libcef.lib"
} else when ODIN_OS == .Linux {
	foreign import lib "CEF/Release/libcef.so"
} else when ODIN_OS == .Darwin {
	foreign import lib "CEF/Release/libcef.dylib"
}

import "core:c"

/// Structure used to create and/or parse command line arguments. Arguments with "--", "-" and, on Windows, "/" prefixes are considered switches. Switches
/// will always precede any arguments without switch prefixes. Switches can
/// optionally have a value specified using the "=" delimiter (e.g.
/// "-switch=value"). An argument of "--" will terminate switch parsing with all
/// subsequent tokens, regardless of prefix, being interpreted as non-switch
/// arguments. Switch names should be lowercase ASCII and will be converted to
/// such if necessary. Switch values will retain the original case and UTF8
/// encoding. This structure can be used before initialize() is called.
/// NOTE: This struct is allocated DLL-side.
Command_line :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if this object is valid. Do not call any other functions if this function returns false (0).
	is_valid: proc "system" (self: ^Command_line) -> b32,

	/// Returns true (1) if the values of this object are read-only. Some APIs may expose read-only objects.
	is_read_only: proc "system" (self: ^Command_line) -> b32,

	/// Returns a writable copy of this object.
	copy: proc "system" (self: ^Command_line) -> ^Command_line,

	/// Initialize the command line with the specified |argc| and |argv| values. The first argument must be the name of the program. This function is only
	/// supported on non-Windows platforms.
	init_from_argv: proc "system" (self: ^Command_line, argc: c.int, argv: ^^c.char),

	/// Initialize the command line with the string returned by calling GetCommandLineW(). This function is only supported on Windows.
	init_from_string: proc "system" (self: ^Command_line, Command_line: ^cef_string),

	/// Reset the command-line switches and arguments but leave the program component unchanged.
	reset: proc "system" (self: ^Command_line),

	/// Retrieve the original command line string as a vector of strings. The argv array: `{ program, [(--|-|/)switch[=value]]*, [--], [argument]* }`
	get_argv: proc "system" (self: ^Command_line, argv: string_list),

	/// Constructs and returns the represented command line string. Use this function cautiously because quoting behavior is unclear.
	get_command_line_string: proc "system" (self: ^Command_line) -> cef_string_userfree,

	/// Get the program part of the command line string (the first item).
	get_program: proc "system" (self: ^Command_line) -> cef_string_userfree,

	/// Set the program part of the command line string (the first item).
	set_program: proc "system" (self: ^Command_line, program: ^cef_string),

	/// Returns true (1) if the command line has switches.
	has_switches: proc "system" (self: ^Command_line) -> b32,

	/// Returns true (1) if the command line contains the given switch.
	has_switch: proc "system" (self: ^Command_line, name: ^cef_string) -> b32,

	/// Returns the value associated with the given switch. If the switch has no value or isn't present this function returns the NULL string.
	get_switch_value: proc "system" (self: ^Command_line, name: ^cef_string) -> cef_string_userfree,

	/// Returns the map of switch names and values. If a switch has no value an NULL string is returned.
	get_switches: proc "system" (self: ^Command_line, switches: string_map),

	/// Add a switch to the end of the command line.
	append_switch: proc "system" (self: ^Command_line, name: ^cef_string),

	/// Add a switch with the specified value to the end of the command line. If the switch has no value pass an NULL value string.
	append_switch_with_value: proc "system" (self: ^Command_line, name: ^cef_string, value: ^cef_string),

	/// True if there are remaining command line arguments.
	has_arguments: proc "system" (self: ^Command_line) -> b32,

	/// Get the remaining command line arguments.
	get_arguments: proc "system" (self: ^Command_line, arguments: string_list),

	/// Add an argument to the end of the command line.
	append_argument: proc "system" (self: ^Command_line, argument: ^cef_string),

	/// Insert a command before the current command. Common for debuggers, like "valgrind" or "gdb --args".
	prepend_wrapper: proc "system" (self: ^Command_line, wrapper: ^cef_string),
} 

@(default_calling_convention="system", link_prefix="cef_", require_results)
foreign lib {
	/// Create a new cef_command_line instance.
	command_line_create :: proc () -> ^Command_line ---

	/// Returns the singleton global cef_command_line object. The returned object will be read-only.
	command_line_get_global :: proc () -> ^Command_line ---
}