package furbs_laycal;

Layout_state :: struct {
	elements : [dynamic]Element_layout,	
	element_stack : [dynamic]Element_layout,	
}

Element_layout :: struct {
	size : [2]i32,
	position : [2]i32,
	user_data : rawptr,
}

make_layout_state :: proc () -> ^Layout_state {

}

destroy_laytout_state :: proc (ls : ^Layout_state) {

}

begin_layout_state :: proc (ls : ^Layout_state) {

}

end_layout_state :: proc (ls : ^Layout_state) -> Element_layout {

}

open_element :: proc (state : ^Layout_state, user_data : rawptr) {

}

close_element :: proc (state : ^Layout_state) {
	


	//calculate the size of the element, we know it here

}







size_pass :: proc () {

}

position_pass :: proc () {

}


