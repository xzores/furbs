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

Type_type :: parser.Type_type;
Primitive_kind :: parser.Primitive_kind;
Sampler_kind :: parser.Sampler_kind;
Location :: token.Location;


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Statement_if :: struct {

}

Statement_return :: struct {

}

Statement_for :: struct {

}

Statement_block :: struct {

}

Statement_assign :: struct {

}

Statement_var_declare :: struct {

}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Attribute_type :: enum {
	_i32   = int(Primitive_kind._i32),
	_u32   = int(Primitive_kind._u32),
	_f32   = int(Primitive_kind._f32),

	_vec2  = int(Primitive_kind._vec2),
	_vec3  = int(Primitive_kind._vec3),
	_vec4  = int(Primitive_kind._vec4),

	_vec2i = int(Primitive_kind._ivec2),
	_vec3i = int(Primitive_kind._ivec3),
	_vec4i = int(Primitive_kind._ivec4),

	_vec2u = int(Primitive_kind._uvec2),
	_vec3u = int(Primitive_kind._uvec3),
	_vec4u = int(Primitive_kind._uvec4),

	_mat2  = int(Primitive_kind._mat2),
	_mat3  = int(Primitive_kind._mat3),
	_mat4  = int(Primitive_kind._mat4),
}

Varying_type :: enum {
	_f32	= int(Primitive_kind._f32),

	_vec2	= int(Primitive_kind._vec2),
	_vec3	= int(Primitive_kind._vec3),
	_vec4	= int(Primitive_kind._vec4),

	/* TODO these should be $flat not $varying
	_vec2i	= int(Primitive_kind._vec2i), //TODO handle flat
	_vec3i	= int(Primitive_kind._vec3i), //TODO handle flat
	_vec4i	= int(Primitive_kind._vec4i), //TODO handle flat

	_vec2u	= int(Primitive_kind._vec2u), //TODO handle flat
	_vec3u	= int(Primitive_kind._vec3u), //TODO handle flat
	_vec4u	= int(Primitive_kind._vec4u), //TODO handle flat
	*/

	_mat2	= int(Primitive_kind._mat2),
	_mat3	= int(Primitive_kind._mat3),
	_mat4	= int(Primitive_kind._mat4),
}

Frag_out_type :: enum {
	_f32	= int(Primitive_kind._f32),

	_vec2	= int(Primitive_kind._vec2),
	_vec3	= int(Primitive_kind._vec3),
	_vec4	= int(Primitive_kind._vec4),

	_ivec2	= int(Primitive_kind._ivec2),
	_ivec3	= int(Primitive_kind._ivec3),
	_ivec4	= int(Primitive_kind._ivec4),

	_uvec2	= int(Primitive_kind._uvec2),
	_uvec3	= int(Primitive_kind._uvec3),
	_uvec4	= int(Primitive_kind._uvec4),
}

Uniform :: struct {
	name		: string,
	type		: Struct_member_type,  	// e.g., mat4, float
	array_size  : int,			//1 = no array
	location	: Location,
}

Attribute :: struct {
	name		: string,
	type		: Attribute_type,  // e.g., vec3, mat4
	location	: Location,
}

Varying :: struct {
	name		: string,
	type		: Varying_type,  	// e.g., float, vec3, mat4, etc.
	array_size	: int,		  		//1 = no array
	location	: Location,
}

Frag_out :: struct {
	name			: string,
	type			: Frag_out_type,
	layout_location	: int,					// e.g., layout(location = X)
	location		: Location,
}

Sampler :: struct {
	name			: string,
	kind			: Sampler_kind,
	array_size		: int,				// 1 = no array
	location		: Location,
}

Local :: struct {
	name		: string,
	type		: Struct_member_type,  	// e.g., mat4, float
	array_size  : int,			//1 = no array
	location	: Location,
}

Storage :: struct {
	name			: string,
	type			: Type_type,  	// e.g., mat4, float
	unsized_array 	: bool,
	array_size  	: int,			//1 = no array
	location		: Location,
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Final_type :: union {
	Primitive_kind,
	Sampler_kind,
	^Struct,
}

//Also used for uniforms
Struct_member_type :: union {
	Primitive_kind,
	^Struct,
}

Struct_member :: struct {
	name : string,
	offset : int,
	size : int,
	type : Struct_member_type,
}

Struct :: struct {
	name : string,
	members : []Struct_member,
	location : Location,
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Statement :: union {
	Statement_return,
};

Function_body :: struct {
	
	statements : []Statement,
};

Function_param :: struct {
	name : string,
	type : Final_type,
	//Todo default value
}

Function :: struct {
	name  : string,
	inputs : []Function_param,
	output : Final_type,
	
	body : Function_body,
	
	referrals : []Referral,
	
	location : token.Location,
};


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

//Anything that can be refered to
Referral :: union {
	^Uniform,
	^Attribute,
	^Varying,
	^Frag_out,
	^Sampler,
	^Local,
	^Storage,
	^Struct,
	^Function,
}

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Vertex_entry :: struct {
	structs 	: []^Struct,		//Sorted structs used by other structs are first, otherwise sort by name
	functions 	:  []^Function,	//Sorted functions called by others are first, otherwise sort by name
	
	uniforms	: []^Uniform,  // Only uniform qualifier
	attributes  : []^Attribute,  // Only attribute qualifier
	varyings	: []^Varying,
	samplers	: []^Sampler, 
	storage	 	: []^Storage,  // For SSBO
	
	entry : ^Function, //The entry function itself.
}

Fragment_entry :: struct {
	structs 	: []^Struct,		//Sorted structs used by other structs are first, otherwise sort by name
	functions 	:  []^Function,	//Sorted functions called by others are first, otherwise sort by name
	
	uniforms	: []^Uniform,  // Only uniform qualifier
	frag_outs   : []Frag_out,
	varyings	: []^Varying,
	samplers	: []^Sampler, 
	storage	 	: []^Storage,  // For SSBO
	
	entry : ^Function, //The entry function itself.
}

Tess_cont_entry :: struct {
	structs 	: []^Struct,		//Sorted structs used by other structs are first, otherwise sort by name
	functions 	:  []^Function,	//Sorted functions called by others are first, otherwise sort by name
	
	//TODO.
	
	entry : ^Function, //The entry function itself.
}

Tess_eval_entry :: struct {
	structs 	: []^Struct,		//Sorted structs used by other structs are first, otherwise sort by name
	functions 	:  []^Function,	//Sorted functions called by others are first, otherwise sort by name
	
	//TODO.
	
	entry : ^Function, //The entry function itself.
}

Compute_entry :: struct {
	structs 	: []^Struct,		//Sorted structs used by other structs are first, otherwise sort by name
	functions 	: []^Function,	//Sorted functions called by others are first, otherwise sort by name
	
	uniforms	: []^Uniform,  // Only uniform qualifier
	samplers	: []^Sampler,  
	locals	  	: []^Local,  // For compute shared
	storage	 	: []^Storage,  // For SSBO
	
	entry : ^Function, //The entry function itself.
}

State :: struct {
	//Owns the data
	structs : []Struct,			//The owner of the data
	functions :  []Function,	//The owner of the data
	
	//Own the data	
	uniforms	: []Uniform,  // Only uniform qualifier
	attributes  : []Attribute,  // Only attribute qualifier
	varyings	: []Varying,
	frag_outs   : []Frag_out,
	samplers	: []Sampler,  
	locals	  	: []Local,  // For compute shared
	storage	 	: []Storage,  // For SSBO
	
	vertex_func 				: Vertex_entry,
	fragment_func 				: Fragment_entry,
	tesselation_control_func 	: Tess_cont_entry,
	tesselation_eval_func 		: Tess_eval_entry,
	compute_func 				: Compute_entry,
}

attribute_consumption_table := #sparse[Attribute_type]int {
	._i32    = 1, // Scalars take 1 location
	._u32    = 1,
	._f32    = 1,

	._vec2   = 1, // Vectors take 1 location
	._vec3   = 1,
	._vec4   = 1,

	._vec2i  = 1,
	._vec3i  = 1,
	._vec4i  = 1,

	._vec2u  = 1,
	._vec3u  = 1,
	._vec4u  = 1,

	._mat2   = 2, // Matrices consume locations per column
	._mat3   = 3, // Each column is treated as a `vec4`
	._mat4   = 4,
}

//Check validity
	//Recursion
	//Return statements(multiple, statements after return)
	//Return types matches
	//Type check everything

finalize :: proc (parsed : parser.State_infos) -> (state : State, errs : []Error) {
	
	{ ////////////// Finalize Struct, Globals and function headers //////////////
		final_structs : [dynamic]Struct;
		final_functions : [dynamic]Function;
		
		//These may not chance size when parseing 
		uniforms	: [dynamic]Uniform; // Only uniform qualifier
		attributes  : [dynamic]Attribute; // Only attribute qualifier
		varyings	: [dynamic]Varying;
		frag_outs   : [dynamic]Frag_out;
		samplers	: [dynamic]Sampler; 
		locals	  	: [dynamic]Local;  // For compute shared
		storage	 	: [dynamic]Storage;  // For SSBO //Maybe dont allow SSBO 
		
		attributes_cnt := 0			//Max 16
		samplers_cnt := 0;			//Max 16
		uniform_component_cnt := 0; //Max 1024
		frag_outs_cnt := 0; 		//Max 8
		
		shared_compute_mem := 0;	//16 KB, but we should not limit this. I think..... if compute with shared mem fails, we likely fall back to CPU anyway.
		storage_mem := 0;			//128 MB, but we should not limit this. I think.... most things allow very large SSBOs and i think they are usefull to have bigger. //Maybe dont allow SSBO 
		
		errs : [dynamic]Error;
		
		si := 0;
		//Start checking structs
		for ps in parsed.structs {
			defer si += 1;
			
			members : [dynamic]Struct_member;
			offset : int = 0;
			
			for m in ps.members {
				
				member_type, ok := get_struct_member_type_from_type_type(final_structs[:], m.type_type);
				if !ok {
					emit_error(&errs, ps.location, "A sampler is not legal to have as a struct member.");
					break;
				}
				
				member_size : int = get_size_of_struct_member(member_type);
				
				new_member : Struct_member = {
					m.name,
					offset,
					member_size,
					member_type,
				};
				
				offset += cast(int)math.ceil_f64(f64(member_size) / 4.0) * 4;
				
				append(&members, new_member);
			}
			
			assert(ps.name != "");
			s := Struct {
				ps.name,
				members[:],
				ps.location,
			}
			
			append(&final_structs, s);
		}
		
		//Start checking globals
		for pg in parsed.globals {
			
			if pg.qualifier == nil {
				fmt.panicf("qualifier may not be nil, should have been caught. got %v", pg.name);
			}
			
			if pg.is_unsized_array {
				e := is_global_configuration_valid(pg^);
				if  e != "" {
					emit_error(&errs, pg.location, e);
					continue;
				}
			}
			
			switch pg.qualifier {
				case .invalid: {
					panic("Invalid");
				}
				
				case .attribute: {
					
					new_type : Attribute_type;
					
					#partial switch t in pg.type_type {
						case parser.Primitive_kind: {
							new_type = auto_cast t;
							ok := reflect.enum_value_has_name(new_type);
							assert(ok);
						}
						case: {
							panic("Attribute must be primitive kind");
						}	
					}
					
					assert(pg.is_unsized_array == false);
					assert(pg.sized_array_length == 1);
					
					attributes_cnt += attribute_consumption_table[new_type];
					
					new_attrib := Attribute{
						pg.name,
						new_type,  // e.g., vec3, mat4
						pg.location,
					};
					
					append(&attributes, new_attrib);
				}
				
				case .uniform: {
					
					new_type : Struct_member_type;
					
					#partial switch t in pg.type_type {
						case parser.Primitive_kind: {
							new_type = auto_cast t;
							ok := reflect.enum_value_has_name(new_type.(Primitive_kind));
							assert(ok);
						}
						case: {
							panic("Uniform must be primitive kind");
						}	
					}
					
					assert(pg.is_unsized_array == false);
					
					uniform_component_cnt += pg.sized_array_length * int(f64(get_size_of_struct_member(new_type)) / 4);
					
					new_uniform := Uniform{
						pg.name,
						new_type,
						pg.sized_array_length,
						pg.location,
					};
					
					append(&uniforms, new_uniform);
				}
				
				case .sampler: {
					
					sampler_type : Sampler_kind;
					
					#partial switch t in pg.type_type {
						case parser.Sampler_kind: {
							sampler_type = auto_cast t;
							ok := reflect.enum_value_has_name(sampler_type);
							assert(ok);
						}
						case: {
							panic("Sampler must be a sampler kind");
						}	
					}
					
					assert(pg.is_unsized_array == false);
						
					samplers_cnt += pg.sized_array_length;
					
					new_sampler := Sampler{
						pg.name,
						sampler_type,
						pg.sized_array_length,				// 1 = no array
						pg.location,
					};
					
					append(&samplers, new_sampler);
					
				}
				
				case .varying: {
					
					vayring_type : Varying_type;
					
					#partial switch t in pg.type_type {
						case parser.Primitive_kind: {
							vayring_type = auto_cast t;
							ok := reflect.enum_value_has_name(vayring_type);
							assert(ok);
						}
						case ^parser.Struct_info: {
							panic("TODO");
						}
						case parser.Sampler_kind: {
							panic("Vayring type must not be a sampler kind");
						}
					}
					
					assert(pg.is_unsized_array == false);
					assert(pg.sized_array_length == 1);
					
					new_vayring := Varying{
						pg.name,
						vayring_type,
						pg.sized_array_length,				// 1 = no array
						pg.location,
					};
					
					append(&varyings, new_vayring);
					
				}
				
				case .frag_out: {
					
					frag_out_type : Frag_out_type;
					
					#partial switch t in pg.type_type {
						case parser.Primitive_kind: {
							frag_out_type = auto_cast t;
							ok := reflect.enum_value_has_name(frag_out_type);
							assert(ok);
						}
						case: {
							panic("Frag out type must be a primative kind");
						}
					}
					
					assert(pg.is_unsized_array == false);
					assert(pg.sized_array_length == 1);
					
					frag_outs_cnt += pg.sized_array_length;
					
					new_frag_out := Frag_out{
						pg.name,
						frag_out_type,
						pg.sized_array_length,				// 1 = no array
						pg.location,
					};
					
					append(&frag_outs, new_frag_out);
				}
				
				case .local: {
					
					new_type : Struct_member_type;
					
					#partial switch t in pg.type_type {
						case parser.Primitive_kind: {
							new_type = auto_cast t;
							ok := reflect.enum_value_has_name(new_type.(parser.Primitive_kind));
							assert(ok);
						}
						case: {
							panic("Uniform must be primitive kind");
						}	
					}
					
					assert(pg.is_unsized_array == false);
					
					shared_compute_mem += pg.sized_array_length * 1; //TODO the mem size of the local
					
					new_local := Local{
						pg.name,
						new_type,
						pg.sized_array_length,				// 1 = no array
						pg.location,
					};
					
					append(&locals, new_local);
					
					panic("TODO see todo above");
				}
				
				case .storage: {
					panic("TODO");
				}
			}
		}
		
		//Start checking function headers
		for pf in parsed.functions {
			
			param : [dynamic]Function_param;
			
			for p in pf.inputs {
				
				in_type := get_final_type_from_type_type(final_structs[:], p.type_type);
				
				append(&param, Function_param{
					p.name,
					in_type,
					//Todo default value
				});
			}
			
			output := get_final_type_from_type_type(final_structs[:], pf.output_type);
			
			//Pass to final_functions
			func : Function = {
				pf.name,
				param[:],
				output,
				{},
				{},
				pf.location,
			};
			
			append(&final_functions, func);
		}
		
		if len(errs) != 0 {
			return state, errs[:];
		}
		
		//Transfer ownsership to state
		state.structs = final_structs[:];
		state.functions = final_functions[:];
		
		state.uniforms = uniforms[:];
		state.attributes = attributes[:];
		state.varyings = varyings[:];
		state.frag_outs = frag_outs[:];
		state.samplers = samplers[:];
		state.locals = locals[:];
		state.storage = storage[:];
	}
	
	//fmt.printf("parsed : %#v\n", parsed.functions);
	
	{ ////////////// Finalize Function Bodies //////////////
		
		errs : [dynamic]Error;
		
		//Check function bodies
		for pf in parsed.functions {
			
			for statement in pf.body.block.statements {
				#partial switch ment in statement.type {
					case parser.Return:{
						if v, ok := ment.value.?; ok {
							type, refs, err := resolve_type_from_parser_expression(state, v);
							
							if e, ok := err.?; ok {
								emit_error(&errs, statement.location, e);
								break;
							}
							
							//TODO what here? we now know the return type
							fmt.printf("return type is : %v\n", type);
						}
					}
					case: {
						panic("TODO");
					}
				}
			}
		}
		
		if len(errs) != 0 {
			return state, errs[:];
		}
	}
	
	/////////////// create information about what calls what and what is used where //////////////
	
	{/////////////// Assign entries /////////////
		
		errs : [dynamic]Error;
		
		for func in parsed.functions {
			#partial switch func.annotation {
				case .none:
					//Do nothing
				case .vertex:
					if state.vertex_func.entry != nil {
						emit_error(&errs, func.location, "There are multiple location for the vertex entry, collides with %v.", state.vertex_func.entry.location);
					}
					state.vertex_func = Vertex_entry{
						structs 	= {}, //TODO
						functions 	= {}, //TODO
						
						uniforms	= {}, //TODO
						attributes  = {}, //TODO
						varyings	= {}, //TODO
						samplers	= {}, //TODO
						storage	 	= {}, //TODO
						
						entry = func,
					};
					 
				case .fragment:
					if state.fragment_func.entry != nil {
						emit_error(&errs, func.location, "There are multiple location for the fragment entry, collides with %v.", state.fragment_func.entry.location);
					}
					state.fragment_func = func;
				
				case .compute:
					if state.compute_func.entry != nil {
						emit_error(&errs, func.location, "There are multiple location for the compute entry, collides with %v.", state.compute_func.entry.location);
					}
					state.compute_func = func;
				
				case .tesselation_control:
					if state.tesselation_control_func.entry != nil {
						emit_error(&errs, func.location, "There are multiple location for the tesselation control entry, collides with %v.", state.tesselation_control_func.entry.location);
					}
					state.tesselation_control_func = func;
				
				case .tesselation_valuation:
					if state.tesselation_eval_func.entry != nil {
						emit_error(&errs, func.location, "There are multiple location for the tesselation evaluation entry, collides with %v.", state.tesselation_eval_func.entry.location);
					}
					state.tesselation_eval_func = func;
				
				case:
					panic("TODO");
			}
		}
		
		if len(errs) != 0 {
			return state, errs[:];
		}
				
	}
	
	return state, nil;
}

is_global_configuration_valid :: proc(type : parser.Global_info) -> string {
	
	switch t in type.type_type {
		case parser.Primitive_kind: {
			
			switch type.qualifier {
				
				case .uniform: {
					if type.is_unsized_array {
						return "A built-in type uniform array must be sized; its size must be known at compile time.";
					}
					
					switch t {
						case ._bool, ._i32, ._u32, ._f32, ._vec2, ._vec3, ._vec4,
							._ivec2, ._ivec3, ._ivec4, ._uvec2, ._uvec3, ._uvec4,
							._bvec2, ._bvec3, ._bvec4, ._mat2, ._mat3, ._mat4,
							._mat2x3, ._mat2x4, ._mat3x2, ._mat3x4, ._mat4x2, ._mat4x3: {
							// OK
						}
						case ._f64, ._dvec2, ._dvec3, ._dvec4, ._dmat2, ._dmat3, ._dmat4,
							._dmat2x3, ._dmat2x4, ._dmat3x2, ._dmat3x4, ._dmat4x2, ._dmat4x3: {
							return "For compatibility reasons, it's not possible to upload f64 (doubles) into uniforms.";
						}
					}
					
					if type.sized_array_length >= 1024 {
						return "For compatibility reasons, a uniform array may not have a constant size above 1023.";
					}
				}
				
				case .attribute: {
					if type.is_unsized_array {
						return "An attribute cannot be an unsized array.";
					}
					else {
						if type.sized_array_length != 1 {
							return "An attribute cannot be a sized array.";
						}
					}
					
					switch t {
						case ._bool, ._i32, ._u32, ._f32, ._vec2, ._vec3, ._vec4,
							._ivec2, ._ivec3, ._ivec4, ._uvec2, ._uvec3, ._uvec4,
							._bvec2, ._bvec3, ._bvec4, ._mat2, ._mat3, ._mat4,
							._mat2x3, ._mat2x4, ._mat3x2, ._mat3x4, ._mat4x2, ._mat4x3: {
							// OK
						}
						case ._f64, ._dvec2, ._dvec3, ._dvec4, ._dmat2, ._dmat3, ._dmat4,
							._dmat2x3, ._dmat2x4, ._dmat3x2, ._dmat3x4, ._dmat4x2, ._dmat4x3: {
							return "For compatibility reasons, it's not possible to upload f64 (doubles) into attributes.";
						}
					}
					
					if type.sized_array_length != 1 {
						return "An attribute cannot be an array (must have an array size of 1).";
					}
				}
				
				case .varying: {
					// Varying (vertex out -> fragment in)
					if type.is_unsized_array {
						return "A varying cannot be an unsized array.";
					}
					
					// Arrays can be valid but limited by 'varying' component limits.
					// For doubles:
					switch t {
						case ._bool, ._i32, ._u32, ._f32: {
							if type.sized_array_length >= 64 {
								return "A varing primitive may not have a size above 64";
							}
						}
						case ._vec2, ._uvec2, ._bvec2, ._ivec2: {
							if type.sized_array_length >= 32 {
								return "A varing vec2 may not have a size above 32";
							}	
						} 
						case ._vec3, ._uvec3, ._bvec3, ._ivec3: {
							if type.sized_array_length >= 16 {
								return "A varing vec3 may not have a size above 16";
							}
						}
						case ._vec4, ._uvec4, ._bvec4, ._ivec4, ._mat2: {
							if type.sized_array_length >= 16 {
								return "A varing vec4 or mat2 may not have a size above 16";
							}
						}
						case ._mat3, ._mat4, ._mat2x3, ._mat2x4, ._mat3x2, ._mat3x4, ._mat4x2, ._mat4x3: {
							if type.sized_array_length >= 8 {
								return "A varing matrix of 3 or bigger may not have a size above 8";
							}
						}
						case ._f64, ._dvec2, ._dvec3, ._dvec4,
							._dmat2, ._dmat3, ._dmat4, ._dmat2x3, ._dmat2x4,
							._dmat3x2, ._dmat3x4, ._dmat4x2, ._dmat4x3: {
							return "For compatibility reasons, doubles are not allowed for varying.";
						}
					}
				}
				
				//TODO Flat (not varying)
				
				case .frag_out: {
					// Fragment shader outputs
					// Typically must be scalar/vector/matrix but not unsized arrays.
					if type.is_unsized_array {
						return "A fragment output cannot be an unsized array.";
					}
					// If you want to disallow arrays entirely:
					if type.sized_array_length != 1 {
						return "A fragment output cannot be a sized array.";
					}
					
					// Also no doubles for typical usage
					switch t {
						case ._bool, ._i32, ._u32, ._f32, ._vec2, ._vec3, ._vec4,
							._ivec2, ._ivec3, ._ivec4, ._uvec2, ._uvec3, ._uvec4,
							._bvec2, ._bvec3, ._bvec4, ._mat2, ._mat3, ._mat4,
							._mat2x3, ._mat2x4, ._mat3x2, ._mat3x4, ._mat4x2, ._mat4x3: {
							// OK
						}
						case ._f64, ._dvec2, ._dvec3, ._dvec4, ._dmat2, ._dmat3, ._dmat4,
							._dmat2x3, ._dmat2x4, ._dmat3x2, ._dmat3x4, ._dmat4x2, ._dmat4x3: {
							return "For compatibility reasons, doubles are not allowed for fragment outputs.";
						}
					}
				}
				
				case .local: {
					// "local" is compute-shared memory: must be sized, float-based typically
					if type.is_unsized_array {
						return "A local (shared) variable cannot be an unsized array.";
					}
					// Might allow arrays, but must be sized
					// Double checks
					switch t {
						case ._bool, ._i32, ._u32, ._f32, ._vec2, ._vec3, ._vec4,
							._ivec2, ._ivec3, ._ivec4, ._uvec2, ._uvec3, ._uvec4,
							._bvec2, ._bvec3, ._bvec4, ._mat2, ._mat3, ._mat4,
							._mat2x3, ._mat2x4, ._mat3x2, ._mat3x4, ._mat4x2, ._mat4x3: {
							// OK
						}
						case ._f64, ._dvec2, ._dvec3, ._dvec4,
							._dmat2, ._dmat3, ._dmat4, ._dmat2x3, ._dmat2x4,
							._dmat3x2, ._dmat3x4, ._dmat4x2, ._dmat4x3: {
							return "For compatibility reasons, double-based types are not allowed in local (shared) memory."; //TODO this might be a good idea to make legal
						}
					}
				}
				
				case .storage: {
					return "The storage qualifier (SSBO) must be a struct";
					/*
					// "storage" is for SSBO usage
					// Might allow sized or runtime array (unsized if last member),
					// but doubles are typically not recommended or might require extension.
					// Keep minimal:
					switch t {
						case ._bool, ._i32, ._u32, ._f32, ._vec2, ._vec3, ._vec4,
							._vec2i, ._vec3i, ._vec4i, ._vec2u, ._vec3u, ._vec4u,
							._vec2b, ._vec3b, ._vec4b, ._mat2, ._mat3, ._mat4,
							._mat2x3, ._mat2x4, ._mat3x2, ._mat3x4, ._mat4x2, ._mat4x3: {
							// OK
						}
						case ._f64, ._vec2d, ._vec3d, ._vec4d, ._mat2d, ._mat3d, ._mat4d,
							._mat2x3d, ._mat2x4d, ._mat3x2d, ._mat3x4d, ._mat4x2d, ._mat4x3d: {
							return "Doubles in SSBO require advanced extensions, not supported here."; //TODO this might be a good idea to make legal
						}
					}
					*/
				}
				
				case .sampler: {
					return "Used wrong qualifier use $uniform for non-sampler uniforms.";
				}
				
				case .invalid: {
					panic("internal error");
				}
			}
		}
		
		case parser.Sampler_kind: {
		
			#partial switch type.qualifier {
				case .sampler:
					// Sampler usage is effectively uniform, but might have special rules
					// regarding arrays or binding. Keep minimal:
					if type.is_unsized_array {
						return "A sampler array must have a fixed size, unsized sampler arrays are not supported.";
					}
					// size checks
					if type.sized_array_length > 16 {
						return "Max sampler array size is limited for compatibility, cannot exceed 16.";
					}
					
				case: {
					return "A texture must have a $sampler qualifier";
				}
			}
		}
		
		case ^parser.Struct_info: {
			switch type.qualifier {
				case .uniform: {
					// A struct can be used as a uniform if it's fully known at compile time (no unsized arrays).
					if type.is_unsized_array {
						return "A struct uniform cannot be declared as an unsized array (use a uniform block for runtime-sized arrays).";
					}
					
					if type.sized_array_length > 0 {
						// Allowed to have a fixed-size array of struct as a uniform:
						if type.sized_array_length >= 1024 {
							return "For compatibility, a uniform array of struct may not exceed 1023 elements.";
						}
						// Otherwise, it's valid in older and modern GLSL (subject to alignment rules).
					} else {
						// Single struct uniform is always fine
					}
				}
				
				case .attribute: {
					// In standard GLSL, you cannot directly pass a struct as a vertex attribute.
					return "A struct cannot be used as a vertex attribute.";
				}
				
				case .varying: {
					// Modern GLSL *can* pass a struct as 'out' in the vertex and 'in' in the fragment
					// if each field is a valid varying type. Older GLSL might not support it well.
					// If you want to disallow it (common in simpler compilers), return an error:
					return "A struct is not allowed as a varying in this environment.";
					// Otherwise, you could parse the fields and ensure each is valid as a varying.
				}
				
				case .frag_out: {
					// Typically fragment outputs must be scalar/vector/matrix.
					// Struct as a single fragment output is unusual and may not be portable.
					return "A struct cannot be used directly as a fragment output.";
					// In very modern GLSL, you can technically do `out MyStruct data;`
					// if each field can map to a location, but it's rarely supported in older contexts.
				}
				
				case .local: {
					// 'local' refer to compute shader shared memory .
					//Note may not be more then 48KB.
					if type.is_unsized_array {
						return "A local (shared) struct cannot be an unsized array.";
					}
				}
				
				case .storage: { //TODO an SSBO can fallback to a texture.
					/*// 'storage' typically refers to SSBO usage. A struct is allowed,
					// but watch alignment rules. Unsized array of struct is only valid
					// if it's the last member in the buffer. If you want to allow that,
					// you'd check if it's the final field, etc.
					if type.is_unsized_array {
						// E.g. struct[] if last in an SSBO
						// If you're not supporting that, return an error:
						return "An unsized array of struct is only valid in SSBOs as the last member (runtime array).";
					}
					
					a := t.members;
					
					// Otherwise, sized array or single struct is valid in a storage block, subject to alignment.
					*/
				}
				
				case .sampler: {
					// A struct is definitely not a sampler:
					return "A struct is not a sampler.";
				}
				
				case .invalid: {
					panic("internal error");
				}
			}
		}
	}
	
	return "";
}

primitive_kind_size := map[Primitive_kind]int {
	._bool   = 4,    // Aligned to 4 bytes
	._i32    = 4,    // 4 bytes for a 32-bit integer
	._u32    = 4,    // 4 bytes for a 32-bit unsigned integer
	._f32    = 4,    // 4 bytes for a 32-bit float
	._f64    = 8,    // 8 bytes for a 64-bit double
	
	// Vector Types
	._vec2   = 8,    // 2 floats (4 bytes each), padded to 8 bytes
	._vec3   = 12,   // 3 floats, padded to 16 bytes in arrays/structs
	._vec4   = 16,   // 4 floats, naturally aligned to 16 bytes
	._ivec2  = 8,    // 2 32-bit integers, aligned to 8 bytes
	._ivec3  = 12,   // 3 integers, padded to 16 bytes
	._ivec4  = 16,   // 4 integers, aligned to 16 bytes
	._uvec2  = 8,    // 2 unsigned integers
	._uvec3  = 12,   // 3 unsigned integers, padded to 16 bytes
	._uvec4  = 16,   // 4 unsigned integers
	._bvec2  = 8,    // 2 booleans (treated as 32-bit integers)
	._bvec3  = 12,   // 3 booleans, padded to 16 bytes
	._bvec4  = 16,   // 4 booleans						(1x4bytes = 4)
	._dvec2  = 16,   // 2 doubles (8 bytes each) 		(2x8bytes = 16)
	._dvec3  = 24,   // 3 doubles, padded to 32 bytes 	(3x8bytes = 24)
	._dvec4  = 32,   // 4 doubles, naturally aligned 	(4x8bytes = 32)

	// Matrix Types
	._mat2      = 32,    // 2x2 floats, 2 columns of vec2 (16 bytes per column)
	._mat3      = 48,    // 3x3 floats, 3 columns of vec3 (aligned as vec4, 16 bytes per column)
	._mat4      = 64,    // 4x4 floats, 4 columns of vec4 (16 bytes per column)
	._mat2x3    = 48,    // 2x3 floats, 2 columns of vec3 (aligned as vec4, 16 bytes per column)
	._mat2x4    = 64,    // 2x4 floats, 2 columns of vec4 (16 bytes per column)
	._mat3x2    = 32,    // 3x2 floats, 3 columns of vec2 (16 bytes per column)
	._mat3x4    = 64,    // 3x4 floats, 3 columns of vec4 (16 bytes per column)
	._mat4x2    = 32,    // 4x2 floats, 4 columns of vec2 (16 bytes per column)
	._mat4x3    = 48,    // 4x3 floats, 4 columns of vec3 (aligned as vec4, 16 bytes per column)

	._dmat2     = 64,    // 2x2 doubles, 2 columns of dvec2 (32 bytes per column)
	._dmat3     = 96,    // 3x3 doubles, 3 columns of dvec3 (aligned as dvec4, 32 bytes per column)
	._dmat4     = 128,   // 4x4 doubles, 4 columns of dvec4 (32 bytes per column)
	._dmat2x3   = 96,    // 2x3 doubles, 2 columns of dvec3 (aligned as dvec4, 32 bytes per column)
	._dmat2x4   = 128,   // 2x4 doubles, 2 columns of dvec4 (32 bytes per column)
	._dmat3x2   = 64,    // 3x2 doubles, 3 columns of dvec2 (32 bytes per column)
	._dmat3x4   = 128,   // 3x4 doubles, 3 columns of dvec4 (32 bytes per column)
	._dmat4x2   = 64,    // 4x2 doubles, 4 columns of dvec2 (32 bytes per column)
	._dmat4x3   = 96,    // 4x3 doubles, 4 columns of dvec3 (aligned as dvec4, 32 bytes per column)
}

//Return the size of a member in bytes.
get_size_of_struct_member :: proc(m : Struct_member_type) -> int {
	
	switch k in m {
		case parser.Primitive_kind:{
			return primitive_kind_size[k];
		}
		case ^Struct: {
			panic("TODO");
		}
	}
	
	unreachable();
}

Error :: struct {
	msg : string,
	origin : Location,
}

@(private="file")
emit_error :: proc (errs : ^[dynamic]Error, origin : Location, msg : string, args: ..any, loc := #caller_location) {
	
	err_msg : string;
	if len(args) != 0 {
		err_msg = fmt.tprintf(msg, ..args);
	}
	else {
		err_msg = msg;
	}
	
	log.error(fmt.tprintf("%v(%v) Parse error : %v, got '%v'", origin.file, origin.line, err_msg, origin.source), location = loc);
	append(errs, Error{err_msg, origin});
}

@(private="file")
get_struct_member_type_from_type_type :: proc (final_structs : []Struct, _t : Type_type) -> (member_type : Struct_member_type, ok : bool) {

	switch t in _t {
		case parser.Primitive_kind:
			member_type = t;
			
		case parser.Sampler_kind:
			return {}, false;
			
		case ^parser.Struct_info:
			found := false;
			
			for s, i in final_structs {
				if s.name == t.name {
					found = true;
					member_type = &final_structs[i];
					break;
				}
			}
			assert(found);
	}
	
	return member_type, true;	
}

@(private="file")
get_final_type_from_type_type :: proc (final_structs : []Struct, _t : Type_type) -> Final_type {
		
	switch t in _t {
		case parser.Primitive_kind:
			return t;
			
		case parser.Sampler_kind:
			return t;
			
		case ^parser.Struct_info:
			for &s, i in final_structs {
				if s.name == t.name {
					return &s;
				}
			}
		case nil:
			return nil;
	}
	
	fmt.panicf("Could not find type : %v", _t);
}

@(private="file")
resolve_type_from_parser_expression :: proc (state : State, exp : ^parser.Expression) -> (type : Final_type, referrals : map[Referral]bool, err : Maybe(string)) {
	
	/*
		Expression :: union {
			Unary_operator,
			Boolean_literal,
			Variable,
		}
	*/
	
	#partial switch e in exp {
		case parser.Call: {
			func := find_function(state, e.called)
			
			if func == nil {
				return nil, nil, fmt.tprintf("No function called : '%v'", e.called);
			}
			
			for r in func.referrals {
				referrals[r] = true;
			}
			
			referrals[func] = true;
			
			return func.output, referrals, nil;
		}
		case parser.Float_literal: {
			return Primitive_kind._f32, {}, nil; //TODO this can be many values like f32, f64, i32, u32 or whatever
		}
		case parser.Int_literal: {
			return Primitive_kind._i32, {}, nil; //TODO this can be many values like f32, f64, i32, u32 or whatever
		}
		case parser.Binary_operator: {
			lhs, lrefs := resolve_type_from_parser_expression(state, e.left) or_return;
			rhs, rrefs := resolve_type_from_parser_expression(state, e.right) or_return;
			// e.op tells which operation it is, like * or +
			
			if lhs != rhs {
				return nil, nil, fmt.tprintf("Left hand side and right hand side of operator %v is not the same", e.op);
			}
			
			for r in lrefs {
				referrals[r] = true;
			}
			for r in rrefs {
				referrals[r] = true;
			}
			
			return lhs, referrals, nil;
		}
		case:
			panic("TODO");
	}
	
	unreachable();
}

@(private="file")
find_function :: proc (state : State, name : string) -> ^Function {
	
	for &f in state.functions {
		if f.name == name {
			return &f;
		}
	}
	
	return nil;
}

@(private="file")
function_from_function_info :: proc (info : parser.Function_info) -> Function {
	
	/*
	Function_info :: struct {
		name : string,
		annotation : Annotation_type,
		
		inputs : []Parameter_info,
		output : string,
		output_type : Type_type,
		
		body_start_token : int,
		body_end_token : int,
		
		body : Function_body_info,
		
		compute_dim : [3]int,
		location : token.Location,
	}
	
	Function :: struct {
		name  : string,
		inputs : []Function_param,
		output : Final_type,
		
		body : Function_body,
		
		referrals : []Referral,
		
		location : token.Location,
	};*/
	
	return Function{
		info.name,
		inputs : []Function_param,
		output : Final_type,
		
		body : Function_body,
		
		referrals : []Referral,
		
		location : token.Location,
	}; 
}