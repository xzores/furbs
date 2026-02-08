package furbs_gui;

import "../render"
import "../layren"
import "../layman"

Gui :: struct {

	man : layman.Layout_mananger,
}

init :: proc (gui : ^Gui = nil) -> ^Gui {
	gui := gui;
	
	if gui == nil {
		gui = new(Gui);
	}

	layman.init(&gui.man);

	return gui;
}

destroy :: proc () {

}


end :: proc () {
	
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