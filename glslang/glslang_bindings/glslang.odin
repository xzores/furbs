package glslang_bindings;

import "core:c"

when ODIN_OS == .Windows {
	
	when !ODIN_DEBUG {
		@(extra_linker_flags="/NODEFAULTLIB:libcmt")
		foreign import glslang {
			"lib/windows/GenericCodeGen.lib",
			"lib/windows/glslang-default-resource-limits.lib",
			"lib/windows/glslang.lib",
			
			"lib/windows/MachineIndependent.lib",
			"lib/windows/OSDependent.lib",
			
			"lib/windows/SPIRV-Tools.lib",
			"lib/windows/SPIRV-Tools-opt.lib",
		}
	} else {
		@(extra_linker_flags="/NODEFAULTLIB:libcmt")
		foreign import glslang {
			"lib/windows/GenericCodeGend.lib",
			"lib/windows/glslang-default-resource-limitsd.lib",
			"lib/windows/glslangd.lib",
			
			"lib/windows/MachineIndependentd.lib",
			"lib/windows/OSDependentd.lib",
			
			"lib/windows/SPIRV-Toolsd.lib",
			"lib/windows/SPIRV-Tools-optd.lib",
		}
	}	
}
when ODIN_OS == .Linux do foreign import glslang { //TODO
    "lib/linux/libGenericCodeGen.a",
    "lib/linux/libglslang-default-resource-limits.a",
    "lib/linux/libglslang.a",
    "lib/linux/libMachineIndependent.a",
    "lib/linux/libOSDependent.a",
	
    "lib/linux/libSPIRV-Tools.a",
    "lib/linux/libSPIRV-Tools-opt.a",
}
when ODIN_OS == .Darwin do foreign import glslang { //TODO
    "lib/darwin/libGenericCodeGen.a",
    "lib/darwin/libglslang-default-resource-limits.a",
    "lib/darwin/libglslang.a",
    "lib/darwin/libMachineIndependent.a",
    "lib/darwin/libOSDependent.a",
	
    "lib/darwin/libSPIRV-Tools-opt.a",
    "lib/darwin/libSPIRV-Tools.a",
}

////////////////// glslang_c_shader_types.h //////////////////

VERSION_MAJOR  :: 15
VERSION_MINOR  :: 1
VERSION_PATCH  :: 0
VERSION_FLAVOR :: ""

version_greater_than :: proc(major, minor, patch: int) -> bool {
    return (VERSION_MAJOR > major || (VERSION_MAJOR == major &&
           (VERSION_MINOR > minor || (VERSION_MINOR == minor &&
           (VERSION_PATCH > patch)))))
}

version_greater_or_equal_to :: proc(major, minor, patch: int) -> bool {
    return (VERSION_MAJOR > major || (VERSION_MAJOR == major &&
           (VERSION_MINOR > minor || (VERSION_MINOR == minor &&
           (VERSION_PATCH >= patch)))))
}

version_less_than :: proc(major, minor, patch: int) -> bool {
    return (VERSION_MAJOR < major || (VERSION_MAJOR == major &&
           (VERSION_MINOR < minor || (VERSION_MINOR == minor &&
           (VERSION_PATCH < patch)))))
}

version_less_or_equal_to :: proc(major, minor, patch: int) -> bool {
    return (VERSION_MAJOR < major || (VERSION_MAJOR == major &&
           (VERSION_MINOR < minor || (VERSION_MINOR == minor &&
           (VERSION_PATCH <= patch)))))
}

////////////////// glslang_c_shader_types.h //////////////////

Stage :: enum u32 {
	vertex,
	tesscontrol,
	tessevaluation,
	geometry,
	fragment,
	compute,
	raygen,
	raygen_nv = raygen,
	intersect,
	intersect_nv = intersect,
	anyhit,
	anyhit_nv = anyhit,
	closesthit,
	closesthit_nv = closesthit,
	miss,
	miss_nv = miss,
	callable,
	callable_nv = callable,
	task,
	task_nv = task,
	mesh,
	mesh_nv = mesh,
}

/*
stage_mask :: enum u32 {
	vertex_mask = 1 << stage.vertex,
	tesscontrol_mask = 1 << stage.tesscontrol,
	tessevaluation_mask = 1 << stage.tessevaluation,
	geometry_mask = 1 << stage.geometry,
	fragment_mask = 1 << stage.fragment,
	compute_mask = 1 << stage.compute,
	raygen_mask = 1 << stage.raygen,
	raygen_nv_mask = raygen_mask,
	intersect_mask = 1 << stage.intersect,
	intersect_nv_mask = intersect_mask,
	anyhit_mask = 1 << stage.anyhit,
	anyhit_nv_mask = anyhit_mask,
	closesthit_mask = 1 << stage.closesthit,
	closesthit_nv_mask = closesthit_mask,
	miss_mask = 1 << stage.miss,
	miss_nv_mask = miss_mask,
	callable_mask = 1 << stage.callable,
	callable_nv_mask = callable_mask,
	task_mask = 1 << stage.task,
	task_nv_mask = task_mask,
	mesh_mask = 1 << stage.mesh,
	mesh_nv_mask = mesh_mask,
}
*/
Stage_mask :: bit_set[Stage; u32];

Source_type :: enum u32 {
	none,
	glsl,
	hlsl,
}

Client :: enum u32 {
	none,
	vulkan,
	opengl,
}

Target_language :: enum u32 {
	none,
	spv,
}

Target_client_version :: enum u32 {
	vulkan_1_0 = 1 << 22,
	vulkan_1_1 = (1 << 22) | (1 << 12),
	vulkan_1_2 = (1 << 22) | (2 << 12),
	vulkan_1_3 = (1 << 22) | (3 << 12),
	opengl_450 = 450,
}

Target_language_version :: enum u32 {
	spv_1_0 = 1 << 16,
	spv_1_1 = (1 << 16) | (1 << 8),
	spv_1_2 = (1 << 16) | (2 << 8),
	spv_1_3 = (1 << 16) | (3 << 8),
	spv_1_4 = (1 << 16) | (4 << 8),
	spv_1_5 = (1 << 16) | (5 << 8),
	spv_1_6 = (1 << 16) | (6 << 8),
}

Executable :: enum u32 {
	vertex_fragment,
	fragment,
}

Optimization_level :: enum u32 {
	no_generation,
	none,
	simple,
	full,
}

Texture_sampler_transform_mode :: enum u32 {
	keep,
	upgrade_texture_remove_sampler,
}

Messages_enum :: enum u32 {
	relaxed_errors = 0,
	suppress_warnings = 1,
	ast = 2,
	spv_rules = 3,
	vulkan_rules = 4,
	only_preprocessor = 5,
	read_hlsl = 6,
	cascading_errors = 7,
	keep_uncalled = 8,
	hlsl_offsets = 9,
	debug_info = 10,
	hlsl_enable_16bit_types = 11,
	hlsl_legalization = 12,
	hlsl_dx9_compatible = 13,
	builtin_symbol_table = 14,
	enhanced = 15,
	absolute_path = 16,
	display_error_column = 17,
}

Messages :: bit_set[Messages_enum; u32];

Reflection_options_enum :: enum u32 {
	strict_array_suffix = 0,
	basic_array_suffix = 1,
	intermediate_ioo = 2,
	separate_buffers = 3,
	all_block_variables = 4,
	unwrap_io_blocks = 5,
	all_io_variables = 6,
	shared_std140_ssbo = 7,
	shared_std140_ubo = 8,
}

Reflection_options :: bit_set[Reflection_options_enum; u32];

Profile_enum :: enum u32 {
	no_profile = 0,
	core_profile = 1,
	compatibility_profile = 2,
	es_profile = 3,
}

Profile :: bit_set[Profile_enum; u32];

Shader_options_enum :: enum u32 {
	auto_map_bindings = 0,
	auto_map_locations = 1,
	vulkan_rules_relaxed = 2,
}

Shader_options :: bit_set[Shader_options_enum; u32];

Resource_type :: enum u32 {
	sampler,
	texture,
	image,
	ubo,
	ssbo,
	uav,
}



///////////////////////// glslang_c_interface.h  /////////////////////////

Handle :: distinct rawptr

Shader  :: distinct Handle
Program :: distinct Handle

//Version counterpart 
Version :: struct {
	major  : i32,
	minor  : i32,
	patch  : i32,
	flavor : cstring, //assumed cstring from const char* flavor;
}

//TLimits counterpart
Limits :: struct {
	non_inductive_for_loops                  : bool,
	while_loops                              : bool,
	do_while_loops                           : bool,
	general_uniform_indexing                 : bool,
	general_attribute_matrix_vector_indexing : bool,
	general_varying_indexing                 : bool,
	general_sampler_indexing                 : bool,
	general_variable_indexing                : bool,
	general_constant_matrix_vector_indexing  : bool,
}

//TBuiltInResource counterpart
Resource :: struct {
	max_lights                              		: i32,
	max_clip_planes                         		: i32,
	max_texture_units                       		: i32,
	max_texture_coords                      		: i32,
	max_vertex_attribs                      		: i32,
	max_vertex_uniform_components           		: i32,
	max_varying_floats                      		: i32,
	max_vertex_texture_image_units          		: i32,
	max_combined_texture_image_units        		: i32,
	max_texture_image_units                 		: i32,
	max_fragment_uniform_components         		: i32,
	max_draw_buffers                        		: i32,
	max_vertex_uniform_vectors              		: i32,
	max_varying_vectors                     		: i32,
	max_fragment_uniform_vectors            		: i32,
	max_vertex_output_vectors               		: i32,
	max_fragment_input_vectors              		: i32,
	min_program_texel_offset                		: i32,
	max_program_texel_offset                		: i32,
	max_clip_distances                      		: i32,
	max_compute_work_group_count_x          		: i32,
	max_compute_work_group_count_y          		: i32,
	max_compute_work_group_count_z          		: i32,
	max_compute_work_group_size_x           		: i32,
	max_compute_work_group_size_y           		: i32,
	max_compute_work_group_size_z           		: i32,
	max_compute_uniform_components          		: i32,
	max_compute_texture_image_units         		: i32,
	max_compute_image_uniforms              		: i32,
	max_compute_atomic_counters             		: i32,
	max_compute_atomic_counter_buffers      		: i32,
	max_varying_components                  		: i32,
	max_vertex_output_components            		: i32,
	max_geometry_input_components           		: i32,
	max_geometry_output_components          		: i32,
	max_fragment_input_components           		: i32,
	max_image_units                         		: i32,
	max_combined_image_units_fragment_outputs 		: i32,
	max_combined_shader_output_resources    		: i32,
	max_image_samples                       		: i32,
	max_vertex_image_uniforms               		: i32,
	max_tess_control_image_uniforms         		: i32,
	max_tess_evaluation_image_uniforms      		: i32,
	max_geometry_image_uniforms             		: i32,
	max_fragment_image_uniforms             		: i32,
	max_combined_image_uniforms             		: i32,
	max_geometry_texture_image_units        		: i32,
	max_geometry_output_vertices            		: i32,
	max_geometry_total_output_components    		: i32,
	max_geometry_uniform_components         		: i32,
	max_geometry_varying_components         		: i32,
	max_tess_control_input_components       		: i32,
	max_tess_control_output_components      		: i32,
	max_tess_control_texture_image_units    		: i32,
	max_tess_control_uniform_components     		: i32,
	max_tess_control_total_output_components 		: i32,
	max_tess_evaluation_input_components    		: i32,
	max_tess_evaluation_output_components   		: i32,
	max_tess_evaluation_texture_image_units 		: i32,
	max_tess_evaluation_uniform_components  		: i32,
	max_tess_patch_components               		: i32,
	max_patch_vertices                      		: i32,
	max_tess_gen_level                      		: i32,
	max_viewports                           		: i32,
	max_vertex_atomic_counters              		: i32,
	max_tess_control_atomic_counters        		: i32,
	max_tess_evaluation_atomic_counters     		: i32,
	max_geometry_atomic_counters            		: i32,
	max_fragment_atomic_counters            		: i32,
	max_combined_atomic_counters            		: i32,
	max_atomic_counter_bindings             		: i32,
	max_vertex_atomic_counter_buffers       		: i32,
	max_tess_control_atomic_counter_buffers 		: i32,
	max_tess_evaluation_atomic_counter_buffers 		: i32,
	max_geometry_atomic_counter_buffers     		: i32,
	max_fragment_atomic_counter_buffers     		: i32,
	max_combined_atomic_counter_buffers     		: i32,
	max_atomic_counter_buffer_size          		: i32,
	max_transform_feedback_buffers          		: i32,
	max_transform_feedback_i32erleaved_components 	: i32,
	max_cull_distances                      		: i32,
	max_combined_clip_cull_distances        		: i32,
	max_samples                             		: i32,
	max_mesh_output_vertices_nv             		: i32,
	max_mesh_output_primitives_nv           		: i32,
	max_mesh_work_group_size_x_nv           		: i32,
	max_mesh_work_group_size_y_nv           		: i32,
	max_mesh_work_group_size_z_nv           		: i32,
	max_task_work_group_size_x_nv           		: i32,
	max_task_work_group_size_y_nv           		: i32,
	max_task_work_group_size_z_nv           		: i32,
	max_mesh_view_count_nv                  		: i32,
	max_mesh_output_vertices_ext            		: i32,
	max_mesh_output_primitives_ext          		: i32,
	max_mesh_work_group_size_x_ext          		: i32,
	max_mesh_work_group_size_y_ext          		: i32,
	max_mesh_work_group_size_z_ext          		: i32,
	max_task_work_group_size_x_ext          		: i32,
	max_task_work_group_size_y_ext          		: i32,
	max_task_work_group_size_z_ext          		: i32,
	max_mesh_view_count_ext                 		: i32,
	
	max_dual_source_draw_buffers_ext 				: i32,
	
	limits                                  		: Limits,
}

// Inclusion result structure allocated by C include_local/include_system callbacks
Include_result :: struct {
	header_name   : cstring, // Name or NULL if inclusion failed
	header_data   : cstring, // Content or NULL
	header_length : i64,
}

Include_system_func :: #type proc "c" (ctx: rawptr, header_name: cstring, includer_name: cstring, include_depth: c.size_t) -> ^Include_result
Include_local_func  :: #type proc "c" (ctx: rawptr, header_name: cstring, includer_name: cstring, include_depth: c.size_t) -> ^Include_result
Free_include_result_func :: #type proc "c" (ctx: rawptr, result: ^Include_result) -> i32

Include_callbacks :: struct {
	include_system : Include_system_func,
	include_local  : Include_local_func,
	free_result    : Free_include_result_func,
}

Input :: struct {
	language                 				: Source_type,
	stage                    				: Stage,
	client                   				: Client,
	client_version           				: Target_client_version,
	target_language          				: Target_language,
	target_language_version  				: Target_language_version,
	code                     				: cstring,
	default_version          				: i32,
	default_profile          				: Profile,
	force_default_version_and_profile    	: b32,
	forward_compatible       				: b32,
	messages                 				: Messages,
	resource                 				: ^Resource,
	callbacks                				: Include_callbacks,
	callbacks_ctx            				: rawptr,
}

Spv_options :: struct {
	generate_debug_info                  : bool,
	strip_debug_info                     : bool,
	disable_optimizer                    : bool,
	optimize_size                        : bool,
	disassemble                          : bool,
	validate                             : bool,
	emit_nonsemantic_shader_debug_info   : bool,
	emit_nonsemantic_shader_debug_source : bool,
	compile_only                         : bool,
	optimize_allow_expanded_id_bound     : bool,
}

// Declare external functions and types related to GLSLang API
@(default_calling_convention="c", link_prefix="glslang_")
foreign glslang {
    // ===================================== glslang_c_interface.h
    initialize_process                  :: proc() -> b32 ---
    finalize_process                    :: proc() ---
	
    shader_create                       :: proc(input: ^Input) -> Shader ---
    shader_delete                       :: proc(shader: Shader) ---
    shader_set_preamble                 :: proc(shader: Shader, s: cstring) ---
    shader_shift_binding                :: proc(shader: Shader, res: Resource_type, base: c.uint) ---
    shader_shift_binding_for_set        :: proc(shader: Shader, res: Resource_type, base: c.uint, set: c.uint) ---
    shader_set_options                  :: proc(shader: Shader, options: Shader_options) ---
    shader_set_glsl_version             :: proc(shader: Shader, version: c.int) ---
    shader_preprocess                   :: proc(shader: Shader, input: ^Input) -> b32 ---
    shader_parse                        :: proc(shader: Shader, input: ^Input) -> b32 ---
    shader_get_preprocessed_code        :: proc(shader: Shader) -> cstring ---
    shader_get_info_log                 :: proc(shader: Shader) -> cstring ---
    shader_get_info_debug_log           :: proc(shader: Shader) -> cstring ---
	
    program_create                      :: proc() -> Program ---
    program_delete                      :: proc(program: Program) ---
    program_add_shader                  :: proc(program: Program, shader: Shader) ---
    program_link                        :: proc(program: Program, messages: Messages) -> b32 ---
    program_add_source_text             :: proc(program: Program, stage: Stage, text: cstring, len: c.size_t) ---
    program_set_source_file             :: proc(program: Program, stage: Stage, file: cstring) ---
    program_map_io                      :: proc(program: Program) -> b32 ---
    program_SPIRV_generate              :: proc(program: Program, stage: Stage) ---
    program_SPIRV_generate_with_options :: proc(program: Program, stage: Stage, spv_options: ^Spv_options) ---
    program_SPIRV_get_size              :: proc(program: Program) -> c.size_t ---
    program_SPIRV_get                   :: proc(program: Program, spirv: [^]c.uint) ---
    program_SPIRV_get_ptr               :: proc(program: Program) -> [^]c.uint ---
    program_SPIRV_get_messages          :: proc(program: Program) -> cstring ---
    program_get_info_log                :: proc(program: Program) -> cstring ---
    program_get_info_debug_log          :: proc(program: Program) -> cstring ---

    // ========================================== resource_limits_c.h
    resource                            :: proc() -> ^Resource ---
    default_resource                    :: proc() -> ^Resource ---
    default_resource_string             :: proc() -> cstring ---
    decode_resource_limits              :: proc(resources: ^Resource, config: cstring) ---
}