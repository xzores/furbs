package flang_parser;

import "core:fmt"

import "../token"


////////////////////////////////////////////////////////////////////////// FROM PARSER ///////////////////////////////////////////////////////////////////////////

Token :: token.Token;
Storage_qualifiers :: token.Storage_qualifiers;
Annotation_type :: token.Annotation_type;
Semicolon :: token.Semicolon;
Identifier :: token.Identifier;
Location :: token.Location;


//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

Primitive_kind :: enum {
	_bool,	//b8
	_i32,	//i32
	_u32,	//u32
	_f32,	//f32
	_f64, 	//f64
	
	// Vector Types
	_vec2,	   // GLSL 1.00+ 
	_vec3,	   // GLSL 1.00+ 
	_vec4,	   // GLSL 1.00+ 
	_ivec2,	  // GLSL 1.30+ 
	_ivec3,	  // GLSL 1.30+
	_ivec4,	  // GLSL 1.30+ 
	_uvec2,	  // GLSL 1.30+ 
	_uvec3,	  // GLSL 1.30+
	_uvec4,	  // GLSL 1.30+
	_bvec2,	  // GLSL 1.00+
	_bvec3,	  // GLSL 1.00+
	_bvec4,	  // GLSL 1.00+
	_dvec2,	   // GLSL 4.00+
	_dvec3,	   // GLSL 4.00+
	_dvec4,	   // GLSL 4.00+
	
	// Matrix Types
	_mat2,	   // GLSL 1.10+
	_mat3,	   // GLSL 1.10+
	_mat4,	   // GLSL 1.10+
	_mat2x3,	 // GLSL 1.50+
	_mat2x4,	 // GLSL 1.50+
	_mat3x2,	 // GLSL 1.50+
	_mat3x4,	 // GLSL 1.50+
	_mat4x2,	 // GLSL 1.50+
	_mat4x3,	 // GLSL 1.50+
	
	_dmat2,	   // GLSL 4.0+
	_dmat3,	   // GLSL 4.0+
	_dmat4,	   // GLSL 4.0+
	_dmat2x3,	 // GLSL 4.0+
	_dmat2x4,	 // GLSL 4.0+
	_dmat3x2,	 // GLSL 4.0+
	_dmat3x4,	 // GLSL 4.0+
	_dmat4x2,	 // GLSL 4.0+
	_dmat4x3,	 // GLSL 4.0+
}

Sampler_kind :: enum {
	_sampler1D,			   // GLSL 1.10
	_sampler2D,			   // GLSL 1.10
	_sampler3D,			   // GLSL 1.10
	_sampler1D_depth,		 // GLSL 1.10
	_sampler2D_depth,		 // GLSL 1.10
	_sampler_cube,			// GLSL 1.10
	_sampler2D_array,		 // GLSL 1.50
	_sampler2_multi,		  // GLSL 3.20
	_sampler_buffer,		  // GLSL 3.10
	// _samplerCubeArray,	 // GLSL 4.00 (commented out for being too new and weird)

	_sampler1D_int,		   // GLSL 1.30
	_sampler2D_int,		   // GLSL 1.30
	_sampler3D_int,		   // GLSL 1.30
	_sampler_cube_int,		// GLSL 1.30
	_sampler2D_array_int,	 // GLSL 3.00
	_sampler2_multi_int,	  // GLSL 3.20
	_sampler_buffer_int,	  // GLSL 3.10
	// _sampler_cube_array_int,// GLSL 4.00 (commented out for being too new and weird)

	_sampler1D_uint,		  // GLSL 1.30
	_sampler2D_uint,		  // GLSL 1.30
	_sampler3D_uint,		  // GLSL 1.30
	_sampler_cube_uint,	   // GLSL 1.30
	_sampler2D_array_uint,	// GLSL 3.00
	_sampler2_multi_uint,	 // GLSL 3.20
	_sampler_buffer_uint,	 // GLSL 3.10
	// _sampler_cube_array_uint// GLSL 4.00 (commented out for being too new and weird)
};

Type_type :: union {
	Primitive_kind,
	Sampler_kind,
	^Struct_info,
}

Parse_error :: struct {
	message : string,
	token : token.Location,
}

State_infos :: struct {
	globals : [dynamic]^Global_info,
	functions : [dynamic]^Function_info,
	structs : [dynamic]^Struct_info,
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

tprint_parse_error :: proc (err : Parse_error) -> string {
	return fmt.tprintf("%v(%v) Parse error : %v, got '%v'", err.token.file, err.token.line, err.message, err.token.source);	
}










/////////////////////////////////////////////////////////////////////////// FROM FINALIZE ///////////////////////////////////////////////////////////////////////////

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









/////////////////////////////////////////////////////////////////////////// MARGED ///////////////////////////////////////////////////////////////////////////

Parameter_info :: struct {
	name : string,
	type : string,
	type_type : Type_type,
	default_value : string, //if "" there is no default value.
	default_value_type : Type_type,
}

Struct_member_info :: struct {
	name : string,
	type : string,
	type_type : Type_type,
	location : Location,
}

Struct_info :: struct {
	name : string,
	members : []Struct_member_info,
	location : token.Location,
}

Global_info :: struct {
	name : string,
	
	type : string,
	type_type : Type_type,
	
	qualifier : Storage_qualifiers,
	
	is_unsized_array : bool,
	sized_array_length : int,
	
	location : token.Location,
}

Function_body_info :: struct {
	//??
	block : Block,
}

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










//////////////////////////////////////// BLOCK PARSING ////////////////////////////////////////

Variable_declaration :: struct {
	lhs : string, //the name
	type : Type_type, //This can be resolved at this stage, because all types have been parsed.
	rhs : Maybe(Expression),
}

Call :: struct {
	called : string,		  // Function name (or reference to a Function)
	args   : []^Expression,	// List of arguments (expressions)
}

Assignment :: struct {
	lhs : string,   // The left-hand side (e.g., variable)
	rhs : ^Expression,   // The right-hand side (e.g., value or expression)
}

Unary_operator_kind :: enum {
	negation,	 // e.g., -a
	inversion,	// e.g., !a
	bitwise_not,  // e.g., ~a
}

Unary_operator :: struct {
	op	  : Unary_operator_kind,	// Operator like "-", "++", "!"
	operand : ^Expression,	  // The expression being operated on
}

Binary_operator_kind :: enum {
	add,		  // e.g., a + b
	subtract,	 // e.g., a - b
	multiply,	 // e.g., a * b
	divide,	   // e.g., a / b
	modulo,	   // e.g., a % b
	abs_modulo,   // e.g., a %% b
	logical_and,  // e.g., a && b
	logical_or,   // e.g., a || b
	bitwise_and,  // e.g., a & b
	bitwise_or,   // e.g., a | b
	bitwise_xor,  // e.g., a ^ b
	shift_left,   // e.g., a << b
	shift_right,  // e.g., a >> b
	equals,	   // e.g., a == b
	not_equals,   // e.g., a != b
	greater_than, // e.g., a > b
	less_than,	// e.g., a < b
	greater_eq,   // e.g., a >= b
	less_eq,	  // e.g., a <= b
}

Binary_operator :: struct {
	op	  : Binary_operator_kind, 
	left : ^Expression,	  // The expression being operated on
	right : ^Expression,	  // The expression being operated on
}

Return :: struct {
	value : Maybe(^Expression),
}

If :: struct {
	condition : Expression,	  // Condition to evaluate
	then_body : []^Statement,	 // Block of statements for the true branch
	else_body : Maybe([]^Statement),  // Optional else block
}

For :: struct { //Also used as a while
	init	  : Maybe(^Statement), // Initialization (e.g., Declaration or Assignment)
	condition : Maybe(Expression), // Loop condition
	increment : Maybe(Expression), // Increment step
	body	  : []Statement,	   // Loop body
}

Float_literal :: struct {
	value : f64,  // Could be int, float, string, bool, etc.
}

Int_literal :: struct {
	value : i128,  // Could be int, float, string, bool, etc.
}

Boolean_literal :: struct {
	value : bool,  // Could be int, float, string, bool, etc.
}

Variable :: struct {
	name : string,
	//scope : Maybe(Scope),  // Optional reference to the variable's scope
}

Expression :: union {
	Call,
	Assignment,
	Unary_operator,
	Binary_operator,
	Float_literal,
	Int_literal,
	Boolean_literal,
	Variable,
}

Statement :: struct {
	type : union {
		Variable_declaration,
		Assignment,
		Expression, //Not legal but handled for better error messages
		Return,
		If,
		For,
		Block,
	},
	location : Location,
}

Symbol :: struct {}

Scope :: struct {
	parent	 : ^Scope,			  // Link to the parent scope (or `nil` if it's the global scope)
	symbols	: map[string]Symbol,   // Map from variable/function names to their metadata (Symbol)
}

Block :: struct {
	statements : []Statement,  // Ordered list of statements
	scope	  : Scope,		// Scope associated with the block
}