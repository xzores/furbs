package translator;

import "core:fmt"
import "core:strings"
import "core:reflect"
import "core:unicode"
import "core:os"

Arg :: struct {
	name : string,
	type : GL_type,
	ptr_cnt : int,
}

Return :: struct {
	type : GL_type,
	ptr_cnt : int,
}

GL_type :: enum {
	unknown,
	void,
	GLboolean,
	GLbyte,
	GLubyte,
	GLshort,
	GLushort,
	GLint,
	GLuint,
	GLsizei,
	GLfloat,
	GLdouble,
	GLenum,			//This must be cast to a u32 when calling impl_**
	GLbitfield,		//This must be cast to a u32 when calling impl_**
	GLchar,
	GLintptr,
	GLsizeiptr,
	GLint64,
	GLuint64,
	
	GLdebugproc,

	GLsync,

	GLstring,
	GLoutstring,

	DrawArraysIndirectCommand,
	DrawElementsIndirectCommand,
	DispatchIndirectCommand,
	uintptr,
}

Func_info :: struct {
	overwrite : Maybe(string),
	name : string,
	args : []Arg,
	ret : Return,
}

get_odin_type_name_arg :: proc(t : GL_type, ptr_cnt : int, alloc := context.allocator, loc := #caller_location) -> string {
	context.allocator = alloc;

	ptr_cnt := ptr_cnt;

	assert(t != .unknown, "!??!?");
	assert(ptr_cnt <= 2, "ptr_cnt must be no more then 2", loc);

	t_arr : string = "";
	t_name : string = "";

	if t == .void {
		assert(ptr_cnt >= 1, "void as an arg must be a pointer", loc);
		ptr_cnt -= 1;
		t_name = "rawptr";
	}
	else {
		t_name = reflect.enum_string(t);
	}

	if ptr_cnt > 0 {
		t_arr = "^"
	}

	return strings.concatenate({t_arr, t_name});
}

get_odin_type_name_ret :: proc(t : GL_type, ptr_cnt : int, alloc := context.allocator, loc := #caller_location) -> string {
	context.allocator = alloc;

	ptr_cnt := ptr_cnt;

	assert(t != .unknown, "!??!?");
	assert(ptr_cnt <= 2, "ptr_cnt must be no more then 2", loc);

	t_arr : string = "";
	t_name : string = "";

	if t == .void {
		ptr_cnt -= 1;
		t_name = "rawptr";
	}
	else {
		t_name = reflect.enum_string(t);
	}

	if ptr_cnt > 0 {
		t_arr = "^"
	}

	return strings.concatenate({t_arr, t_name});
}

name_map : map[string]string = {
	"map" = "_map",
}

args_map : map[string]Arg = {

	"DrawArraysIndirect" = Arg{"indirect", .DrawArraysIndirectCommand, 1},

	"DrawArraysIndirect" = Arg{"indirect", .DrawArraysIndirectCommand, 1},
	"MultiDrawArraysIndirect" = Arg{"indirect", .DrawArraysIndirectCommand, 1},
	"MultiDrawArraysIndirectCount" = Arg{"indirect", .DrawArraysIndirectCommand, 1},
	
	"DrawElementsIndirect" = Arg{"indirect", .DrawElementsIndirectCommand, 1},
	"MultiDrawElementsIndirect" = Arg{"indirect", .DrawElementsIndirectCommand, 1},
	"MultiDrawElementsIndirectCount" = Arg{"indirect", .DrawElementsIndirectCommand, 1},

	"DispatchComputeIndirect"  = Arg{"indirect", .DispatchIndirectCommand, 1},

	"VertexAttribPointer" = Arg{"pointer", .uintptr, 0},
	"VertexAttribIPointer" = Arg{"pointer", .uintptr, 0},
	"VertexAttribLPointer" = Arg{"pointer", .uintptr, 0},
	"GetNamedBufferPointerv" = Arg{"pointer", .uintptr, 1},
	"GetVertexAttribPointerv" = Arg{"pointer", .uintptr, 1},

	"GetProgramInfoLog" = Arg{"infoLog", .GLoutstring, 0},
	"GetShaderInfoLog" = Arg{"infoLog", .GLoutstring, 0},
	"GetProgramPipelineInfoLog" = Arg{"infoLog", .GLoutstring, 0},
	"GetActiveAttrib" = Arg{"name", .GLoutstring, 0},
	"GetActiveUniform" = Arg{"name", .GLoutstring, 0},
	"GetTransformFeedbackVarying" = Arg{"name", .GLoutstring, 0},
	"GetActiveSubroutineName" = Arg{"name", .GLoutstring, 0},
	"GetActiveSubroutineUniformName" = Arg{"name", .GLoutstring, 0},

	"GetObjectPtrLabel" = Arg{"label", .GLoutstring, 0},
	"GetObjectLabel" = Arg{"label", .GLoutstring, 0},
	
	"GetDebugMessageLog" = Arg{"messageLog", .GLoutstring, 0},

	"GetShaderSource" = Arg{"source", .GLoutstring, 0},
	//"GetShaderSource" = Arg{"source", .GLoutstring, 0},
}

rets_map : map[string]Return = {
	"GetString" = {.GLstring, 0},
	"GetStringi" = {.GLstring, 0},
}

main :: proc () {

	{
		v, ok := reflect.enum_from_name(GL_type, "GLuint64");
		assert(ok, "reflect.enum_from_name does not work!");
		assert(v == GL_type.GLuint64, "reflect.enum_from_name does not work!");

		v, ok = reflect.enum_from_name(GL_type, "GLuint");
		assert(ok, "reflect.enum_from_name does not work!");
		assert(v == GL_type.GLuint, "reflect.enum_from_name does not work!");
	}

	txt : string = #load("functions.txt");

	function_list := make([dynamic]Func_info);

	lines := strings.split(txt, "\n");
	
	for line in lines {
		
		name : strings.Builder = strings.builder_make_none();
		defer strings.builder_destroy(&name);

		args := make([dynamic]Arg);
		/*defer {
			for a in args {
				delete(a.name);
			}
			delete(args);
		}*/
		
		ret : strings.Builder = strings.builder_make_none();
		defer strings.builder_destroy(&ret);

		/////////////

		State :: enum {
			none,
			gl_prefix,
			name,
			//args,
			arg_pre,
			arg_type,
			arg_name,
			rets,
			ret,
		}

		state : State = .name;

		cur_arg_type := strings.builder_make_none();
		cur_arg_name := strings.builder_make_none();
		arg_ptr_cnt : int = 0;

		ret_ptr_cnt : int = 0;

		skip : bool = false;

		for r in line {
			switch state {
				case .none:
					switch r {
						case '\n':
							skip = true; //because we start in .name
						case '/':
							skip = true; //because we start in .name
						case 'g':
							state = .gl_prefix;
						case:
							fmt.panicf("ahh! the function does not start with gl, line : %v", line); 
					}
				case .gl_prefix:
					switch r {
						case '\n':
							skip = true; //because we start in .name
						case '/':
							skip = true; //because we start in .name
						case 'l':
							state = .name;
						case:
							fmt.panicf("ahh! the function does not start with gl, line : %v", line); 
					}
				case .name:
					switch r {
						case '\n':
							skip = true; //because we start in .name
						case '/':
							skip = true; //because we start in .name
						case '(':
							state = .arg_type;
						case:
							strings.write_rune(&name, r);
					}
				case .arg_pre:
					state = .arg_type;
					switch r {
						case ' ':
						case:
							strings.write_rune(&cur_arg_type, r);
					}
				case .arg_type:
					switch r {
						case '*':
							arg_ptr_cnt += 1;
						case ')':
							state = .rets;
						case ' ':
							state = .arg_name;
						case:
							strings.write_rune(&cur_arg_type, r);
					}
				case .arg_name:
					switch r {
						case '*':
							arg_ptr_cnt += 1;
						case ',':
							arg_name : string;
							if strings.to_string(cur_arg_name) in name_map {
								arg_name = strings.clone(name_map[strings.to_string(cur_arg_name)]);
							}
							else {
								arg_name = strings.clone(strings.to_string(cur_arg_name));
							}
							typename := strings.to_string(cur_arg_type);
							type, ok := reflect.enum_from_name(GL_type, typename);
							fmt.assertf(ok, "The name '%v' for line : %v is not a valid enum name.\n", typename, line);
							
							name := strings.to_string(name);
							to_add : Arg = {arg_name, type, arg_ptr_cnt};
							if name in args_map { //change the type to fit some custom stuff
								arg_entry : Arg = args_map[name];
								if arg_entry.name == to_add.name {
									to_add.ptr_cnt = arg_entry.ptr_cnt;
									to_add.type = arg_entry.type;
								}
							}
							append(&args, to_add)
							
							strings.builder_reset(&cur_arg_name);
							strings.builder_reset(&cur_arg_type);
							arg_ptr_cnt = 0;
							state = .arg_pre;
						case ')':
							arg_name : string;
							if strings.to_string(cur_arg_name) in name_map {
								arg_name = strings.clone(name_map[strings.to_string(cur_arg_name)]);
							}
							else {
								arg_name = strings.clone(strings.to_string(cur_arg_name));
							}
							typename := strings.to_string(cur_arg_type);
							type, ok := reflect.enum_from_name(GL_type, typename);
							fmt.assertf(ok, "The name '%v' for line : %v is not a valid enum name.\n", typename, line);
							
							name := strings.to_string(name);
							to_add : Arg = {arg_name, type, arg_ptr_cnt};
							if name in args_map { //change the type to fit some custom stuff
								arg_entry : Arg = args_map[name];
								if arg_entry.name == to_add.name {
									to_add.ptr_cnt = arg_entry.ptr_cnt;
									to_add.type = arg_entry.type;
								}
							}
							append(&args, to_add)
							
							strings.builder_reset(&cur_arg_name);
							strings.builder_reset(&cur_arg_type);
							arg_ptr_cnt = 0;
							state = .rets;
						case:
							strings.write_rune(&cur_arg_name, r);
					}
				case .rets:
					switch r {
						case '-':
						case '>':
							state = .ret;
						case:
							panic("No!");
					}
				case .ret:
					if unicode.is_letter(r) || unicode.is_number(r) {
						strings.write_rune(&ret, r);
					} else if r == '*' {
						ret_ptr_cnt += 1;
					}
			}
		}

		func_info : Func_info;

		if !skip {
			enum_type, ok := reflect.enum_from_name(GL_type, strings.to_string(ret));
			fmt.assertf(ok, "The line : %v is not a valid enum name. Name : %v\n", line, strings.to_string(ret));

			func_info = {
				overwrite = nil,
				name = strings.clone(strings.to_string(name)),
				args = args[:],
				ret = {enum_type, ret_ptr_cnt},
			}
			
			name := strings.to_string(name);
			if name in rets_map {
				func_info.ret = rets_map[name];
			}
		}
		else {
			func_info.overwrite = line;
			fmt.printf("skipping\n");
		}
		
		append(&function_list, func_info);
	}

	template : string = #load("template.txt");
	t_lines := strings.split(template, "\n");

	/*
		$function$				function_name
		$args_defs$ 			name : Type, name : Type, ...
		$return_pointer_cond$	Maybe ->
		$return_type_cond$		Type or ''
		$return_type$			Type
		$return_cond$			'return' if there is a return
		$args_pass$ 			name, name, ...s
		$args_pass_cast$ 		name, cast(u32)name, ...  the "cast(u32)" happens for GLenums
		£ 						', ' when there is more then 0 arguments
	*/

	code_res_builder : strings.Builder = strings.builder_make_none();

	for t_line in t_lines {
		
		require_return : bool = false;
		require_no_return : bool = false;

		if strings.contains(t_line, "@return") {
			require_return = true;
		}
		if strings.contains(t_line, "@no_return") {
			require_no_return = true;
		}

		if strings.contains(t_line, "$") {
			for func in function_list {
				if s, ok := func.overwrite.?; ok {
					strings.write_string(&code_res_builder, s);
				} else {

					new_line := strings.clone(t_line);
					
					if (func.ret.type == .void && func.ret.ptr_cnt == 0) {
						//this functions returns nothing
						if require_return {
							continue;
						}
					}
					else {
						if require_no_return {
							continue;
						}
					}

					{
						res, was_alloc := strings.replace_all(new_line, "@return", "");
						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}
					{
						res, was_alloc := strings.replace_all(new_line, "@no_return", "");
						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}

					{
						res, was_alloc := strings.replace_all(new_line, "$function$", func.name);
						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}
					{
						args_string : strings.Builder = strings.builder_make_none();
						
						for a, i in func.args {
							strings.write_string(&args_string, a.name);
							strings.write_string(&args_string, " : ");
							
							t := get_odin_type_name_arg(a.type, a.ptr_cnt);
							defer delete(t);
							strings.write_string(&args_string, t);

							if i < len(func.args) - 1 {
								strings.write_string(&args_string, ", ");
							}
							//fmt.printf("a : %v\n", a);
						}
						res, was_alloc := strings.replace_all(new_line, "$args_defs$", strings.to_string(args_string));
						
						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}
					{
						res : string;
						was_alloc : bool;

						if len(func.args) == 0 {
							res, was_alloc = strings.replace_all(new_line, "£", "");
						}
						else {
							res, was_alloc = strings.replace_all(new_line, "£", ", ");
						}

						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}
					{
						args_string : strings.Builder = strings.builder_make_none();
						
						for a, i in func.args {
							strings.write_string(&args_string, a.name);
							if i < len(func.args) - 1 {
								strings.write_string(&args_string, ", ");
							}
						}
						res, was_alloc := strings.replace_all(new_line, "$args_pass$", strings.to_string(args_string));
						
						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}
										{
						args_string : strings.Builder = strings.builder_make_none();
						
						for a, i in func.args {
							if a.type == .GLenum || a.type == .GLbitfield {
								if a.ptr_cnt == 0 {
									strings.write_string(&args_string, "cast(u32)");
								}
								else if a.ptr_cnt == 1 {
									strings.write_string(&args_string, "cast(^u32)");
								}
								else{
									panic("AGGGGHHH!");
								}
							}
							strings.write_string(&args_string, a.name);
							if i < len(func.args) - 1 {
								strings.write_string(&args_string, ", ");
							}
						}
						res, was_alloc := strings.replace_all(new_line, "$args_pass_cast$", strings.to_string(args_string));
						
						if was_alloc {
							delete(new_line);
						}
						new_line = res;
					}
					{
						res : string;
						was_alloc : bool;

						if func.ret.type == .unknown || (func.ret.type == .void && func.ret.ptr_cnt == 0) {
							res, was_alloc = strings.replace_all(new_line, "$return_pointer_cond$", "");
						}
						else {
							res, was_alloc = strings.replace_all(new_line, "$return_pointer_cond$", "->");
						}
						
						if was_alloc {
							delete(new_line);
						}
						
						new_line = res;
					}
					{
						res : string;
						was_alloc : bool;

						if func.ret.type == .unknown || (func.ret.type == .void && func.ret.ptr_cnt == 0) {
							res, was_alloc = strings.replace_all(new_line, "$return_type_cond$", "");
						}
						else {
							res, was_alloc = strings.replace_all(new_line, "$return_type_cond$", get_odin_type_name_ret(func.ret.type, func.ret.ptr_cnt, context.temp_allocator));
						}
						
						if was_alloc {
							delete(new_line);
						}
						
						new_line = res;
					}
					{
						res : string;
						was_alloc : bool;

						if func.ret.type == .unknown || (func.ret.type == .void && func.ret.ptr_cnt == 0) {
							res, was_alloc = strings.replace_all(new_line, "$return_type$", "nil");
						}
						else {
							res, was_alloc = strings.replace_all(new_line, "$return_type$", get_odin_type_name_ret(func.ret.type, func.ret.ptr_cnt, context.temp_allocator));
						}
						
						if was_alloc {
							delete(new_line);
						}
						
						new_line = res;
					}
					{
						res : string;
						was_alloc : bool;

						if func.ret.type == .unknown || (func.ret.type == .void && func.ret.ptr_cnt == 0) {
							res, was_alloc = strings.replace_all(new_line, "$return_cond$", "");
						}
						else {
							if func.ret.type == .GLenum {
								res, was_alloc = strings.replace_all(new_line, "$return_cond$", "return cast(GLenum)");
							}
							else {
								res, was_alloc = strings.replace_all(new_line, "$return_cond$", "return");
							}
						}
						
						if was_alloc {
							delete(new_line);
						}
						
						new_line = res;
					}

					strings.write_string(&code_res_builder, new_line);
					strings.write_string(&code_res_builder, "\n");
				
				}
			}
		}
		else {
			strings.write_string(&code_res_builder, t_line);
		}
		strings.write_string(&code_res_builder, "\n");
	}

	code_res := strings.to_string(code_res_builder);
	
	os.write_entire_file("res.txt", code_res_builder.buf[:]);
}
