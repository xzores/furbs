package odin_cef

import "core:c"

/// Structure that facilitates managing the browser-related tasks. The functions of this structure may only be called on the UI thread.
/// NOTE: This struct is allocated DLL-side.
task_manager :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns the number of tasks currently tracked by the task manager. Returns 0 if the function was called from the incorrect thread.
	get_tasks_count: proc "system" (self: ^task_manager) -> c.size_t,

	/// Gets the list of task IDs currently tracked by the task manager. Tasks that share the same process id will always be consecutive. The list will
	/// be sorted in a way that reflects the process tree: the browser process
	/// will be first, followed by the gpu process if it exists. Related processes
	/// (e.g., a subframe process and its parent) will be kept together if
	/// possible. Callers can expect this ordering to be stable when a process is
	/// added or removed. The task IDs are unique within the application lifespan.
	/// Returns false (0) if the function was called from the incorrect thread.
	get_task_ids_list: proc "system" (self: ^task_manager, task_idsCount: ^c.size_t, task_ids: ^i64) -> b32,

	/// Gets information about the task with |task_id|. Returns true (1) if the information about the task was successfully retrieved and false (0) if the
	/// |task_id| is invalid or the function was called from the incorrect thread.
	get_task_info: proc "system" (self: ^task_manager, task_id: i64, info: ^Task_info) -> b32,

	/// Attempts to terminate a task with |task_id|. Returns false (0) if the |task_id| is invalid, the call is made from an incorrect thread, or if the
	/// task cannot be terminated.
	kill_task: proc "system" (self: ^task_manager, task_id: i64) -> b32,

	/// Returns the task ID associated with the main task for |browser_id| (value from browser::get_identifier). Returns -1 if |browser_id| is invalid,
	/// does not currently have an associated task, or the function was called
	/// from the incorrect thread.
	get_task_id_for_browser_id: proc "system" (self: ^task_manager, browser_id: c.int) -> i64,
}

/// Returns the global task manager object. Returns nullptr if the function was called from the incorrect thread.
///
task_manager_get :: proc "system" () -> ^task_manager 