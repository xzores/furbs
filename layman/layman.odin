package furbs_layman;

import "../render"
import "../layren"
import "../laycal"

Element :: struct {
	render : layren.To_render,
	options : layren.Rect_options,
}

Layout_mananger :: struct {
	ls : laycal.Layout_state,
	lr : layren.Layout_render,

	renders : #soa [dynamic]Element,
}

Layout_dir :: laycal.Layout_dir;
Alignment ::laycal.Alignment;
Anchor_point :: laycal.Anchor_point;
Axis :: laycal.Axis;
Size :: laycal.Size;
Min_size :: laycal.Min_size;
Max_size :: laycal.Max_size;
Absolute_postion :: laycal.Absolute_postion;
Overflow :: laycal.Overflow;
Parameters :: laycal.Parameters;

Shadow :: layren.Shadow;
Color_stop :: layren.Color_stop;
Gradient :: layren.Gradient; 
Rect_options :: layren.Rect_options; 
Render_rect :: layren.Render_rect; 
Render_polygon :: layren.Render_polygon; 
To_render :: layren.To_render; 
Layout_render :: layren.Layout_render;

Fixed :: laycal.Fixed;
Parent_ratio :: laycal.Parent_ratio;
Fit :: laycal.Fit;
Grow :: laycal.Grow;
Grow_fit :: laycal.Grow_fit;
fit :: laycal.fit;
grow :: laycal.grow;
grow_fit :: laycal.grow_fit;
parameters :: laycal.parameters;

make_layout_render :: proc (lm : ^Layout_mananger = nil) -> ^Layout_mananger {
	lm := lm;

	if lm == nil {
		lm = new(Layout_mananger);
	}

	laycal.make_layout_state(&lm.ls);
	layren.make_layout_render(&lm.lr);
	
	return lm;
}

destroy_layout_render :: proc (lm : ^Layout_mananger) {
	laycal.destroy_laytout_state(&lm.ls);
	layren.destroy_layout_render(&lm.lr);
}

begin :: proc (lm : ^Layout_mananger) {
	laycal.begin_layout_state(&lm.ls, render.get_render_target_size(render.get_current_render_target()));
}

open_element :: proc (lm : ^Layout_mananger, params : laycal.Parameters, options : layren.Rect_options, debug_name : cstring = "") {

	laycal.open_element(&lm.ls, params, nil, debug_name);
	append(&lm.renders, Element{
		{},
		options,
	});
}

close_element :: proc (lm : ^Layout_mananger) {

	laycal.close_element(&lm.ls);
}

end :: proc (lm : ^Layout_mananger) {
	clear(&lm.renders)
	elems := laycal.end_layout_state(&lm.ls);
	
	for e, i in elems {
		pos := [4]f32{cast(f32)e.position.x, cast(f32)e.position.y, cast(f32)e.size.x, cast(f32)e.size.y};
		
		lm.renders.render[i] = layren.Render_rect{
			pos,
			render.texture2D_get_white(), 
			lm.renders.options[i],
			0,
		}
	}
	
	layren.render(&lm.lr, lm.renders.render[:len(lm.renders)]);
}
