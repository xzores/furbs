package glslang;

import glsl "glslang_bindings"
import utils "../utils"

import "core:os"
import "core:fmt"
import "core:strings"
import "core:slice"
import "core:c"

import "core:testing"

// Declare a basic test for interacting with GLSLang API
//@test
//glsl.api_test :: proc(t : ^testing.T) {

main :: proc () {	
	
	include_proc : glsl.Include_system_func : proc "c" (ctx: rawptr, header_name: cstring, includer_name: cstring, include_depth: c.size_t) -> ^glsl.Include_result {
		
		return nil;
	}
	
	local_proc : glsl.Include_local_func : proc "c" (ctx: rawptr, header_name: cstring, includer_name: cstring, include_depth: c.size_t) -> ^glsl.Include_result {
		
		return nil;
	}
	
	free_res_proc : glsl.Free_include_result_func : proc "c" (ctx: rawptr, result: ^glsl.Include_result) -> c.int {
		
		return 0;
	}
	
	callbacks := glsl.Include_callbacks {
		include_system      = include_proc,
		include_local       = local_proc,
		free_result 		= free_res_proc,
	}
	
	vert_code, vert_ok := os.read_entire_file_from_filename("test.vert");
	defer delete(vert_code)
	assert(vert_ok, "failed to load vertex shader file");
	
	frag_code, frag_ok := os.read_entire_file_from_filename("test.frag");
	defer delete(frag_code)
	assert(frag_ok, "failed to load fragment shader file");
	
	glsl.initialize_process();
	
	default_resource := glsl.default_resource();
	
	c_vert_code, e := strings.clone_to_cstring(string(vert_code));
	assert(e == nil);
	
    // Variables for version and shaders
    vert_input := glsl.Input{
		language 							= .glsl,
		stage                             	= .vertex,
		
		//The version the PC is using
		client                            	= .opengl,
		client_version                    	= .opengl_450,
		
		//What we want to compile to
		target_language                   	= .spv,
		target_language_version           	= .spv_1_3,
		
		/* Shader source code */
		code                              	= c_vert_code,
		default_version                   	= 330,
		default_profile                   	= {.core_profile},
		force_default_version_and_profile 	= true,
		forward_compatible                	= true,
		messages                          	= {},
		resource                          	= default_resource,
		//callbacks                         	= callbacks,
		//callbacks_ctx                     	= nil,
	};
	
	frag_input := glsl.Input{
		language 							= .glsl,
		stage                             	= .fragment,
		
		//The version the PC is using
		client                            	= .opengl,
		client_version                    	= .opengl_450,
		
		//What we want to compile to
		target_language                   	= .spv,
		target_language_version           	= .spv_1_3,
		
		/* Shader source code */
		code                              	= fmt.ctprintf("%v", frag_code),
		default_version                   	= 330,
		default_profile                   	= {.core_profile},
		force_default_version_and_profile 	= true,
		forward_compatible                	= true,
		messages                          	= {},
		resource                          	= default_resource,
		//callbacks                         	= callbacks,
		//callbacks_ctx                     	= nil,
	};
	vert_shader := glsl.shader_create(&vert_input);
	
	pre_err := glsl.shader_preprocess(vert_shader, &vert_input);
	fmt.printf("Preprocessor info result: %v\n", glsl.shader_get_info_log(vert_shader));
	fmt.printf("Preprocessor debug info result: %v\n", glsl.shader_get_info_debug_log(vert_shader));
	
	par_err := glsl.shader_parse(vert_shader, &vert_input);
	fmt.printf("Parser info result: %v\n", glsl.shader_get_info_log(vert_shader));
	fmt.printf("Parser debug info result: %v\n", glsl.shader_get_info_debug_log(vert_shader));
	
	/*
	program := glsl.program_create();
	glsl.program_add_shader(program, vert_shader);
	
	if (!glsl.program_link(program, {}))
	{
		//fmt.printf("Linker info result: %v\n", glsl.shader_get_info_log(vert_shader));
		//fmt.printf("Linker debug info result: %v\n", glsl.shader_get_info_debug_log(vert_shader));
	}
	
	glsl.program_SPIRV_generate(program, vert_input.stage);
	
	sprv_msgs := glsl.program_SPIRV_get_messages(program)
	if (sprv_msgs != nil)
	{
		//fmt.printf("SPIRV messages: %s\n", sprv_msgs);
	}
	*/
	
	glsl.shader_delete(vert_shader);
}
