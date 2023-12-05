package interface;

import "core:math/linalg"

import "../render"
//import "../gui"


//////////////////////////////////////////////////////////////////////// FURBS INTERFACE BEGIN ////////////////////////////////////////////////////////////////////////



//////////////////////////////////// RENDER STATE BELOW ////////////////////////////////////

//This is the state of the render API, virtually all furbs function requires this as a parameter.
render_state : render.Render_state(Uniform_location, Attribute_location);

Uniform_info :: render.Uniform_info;
Attribute_info :: render.Attribute_info;

init_render :: proc (shader_defines : map[string]string, shader_folder : string, loc := #caller_location) {
	render.init_render(&render_state, uniforms_types, attribute_types, shader_defines, shader_folder, loc);
}

destroy_render :: proc () {
	render.destroy_render(&render_state);
}


//////////////////////////////////// CAMERA STUFF BELOW ////////////////////////////////////

Camera3D :: render.Camera3D;
Camera2D :: render.Camera2D;

/*
Description 		: drawing between begin_mode_3D and end_mode_3D will draw in 3D using the camera given.
GPU_state_changes 	: yes, camera uniforms will be bound and depth test enabled.
CPU_state_changes 	: yes, follows GPU
Allocations 		: no
Notes 				: ---
Failures			: yes, this function can fail if the state is not correct.
*/
begin_mode_3D :: proc (camera : Camera3D, use_transparency := true, loc := #caller_location) {
	render.begin_mode_3D(&render_state, camera, use_transparency, loc);
};

/*
Description 		: ends the current camera and stops 3D mode.
GPU_state_changes 	: yes, depth test disabled.
CPU_state_changes 	: yes, follows GPU.
Allocations 		: no
Notes 				: the camera must be the same as used in the previous begin_mode_3D.
Failures			: yes
*/
end_mode_3D :: proc (using camera : Camera3D, loc := #caller_location) {
	render.end_mode_3D(&render_state, camera, loc);
};

/*
Description 		: drawing between begin_mode_2D and end_mode_2D will draw in 2D using the camera given.
GPU_state_changes 	: yes, camera uniforms will be bound.
CPU_state_changes 	: yes, follows GPU
Allocations 		: no
Notes 				: ---
Failures			: yes
*/
begin_mode_2D :: proc(using camera : Camera2D = {{0,0}, {0,0}, 0, 1, 1, -1}, use_transparency := true, loc := #caller_location) {
	render.begin_mode_2D(&render_state, camera, use_transparency, loc);
}

/*
Description 		: ends the current camera and stops 2D mode.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: the camera must be the same as used in the previous begin_mode_2D.
Failures			: yes
*/
end_mode_2D :: proc(using camera : Camera2D = {{0,0}, {0,0}, 0, 1, 1, -1}, loc := #caller_location) {
	render.end_mode_2D(&render_state, camera, loc);
}

/*
Description 		: get a camera that transform to pixel space, aka 1 unit = 1 pixel.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: the transformation is determined by the currently bound window.
Failures			: no
*/
get_pixel_space_camera :: proc(loc := #caller_location) -> Camera2D {
	return render.get_pixel_space_camera(&render_state, loc);
}

/*
Description 		: Returns the forward direction of a camera_3D.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: purely maths.
Failures			: no
*/
camera_forward :: render.camera_forward;

/*
Description 		: Returns the forward direction of a camera_3D only in x and z coords.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: purely maths.
Failures			: no
*/
camera_forward_horizontal :: render.camera_forward_horizontal;

/*
Description 		: Returns the right direction of a camera_3D.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: purely maths.
Failures			: no
*/
camera_right :: render.camera_right;

/*
Description 		: Moves a camera_3D by changing both the position and the target.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: purely maths. defined "camera_move :: proc(cam : ^Camera3D, movement : [3]f32)"
Failures			: no
*/
camera_move :: render.camera_move;

/*
Description 		: Sets a camera rotation as determined by the passed yaw and pitch.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: purely maths. Usefull for FPS cameras.
Failures			: no
*/
camera_rotation :: render.camera_rotation;





//////////////////////////////////// INPUT STUFF BELOW ////////////////////////////////////

/*
Can have the following states : release, press, repeat.
*/

Key_code  :: render.Key_code;		//enum
Mouse_code :: render.Mouse_code; 	//enum

/*
Description 		: Retrive the next char, a true is retruned in secound parameter when there is not more to recive.
GPU_state_changes 	: no
CPU_state_changes 	: yes
Allocations 		: yes, might shrink queue.
Notes 				: Usefull for getting keyboard inputs in a text/string like context.
Failures			: maybe
*/
recive_next_input :: proc () -> (char : rune, done : bool) {
	return render.recive_next_input(&render_state);
}

/*
Description 		: Retrive whatever the user has in his/hers clipboard.
GPU_state_changes 	: no
CPU_state_changes 	: glfw might change its state.
Allocations 		: yes, the returned string.
Notes 				: 
Failures			: yes, needs a bound window.
*/
get_clipboard_string :: proc(loc := #caller_location) -> string {
	return render.get_clipboard_string(&render_state);
}

/*
Description 		: Returns true if the key is down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes, window must be bound
*/
is_key_down :: proc(key : Key_code) -> bool {
	return render.is_key_down(&render_state, key);
}

/*
Description 		: Returns true if the key was not down last frame, but is down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes, window must be bound
*/
is_key_pressed :: proc(key : Key_code) -> bool {
	return render.is_key_pressed(&render_state, key);
}

/*
Description 		: Returns true if the key was down last frame, but is not down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes, window must be bound
*/
is_key_released :: proc(key : Key_code) -> bool {
	return render.is_key_released(&render_state, key);
}

/*
Description 		: Returns true if a key press signal was recived this frame, this includes the initial press and the repeating signal.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: Usefull for text fields, specificly if you want to detect backspace or likewise.
Failures			: yes, window must be bound
*/
is_key_triggered :: proc(key : Key_code) -> bool {
	return render.is_key_triggered(&render_state, key);
}

/*
Description 		: Returns true if the mouse button is down.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes, window must be bound
*/
is_button_down :: proc(button : Mouse_code) -> bool {
	return render.is_button_down(&render_state, button);
}

/*
Description 		: Returns true if the mouse button was not down last frame, but is down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes, window must be bound
*/
is_button_pressed :: proc(button : Mouse_code) -> bool {
	return render.is_button_pressed(&render_state, button);
}

/*
Description 		: Returns true if the mouse button was down last frame, but is not down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes, window must be bound
*/
is_button_released :: proc(button : Mouse_code) -> bool {
	return render.is_button_released(&render_state, button);
}

//TODO docs
get_mouse_pos :: proc () -> [2]f32 {
	return render.get_mouse_pos(&render_state);
}

//TODO docs
get_mouse_delta :: proc () -> [2]f32 {
	return render.get_mouse_delta(&render_state);
}

//TODO docs
get_scroll_delta :: proc () -> [2]f32 {
	return render.get_scroll_delta(&render_state);
}


//////////////////////////////////// MESH STUFF BELOW ////////////////////////////////////

/*
The Mesh is a intergal part of rendering, the meshs job is mainly to hold 2 things. First thing is the data. The data is stored in a Mesh_data struct.
The mesh_data struct holds the attributes for the mesh (attributes might be disabled) and it holds the indices data, which can be a []u16 or []u32.
The data once uploaded to the GPU can be deleted from the CPU if the ussage allows.
Furthermore the mesh holds the implementation. The implementation tells how the data is uploaded, the data can be uploaded in "single mode".
Single mode refers to the mesh being a stored isolated from other meshes, this is not fastest way to draw stuff, in fact is a very slow to draw stuff.
If single mode is used the implementation will be of type "Mesh_identifiers".
So a different aproch can optinally be used, this aproch stores many meshes together and this advantages when drawing. 
This means the mesh does not own the data on the GPU, instead the data is hold by a Mesh_buffer, and the implementation of type Mesh_buffer_index points into this mesh buffer.
*/

Mesh :: render.Mesh(Attribute_location);
Mesh_buffer :: render.Mesh_buffer(Attribute_location);

//skinny, moderate, thick
Reserve_behavior :: render.Reserve_behavior;


/*
Description 		: Creates big buffers of memory on the GPU, the buffers created depends on what is passed in active_locations. A buffer is allocated for each active location.
						An additionals buffer is also created if use_indicies is true. 
						initial_mem is the number of verticeis initally allocated for.
						padding is the amount of verticies between each mesh, this allows one to append to a mesh without rellocating it, pass 0 for thighly packed.
						active_locations is the attributes that the mesh buffer contains, ex : {.position, .texcoord}
						use_indicies tell if indicies should be used, the type used in the element buffer is always unsigned 32bits (unlike mesh, which can be both u32 and u16).
						reserve_behaviorhow the mesh buffer reallocates, if skinny then only the minimum required memory is allocated (not recommended).
							If moderate then a nice balance between wasted memory and required reallocations is made.
							If thick then you tell that you will need much speed and memory is less of a concern, this will allocate a lot of memory and not shrink.
GPU_state_changes 	: yes, buffer are created
CPU_state_changes 	: yes, follows GPU
Allocations 		: yes
Notes 				: This is what you want to do to draw fast. Try to keep things that are the same in the same mesh_buffer. Ex keep all players in the same mesh_buffer.
						And all static terrain in the same mesh buffer, and all 2D stuff in the same mesh buffer. In most cases you would want 1 shader per 1 mesh buffer.
Failures			: yes
*/
init_mesh_buffer :: proc(mesh_buffer : ^Mesh_buffer, initial_mem : u64, padding : u64, active_locations : bit_set[Attribute_location], use_indicies : bool, reserve_behavior : Reserve_behavior = .moderate, loc := #caller_location) {
	render.init_mesh_buffer(&render_state, mesh_buffer, initial_mem, padding, active_locations, use_indicies, reserve_behavior);
}

/*
Description 		: Uploads the data from a mesh to a place in a mesh_buffer, the implementation of the mesh is created to match the mesh_buffers data.
GPU_state_changes 	: yes, data is uploaded
CPU_state_changes 	: yes, follows GPU
Allocations 		: no
Notes 				: Once uploaded you can delete the CPU side mesh.
Failures			: yes
*/
upload_mesh_shared :: proc (mesh : ^Mesh, mesh_buffer : ^Mesh_buffer, loc := #caller_location) {
	render.upload_mesh_shared(&render_state, mesh, mesh_buffer);
}

unload_mesh_shared :: proc () {
	panic("TODO");
}

draw_mesh_shared :: proc () {
	panic("TODO");
}

/*
Description 		: draw a mesh. The shader passed must be the same as the currently bound shader.
GPU_state_changes 	: yes
CPU_state_changes 	: yes, follows GPU
Allocations 		: no
Notes 				: is the same as draw_mesh_single, but here the implementation of the mesh is a "Mesh_buffer_index". Uploads mvp uniform.
Failures			: yes
*/
draw_mesh_single_shared :: proc (shader : Shader, mesh : Mesh, mesh_buffer : Mesh_buffer, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, loc := #caller_location) {
	render.draw_mesh_single_shared(&render_state, shader, mesh, mesh_buffer, transform, loc)
}

draw_mesh_single_shared_instanced :: proc() {
	panic("TODO");
}

destroy_mesh_buffer :: proc() {
	panic("TODO");
}

/*
Description 		: uploads the data in a mesh to the GPU. if dyn is true then the GPU/driver expects the data to change often.
GPU_state_changes 	: yes
CPU_state_changes 	: yes, follows GPU
Allocations 		: no
Notes 				: the implementation of the mesh will become "Mesh_identifiers". The CPU side data can be deleted after this step.
Failures			: yes
*/
upload_mesh_single :: proc (mesh : ^Mesh, dyn : bool = false, loc := #caller_location) {
	render.upload_mesh_single(&render_state, mesh, dyn, loc)
}

/*
Description 		: Deleted the data from the GPU and CPU. The mesh will not reference any memory, CPU nor GPU.
GPU_state_changes 	: yes
CPU_state_changes 	: yes, follows GPU
Allocations 		: yes, deletes
Notes 				: 
Failures			: yes, implementation must be Mesh_identifiers
*/
unload_mesh_single :: proc(mesh : ^Mesh, loc := #caller_location) {
	render.unload_mesh_single(&render_state, mesh, loc)
}

/*
Description 		: draw a mesh. The shader passed must be the same as the currently bound shader.
GPU_state_changes 	: yes
CPU_state_changes 	: yes, follows GPU
Allocations 		: no
Notes 				: Uploads mvp uniform.
Failures			: yes, implementation must be Mesh_identifiers
*/
draw_mesh_single :: proc(shader : Shader, mesh : Mesh, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, loc := #caller_location) {
	render.draw_mesh_single(&render_state, shader, mesh, transform, loc);
}

draw_mesh_single_instanced :: proc() {
	panic("TODO");
}

/*
Description 		: calculates and places the result in the "tangent" attribute CPU side only.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The mesh shall contain data in the "postion" attribute before this call,
Failures			: ???
*/
calculate_tangents :: proc (mesh : ^Mesh) {
	render.calculate_tangents(&render_state, mesh);
}

/*
Description 		: returns a mesh containing a quad. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_quad :: proc(size : [3]f32 = {1,1,1}, position : [3]f32 = {0,0,0}, use_index_buffer := true, loc := #caller_location) -> Mesh {
	return render.generate_quad(&render_state, size, position, use_index_buffer, loc);
}

/*
Description 		: returns a mesh containing a circle. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_circle :: proc(diameter : f32 = 1, positon : [2]f32 = {0,0}, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (circle : Mesh) {
	return render.generate_circle(&render_state, diameter, positon, sectors, use_index_buffer, loc);
}

generate_triangle :: proc() {
	panic("TODO");
}

/*
Description 		: returns a mesh containing a cube. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_cube :: proc(size : [3]f32 = {1,1,1}, position : [3]f32 = {0,0,0}, use_index_buffer := true, loc := #caller_location) -> (circle : Mesh) {
	return render.generate_cube(&render_state, size, position, use_index_buffer, loc);
}

/*
Description 		: returns a mesh containing a cylinder. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_cylinder :: proc(offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 1, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> Mesh {
	return render.generate_cylinder(&render_state, offset, transform, stacks, sectors, use_index_buffer, loc);
}

/*
Description 		: returns a mesh containing a sphere. Contains attributes position, texcoord, normal and tangent. 
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_sphere :: proc(offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 10, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (sphere : Mesh) {
	return render.generate_sphere(&render_state, offset, transform, stacks, sectors, use_index_buffer, loc);
}

generate_pyramide :: proc() {
	panic("TODO");
}






//////////////////////////////////// SHADER STUFF BELOW ////////////////////////////////////


Shader :: render.Shader(Uniform_location, Attribute_location);


/*
Description 		: load all shaders in the specified shader folder into memory and compile them. This also does error checking.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: Will not load anything if the shader folder is nil.
Failures			: yes, shader code might be invalid.
*/
init_shaders :: proc(loc := #caller_location) {
	render.init_shaders(&render_state, loc);
}

/*
Description 		: unloads the shaders from the CPU and GPU. Called after init_shaders and before program exit.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes, frees some stuff.
Notes 				: 
Failures			: no
*/
destroy_shaders  :: proc(loc := #caller_location) {
	render.destroy_shaders(&render_state, loc);
}

/*
Description 		: this creates the shader program. Specify the name of the vertex and fraqment shader you want to use. A shader will be returned.
						The name you pass is without the extension, so ex : load_shader(&some_shader, "default", "default");
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: 
Failures			: yes
*/
load_shader :: proc(shader : ^Shader, vs_name : string, fs_name : string, loc := #caller_location) {
	render.load_shader(&render_state, shader, vs_name, fs_name, loc);
}

/*
Description 		: 
GPU_state_changes 	: 
CPU_state_changes 	: 
Allocations 		: 
Notes 				: 
Failures			: 
*/
unload_shader :: proc(shader : ^Shader) {
	render.unload_shader(&render_state, shader);
}

/*
Description 		: creates and returns the default shader used by furbs.
GPU_state_changes 	: Yes
CPU_state_changes 	: Yes
Allocations 		: yes
Notes 				: If you do not use the default shader, it is not created, the creation happens when you call this.
Failures			: hopefully not.
*/
get_default_shader :: proc() -> Shader {
	return render.get_default_shader(&render_state);
}

/*
Description 		: sets a uniform in a shader
GPU_state_changes 	: Yes
CPU_state_changes 	: Yes
Allocations 		: no
Notes 				: todo
Failures			: yes, types must match.
*/
place_uniform :: proc(shader : Shader, uniform_loc : Uniform_location, value : $T, loc := #caller_location) {
	render.place_uniform(&render_state, shader, uniform_loc, value, loc);
}

/*
Description 		: binds a shader, after it has been bound. any drawcalls will use that shader.
GPU_state_changes 	: Yes
CPU_state_changes 	: Yes
Allocations 		: no
Notes 				: Will set the uniforms, prj_mat, inv_prj_mat, view_mat and inv_view_mat from the currently bound camera.
Failures			: yes, types must match.
*/
bind_shader :: proc(shader : Shader, loc := #caller_location) {
	render.bind_shader(&render_state, shader);
}

/*
Description 		: unbinds a shader
GPU_state_changes 	: Yes
CPU_state_changes 	: Yes
Allocations 		: no
Notes 				: does not change the GPU state in non -debug.
Failures			: yes, shader must match the currently bound, camera must not be unbound.
*/
unbind_shader :: proc(shader : Shader, loc := #caller_location){
	render.unbind_shader(&render_state, shader);
}






//////////////////////////////////// SHAPES STUFF BELOW ////////////////////////////////////

Shape :: render.Shape;

/*
Description 		: Draw a shape, can be a Circle, Line or quad([4]f32)
GPU_state_changes 	: Yes
CPU_state_changes 	: Yes
Allocations 		: no
Notes 				: more comming, triangles and rounded.
Failures			: yes
*/
draw_shape :: proc(shape : Shape, rot : f32 = 0, texture : Maybe(Texture2D), shader : Shader, color : [4]f32, loc := #caller_location) {
	render.draw_shape(&render_state, shape, rot, texture, shader, color, loc);
}









//////////////////////////////////// SHAPES STUFF BELOW ////////////////////////////////////

Font :: render.Font;

/*
Description 		: loads a font given a filename relative to the exe
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: this creates a texture on the GPU and only uploads used symbosl to the GPU. The texture start empty.
Failures			: yes, font_context must be valid
*/
load_font_from_file :: proc(font_name : string, path : string) -> Font {
	return render.load_font_from_file(&render_state, font_name, path);
}

/*
Description 		: loads a font given some memory, the memory must be in a "true type format".
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: this creates a texture on the GPU and only uploads used symbosl to the GPU. The texture start empty.
Failures			: yes, font_context must be valid
*/
load_font_from_memory :: proc (font_name : string, data : []u8) -> Font {
	return render.load_font_from_memory(&render_state, font_name, data);
}

/*
Description 		: Returns the width and hieght of some text given the font, size and spacing.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: spacing is ussually 0.
Failures			: yes, font_context must be valid
*/
get_text_dimensions :: proc(text : string, font : Font, size : f32, spacing : f32 = 0) -> [2]f32 {
	return render.get_text_dimensions(&render_state, text, font, size, spacing);
}

/*
Description 		: Returns the maximum height that any text could fill. (Buggy, not true)
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: There seems to be a bug in font_stash or sbt's truetype, so this does not always true.
Failures			: yes, font_context must be valid
*/
get_max_text_height :: proc(font : Font, size : f32) -> f32 {
	return render.get_max_text_height(&render_state, font, size);
}

/*
Description 		: Returns pos_x, pos_y, width, height of some text given a position.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: get_text_dimensions can also be used.
Failures			: yes, font_context must be valid
*/
get_text_bounds :: proc(text : string, position : [2]f32, font : Font, size : f32, spacing : f32 = 0) -> (bounds : [4]f32) {
	return render.get_text_bounds(&render_state, text, position, font, size, spacing);
}

/*
Description 		: Draws text to the screen, the camera must be in pixel space to ensure proper dimensioning.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: Use get_pixel_space_camera.
Failures			: yes
*/
draw_text :: proc (text : string, position : [2]f32, font : Font, size : f32, spacing : f32, color : [4]f32, shader : Shader, loc := #caller_location) {
	render.draw_text(&render_state, text, position, font, size, spacing, color, shader, loc);
}






//////////////////////////////////// TEXTURE STUFF BELOW ////////////////////////////////////


Texture2D :: render.Texture2D;
Depth_texture2D :: render.Depth_texture2D;

Render_texture :: render.Render_texture;
Pixel_format :: render.Pixel_format;
Depth_format :: render.Depth_format;

/*
Description 		: load a texture from a png file.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: the texture is uploaded to GPU and is kept in memory on CPU side.
Failures			: yes
*/
load_texture_from_file :: proc(filename : string, loc := #caller_location) -> Texture2D {
	return render.load_texture_from_file(&render_state, filename, loc);
}

/*
Description 		: load a texture from memory, the format must be png. 
						texture_path can be left "", it is used for debuging messages.
						flipped tells if the image should flip verically.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: data is uploaded as R8B8G8A8 format.
Failures			: yes
*/
load_texture_from_png_bytes :: proc(data : []byte, texture_path := "", flipped := true, loc := #caller_location) -> Texture2D {
	return render.load_texture_from_png_bytes(&render_state, data, texture_path, flipped, loc);
}

/*
Description 		: load a texture from memory, the data format must be the same as Pixel_format.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: data is keept in both GPU and CPU.
Failures			: yes
*/
load_texture_from_raw_bytes :: proc(data : []byte, width, height : i32, format : Pixel_format = .uncompressed_RGBA8, loc := #caller_location) -> Texture2D {
	return render.load_texture_from_raw_bytes(&render_state, data, width, height, format);
}

/*
Description 		: flips the contents of a texture in the y(vertical) direction.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: the data is not updated in the GPU. This is primarily used internally.
Failures			: no
*/
flip_texture :: proc(data : []byte, width, height, channels : int) {
	render.flip_texture(&render_state, data, width, height, channels);
}

/*
Description 		: unloads a texture, it removes both CPU and GPU memory.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: 
Failures			: not likely
*/
unload_texture :: proc(tex : ^Texture2D) {
	render.unload_texture(&render_state, tex);
}

/*
Description 		: unloads a depth texture, it removes both CPU and GPU memory.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: 
Failures			: not likely
*/
unload_depth_texture :: proc(rt : ^Render_texture) {
	render.unload_depth_texture(&render_state, rt);
}

/*
Description 		: check if a texture is ready to use.
GPU_state_changes 	: no, but might do some driver interaction. 
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes
*/
is_texture_ready :: proc(texture : Texture2D, loc := #caller_location) {
	render.is_texture_ready(&render_state, texture, loc);
}


is_depth_texture_ready :: proc(depth : Depth_texture2D, loc := #caller_location) -> bool {
	render.is_depth_texture_ready(&render_state, depth, loc);
}


/*
Description 		: creates a Render_texture (Framebuffer) 
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: mutliple color atchments will be supported later.
Failures			: yes
*/
load_render_texture :: proc(width : i32, height : i32, number_of_color_attachments : int = 1, depth_as_render_buffer : bool = false,
							 depth_buffer_bits : Depth_format = .bits_24, color_format : Pixel_format = .uncompressed_RGBA8, loc := #caller_location) -> Render_texture {
	return render.load_render_texture(&render_state, width, height, number_of_color_attachments, depth_as_render_buffer, depth_buffer_bits, color_format, loc);
}


/*
Description 		: unloads a render_texture, it removes both CPU and GPU memory.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: 
Failures			: yes
*/
unload_render_texture :: proc(rt : ^Render_texture) {
	render.unload_render_texture(&render_state, rt);
}

/*
Description 		: check if a render texture is ready
GPU_state_changes 	: no, but might call some gl/vulkan functions
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: yes
*/
is_render_texture_ready :: proc(render_texture : Render_texture, loc := #caller_location) -> bool {
	render.is_render_texture_ready(&render_state, render_texture, loc);
}

/*
Description 		: resizes a render texture, content might be lost.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: 
Failures			: yes
*/
resize_render_texture :: proc(render_texture : ^Render_texture, width : i32, height : i32) {
	render.resize_render_texture(&render_state, render_texture, width, height);
}

/*
Description 		: resizes a render texture, content might be lost.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: 
Failures			: yes
*/
blit_render_texture_to_screen :: proc(render_texture : Render_texture, loc := #caller_location) { //TODO choose attachment
	render.blit_render_texture_to_screen(&render_state, render_texture, loc);
}

/*
Description 		: sets a render texture as the render target, this mean you will render to that texture.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: 
Failures			: yes
*/
begin_texture_mode :: proc(target : Render_texture, loc := #caller_location) {
	render.begin_texture_mode(&render_state, target, loc);
}


/*
Description 		: sets the render target to the screens
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: 
Failures			: yes
*/
end_texture_mode :: proc(target : Render_texture, loc := #caller_location) {
	render.end_texture_mode(&render_state, target, loc);
}


/*
Description 		: returns a 1x1 pixel white texture.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: Used internally
Failures			: yes
*/
get_white_texture :: proc(target : Render_texture, loc := #caller_location) {
	render.get_white_texture(&render_state, target, loc);
}






//////////////////////////////////// WINDOW STUFF BELOW ////////////////////////////////////

Window :: render.Window;
Mouse_mode :: render.Mouse_mode;
GL_version :: render.GL_version;

/*
Description 		: creates a window
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes
Notes 				: mutiple windows can be created. The window is bound when created.
Failures			: yes
*/
init_window :: proc(width, height : i32, title : string, required_gl_verion : Maybe(GL_version) = nil, culling : bool = true, loc := #caller_location) -> Window {
	return render.init_window(&render_state, width, height, title, required_gl_verion, culling, loc);
}

/*
Description 		: destroys the window
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: yes something happens
Notes 				: 
Failures			: ??
*/
destroy_window  :: proc(window : ^Window, loc := #caller_location) -> Window {
	return render.destroy_window(&render_state, window, loc);
}

/*
Description 		: binds a window, gl calls will target this window.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: only needed when using multiple windows, creating a window also binds it.
Failures			: yes
*/
bind_window :: proc(window : Window, loc := #caller_location) {
	render.bind_window(&render_state, window, loc);
}

/*
Description 		: Begins the frame
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: call every frame in the begining of your render loop for each window.
Failures			: no
*/
begin_frame :: proc(window : Window, clear_color : [4]f32 = {0,0,0,1}, loc := #caller_location) {
	render.begin_frame(&render_state, window, clear_color, loc);
}

/*
Description 		: ends the frame
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: call every frame in the end of your render loop for each window.
Failures			: no
*/
end_frame :: proc(window : Window, loc := #caller_location) {
	render.end_frame(&render_state, window, loc);
}

/*
Description 		: set the opengl viewport, you don't need to call this.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: used internally, dependent on bound window.
Failures			: no
*/
set_view :: proc() {
	render.set_view(&render_state);
}

/*
Description 		: should the window close.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
should_close :: proc(window : Window) -> bool {
	return render.should_close(&render_state, window);
}

/*
Description 		: enable or disable vsync
GPU_state_changes 	: yes
CPU_state_changes 	: no
Allocations 		: no
Notes 				: true to enable, false to disable
Failures			: no
*/
enable_vsync :: proc(enable : bool) {
	render.enable_vsync(&render_state, enable);
}

/*
Description 		: returns the width of the currently bound window.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
get_screen_width :: proc(loc := #caller_location) -> i32 {
	return render.get_screen_width(&render_state, loc);
}

/*
Description 		: returns the height of the currently bound window.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
get_screen_height :: proc(loc := #caller_location) -> i32 {
	return render.get_screen_width(&render_state, loc);
}

/*
Description 		: sets the mousemode
						locked for a FPS like mode 
						hidden to not show the cursor
						normal to show the cursor.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: use to make FPS
Failures			: no
*/
mouse_mode :: proc(mouse_mode : Mouse_mode, loc := #caller_location) {
	render.mouse_mode(&render_state, mouse_mode, loc);
}

/*
Description 		: sets a custom cursor, the format is passed in R8G8B8A8. 
GPU_state_changes 	: no, OS might do some stuff
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: works well on windows
Failures			: yes
*/
set_cursor :: proc(cursor : []u8, size : i32, loc := #caller_location) {
	render.set_cursor(&render_state, cursor, size, loc);
}

/*
Description 		: gets the delta time of the currently bound window, make your own if you use many windows.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
delta_time :: proc() -> f32 {
	return render.delta_time(&render_state);
}

/*
Description 		: return the time in sec since the bound window was created 
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
time_since_window_creation :: proc() -> f64 {
	return render.time_since_window_creation(&render_state);
}








