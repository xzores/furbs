package utils;

import "base:intrinsics"

import "core:log"
import "core:fmt"
import "core:math"
import "core:math/rand"
import "core:slice"

Tensor :: struct(T : typeid) where intrinsics.type_is_numeric(T) {
	dims : []int, // dimensions
	data : []T, // Flattened tensor data
}

tensor_make :: proc ($T : typeid, dims : ..int) -> Tensor(T) {

	total_size : int = 1;

	for d in dims {
		total_size *= d;
	}

	return {slice.clone(dims), make([]t, total_size)};
}

tensor_make_identity :: proc($T: typeid, dims: ..int) -> Tensor(T) {
	t := tensor_make(T, ..dims);
	least := slice.min(dims);

	indices := make([]int, len(dims));
	for i in 0..<least {
		for j in 0..<len(dims) {
			indices[j] = i;
		}
		tensor_set(t, T(1), indices);
	}

	return t;
}

tensor_destroy :: proc (m : Tensor($T)) {
	delete(m.data);
}



///////////////////////////// Indexing, columns and rows /////////////////////////////

tensor_get :: #force_inline proc (m : Tensor($T), dims: []int, indices: []int) -> T {
	return #force_inline get_array(m.data, dims, indices)
}

tensor_set :: #force_inline proc (m : Tensor($T), value : T, dims: []int, indices: []int) {
	#force_inline set_array_xy(m.data, value, dims, indices);
}

///////////////////////////// Linear algebra, multiplication and vectors /////////////////////////////
/*
tensor_mul :: #force_inline proc(A, B : Tensor($T), loc := #caller_location) -> Tensor(T) {
	// Ensure the matrices can be multiplied (A.columns == B.rows)
	if A.columns != B.rows {
		panic("Tensor dimensions do not align for multiplication.");
	}
	
	// Initialize result Tensor
	result := Tensor(T) {
		rows = A.rows,
		columns = B.columns,
		data = make([]T, A.rows * B.columns, loc = loc), // Flattened 2D Tensor with zeros, as Odin is zero-init
	};

	// Perform Tensor multiplication
	for i in 0 ..< A.rows {
		for j in 0 ..< B.columns {
			sum : T;
			
			for k in 0 ..< A.columns {
				// Access elements in flattened arrays
				a_elem := A.data[i * A.columns + k];
				b_elem := B.data[k * B.columns + j];
				sum += a_elem * b_elem;
			}
			result.data[i * B.columns + j] = sum;
		}
	}

	return result;
}

tensor_vec_mul_inplace :: #force_inline proc(A : Tensor($T), B : []T, result : []T, loc := #caller_location) where intrinsics.type_is_numeric(T) {
	// Ensure the Tensor and vector can be multiplied (A.columns == length(B))
	fmt.assertf(len(result) == A.rows, "Result vector must have the same length as the Tensor rows, got %v, expected %v", len(result), A.rows, loc = loc);
	if A.columns != len(B) {
		fmt.panicf("Tensor and vector dimensions do not align for multiplication, Tensor : (%v, %v). The vector has length %v and the Tensor has %v columbs", A.rows, A.columns, len(B), A.columns);
	}

	// Perform Tensor-vector multiplication
	for i in 0 ..< A.rows {
		sum : T;
		
		for j in 0 ..< A.columns {
			// Access elements in flattened arrays
			a_elem := A.data[i * A.columns + j];
			b_elem := B[j];
			sum += a_elem * b_elem;
		}
		result[i] = sum;
	}
}

tensor_vec_mul :: #force_inline proc(A : Tensor($T), B : []T, loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	// Ensure the Tensor and vector can be multiplied (A.columns == length(B))
	if A.columns != len(B) {
		fmt.panicf("Tensor and vector dimensions do not align for multiplication, Tensor : (%v, %v). The vector has length %v and the Tensor has %v columbs", A.rows, A.columns, len(B), A.columns);
	}

	// Initialize result vector
	result := make([]T, A.rows, loc = loc);

	tensor_vec_mul_inplace(A, B, result, loc);

	return result;
}

vec_tensor_mul :: #force_inline proc(B : []$T, A : Tensor(T), loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	// Ensure the vector and Tensor can be multiplied (len(B) == A.rows)
	if len(B) != A.rows {
		fmt.panicf("Vector and Tensor dimensions do not align for multiplication, Tensor : (%v, %v). The vector has length %v and the Tensor has %v rows", A.rows, A.columns, len(B), A.rows);
	}

	// Initialize result vector
	result := make([]T, A.columns, loc);

	// Perform vector-Tensor multiplication
	for j in 0 ..< A.columns {
		sum : T;
		
		for i in 0 ..< A.rows {
			// Access elements in flattened arrays
			b_elem := B[i];
			a_elem := A.data[i * A.columns + j];
			sum += b_elem * a_elem;
		}
		result[j] = sum;
	}

	return result;
}

//This multiplies a columb vector with a row vector, the result from a jx1 and 1xi vector is a jxi Tensor. 
vec_columb_vec_row_mul :: #force_inline proc(A, B : []$T, loc := #caller_location) -> Tensor(T) where intrinsics.type_is_numeric(T) {
	// Ensure both vectors are non-empty
	if len(A) == 0 || len(B) == 0 {
		panic("Vectors must be non-empty for multiplication.");
	}

	// Initialize result Tensor
	result := Tensor(T) {
		rows = len(A),
		columns = len(B),
		data = make([]T, len(A) * len(B), loc=loc),
	};

	// Perform column-vector x row-vector multiplication
	for i in 0 ..< len(A) {
		for j in 0 ..< len(B) {
			result.data[i * len(B) + j] = A[i] * B[j];
		}
	}

	return result;
}

//This will first transpose the Tensor a then multiply with the vector.
tensor_transposed_vec_mul :: #force_inline proc(col_vec : Tensor($T), row_vec : []T, loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	A := col_vec; B := row_vec;
	
	// Ensure the Tensor and vector can be multiplied (A.rows == len(B) after transpose)
	if A.rows != len(B) {
		fmt.panicf("Tensor and vector dimensions do not align for multiplication after transpose, Tensor: (%v, %v). The vector has length %v and the Tensor has %v rows", A.rows, A.columns, len(B), A.rows);
	}

	// Initialize result vector
	result := make([]T, A.columns, loc = loc);  // After transpose, we have A.columns rows

	// Perform transposed Tensor-vector multiplication
	for j in 0 ..< A.columns { // Iterate over what will be rows after transpose
		sum : T;

		for i in 0 ..< A.rows { // Iterate over what will be columns after transpose
			// Access elements in flattened arrays as if the Tensor were transposed
			a_elem := A.data[i * A.columns + j];
			b_elem := B[i];
			sum += a_elem * b_elem;
		}
		result[j] = sum;  // Result has A.columns elements (since A^T has A.columns rows)
	}

	return result;
}

tensor_clone  :: #force_inline proc(mat : Tensor($T), loc := #caller_location) -> Tensor(T) where intrinsics.type_is_numeric(T) {
	
	mat_t := tensor_make(mat.columns, mat.rows, T);
		
	for c in 0..<mat.columns {
		for r in 0..<mat.rows {
			v := tensor_get(mat, c, r);
			tensor_set(mat_t, c, r, v);
		}
	}
	
	return mat_t;
}

tensor_add_to_inplace :: #force_inline proc(A, B : Tensor($T), loc := #caller_location) where intrinsics.type_is_numeric(T) {
	
	assert(A.columns == B.columns, "Tensor does not have same dimensions", loc);
	assert(A.rows == B.rows, "Tensor does not have same dimensions", loc);
		
	for c in 0..<A.columns {
		for r in 0..<A.rows {
			a := tensor_get(A, c, r);
			b := tensor_get(B, c, r);
			tensor_set(A, c, r, a + b);
		}
	}
}
*/

@(private = "file")
get_array :: #force_inline proc(a: []$T, dims: []int, indices: []int) -> T {
	assert(len(dims) == len(indices), "dimension count mismatch");

	stride := 1;
	index  := 0;

	for i := len(dims)-1; i >= 0; i -= 1 {
		index += indices[i] * stride;
		stride *= dims[i];
	}

	return a[index];
}

@(private="file")
set_array_xy :: #force_inline proc (a : []$T, value : T, dims: []int, indices: []int) {
	assert(len(dims) == len(indices), "dimension count mismatch");

	stride := 1;
	index  := 0;

	for i := len(dims)-1; i >= 0; i -= 1 {
		index += indices[i] * stride;
		stride *= dims[i];
	}

	a[index] = value;
}
