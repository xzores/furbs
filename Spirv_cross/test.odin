package spriv_cross_wrapper;

const SpvId *spirv = get_spirv_data();
size_t word_count = get_spirv_word_count();

spvc_context context = NULL;
spvc_parsed_ir ir = NULL;
spvc_compiler compiler_glsl = NULL;
spvc_compiler_options options = NULL;
spvc_resources resources = NULL;
const spvc_reflected_resource *list = NULL;
const char *result = NULL;
size_t count;
size_t i;

// Create context.
spvc_context_create(&context);

// Set debug callback.
spvc_context_set_error_callback(context, error_callback, userdata);

// Parse the SPIR-V.
spvc_context_parse_spirv(context, spirv, word_count, &ir);

// Hand it off to a compiler instance and give it ownership of the IR.
spvc_context_create_compiler(context, SPVC_BACKEND_GLSL, ir, SPVC_CAPTURE_MODE_TAKE_OWNERSHIP, &compiler_glsl);

// Do some basic reflection.
spvc_compiler_create_shader_resources(compiler_glsl, &resources);
spvc_resources_get_resource_list_for_type(resources, SPVC_RESOURCE_TYPE_UNIFORM_BUFFER, &list, &count);

for (i = 0; i < count; i++)
{
    printf("ID: %u, BaseTypeID: %u, TypeID: %u, Name: %s\n", list[i].id, list[i].base_type_id, list[i].type_id,
           list[i].name);
    printf("  Set: %u, Binding: %u\n",
           spvc_compiler_get_decoration(compiler_glsl, list[i].id, SpvDecorationDescriptorSet),
           spvc_compiler_get_decoration(compiler_glsl, list[i].id, SpvDecorationBinding));
}

// Modify options.
spvc_compiler_create_compiler_options(compiler_glsl, &options);
spvc_compiler_options_set_uint(options, SPVC_COMPILER_OPTION_GLSL_VERSION, 330);
spvc_compiler_options_set_bool(options, SPVC_COMPILER_OPTION_GLSL_ES, SPVC_FALSE);
spvc_compiler_install_compiler_options(compiler_glsl, options);

spvc_compiler_compile(compiler_glsl, &result);
printf("Cross-compiled source: %s\n", result);

// Frees all memory we allocated so far.
spvc_context_destroy(context);