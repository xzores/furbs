
import "math";
import debug "log";

//This is a comment

my_struct :: struct {
	some_member : string,
}

my_func :: proc () {
	
	res : f64 = 10 * 20 + 5;
	//res : f64 = math.cos(10);
	//debug.printf("res is %v", res);
}

my_func_with_args :: proc (my_arg : f64) {
	
	//res := math.cos(my_arg);
	//debug.printf("res is %v", res);
}

my_func_with_args_and_return :: proc (my_arg : f64) { // -> f64
	
	//res := math.cos(my_arg) + math.abs(my_arg);
	//debug.printf("res is %v", res);
}
