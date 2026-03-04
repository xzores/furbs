package furbs_gui;

import "../render"
import "../layren"
/*
import "../layman_new"

Gui :: struct {

	man : layman.State,
}

Text_width_f :: proc (user_data : rawptr, size : f32, str: string) -> (width : f32) {
	return 0
}

Text_height_f :: proc (user_data : rawptr, size : f32) -> (acsender : f32, decender : f32) {
	return 0, 0
}

init :: proc (gui : ^Gui = nil) -> ^Gui {
	gui := gui;
	
	if gui == nil {
		gui = new(Gui);
	}

	layman.init(&gui.man, nil, nil);

	return gui;
}

destroy :: proc (gui : ^Gui) {
	
}

end :: proc (gui : ^Gui) {

	layman.end(gui.man, render.time, loc);

	elems := laycal.end_layout_state(&lm.ls);
	for e, i in elems {
		pos := [4]f32{cast(f32)e.position.x, cast(f32)e.position.y, cast(f32)e.size.x, cast(f32)e.size.y};
		itm := item[i];
		
		append(&lm.renders, layren.Render_rect{
			pos,
			render.texture2D_get_white(), 
			itm.visual,
			0,
		});
	}
	
	layren.render(&lm.lr, lm.renders[:]);
	clear(&lm.renders);
	clear(&lm.items);
}
*/