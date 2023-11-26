package examples;

import "../gui"
import "../render"


//////////////////////////////////////////////////////////////////////// DOCUMENTATION ////////////////////////////////////////////////////////////////////////

//This file is not required to use furbs, but it is very recommended that you add this file to your project or you create a new package with this file.
//This will handle the global state of the render furbs libs. This file creates a single "Render_state", this might be refered to as the global state.

//In this file you will find comments like this above functions, these are the documentation for that function.
/*
Description 		: Here you will find a description of the function,
GPU_state_changes 	: Here you will typically find a yes or a no, telling you if the function interacts with the GPU. Somethis this is more elaporated.
CPU_state_changes 	: Furbs keep track of the GPU state to minimize state changes and more.
Allocations 		: This tells if the function allocates/frees any memory from the heap.
Notes 				: Some additional comments
Failures			: This tells if the function can fail, aka it has a assert, panic or return an error code. Somethis this is more elaporated, if elaporated there might still be more then one way to fail.
*/



//////////////////////////////////////////////////////////////////////// USER IMPLEMENTATION ////////////////////////////////////////////////////////////////////////

//Here you can define the attributes you need, position, texcoord, normal and tangent are required by furbs.
Attribute_location :: enum {
	position,
    texcoord,
    normal,
	tangent,
}

//Here you can define the uniforms you need. The following are required and set by furbs:
	//time
	//prj_mat, inv_prj_mat
	//view_mat, inv_view_mat
	//mvp, inv_mvp
	//model_mat, inv_model_mat
	//color_diffuse
	//texture_diffuse
	//texcoords_mat
Uniform_location :: enum {

	//TODO time,

	//Per camera
	prj_mat,
	inv_prj_mat,
	
	view_mat,
	inv_view_mat,
		
	/////////// Anything above binds at bind_shader or before, anything below is a draw call implementation thing ///////////

	//Per model
	mvp,
	inv_mvp,		//will it ever be used?

	model_mat,
	inv_model_mat,	//will it ever be used?
	
	//Per material (materials are not a part of furbs, handle yourself)
	diffuse_color,
	diffuse_texture,

	//Primarily for text
	texcoords_mat,

	/////////// Enter user uniforms below ///////////
}

//////////////////////////////////////////////////////////////////////// FURBS INTERFACE BEGIN ////////////////////////////////////////////////////////////////////////





//////////////////////////////////// RENDER STATE BELOW ////////////////////////////////////

//This is the state of the render API, virtually all furbs function requires this as a parameter.
render_state : render.Render_state(Uniform_location, Attribute_location);







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
begin_mode_3D :: proc (using camera : Camera3D, use_transparency := true, loc := #caller_location) {
	using render;
	begin_mode_3D(render_state, camera, use_transparency, loc);
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
	using render;
	begin_mode_3D(render_state, camera, use_transparency, loc);
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
	using render;
	begin_mode_2D(render_state, camera, use_transparency, loc);
}

/*
Description 		: ends the current camera and stops 2D mode.
GPU_state_changes 	: yes
CPU_state_changes 	: yes
Allocations 		: no
Notes 				: the camera must be the same as used in the previous begin_mode_2D.
Failures			: yes
*/
end_mode_2D :: proc(using camera : Camera2D = {{0,0}, {0,0}, 0, 1, 1, -1}, use_transparency := true, loc := #caller_location) {
	using render;
	end_mode_2D(render_state, camera, use_transparency, loc);
}

/*
Description 		: get a camera that transform to pixel space, aka 1 unit = 1 pixel.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: the transformation is determined by the currently bound window.
Failures			: no
*/
get_pixel_space_camera :: proc(loc := #caller_location) -> (cam : Camera2D) {
	using render;
	get_pixel_space_camera(render_state, loc);
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
	using render;
	recive_next_input(render_state);
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
	using render;
	get_clipboard_string(render_state);
}

/*
Description 		: Returns true if the key is down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
is_key_down :: proc(key : Key_code) -> bool {
	using render;
	is_key_down(render_state, key);
}

/*
Description 		: Returns true if the key was not down last frame, but is down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
is_key_pressed :: proc(key : Key_code) -> bool {
	using render;
	is_key_pressed(render_state, key);
}

/*
Description 		: Returns true if the key was down last frame, but is not down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
is_key_released :: proc(key : Key_code) -> bool {
	using render;
	is_key_released(render_state, key);
}

/*
Description 		: Returns true if a key press signal was recived this frame, this includes the initial press and the repeating signal.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: Usefull for text fields, specificly if you want to detect backspace or likewise.
Failures			: no
*/
is_key_triggered :: proc(key : Key_code) -> bool {
	using render;
	is_key_triggered(render_state, key);
}

/*
Description 		: Returns true if the mouse button is down.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
is_button_down :: proc(button : Mouse_code) -> bool {
	using render;
	is_button_down(render_state, button);
}

/*
Description 		: Returns true if the mouse button was not down last frame, but is down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
is_button_pressed :: proc(button : Mouse_code) -> bool {
	using render;
	is_button_pressed(render_state, button);
}

/*
Description 		: Returns true if the mouse button was down last frame, but is not down this frame.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: no
Notes 				: 
Failures			: no
*/
is_button_released :: proc(button : Mouse_code) -> bool {
	using render;
	is_button_released(render_state, button);
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
Mesh :: render.Mesh;

Mesh_buffer :: render.Mesh;

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
	using render;
	init_mesh_buffer(render_state, mesh_buffer, initial_mem, padding, active_locations, use_indicies, reserve_behavior);
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
	using render;
	upload_mesh_shared(render_state, mesh, mesh_buffer);
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
	using render;
	draw_mesh_single_shared(render_state, shader, mesh, mesh_buffer, transform, loc)
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
	using render;
	upload_mesh_single(render_state, mesh, dyn, loc)
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
	using render;
	unload_mesh_single(render_state, mesh, loc)
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
	using render;
	draw_mesh_single(shader, mesh, transform, loc);
}

draw_mesh_single_instanced :: proc() {
	panic("TODO");
}

/*
Description 		: Calculates and places the result in the "tangent" attribute CPU side only.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The mesh shall contain data in the "postion" attribute before this call,
Failures			: ???
*/
calculate_tangents :: proc (mesh : ^Mesh) {
	using render;
	calculate_tangents(render_state, mesh);
}

/*
Description 		: Returns a mesh containing a quad. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_quad :: proc(size : [3]f32 = {1,1,1}, position : [3]f32 = {0,0,0}, use_index_buffer := true, loc := #caller_location) -> Mesh {
	using render;
	return generate_quad(render_state, size, position, use_index_buffer, loc);
}

/*
Description 		: Returns a mesh containing a circle. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_circle :: proc(diameter : f32 = 1, positon : [2]f32 = {0,0}, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (circle : Mesh) {
	using render;
	return generate_circle(render_state, diameter, positon, sectors, use_index_buffer, loc);
}

generate_triangle :: proc() {
	panic("TODO");
}

/*
Description 		: Returns a mesh containing a cube. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_cube :: proc(size : [3]f32 = {1,1,1}, position : [3]f32 = {0,0,0}, use_index_buffer := true, loc := #caller_location) -> (circle : Mesh) {
	using render;
	return generate_cube(render_state, size, position, use_index_buffer, loc);
}

/*
Description 		: Returns a mesh containing a cylinder. Contains attributes position, texcoord, normal and tangent.
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_cylinder :: proc(offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 1, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> Mesh {
	using render;
	return generate_cylinder(offset, transform, stacks, sectors, use_index_buffer, loc);
}

/*
Description 		: Returns a mesh containing a sphere. Contains attributes position, texcoord, normal and tangent. 
GPU_state_changes 	: no
CPU_state_changes 	: no
Allocations 		: yes
Notes 				: The implementation is nil and must be created calling upload_mesh_single or upload_mesh_shared.
Failures			: no
*/
generate_sphere :: proc(offset : [3]f32 = {0,0,0}, transform : matrix[4, 4]f32 = linalg.MATRIX4F32_IDENTITY, stacks : int = 10, sectors : int = 20, use_index_buffer := true, loc := #caller_location) -> (sphere : Mesh) {
	using render;
	return generate_sphere(render_state, offset, transform, stacks, sectors, use_index_buffer, loc);
}

generate_pyramide :: proc() {
	panic("TODO");
}






//////////////////////////////////// SHADER STUFF BELOW ////////////////////////////////////










//////////////////////////////////// WINDOW STUFF BELOW ////////////////////////////////////

Window :: render.Window;














