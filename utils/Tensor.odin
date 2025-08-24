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

	return {slice.clone(dims), make([]T, total_size)};
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

tensor_destroy :: proc (m : Tensor($T), loc := #caller_location) {
	delete(m.data, loc = loc);
	delete(m.dims, loc = loc);
}

///////////////////////////// Indexing, columns and rows /////////////////////////////

tensor_get :: #force_inline proc (m : Tensor($T), indices: []int) -> T {
	return #force_inline get_array(m.data, m.dims, indices)
}

tensor_set :: #force_inline proc (m : Tensor($T), value : T, indices: []int) {
	#force_inline set_array_xy(m.data, value, m.dims, indices);
}

// Copy tensor data from src to dest
tensor_copy :: proc(dest: Tensor($T), src: Tensor(T), loc := #caller_location) {
	assert(len(dest.data) == len(src.data), "Tensor sizes must match for copy", loc);
	for i in 0..<len(src.data) {
		dest.data[i] = src.data[i];
	}
}

// Matrix-tensor multiplication inplace (for batch processing)
// result = tensor * mat
tensor_matrix_mul_inplace :: proc(result: Tensor($T), tensor: Tensor(T), mat: Matrix(T), loc := #caller_location) {
	// For 2D tensors: tensor shape is [batch_size, input_features]
	// mat shape is [input_features, output_features]
	// result shape should be [batch_size, output_features]
	
	assert(len(tensor.dims) >= 2, "Tensor must be at least 2D", loc);
	assert(tensor.dims[1] == mat.columns, "Tensor features must match matrix columns", loc);
	assert(len(result.dims) >= 2, "Result tensor must be at least 2D", loc);
	assert(result.dims[0] == tensor.dims[0], "Batch sizes must match", loc);
	assert(result.dims[1] == mat.rows, "Result features must match matrix rows", loc);
	
	batch_size := tensor.dims[0];
	input_features := tensor.dims[1];
	output_features := mat.rows;
	
	// For each sample in the batch
	for batch_idx in 0..<batch_size {
		// Get the input slice for this batch
		input_start := batch_idx * input_features;
		input_end := input_start + input_features;
		input_slice := tensor.data[input_start:input_end];
		
		// Get the output slice for this batch
		output_start := batch_idx * output_features;
		output_end := output_start + output_features;
		output_slice := result.data[output_start:output_end];
		
		// Matrix-vector multiplication for this sample
		matrix_vec_mul_inplace(mat, input_slice, output_slice, loc);
	}
}

// Add bias to tensor inplace (broadcast across batch)
tensor_add_bias_inplace :: proc(tensor: Tensor($T), biases: []T, loc := #caller_location) {
	assert(len(tensor.dims) >= 2, "Tensor must be at least 2D", loc);
	assert(tensor.dims[1] == len(biases), "Tensor features must match bias length", loc);
	
	batch_size := tensor.dims[0];
	features := tensor.dims[1];
	
	// For each sample in the batch
	for batch_idx in 0..<batch_size {
		// Get the slice for this batch
		start := batch_idx * features;
		end := start + features;
		slice := tensor.data[start:end];
		
		// Add biases to this sample
		add_to_slice(slice, biases);
	}
}

// Add two tensors inplace
tensor_add_inplace :: proc(A: Tensor($T), B: Tensor(T), loc := #caller_location) {
	assert(len(A.data) == len(B.data), "Tensor sizes must match for addition", loc);
	for i in 0..<len(A.data) {
		A.data[i] += B.data[i];
	}
}

// Subtract two tensors inplace
tensor_subtract_inplace :: proc(A: Tensor($T), B: Tensor(T), loc := #caller_location) {
	assert(len(A.data) == len(B.data), "Tensor sizes must match for subtraction", loc);
	for i in 0..<len(A.data) {
		A.data[i] -= B.data[i];
	}
}

// Element-wise multiplication inplace, the result is placed in A
tensor_elem_wise_multiply_inplace :: proc(A: Tensor($T), B: Tensor(T), loc := #caller_location) {
	assert(len(A.data) == len(B.data), "Tensor sizes must match for multiplication", loc);
	for i in 0..<len(A.data) {
		A.data[i] *= B.data[i];
	}
}

// Element-wise division inplace
tensor_divide_inplace :: proc(A: Tensor($T), B: Tensor(T), loc := #caller_location) {
	assert(len(A.data) == len(B.data), "Tensor sizes must match for division", loc);
	for i in 0..<len(A.data) {
		A.data[i] /= B.data[i];
	}
}

// Scale tensor by scalar inplace
tensor_scale_inplace :: proc(tensor: Tensor($T), scalar: T) {
	for i in 0..<len(tensor.data) {
		tensor.data[i] *= scalar;
	}
}

// Fill tensor with value
tensor_fill :: proc(tensor: Tensor($T), value: T) {
	for i in 0..<len(tensor.data) {
		tensor.data[i] = value;
	}
}

// Get tensor shape as string
tensor_shape_string :: proc(tensor: Tensor($T)) -> string {
	if len(tensor.dims) == 0 {
		return "[]";
	}
	
	result := fmt.tprintf("[%d", tensor.dims[0]);
	for i in 1..<len(tensor.dims) {
		result = fmt.tprintf("%s, %d", result, tensor.dims[i]);
	}
	result = fmt.tprintf("%s]", result);
	return result;
}

// Check if tensors have same shape
tensor_same_shape :: proc(A: Tensor($T), B: Tensor(T)) -> bool {
	if len(A.dims) != len(B.dims) {
		return false;
	}
	for i in 0..<len(A.dims) {
		if A.dims[i] != B.dims[i] {
			return false;
		}
	}
	return true;
}

// Get total number of elements in tensor
tensor_size :: proc(tensor: Tensor($T)) -> int {
	return len(tensor.data);
}

// Get tensor dimensions
tensor_dims :: proc(tensor: Tensor($T)) -> []int {
	return tensor.dims;
}

// Create tensor from slice with given dimensions
tensor_from_slice :: proc(data: []$T, dims: []int, loc := #caller_location) -> Tensor(T) {
	total_size := 1;
	for d in dims {
		total_size *= d;
	}
	assert(len(data) == total_size, "Data size must match dimensions", loc);
	
	return {slice.clone(dims), slice.clone(data)};
}

// Convert tensor to slice (returns a copy)
tensor_to_slice :: proc(tensor: Tensor($T), loc := #caller_location) -> []T {
	return slice.clone(tensor.data);
}

// Get a slice of the tensor data (no copy)
tensor_data_slice :: proc(tensor: Tensor($T)) -> []T {
	return tensor.data;
}

// Reshape tensor (if possible)
tensor_reshape :: proc(tensor: Tensor($T), new_dims: []int, loc := #caller_location) -> Tensor(T) {
	total_size := 1;
	for d in new_dims {
		total_size *= d;
	}
	assert(len(tensor.data) == total_size, "Cannot reshape: size mismatch", loc);
	
	return {slice.clone(new_dims), slice.clone(tensor.data)};
}

// Transpose 2D tensor
tensor_transpose_2d :: proc(tensor: Tensor($T), loc := #caller_location) -> Tensor(T) {
	assert(len(tensor.dims) == 2, "Tensor must be 2D for transpose", loc);
	
	rows := tensor.dims[0];
	cols := tensor.dims[1];
	
	result := tensor_make(T, cols, rows);
	
	for i in 0..<rows {
		for j in 0..<cols {
			src_idx := i * cols + j;
			dst_idx := j * rows + i;
			result.data[dst_idx] = tensor.data[src_idx];
		}
	}
	
	return result;
}

// Helper function to add to slice (used by tensor_add_bias_inplace)
add_to_slice :: proc(A: []$T, B: []T, loc := #caller_location) {
	assert(len(A) == len(B), "Cannot add slices with different lengths", loc);
	for i in 0..<len(A) {
		A[i] += B[i];
	}
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

// Convert tensor to matrix view (no copy, just different view)
tensor_as_matrix :: proc(tensor: Tensor($T), loc := #caller_location) -> Matrix(T) {
	assert(len(tensor.dims) >= 2, "Tensor must be at least 2D for matrix view", loc);
	
	// For a tensor with shape [batch_size, features], we view it as a matrix
	// where rows = batch_size and columns = features
	rows := tensor.dims[0];
	columns := tensor.dims[1];
	
	return Matrix(T){
		rows = rows,
		columns = columns,
		data = tensor.data, // Same data, different view
	};
}

// Outer product of two vectors, creating a tensor
// If A has shape [batch_size, out_dim] and B has shape [batch_size, in_dim]
// Result has shape [batch_size, out_dim, in_dim]
outer_prodcut :: proc(A: Tensor($T), B: Tensor(T), loc := #caller_location) -> Tensor(T) {
	assert(len(A.dims) >= 2, "A must be at least 2D", loc);
	assert(len(B.dims) >= 2, "B must be at least 2D", loc);
	assert(A.dims[0] == B.dims[0], "Batch sizes must match for outer product", loc);
	
	batch_size := A.dims[0];
	out_dim := A.dims[1];
	in_dim := B.dims[1];
	
	// Create result tensor with shape [batch_size, out_dim, in_dim]
	result := tensor_make(T, batch_size, out_dim, in_dim);
	
	// For each batch
	for batch_idx in 0..<batch_size {
		// Get the slices for this batch
		a_start := batch_idx * out_dim;
		a_end := a_start + out_dim;
		a_slice := A.data[a_start:a_end];
		
		b_start := batch_idx * in_dim;
		b_end := b_start + in_dim;
		b_slice := B.data[b_start:b_end];
		
		// Compute outer product for this batch
		result_start := batch_idx * out_dim * in_dim;
		for i in 0..<out_dim {
			for j in 0..<in_dim {
				result_idx := result_start + i * in_dim + j;
				result.data[result_idx] = a_slice[i] * b_slice[j];
			}
		}
	}
	
	return result;
}

// Get a sub-matrix from a tensor at a specific batch index
// For a tensor with shape [batch_size, rows, cols], returns a matrix with shape [rows, cols]
tensor_get_sub_matrix :: proc(tensor: Tensor($T), batch_indices: []int, loc := #caller_location) -> Matrix(T) {
	assert(len(tensor.dims) >= 3, "Tensor must be at least 3D for sub-matrix extraction", loc);
	assert(len(batch_indices) == 1, "Currently only supports single batch index", loc);
	
	batch_idx := batch_indices[0];
	rows := tensor.dims[1];
	cols := tensor.dims[2];
	
	// Calculate the start index for this batch
	start_idx := batch_idx * rows * cols;
	end_idx := start_idx + rows * cols;
	
	// Create a matrix view of the tensor data for this batch
	return Matrix(T){
		rows = rows,
		columns = cols,
		data = tensor.data[start_idx:end_idx], // View into the tensor data
	};
}

// Get a sub-vector from a tensor at a specific batch index
// For a tensor with shape [batch_size, vector_length], returns a slice with shape [vector_length]
tensor_get_sub_vector :: proc(tensor: Tensor($T), batch_indices: []int, loc := #caller_location) -> []T {
	assert(len(tensor.dims) >= 2, "Tensor must be at least 2D for sub-vector extraction", loc);
	assert(len(batch_indices) == 1, "Currently only supports single batch index", loc);
	
	batch_idx := batch_indices[0];
	vector_length := tensor.dims[1];
	
	// Calculate the start and end indices for this batch
	start_idx := batch_idx * vector_length;
	end_idx := start_idx + vector_length;
	
	// Return a view into the tensor data for this batch
	return tensor.data[start_idx:end_idx];
}
