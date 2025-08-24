
import "math";
import debug "log";

//This is a comment

my_struct :: struct {
	some_member : string,
}

my_func_with_args :: proc (my_arg : f64) {
	
	//res := math.cos(my_arg);
	//debug.printf("res is %v", res);
}

my_func_with_args_and_return :: proc (my_arg : f64) -> f64 {
	
	//res := math.cos(my_arg) + math.abs(my_arg);
	//debug.printf("res is %v", res);
}

my_func :: proc () {
	
	call_this :: proc (a : f64) {
		call_this_res : f64 = a + 3 * 2;
	}
	
	res : f64 = 10 + 20 * 5;
	call_this(res);
	
	print("Hello world %v is %v", "res", res);
	
	//b : f64 = my_func_with_args_and_return(2);
	//c : f64 = res + b;
	//res : f64 = math.cos(10);
	//debug.printf("res is %v", res);
}