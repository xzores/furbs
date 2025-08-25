package cef_internal

import "core:c"

/// Structure representing a point.
cef_point :: struct {
	x: c.int,
	y: c.int,
}

/// Structure representing a rectangle.
cef_rect :: struct {
	x: c.int,
	y: c.int,
	width: c.int,
	height: c.int,
}

/// Structure representing a size.
cef_size :: struct {
	width: c.int,
	height: c.int,
}

/// Structure representing insets.
cef_insets :: struct {
	top: c.int,
	left: c.int,
	bottom: c.int,
	right: c.int,
}
