package HADL

import "core:math"
import "core:fmt"

Stacked_array :: struct(Data_type : typeid) {
    size : int,
    stack : [dynamic][]Data_type,
}

Stacked_array_iterator :: struct(Data_type : typeid) {
    index : int,
    data : ^Stacked_array(Data_type),
}

//TODO, this currently run in O log(n) time, we could make it constant, assuming the capacity doubles every time.
stacked_array_append :: proc (array : ^Stacked_array($T), element : T, init_capacity : int = 32) {
    using array, math;
    
    if len(stack) == 0 {
        append(&stack, make([]T, init_capacity));
    }
    
    target : int = size;
    cur_place : int = 0;
    i : int;

    for i = 0; ; i+=1 {

        if(len(stack) == i){
            prev_len := len(stack[len(stack) - 1])
            append(&stack, make([]T, 2 * prev_len));
        }

        if(cur_place + len(stack[i]) > target){
            break;
        }

        cur_place += len(stack[i]);
    }
    
    stack[i][target - cur_place] = element
    size+=1;
}

stacked_array_get :: proc (array : Stacked_array($T), index: int) -> T {    
    using array;

    return stacked_array_get_ptr(array, index)^;
}

//TODO, this currently run in O log(n) time, we could make it constant.
stacked_array_get_ptr :: proc (array : Stacked_array($T), index: int) -> ^T {    
    using array, math;

    target : int = index;
    i : int;

    for i = 0; i < len(stack) - 1; i+=1 {

        if target - len(stack[i]) < 0 {
            break;
        }

        target -= len(stack[i])
    }

    return &stack[i][target];    
}

stacked_array_contains :: proc (array : ^Stacked_array($T), value : T) -> bool {

    itter := make_stacked_array_iterator(array);
	for v,i in iterate_stacked_array(&itter) {
		if itter == value {
            return true;
        }
	}

    return false;
}

stacked_array_contains_ptr :: proc (array : ^Stacked_array($T), value : ^T) -> bool {

    itter := make_stacked_array_iterator(array);
	for _,i in iterate_stacked_array(&itter) {
		if stacked_array_get_ptr(array^, i) == value {
            return true;
        }
	}

    return false;
}


/*
stacked_array_capacity :: proc (array : Stacked_array($T)) -> (size : int) {
    using array;
    return pow(2, len(stack) + 1) - 1;
}

clear_stacked_array :: proc (a: ^Stacked_array($T)) {
}
*/

make_stacked_array_iterator :: proc(a: ^Stacked_array($T)) -> Stacked_array_iterator(T) {

    return Stacked_array_iterator(T){index = 0, data = a};
}

iterate_stacked_array :: proc(it : ^Stacked_array_iterator($T)) -> (val: T, idx: int, cond: bool) {
    
    cond = it.index < it.data.size
    if cond {
        val = get(it.data^, it.index)
        idx = it.index
        it.index += 1
    }
    
    return
}

iterate_stacked_array_ptr :: proc(it : ^Stacked_array_iterator($T)) -> (val: ^T, idx: int, cond: bool) {
    
    cond = it.index < it.data.size
    if cond {
        val = get_ptr(it.data^, it.index)
        idx = it.index
        it.index += 1
    }
    
    return
}


get :: proc {stacked_array_get}
get_ptr :: proc {stacked_array_get_ptr}



stacked_array_set_formatter :: proc($t : typeid){

	_stacked_array_formatter :: proc(fi: ^fmt.Info, arg: any, verb: rune) -> bool {

		a := arg.(Stacked_array(t))

        fmt.wprintf(fi.writer, "[")
        
        for s,i in a.stack {
            fmt.wprintf(fi.writer, "| ")
            for e in s {
                fmt.wprintf(fi.writer, " %v ", e)
            }
            fmt.wprintf(fi.writer, " |")
        }

        fmt.wprintf(fi.writer, "]")

		return true;
	}
    
	fmt.register_user_formatter(Stacked_array(t), _stacked_array_formatter)
}

