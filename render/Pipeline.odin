



make_pipeline :: proc(s : Render_state($U, $A), camera : union {Camera2D, Camera3D}, target : Render_target, shader : Shader(U, A),
							clear_color : [4]f32 = {0,0,0,1}, use_transparency : bool = true, blend_mode : .alpha_minus_one, depth_write : bool = true,
							depth_test : bool = true, render_topology : .triangles, fill_mode : .fill, culling : Cull_method = .no_cull) {
	
	

}