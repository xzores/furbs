package odin_cef

import "core:c"

// Forward declarations for dependencies
// base_ref_counted is defined in cef_base_capi.odin
// task_runner is defined in cef_task_capi.odin
// browser is defined in Browser_capi.odin
// frame is defined in Frame_capi.odin
// cef_string is defined in cef_string_capi.odin
// cef_string_userfree is defined in cef_string_capi.odin
// cef_basetime is defined in cef_types_capi.odin
// V8_property_attribute is defined in cef_types_capi.odin

/// Structure representing a V8 context handle. V8 handles can only be accessed from the thread on which they are created. Valid threads for creating a V8
/// handle include the render process main thread (TID_RENDERER) and WebWorker
/// threads. A task runner for posting tasks on the associated thread can be
/// retrieved via the V8_context::get_task_runner() function.
/// NOTE: This struct is allocated DLL-side.
V8_context :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns the task runner associated with this context. V8 handles can only be accessed from the thread on which they are created. This function can
	/// be called on any render process thread.
	get_task_runner: proc "system" (self: ^V8_context) -> ^task_runner,

	/// Returns true (1) if the underlying handle is valid and it can be accessed on the current thread. Do not call any other functions if this function
	/// returns false (0).
	is_valid: proc "system" (self: ^V8_context) -> b32,

	/// Returns the browser for this context. This function will return an NULL reference for WebWorker contexts.
		get_browser: proc "system" (self: ^V8_context) -> ^Browser,

	/// Returns the frame for this context. This function will return an NULL reference for WebWorker contexts.
	get_frame: proc "system" (self: ^V8_context) -> ^Frame,

	/// Returns the global object for this context. The context must be entered before calling this function.
	get_global: proc "system" (self: ^V8_context) -> ^v8_value,

	/// Enter this context. A context must be explicitly entered before creating a V8 Object, Array, Function or Date asynchronously. exit() must be called
	/// the same number of times as enter() before releasing this context. V8
	/// objects belong to the context in which they are created. Returns true (1)
	/// if the scope was entered successfully.
	enter: proc "system" (self: ^V8_context) -> b32,

	/// Exit this context. Call this function only after calling enter(). Returns true (1) if the scope was exited successfully.
	exit: proc "system" (self: ^V8_context) -> b32,

	/// Returns true (1) if this object is pointing to the same handle as |that| object.
	is_same: proc "system" (self: ^V8_context, that: ^V8_context) -> b32,

	/// Execute a string of JavaScript code in this V8 context. The |script_url| parameter is the URL where the script in question can be found, if any.
	/// The |start_line| parameter is the base line number to use for error
	/// reporting. On success |retval| will be set to the return value, if any,
	/// and the function will return true (1). On failure |exception| will be set
	/// to the exception, if any, and the function will return false (0).
	eval: proc "system" (self: ^V8_context, code: ^cef_string, script_url: ^cef_string, start_line: c.int, retval: ^^v8_value, exception: ^^V8_exception) -> b32,
}

/// Returns the current (top) context object in the V8 context stack.
V8_context_get_current_context :: proc "system" () -> ^V8_context

/// Returns the entered (bottom) context object in the V8 context stack.
V8_context_get_entered_context :: proc "system" () -> ^V8_context

/// Returns true (1) if V8 is currently inside a context.
V8_context_in_context :: proc "system" () -> b32

/// Structure that should be implemented to handle V8 function calls. The functions of this structure will be called on the thread associated with the
/// V8 function.
/// NOTE: This struct is allocated client-side.
v8_handler :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Handle execution of the function identified by |name|. |object| is the receiver ('this' object) of the function. |arguments| is the list of
	/// arguments passed to the function. If execution succeeds set |retval| to
	/// the function return value. If execution fails set |exception| to the
	/// exception that will be thrown. Return true (1) if execution was handled.
	execute: proc "system" (self: ^v8_handler, name: ^cef_string, object: ^v8_value, argumentsCount: c.size_t, arguments: ^^v8_value, retval: ^^v8_value, exception: ^cef_string) -> b32,
}

/// Structure that should be implemented to handle V8 accessor calls. Accessor identifiers are registered by calling v8_value::set_value(). The
/// functions of this structure will be called on the thread associated with the
/// V8 accessor.
/// NOTE: This struct is allocated client-side.
v8_accessor :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Handle retrieval the accessor value identified by |name|. |object| is the receiver ('this' object) of the accessor. If retrieval succeeds set
	/// |retval| to the return value. If retrieval fails set |exception| to the
	/// exception that will be thrown. Return true (1) if accessor retrieval was
	/// handled.
	get: proc "system" (self: ^v8_accessor, name: ^cef_string, object: ^v8_value, retval: ^^v8_value, exception: ^cef_string) -> b32,

	/// Handle assignment of the accessor value identified by |name|. |object| is the receiver ('this' object) of the accessor. |value| is the new value
	/// being assigned to the accessor. If assignment fails set |exception| to the
	/// exception that will be thrown. Return true (1) if accessor assignment was
	/// handled.
	set: proc "system" (self: ^v8_accessor, name: ^cef_string, object: ^v8_value, value: ^v8_value, exception: ^cef_string) -> b32,
}

/// Structure that should be implemented to handle V8 interceptor calls. The functions of this structure will be called on the thread associated with the
/// V8 interceptor.
/// NOTE: This struct is allocated client-side.
v8_interceptor :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Handle retrieval of the interceptor value identified by |name|. |object| is the receiver ('this' object) of the interceptor. If retrieval succeeds,
	/// set |retval| to the return value. If the requested value does not exist,
	/// don't set either |retval| or |exception|. If retrieval fails, set
	/// |exception| to the exception that will be thrown. If the property has an
	/// associated accessor, it will be called only if you don't set |retval|.
	/// Return true (1) if interceptor retrieval was handled, false (0) otherwise.
	get_byname: proc "system" (self: ^v8_interceptor, name: ^cef_string, object: ^v8_value, retval: ^^v8_value, exception: ^cef_string) -> b32,

	/// Handle retrieval of the interceptor value identified by |index|. |object| is the receiver ('this' object) of the interceptor. If retrieval succeeds,
	/// set |retval| to the return value. If the requested value does not exist,
	/// don't set either |retval| or |exception|. If retrieval fails, set
	/// |exception| to the exception that will be thrown. Return true (1) if
	/// interceptor retrieval was handled, false (0) otherwise.
	get_byindex: proc "system" (self: ^v8_interceptor, index: c.int, object: ^v8_value, retval: ^^v8_value, exception: ^cef_string) -> b32,

	/// Handle assignment of the interceptor value identified by |name|. |object| is the receiver ('this' object) of the interceptor. |value| is the new
	/// value being assigned to the interceptor. If assignment fails, set
	/// |exception| to the exception that will be thrown. This setter will always
	/// be called, even when the property has an associated accessor. Return true
	/// (1) if interceptor assignment was handled, false (0) otherwise.
	set_byname: proc "system" (self: ^v8_interceptor, name: ^cef_string, object: ^v8_value, value: ^v8_value, exception: ^cef_string) -> b32,

	/// Handle assignment of the interceptor value identified by |index|. |object| is the receiver ('this' object) of the interceptor. |value| is the new
	/// value being assigned to the interceptor. If assignment fails, set
	/// |exception| to the exception that will be thrown. Return true (1) if
	/// interceptor assignment was handled, false (0) otherwise.
	set_byindex: proc "system" (self: ^v8_interceptor, index: c.int, object: ^v8_value, value: ^v8_value, exception: ^cef_string) -> b32,
}

/// Structure representing a V8 exception. The functions of this structure may be called on any render process thread.
/// NOTE: This struct is allocated DLL-side.
V8_exception :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns the exception message.
	get_message: proc "system" (self: ^V8_exception) -> cef_string_userfree,

	/// Returns the line of source code that the exception occurred within.
	get_source_line: proc "system" (self: ^V8_exception) -> cef_string_userfree,

	/// Returns the resource name for the script from where the function causing the error originates.
	get_script_resource_name: proc "system" (self: ^V8_exception) -> cef_string_userfree,

	/// Returns the 1-based number of the line where the error occurred or 0 if the line number is unknown.
	get_line_number: proc "system" (self: ^V8_exception) -> c.int,

	/// Returns the index within the script of the first character where the error occurred.
	get_start_position: proc "system" (self: ^V8_exception) -> c.int,

	/// Returns the index within the script of the last character where the error occurred.
	get_end_position: proc "system" (self: ^V8_exception) -> c.int,

	/// Returns the index within the line of the first character where the error occurred.
	get_start_column: proc "system" (self: ^V8_exception) -> c.int,

	/// Returns the index within the line of the last character where the error occurred.
	get_end_column: proc "system" (self: ^V8_exception) -> c.int,
}

/// Structure that should be implemented to handle V8 ArrayBuffer memory release. The functions of this structure will be called on the thread
/// associated with the V8 ArrayBuffer.
/// NOTE: This struct is allocated client-side.
v8_array_buffer_release_callback :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Called to release |buffer| when the ArrayBuffer JS object is garbage collected. |buffer| is the value that was passed to create_array_buffer
	/// along with this object.
	release_buffer: proc "system" (self: ^v8_array_buffer_release_callback, buffer: rawptr),
}

/// Structure representing a V8 value handle. V8 handles can only be accessed from the thread on which they are created. Valid threads for creating a V8
/// handle include the render process main thread (TID_RENDERER) and WebWorker
/// threads. A task runner for posting tasks on the associated thread can be
/// retrieved via the cef_V8_context_t::get_task_runner() function.
/// NOTE: This struct is allocated DLL-side.
v8_value :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if the underlying handle is valid and it can be accessed on the current thread. Do not call any other functions if this function
	/// returns false (0).
	is_valid: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is undefined.
	is_undefined: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is null.
	is_null: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is bool.
	is_bool: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is int.
	is_int: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is unsigned int.
	is_uint: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is double.
	is_double: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is Date.
	is_date: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is string.
	is_string: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is object.
	is_object: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is array.
	is_array: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is an ArrayBuffer.
	is_array_buffer: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is function.
	is_function: proc "system" (self: ^v8_value) -> b32,

	/// True if the value type is a Promise.
	is_promise: proc "system" (self: ^v8_value) -> b32,

	/// Returns true (1) if this object is pointing to the same handle as |that| object.
	is_same: proc "system" (self: ^v8_value, that: ^v8_value) -> b32,

	/// Return a bool value.
	get_bool_value: proc "system" (self: ^v8_value) -> b32,

	/// Return an int value.
	get_int_value: proc "system" (self: ^v8_value) -> i32,

	/// Return an unsigned int value.
	get_uint_value: proc "system" (self: ^v8_value) -> u32,

	/// Return a double value.
	get_double_value: proc "system" (self: ^v8_value) -> f64,

	/// Return a Date value.
	get_date_value: proc "system" (self: ^v8_value) -> Basetime,

	/// Return a string value.
	get_string_value: proc "system" (self: ^v8_value) -> cef_string_userfree,

	/// Returns true (1) if this is a user created object.
	is_user_created: proc "system" (self: ^v8_value) -> b32,

	/// Returns true (1) if the last function call resulted in an exception. This attribute exists only in the scope of the current CEF value object.
	has_exception: proc "system" (self: ^v8_value) -> b32,

	/// Returns the exception resulting from the last function call. This attribute exists only in the scope of the current CEF value object.
	get_exception: proc "system" (self: ^v8_value) -> ^V8_exception,

	/// Clears the last exception and returns true (1) on success.
	clear_exception: proc "system" (self: ^v8_value) -> b32,

	/// Returns true (1) if this object will re-throw future exceptions. This attribute exists only in the scope of the current CEF value object.
	will_rethrow_exceptions: proc "system" (self: ^v8_value) -> b32,

	/// Set whether this object will re-throw future exceptions. By default exceptions are not re-thrown. If a exception is re-thrown the current
	/// context should not be accessed again until after the exception has been
	/// caught and not re-thrown. Returns true (1) on success. This attribute
	/// exists only in the scope of the current CEF value object.
	set_rethrow_exceptions: proc "system" (self: ^v8_value, rethrow: b32) -> b32,

	/// Returns true (1) if the object has a value with the specified identifier.
	has_value_bykey: proc "system" (self: ^v8_value, key: ^cef_string) -> b32,

	/// Returns true (1) if the object has a value with the specified identifier.
	has_value_byindex: proc "system" (self: ^v8_value, index: c.int) -> b32,

	/// Deletes the value with the specified identifier and returns true (1) on success. Returns false (0) if this function is called incorrectly or an
	/// exception is thrown. For read-only and don't-delete values this function
	/// will return true (1) even though deletion failed.
	delete_value_bykey: proc "system" (self: ^v8_value, key: ^cef_string) -> b32,

	/// Deletes the value with the specified identifier and returns true (1) on success. Returns false (0) if this function is called incorrectly,
	/// deletion fails or an exception is thrown. For read-only and don't-delete
	/// values this function will return true (1) even though deletion failed.
	delete_value_byindex: proc "system" (self: ^v8_value, index: c.int) -> b32,

	/// Returns the value with the specified identifier on success. Returns NULL if this function is called incorrectly or an exception is thrown.
	get_value_bykey: proc "system" (self: ^v8_value, key: ^cef_string) -> ^v8_value,

	/// Returns the value with the specified identifier on success. Returns NULL if this function is called incorrectly or an exception is thrown.
	get_value_byindex: proc "system" (self: ^v8_value, index: c.int) -> ^v8_value,

	/// Associates a value with the specified identifier and returns true (1) on success. Returns false (0) if this function is called incorrectly or an
	/// exception is thrown. For read-only values this function will return true
	/// (1) even though assignment failed.
	set_value_bykey: proc "system" (self: ^v8_value, key: ^cef_string, value: ^v8_value, attribute: V8_property_attribute) -> b32,
	
	/// Associates a value with the specified identifier and returns true (1) on success. Returns false (0) if this function is called incorrectly or an
	/// exception is thrown. For read-only values this function will return true
	/// (1) even though assignment failed.
	set_value_byindex: proc "system" (self: ^v8_value, index: c.int, value: ^v8_value) -> b32,

	/// Registers an identifier and returns true (1) on success. Access to the identifier will be forwarded to the v8_accessor instance passed to
	/// v8_value::create_object(). Returns false (0) if this
	/// function is called incorrectly or an exception is thrown. For read-only
	/// values this function will return true (1) even though assignment failed.
	set_value_byaccessor: proc "system" (self: ^v8_value, key: ^cef_string, attribute: V8_property_attribute) -> b32,

	/// Read the keys for the object's values into the specified vector. Integer- based keys will also be returned as strings.
	get_keys: proc "system" (self: ^v8_value, keys: string_list) -> b32,

	/// Sets the user data for this object and returns true (1) on success. Returns false (0) if this function is called incorrectly. This function
	/// can only be called on user created objects.
	set_user_data: proc "system" (self: ^v8_value, user_data: ^base_ref_counted) -> b32,

	/// Returns the user data, if any, assigned to this object.
	get_user_data: proc "system" (self: ^v8_value) -> ^base_ref_counted,

	/// Returns the amount of externally allocated memory registered for the object.
	get_externally_allocated_memory: proc "system" (self: ^v8_value) -> c.int,

	/// Adjusts the amount of registered external memory for the object. Used to give V8 an indication of the amount of externally allocated memory that is
	/// kept alive by JavaScript objects. V8 uses this information to decide when
	/// to perform global garbage collection. Each v8_value tracks the
	/// amount of external memory associated with it and automatically decreases
	/// the global total by the appropriate amount on its destruction.
	/// |change_in_bytes| specifies the number of bytes to adjust by. This
	/// function returns the number of bytes associated with the object after the
	/// adjustment. This function can only be called on user created objects.
	adjust_externally_allocated_memory: proc "system" (self: ^v8_value, change_in_bytes: c.int) -> c.int,

	/// Returns the number of elements in the array.
	get_array_length: proc "system" (self: ^v8_value) -> c.int,

	/// Returns the release_callback object associated with the ArrayBuffer or NULL if the ArrayBuffer was not created with create_array_buffer.
	get_array_buffer_release_callback: proc "system" (self: ^v8_value) -> ^v8_array_buffer_release_callback,

	/// Prevent the ArrayBuffer from using it's memory block by setting the length to zero. This operation cannot be undone. If the ArrayBuffer was created
	/// with create_array_buffer then
	/// v8_array_buffer_release_callback::release_buffer will be called to
	/// release the underlying buffer.
	neuter_array_buffer: proc "system" (self: ^v8_value) -> b32,

	/// Returns the length (in bytes) of the ArrayBuffer.
	get_array_buffer_byte_length: proc "system" (self: ^v8_value) -> c.size_t,

	/// Returns a pointer to the beginning of the memory block for this ArrayBuffer backing store. The returned pointer is valid as long as the
	/// v8_value is alive.
	get_array_buffer_data: proc "system" (self: ^v8_value) -> rawptr,

	/// Returns the function name.
	get_function_name: proc "system" (self: ^v8_value) -> cef_string_userfree,

	/// Returns the function handler or NULL if not a CEF-created function.
	get_function_handler: proc "system" (self: ^v8_value) -> ^v8_handler,

	/// Execute the function using the current V8 context. This function should only be called from within the scope of a v8_handler or
	/// v8_accessor callback, or in combination with calling enter() and
	/// exit() on a stored V8_context reference. |object| is the receiver
	/// ('this' object) of the function. If |object| is NULL the current context's
	/// global object will be used. |arguments| is the list of arguments that will
	/// be passed to the function. Returns the function return value on success.
	/// Returns NULL if this function is called incorrectly or an exception is
	/// thrown.
	execute_function: proc "system" (self: ^v8_value, object: ^v8_value, argumentsCount: c.size_t, arguments: ^^v8_value) -> ^v8_value,

	/// Execute the function using the specified V8 context. |object| is the receiver ('this' object) of the function. If |object| is NULL the
	/// specified context's global object will be used. |arguments| is the list of
	/// arguments that will be passed to the function. Returns the function return
	/// value on success. Returns NULL if this function is called incorrectly or
	/// an exception is thrown.
	execute_function_with_context: proc "system" (self: ^v8_value, ctx: ^V8_context, object: ^v8_value, argumentsCount: c.size_t, arguments: ^^v8_value) -> ^v8_value,

	/// Resolve the Promise using the current V8 context. This function should only be called from within the scope of a v8_handler or
	/// v8_accessor callback, or in combination with calling enter() and
	/// exit() on a stored V8_context reference. |arg| is the argument
	/// passed to the resolved promise. Returns true (1) on success. Returns false
	/// (0) if this function is called incorrectly or an exception is thrown.
	resolve_promise: proc "system" (self: ^v8_value, arg: ^v8_value) -> b32,

	/// Reject the Promise using the current V8 context. This function should only be called from within the scope of a v8_handler or v8_accessor
	/// callback, or in combination with calling enter() and exit() on a stored
	/// V8_context reference. Returns true (1) on success. Returns false (0)
	/// if this function is called incorrectly or an exception is thrown.
	reject_promise: proc "system" (self: ^v8_value, errorMsg: ^cef_string) -> b32,
}

/// Create a new v8_value object of type undefined.
v8_value_create_undefined :: proc "system" () -> ^v8_value

/// Create a new v8_value object of type null.
v8_value_create_null :: proc "system" () -> ^v8_value

/// Create a new v8_value object of type bool.
v8_value_create_bool :: proc "system" (value: b32) -> ^v8_value

/// Create a new v8_value object of type int.
v8_value_create_int :: proc "system" (value: i32) -> ^v8_value

/// Create a new v8_value object of type unsigned int.
v8_value_create_uint :: proc "system" (value: u32) -> ^v8_value

/// Create a new v8_value object of type double.
v8_value_create_double :: proc "system" (value: f64) -> ^v8_value

/// Create a new v8_value object of type Date. This function should only be called from within the scope of a V8_context, v8_handler or
/// v8_accessor callback, or in combination with calling enter() and exit()
/// on a stored V8_context reference.
///
v8_value_create_date :: proc "system" (date: Basetime) -> ^v8_value

/// Create a new v8_value object of type string.
v8_value_create_string :: proc "system" (value: ^cef_string) -> ^v8_value

/// Create a new v8_value object of type object with optional accessor. This function should only be called from within the scope of a V8_context,
/// v8_handler or v8_accessor callback, or in combination with calling
/// enter() and exit() on a stored V8_context reference.
///
v8_value_create_object :: proc "system" (accessor: ^v8_accessor, interceptor: ^v8_interceptor) -> ^v8_value

/// Create a new v8_value object of type array with the specified |length|. If |length| is negative the returned array will have length 0. This function
/// should only be called from within the scope of a V8_context, v8_handler or
/// v8_accessor callback, or in combination with calling enter() and exit()
/// on a stored V8_context reference.
///
v8_value_create_array :: proc "system" (length: c.int) -> ^v8_value

/// Create a new v8_value object of type ArrayBuffer. This function should only be called from within the scope of a V8_context, v8_handler or
/// v8_accessor callback, or in combination with calling enter() and exit()
/// on a stored V8_context reference.
///
v8_value_create_array_buffer :: proc "system" (buffer: rawptr, length: c.size_t, release_callback: ^v8_array_buffer_release_callback) -> ^v8_value

/// Create a new v8_value object of type function. This function should only be called from within the scope of a V8_context, v8_handler or
/// v8_accessor callback, or in combination with calling enter() and exit()
/// on a stored V8_context reference.
///
v8_value_create_function :: proc "system" (name: ^cef_string, handler: ^v8_handler) -> ^v8_value

/// Create a new v8_value object of type Promise. This function should only be called from within the scope of a V8_context, v8_handler or
/// v8_accessor callback, or in combination with calling enter() and exit()
/// on a stored V8_context reference.
///
v8_value_create_promise :: proc "system" () -> ^v8_value

/// Returns the stack trace for the currently active context. |frame_limit| is the maximum number of frames that will be captured.
///
v8_get_current_stack_trace :: proc "system" (frame_limit: c.int) -> ^V8_stack_trace

/// Structure representing a V8 stack trace handle. The functions of this structure may be called on any render process thread.
/// NOTE: This struct is allocated DLL-side.
V8_stack_trace :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if the underlying handle is valid and it can be accessed on the current thread. Do not call any other functions if this function
	/// returns false (0).
	is_valid: proc "system" (self: ^V8_stack_trace) -> b32,

	/// Returns the number of stack frames.
	get_frame_count: proc "system" (self: ^V8_stack_trace) -> c.int,

	/// Returns the stack frame at the specified 0-based index.
	get_frame: proc "system" (self: ^V8_stack_trace, index: c.int) -> ^v8_stack_frame,
}

/// Structure representing a V8 stack frame handle. The functions of this structure may be called on any render process thread.
/// NOTE: This struct is allocated DLL-side.
v8_stack_frame :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if the underlying handle is valid and it can be accessed on the current thread. Do not call any other functions if this function
	/// returns false (0).
	is_valid: proc "system" (self: ^v8_stack_frame) -> b32,

	/// Returns the name of the resource script that contains the function.
	get_script_name: proc "system" (self: ^v8_stack_frame) -> cef_string_userfree,

	/// Returns the name of the resource script that contains the function or the sourceURL value if the script name is undefined and its source ends with a
	/// "//@ sourceURL=..." string.
	get_script_name_or_source_url: proc "system" (self: ^v8_stack_frame) -> cef_string_userfree,

	/// Returns the name of the function.
	get_function_name: proc "system" (self: ^v8_stack_frame) -> cef_string_userfree,

	/// Returns the 1-based line number for the function call or 0 if unknown.
	get_line_number: proc "system" (self: ^v8_stack_frame) -> c.int,

	/// Returns the 1-based column offset on the line for the function call or 0 if unknown.
	get_column: proc "system" (self: ^v8_stack_frame) -> c.int,

	/// Returns true (1) if the function was compiled using eval().
	is_eval: proc "system" (self: ^v8_stack_frame) -> b32,

	/// Returns true (1) if the function was called as a constructor via "new".
	is_constructor: proc "system" (self: ^v8_stack_frame) -> b32,
}

/// Register a new V8 extension with the specified |extension_name| and |javascript_code|. JavaScript code should be wrapped in a function
/// immediately invoked (FII) so that each extension's code is isolated from
/// other extensions. The |handler| parameter will be called if the extension
/// attempts to interact with the browser through CEF's V8 bindings. This
/// function may only be called on the render process main thread and only
/// before the context is created for the first time in the render process.
///
register_extension :: proc "system" (extension_name: ^cef_string, javascript_code: ^cef_string, handler: ^v8_handler) -> b32 