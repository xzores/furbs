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
	._ivec2 = "ivec2",  // GLSL 1.30+ 
	._ivec3 = "ivec3",  // GLSL 1.30+
	._ivec4 = "ivec4",  // GLSL 1.30+ 
	._uvec2 = "uvec2",  // GLSL 1.30+ 
	._uvec3 = "uvec3",  // GLSL 1.30+
	._uvec4 = "uvec4",  // GLSL 1.30+
	._bvec2 = "bvec2",  // GLSL 1.00+
	._bvec3 = "bvec3",  // GLSL 1.00+
	._bvec4 = "bvec4",  // GLSL 1.00+
	._dvec2 = "dvec2",  // GLSL 4.00+
	._dvec3 = "dvec3",  // GLSL 4.00+
	._dvec4 = "dvec4",  // GLSL 4.00+
	._mat2 = "mat2",	     // GLSL 1.10+
	._mat3 = "mat3",	     // GLSL 1.10+
	._mat4 = "mat4",	     // GLSL 1.10+
	._mat2x3 = "mat2x3",  // GLSL 1.50+
	._mat2x4 = "mat2x4",  // GLSL 1.50+
	._mat3x2 = "mat3x2",  // GLSL 1.50+
	._mat3x4 = "mat3x4",  // GLSL 1.50+
	._mat4x2 = "mat4x2",  // GLSL 1.50+
	._mat4x3 = "mat4x3",  // GLSL 1.50+
	._dmat2 = "dmat2",	   // GLSL 4.00+
	._dmat3 = "dmat3",	   // GLSL 4.00+
	._dmat4 = "dmat4",	   // GLSL 4.00+
	._dmat2x3 = "dmat2x3", // GLSL 4.00+
	._dmat2x4 = "dmat2x4", // GLSL 4.00+
	._dmat3x2 = "dmat3x2", // GLSL 4.00+
	._dmat3x4 = "dmat3x4", // GLSL 4.00+
	._dmat4x2 = "dmat4x2", // GLSL 4.00+
	._dmat4x3 = "dmat4x3", // GLSL 4.00+
};

sampler_type_glsl_name : [Sampler_kind]string = {
	._sampler1D = "sampler1D",               // GLSL 1.10
	._sampler2D = "sampler2D",               // GLSL 1.10
	._sampler3D = "sampler3D",               // GLSL 1.10
	._sampler1D_depth = "sampler1DShadow",   // GLSL 1.10
	._sampler2D_depth = "sampler2DShadow",   // GLSL 1.10
	._sampler_cube = "samplerCube",          // GLSL 1.10
	._sampler2D_array = "sampler2DArray",    // GLSL 1.50
	._sampler2_multi = "sampler2DMS",        // GLSL 3.20
	._sampler_buffer = "samplerBuffer",      // GLSL 3.10

	._sampler1D_int = "isampler1D",          // GLSL 1.30
	._sampler2D_int = "isampler2D",          // GLSL 1.30
	._sampler3D_int = "isampler3D",          // GLSL 1.30
	._sampler_cube_int = "isamplerCube",     // GLSL 1.30
	._sampler2D_array_int = "isampler2DArray", // GLSL 3.00
	._sampler2_multi_int = "isampler2DMS",   // GLSL 3.20
	._sampler_buffer_int = "isamplerBuffer", // GLSL 3.10

	._sampler1D_uint = "usampler1D",         // GLSL 1.30
	._sampler2D_uint = "usampler2D",         // GLSL 1.30
	._sampler3D_uint = "usampler3D",         // GLSL 1.30
	._sampler_cube_uint = "usamplerCube",    // GLSL 1.30
	._sampler2D_array_uint = "usampler2DArray", // GLSL 3.00
	._sampler2_multi_uint = "usampler2DMS",  // GLSL 3.20
	._sampler_buffer_uint = "usamplerBuffer", // GLSL 3.10
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
	
	output_uniforms : []^Uniform;
	output_attributes : []^Attribute;
	
	entry_func : ^Function;
	
	switch target {
		case .vertex: {
			output_uniforms = state.vertex_func.uniforms;
			output_attributes = state.vertex_func.attributes;
			entry_func = state.vertex_func.entry;
		}
		case .fragment: {
			output_uniforms = state.fragment_func.uniforms;
			entry_func = state.fragment_func.entry;
		}
		case .compute: {
			output_uniforms = state.compute_func.uniforms;
			entry_func = state.compute_func.entry;
		}
		case .tesselation_control: {
			
		}
		case .tesselation_eval: {
			
		}
	}
	
	if entry_func == nil {
		log.errorf("The entry %v does not exists", target);
		return "The entry does not exists";
	}
	
	if target == .vertex { //Write attriburtes
		
		write_string(&glsl_code, "//// Attributes ////\n");
		
		for a, i in output_attributes {
			
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
		
		for u, i in output_uniforms {
			
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
	
	{ //Write Functions
		
	}
	
	{ //Write Entry
		write_glsl_function(&glsl_code, entry_func);
	}
	
	return strings.clone(to_string(glsl_code));
}

@(private="file")
write_glsl_function :: proc (glsl_code : ^strings.Builder, func : ^Function) {
	using strings;
	
	write_glsl_final_variable(glsl_code, func.output);
	
	write_string(glsl_code, " ");
	write_string(glsl_code, func.name);
	write_string(glsl_code, "(");
	for input, i in func.inputs {
		
		if i != 0 {
			write_string(glsl_code, ", ");
		}
		
		write_glsl_final_variable(glsl_code, input.type);
		write_string(glsl_code, " ");
		write_string(glsl_code, input.name);
	}
	write_string(glsl_code, ")");
	
	write_string(glsl_code, "{\n");
	
	for statement in func.body.statements {
	
	}
	
	write_string(glsl_code, "}");
	
}

@(private="file")
write_glsl_final_variable :: proc (glsl_code : ^strings.Builder, type : Final_type) { 
	using strings;
	
	switch t in type {
		case ^Struct: {
			write_string(glsl_code, t.name);
		}
		case parser.Primitive_kind: {
			write_string(glsl_code, primitive_type_glsl_name[t]);
		}
		case parser.Sampler_kind: {
			write_string(glsl_code, sampler_type_glsl_name[t]);
		}
		case: {
			write_string(glsl_code, "void");
		}
	}
}






