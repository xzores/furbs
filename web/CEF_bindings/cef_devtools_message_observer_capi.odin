package odin_cef

import "core:c"

// Callback structure for Browser_host.AddDevToolsMessageObserver (UI thread).
// NOTE: This struct is allocated client-side.
Dev_tools_message_observer :: struct {
	// Base structure.
	base: base_ref_counted,

	// Called on receipt of a DevTools protocol message.
	// |browser| is the origin. |message| is UTF-8 JSON (function result or event), valid only for this call.
	// Return 1 if handled; 0 to allow further processing (OnDevToolsMethodResult / OnDevToolsEvent).
	on_dev_tools_message: proc "system" (
		self: ^Dev_tools_message_observer,
		browser: ^Browser,
		message: rawptr,
		message_size: c.size_t,
	) -> c.int,

	// Called after attempted execution of a DevTools protocol function.
	// |message_id| matches the "id" from SendDevToolsMessage. |success|=1 => |result| is "result" JSON (may be nil);
	// |success|=0 => |result| is "error" JSON. |result| valid only for this call.
	on_dev_tools_method_result: proc "system" (
		self: ^Dev_tools_message_observer,
		browser: ^Browser,
		message_id: c.int,
		success: c.int,
		result: rawptr,
		result_size: c.size_t,
	),

	// Called on receipt of a DevTools protocol event.
	// |method| is the event name ("function"). |params| is UTF-8 JSON "params" (may be nil), valid only for this call.
	on_dev_tools_event: proc "system" (
		self: ^Dev_tools_message_observer,
		browser: ^Browser,
		method: ^cef_string,
		params: rawptr,
		params_size: c.size_t,
	),

	// Called when the DevTools agent has attached.
	on_dev_tools_agent_attached: proc "system" (
		self: ^Dev_tools_message_observer,
		browser: ^Browser,
	),

	// Called when the DevTools agent has detached (pending results won't be delivered; subscriptions canceled).
	on_dev_tools_agent_detached: proc "system" (
		self: ^Dev_tools_message_observer,
		browser: ^Browser,
	),
}
