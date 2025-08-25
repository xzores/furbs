package odin_cef

import "core:c"

/// Implement this structure for asynchronous task execution. If the task is posted successfully and if the associated message loop is still running then
/// the execute() function will be called on the target thread. If the task
/// fails to post then the task object may be destroyed on the source thread
/// instead of the target thread. For this reason be cautious when performing
/// work in the task object destructor.
/// NOTE: This struct is allocated client-side.
task :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Method that will be executed on the target thread.
	execute: proc "system" (self: ^task),
}

/// Structure that asynchronously executes tasks on the associated thread. It is safe to call the functions of this structure on any thread.
/// CEF maintains multiple internal threads that are used for handling different types of tasks in different processes. The cef_thread_id definitions in
/// cef_types.h list the common CEF threads. Task runners are also available for
/// other CEF threads as appropriate (for example, V8 WebWorker threads).
/// NOTE: This struct is allocated DLL-side.
task_runner :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns true (1) if this object is pointing to the same task runner as |that| object.
	is_same: proc "system" (self: ^task_runner, that: ^task_runner) -> b32,

	/// Returns true (1) if this task runner belongs to the current thread.
	belongs_to_current_thread: proc "system" (self: ^task_runner) -> b32,

	/// Returns true (1) if this task runner is for the specified CEF thread.
	belongs_to_thread: proc "system" (self: ^task_runner, threadId: cef_thread_id) -> b32,

	/// Post a task for execution on the thread associated with this task runner. Execution will occur asynchronously.
	post_task: proc "system" (self: ^task_runner, task: ^task) -> b32,

	/// Post a task for delayed execution on the thread associated with this task runner. Execution will occur asynchronously. Delayed tasks are not
	/// supported on V8 WebWorker threads and will be executed without the
	/// specified delay.
	post_delayed_task: proc "system" (self: ^task_runner, task: ^task, delay_ms: i64) -> b32,
}

/// Returns the task runner for the current thread. Only CEF threads will have task runners. An NULL reference will be returned if this function is called
/// on an invalid thread.
///
task_runner_get_for_current_thread :: proc "system" () -> ^task_runner

/// Returns the task runner for the specified CEF thread.
task_runner_get_for_thread :: proc "system" (threadId: cef_thread_id) -> ^task_runner

/// Returns true (1) if called on the specified thread. Equivalent to using task_runner::get_for_thread(threadId)->belongs_to_current_thread().
///
currently_on :: proc "system" (threadId: cef_thread_id) -> b32

/// Post a task for execution on the specified thread. Equivalent to using task_runner::get_for_thread(threadId)->post_task(task).
///
post_task :: proc "system" (threadId: cef_thread_id, task: ^task) -> b32

/// Post a task for delayed execution on the specified thread. Equivalent to using task_runner::get_for_thread(threadId)->post_delayed_task(task,
/// delay_ms).
/// 