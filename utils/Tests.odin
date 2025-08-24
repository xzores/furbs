package utils;

import "core:fmt"
import "base:runtime"
import "core:testing"

@test
test_seri_deseri_dyn_arr :: proc (t : ^testing.T) {

	My_test_struct :: struct {
		data : []u8,
	}

	my_test_struct : My_test_struct = {data = {1,2,3,4,5,10,20,30,40,50,60,70,80,90}};
	
	ser, err := serialize_to_bytes(my_test_struct);
	my_test_struct2, err2 := deserialize_from_bytes(My_test_struct, ser[:], context.temp_allocator);
	fmt.assertf(err2 == .ok, "Deserialize did not go well, err : %v\n", err2);

	for d, i in my_test_struct.data {
		v := my_test_struct2.data[i];
		if v != d {
			fmt.printf("data at %i was %v, while it should be %v\n", i, v, d)
		};
	}

	free_all(context.temp_allocator);
}