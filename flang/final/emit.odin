package flang_finalizer;

import "core:fmt"
import "core:strings"
import "base:builtin"
import "base:runtime"
import "core:reflect"
import "core:unicode"
import "core:os"
import "core:log"
import "core:math"
import "core:slice"
import "core:path/slashpath"

import "../token"
import "../parser"

Entry_target :: enum {
	vertex,
	fragment,
	tesselation_control,
	tesselation_eval,
	compute,
	//TODO ray tracing
}

primitive_type_glsl_name : [Primitive_kind]string = {
	._bool = "bool",	// b8
	._i32 = "int",	// i32
	._u32 = "uint",	// u32
	._f32 = "float",	// f32
	._f64 = "double", // f64
	._vec2 = "vec2",	   // GLSL 1.00+ 
	._vec3 = "vec3",	   // GLSL 1.00+ 
	._vec4 = "vec4",	   // GLSL 1.00+ 
	._vec2i = "ivec2",  // GLSL 1.30+ 
	._vec3i = "ivec3",  // GLSL 1.30+
	._vec4i = "ivec4",  // GLSL 1.30+ 
	._vec2u = "uvec2",  // GLSL 1.30+ 
	._vec3u = "uvec3",  // GLSL 1.30+
	._vec4u = "uvec4",  // GLSL 1.30+
	._vec2b = "bvec2",  // GLSL 1.00+
	._vec3b = "bvec3",  // GLSL 1.00+
	._vec4b = "bvec4",  // GLSL 1.00+
	._vec2d = "dvec2",  // GLSL 4.00+
	._vec3d = "dvec3",  // GLSL 4.00+
	._vec4d = "dvec4",  // GLSL 4.00+
	._mat2 = "mat2",	     // GLSL 1.10+
	._mat3 = "mat3",	     // GLSL 1.10+
	._mat4 = "mat4",	     // GLSL 1.10+
	._mat2x3 = "mat2x3",  // GLSL 1.50+
	._mat2x4 = "mat2x4",  // GLSL 1.50+
	._mat3x2 = "mat3x2",  // GLSL 1.50+
	._mat3x4 = "mat3x4",  // GLSL 1.50+
	._mat4x2 = "mat4x2",  // GLSL 1.50+
	._mat4x3 = "mat4x3",  // GLSL 1.50+
	._mat2d = "dmat2",	   // GLSL 4.00+
	._mat3d = "dmat3",	   // GLSL 4.00+
	._mat4d = "dmat4",	   // GLSL 4.00+
	._mat2x3d = "dmat2x3", // GLSL 4.00+
	._mat2x4d = "dmat2x4", // GLSL 4.00+
	._mat3x2d = "dmat3x2", // GLSL 4.00+
	._mat3x4d = "dmat3x4", // GLSL 4.00+
	._mat4x2d = "dmat4x2", // GLSL 4.00+
	._mat4x3d = "dmat4x3", // GLSL 4.00+
};

emit_glsl :: proc (state : State, target : Entry_target, version : int = 330) -> string {
	using strings;
	
	glsl_code := builder_make();
	defer builder_destroy(&glsl_code);
	
	{ //Write the version
		write_string(&glsl_code, "#version ");
		write_int(&glsl_code, version);
		write_string(&glsl_code, "\n\n");
	}
	
	{ //Write the extresions
		
	}
	
	if target == .vertex { //Write attriburtes
		
		write_string(&glsl_code, "//// Attributes ////\n");
		
		for a, i in state.attributes {
			
		 	write_string(&glsl_code, "layout (location = ");
			write_int(&glsl_code, i);
			write_string(&glsl_code, ") in ");
			write_string(&glsl_code, primitive_type_glsl_name[auto_cast a.type]);
			write_string(&glsl_code, " ");
			write_string(&glsl_code, a.name);
			write_string(&glsl_code, ";\n");
		}
		
		write_string(&glsl_code, "\n");
	}
	
	{ //Write uniforms
		
		write_string(&glsl_code, "//// Uniforms ////\n");
		
		for u, i in state.uniforms {
			
			if k, ok := u.type.(parser.Primitive_kind); ok {
				write_string(&glsl_code, "uniform ");
				write_string(&glsl_code, primitive_type_glsl_name[k]);
				write_string(&glsl_code, " ");
				write_string(&glsl_code, u.name);
				if u.array_size != 1 {
					write_string(&glsl_code, "[");
					write_int(&glsl_code, u.array_size);
					write_string(&glsl_code, "]");
				}
				write_string(&glsl_code, ";\n");
			}
			else {
				//Output as a uniform block:
				/*
					layout(std140, binding = 1) uniform MyBlock {
						mat4 projection;
						vec3 lightPosition;
					};
				*/
				//OR as a uniform which is a struct. 
				/*
					struct MyStruct {
						mat4 viewMatrix;
						vec3 lightPosition;
					};
					uniform MyStruct myData; // No UBO, treated as individual uniforms
				*/
				//OR allow both:
				/*
					struct MyStruct {
						mat4 viewMatrix;
						vec3 lightPosition;
					};

					layout(std140, binding = 0) uniform MyBlock {
						MyStruct data;
					};
				*/
				
				panic("TODO");
			}
		}
	}
	
	return strings.clone(to_string(glsl_code));
}
