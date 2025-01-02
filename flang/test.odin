package flang;

import "core:fmt"

main :: proc () {
	
	s := create_context_from_file("shaders/test.flang"); 
	lex(s);
	//fmt.printf("Shader : %#v", s);
	
}


