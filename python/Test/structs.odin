package furbs_python_helper_package_tests;

import "base:runtime"

import "core:log"
import "core:mem"

import "../../utils" 
import python ".."

main :: proc () {
	
	context.logger = utils.create_console_logger(.Debug);
	defer utils.destroy_console_logger(context.logger);
	
	when ODIN_DEBUG {
		context.assertion_failure_proc = utils.init_stack_trace();
		defer utils.destroy_stack_trace();
		
		utils.init_tracking_allocators();
		
		{
			tracker : ^mem.Tracking_Allocator;
			context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,
			
			test_main();
		}
		
		utils.print_tracking_memory_results();
		utils.destroy_tracking_allocators();
	}
	else {
		test_main();
	}
}


Hello :: struct {};

Version_check :: struct {
    major_version : u16,
    minor_version : u16,
    patch         : u16,
};

Version_check_passed :: struct { was_passed : bool };

Chat_message :: struct {
    text : string,
};

// --- Added types ---

// Basic numbers
Numbers :: struct {
    i  : int,
    u  : u32,
    f  : f64,
}

// Complex numbers
HasComplex :: struct {
    z32 : complex64,
    z64 : complex128,
}

// Fixed array, slice, dynamic array
Collections :: struct {
    fixed3 : [3]int,
    slice  : []string,
    dyn    : [dynamic]u8,
}

// Map / dict
Dictish :: struct {
    counts : map[string]int,
}

// Nested structs
DeepInner :: struct {
    value : f64,
}
Inner :: struct {
    deep : DeepInner,
}
Outer :: struct {
    inner : Inner,
}

// Enum usage
Color :: enum u8 {
    Red, Green, Blue,
}

Colored :: struct {
    color : Color,
}

// “Matrix-like” using list-of-lists pattern: slice of fixed-size rows
MatrixLike :: struct {
    rows : [][3]f32,
}

Point2D :: struct {
    x : f32,
    y : f32,
}

User :: struct {
    name    : string,
    age     : u16,
    is_admin: bool,
}

Status :: enum i32 {
    Unknown = -1,
    Ok,
    Warn,
    Error,
}

// The big one
KitchenSink :: struct {
    // Scalars
    i_signed   : i64,
    u_unsigned : u32,
    f_num      : f64,
    b_flag     : bool,
    s_text     : string,

    // Complex
    z32 : complex64,
    z64 : complex128,

    // Fixed-size arrays
    fixed_ints    : [3]int,
    fixed_points  : [2]Point2D,

    // Slices / dynamic arrays
    str_slice     : []string,
    byte_dyn      : [dynamic]u8,       // dynamic array
    inner_slice   : []Inner,

    // Maps
    str_to_int    : map[string]int,
    id_to_user    : map[u64]User,
    color_to_name : map[Color]string,

    // Nested structs (composition)
    inner  : Inner,
    /*config : struct {
        retries : u8,
        delay_ms: u32,
        status  : Status,
    },*/

    // “Matrix-like” (rows of fixed-size float triples)
    mat_like : [][3]f32,

    // Tuples via fixed arrays
    quaternion_like : [4]f64,     // if you later map Quaternion, swap this type

    // Mixed collections
    list_of_lists : [][]int,
    map_of_lists  : map[string][]u16,
    list_of_maps  : []map[string]int,

    // Enums
    color  : Color,
    status : Status,

    // More nested composition
    user    : User,
    vertices: []Point2D,
}

test_main :: proc () {

	dependencies : map[^runtime.Type_Info]struct{};
	defer delete(dependencies)

    hello := python.convert_struct_definition(type_info_of(Hello), &dependencies)
    log.debugf("hello became:\n%v", hello)

    version_check := python.convert_struct_definition(type_info_of(Version_check), &dependencies)
    log.debugf("version_check became:\n%v", version_check)

    version_check_passed := python.convert_struct_definition(type_info_of(Version_check_passed), &dependencies)
    log.debugf("version_check_passed became:\n%v", version_check_passed)

    chat_message := python.convert_struct_definition(type_info_of(Chat_message), &dependencies)
    log.debugf("chat_message became:\n%v", chat_message)

    numbers := python.convert_struct_definition(type_info_of(Numbers), &dependencies)
    log.debugf("numbers became:\n%v", numbers)

    has_complex := python.convert_struct_definition(type_info_of(HasComplex), &dependencies)
    log.debugf("has_complex became:\n%v", has_complex)

    collections := python.convert_struct_definition(type_info_of(Collections), &dependencies)
    log.debugf("collections became:\n%v", collections)

    dictish := python.convert_struct_definition(type_info_of(Dictish), &dependencies)
    log.debugf("dictish became:\n%v", dictish)

    outer := python.convert_struct_definition(type_info_of(Outer), &dependencies)
    log.debugf("outer became:\n%v", outer)

    colored := python.convert_struct_definition(type_info_of(Colored), &dependencies)
    log.debugf("colored became:\n%v", colored)

    matrix_like := python.convert_struct_definition(type_info_of(MatrixLike), &dependencies)
    log.debugf("matrix_like became:\n%v", matrix_like)



	sink := python.convert_to_python({type_info_of(KitchenSink)});
	defer delete(sink);
	log.debugf("KitchenSink became:\n%v", sink)

}
