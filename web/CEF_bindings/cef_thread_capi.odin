package odin_cef

import "core:c"

/// A simple thread abstraction that establishes a message loop on a new thread.
/// The consumer uses task_runner to execute code on the thread's message
/// loop. The thread is terminated when the thread object is destroyed or
/// stop() is called. All pending tasks queued on the thread's message loop will
/// run to completion before the thread is terminated. thread_create() can
/// be called on any valid CEF thread in either the browser or render process.
/// This structure should only be used for tasks that require a dedicated
/// thread. In most cases you can post tasks to an existing CEF thread instead
/// of creating a new one; see task.h for details.
/// NOTE: This struct is allocated DLL-side.
thread :: struct {
	/// Base structure.
	base: base_ref_counted,

	/// Returns the task_runner that will execute code on this thread's
	/// message loop. This function is safe to call from any thread.
	get_task_runner: proc "system" (self: ^thread) -> ^task_runner,

	/// Returns the platform thread ID. It will return the same value after stop()
	/// is called. This function is safe to call from any thread.
	get_platform_thread_id: proc "system" (self: ^thread) -> cef_platform_thread_id,

	/// Stop and join the thread. This function must be called from the same
	/// thread that called thread_create(). Do not call this function if
	/// thread_create() was called with a |stoppable| value of false (0).
	stop: proc "system" (self: ^thread),

	/// Returns true (1) if the thread is currently running. This function must be
	/// called from the same thread that called thread_create().
	is_running: proc "system" (self: ^thread) -> b32,
}

/// Create and start a new thread. This function does not block waiting for the
/// thread to run initialization. |display_name| is the name that will be used
/// to identify the thread. |priority| is the thread execution priority.
/// |message_loop_type| indicates the set of asynchronous events that the thread
/// can process. If |stoppable| is true (1) the thread will stopped and joined
/// on destruction or when stop() is called; otherwise, the thread cannot be
/// stopped and will be leaked on shutdown. On Windows the |Com_init_mode| value
/// specifies how COM will be initialized for the thread. If |Com_init_mode| is
/// set to COM_INIT_MODE_STA then |message_loop_type| must be set to ML_TYPE_UI.
thread_create :: proc "system" (display_name: ^cef_string, priority: Thread_priority, message_loop_type: Message_loop_type, stoppable: b32, Com_init_mode: Com_init_mode) -> ^thread 