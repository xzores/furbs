package odin_cef

import "core:c"

/// Implement this structure to handle events related to dragging. The functions of this structure will be called on the UI thread.
/// NOTE: This struct is allocated client-side.
Drag_handler :: struct {
	/// Base structure.
	base: base_ref_counted,
	
	/// Called when an external drag event enters the browser window. |dragData|
	/// contains the drag event data and |mask| represents the type of drag
	/// operation. Return false (0) for default drag handling behavior or true (1)
	/// to cancel the drag event.
	on_drag_enter: proc "system" (self: ^Drag_handler, browser: ^Browser, dragData: ^Drag_data, mask: Drag_operations_mask) -> b32,

	/// Called whenever draggable regions for the browser window change. These can
	/// be specified using the '-webkit-app-region: drag/no-drag' CSS-property. If
	/// draggable regions are never defined in a document this function will also
	/// never be called. If the last draggable region is removed from a document
	/// this function will be called with an NULL vector.
	on_draggable_regions_changed: proc "system" (self: ^Drag_handler, browser: ^Browser, frame: ^Frame, regionsCount: c.size_t, regions: ^Draggable_region),
} 