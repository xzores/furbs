package utils;

import "base:intrinsics"

import "core:fmt"

Matrix :: struct(T : typeid) where intrinsics.type_is_numeric(T) {
    // Matrix dimensions
    rows : int,
    cols : int,
    data : []T, // Flattened 2D matrix
}

matrix_make :: proc (rows : int, cols : int, $t : typeid) -> Matrix(t) {
	return Matrix(t){rows, cols, make([]t, rows * cols)};
}

matrix_destroy :: proc (m : Matrix($T)) {
	delete(m.data);
}

matrix_mul :: proc(A, B : Matrix($T), loc := #caller_location) -> Matrix(T) {
    // Ensure the matrices can be multiplied (A.cols == B.rows)
    if A.cols != B.rows {
        panic("Matrix dimensions do not align for multiplication.");
    }

    // Initialize result matrix
    result := Matrix(T) {
        rows = A.rows,
        cols = B.cols,
        data = make([]T, A.rows * B.cols, loc = loc), // Flattened 2D matrix with zeros, as Odin is zero-init
    };

    // Perform matrix multiplication
    for i in 0 ..< A.rows {
        for j in 0 ..< B.cols {
            sum : T;
            
            for k in 0 ..< A.cols {
                // Access elements in flattened arrays
                a_elem := A.data[i * A.cols + k];
                b_elem := B.data[k * B.cols + j];
                sum += a_elem * b_elem;
            }
            result.data[i * B.cols + j] = sum;
        }
    }

    return result;
}

matrix_vec_mul :: proc(A : Matrix($T), B : []T, loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
    // Ensure the matrix and vector can be multiplied (A.cols == length(B))
    if A.cols != len(B) {
        fmt.panicf("Matrix and vector dimensions do not align for multiplication, Matrix : (%v, %v). The vector has length %v and the matrix has %v columbs", A.rows, A.cols, len(B), A.cols);
    }

    // Initialize result vector
    result := make([]T, A.rows, loc = loc);

    // Perform matrix-vector multiplication
    for i in 0 ..< A.rows {
        sum : T;
        
        for j in 0 ..< A.cols {
            // Access elements in flattened arrays
            a_elem := A.data[i * A.cols + j];
            b_elem := B[j];
            sum += a_elem * b_elem;
        }
        result[i] = sum;
    }

    return result;
}

vec_matrix_mul :: proc(B : []$T, A : Matrix(T), loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
    // Ensure the vector and matrix can be multiplied (len(B) == A.rows)
    if len(B) != A.rows {
        fmt.panicf("Vector and matrix dimensions do not align for multiplication, Matrix : (%v, %v). The vector has length %v and the matrix has %v rows", A.rows, A.cols, len(B), A.rows);
    }

    // Initialize result vector
    result := make([]T, A.cols, loc);

    // Perform vector-matrix multiplication
    for j in 0 ..< A.cols {
        sum : T;
        
        for i in 0 ..< A.rows {
            // Access elements in flattened arrays
            b_elem := B[i];
            a_elem := A.data[i * A.cols + j];
            sum += b_elem * a_elem;
        }
        result[j] = sum;
    }

    return result;
}

//This multiplies a columb vector with a row vector, the result from a jx1 and 1xi vector is a jxi matrix. 
vec_columb_vec_row_mul :: proc(A, B : []$T, loc := #caller_location) -> Matrix(T) where intrinsics.type_is_numeric(T) {
    // Ensure both vectors are non-empty
    if len(A) == 0 || len(B) == 0 {
        panic("Vectors must be non-empty for multiplication.");
    }

    // Initialize result matrix
    result := Matrix(T) {
        rows = len(A),
        cols = len(B),
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

//This will first transpose the matrix a then multiply with the vector.
matrix_transposed_vec_mul :: proc(col_vec : Matrix($T), row_vec : []T, loc := #caller_location) -> []T where intrinsics.type_is_numeric(T) {
	A := col_vec; B := row_vec;
	
    // Ensure the matrix and vector can be multiplied (A.rows == len(B) after transpose)
    if A.rows != len(B) {
        fmt.panicf("Matrix and vector dimensions do not align for multiplication after transpose, Matrix: (%v, %v). The vector has length %v and the matrix has %v rows", A.rows, A.cols, len(B), A.rows);
    }

    // Initialize result vector
    result := make([]T, A.cols, loc = loc);  // After transpose, we have A.cols rows

    // Perform transposed matrix-vector multiplication
    for j in 0 ..< A.cols { // Iterate over what will be rows after transpose
        sum : T;

        for i in 0 ..< A.rows { // Iterate over what will be columns after transpose
            // Access elements in flattened arrays as if the matrix were transposed
            a_elem := A.data[i * A.cols + j];
            b_elem := B[i];
            sum += a_elem * b_elem;
        }
        result[j] = sum;  // Result has A.cols elements (since A^T has A.cols rows)
    }

    return result;
}



mul :: proc {matrix_mul, matrix_vec_mul, vec_matrix_mul};
