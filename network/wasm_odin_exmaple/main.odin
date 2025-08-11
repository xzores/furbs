package main

import "base:runtime"
import "core:fmt"
import "core:time"
import "core:mem"
import "core:strings"
import "core:sys/wasm/js"

import websock "../websock_wasm_api"

default_context : runtime.Context;

// Export functions for WebAssembly
@(export)
add :: proc "c" (a, b: i32) -> i32 {
	return a + b
}

@(export)
multiply :: proc "c" (a, b: i32) -> i32 {
	return a * b
}

@(export)
fibonacci :: proc "c" (n: i32) -> i32 {
	if n <= 1 {
		return n
	}
	return fibonacci(n - 1) + fibonacci(n - 2)
}

@(export)
my_func :: proc "c" () -> i32 {
	context = default_context
	my_int := new(i32);
	my_int^ = 24;

	return my_int^;
}

@(export)
test_alloc :: proc "c" () -> i32 {
	context = default_context
	b := new([1024]i32);
	b[0] = 123;
	return b[0];
}

@(export)
alloc :: proc "c" (size : int) -> rawptr {
	context = default_context;
	
	ptr, err := mem.alloc(size);
 	fmt.assertf(err == nil, "error on alloc : %v", err);
	return ptr;
}

@(export)
free :: proc "c" (ptr : rawptr) {
	context = default_context
	
	err := mem.free(ptr);
	fmt.assertf(err == nil, "error on free : %v", err);
}

@(export)
sock_open : websock.sock_open_fn : proc "c" (sock : websock.ws_socket_handle) {
	context = default_context
	fmt.printf("odin connected\n");
	msg : string = "hello world"
	
	websock.send(sock, .array_buffer, transmute([]u8)msg);
	//websock.close(sock);	
}

@(export)
sock_recv : websock.sock_recv_fn : proc "c" (sock : websock.ws_socket_handle, kind : websock.Data_kind, data : [^]u8, length : int) {
	context = default_context

	switch kind {
		case .text: {
			msg : string = transmute(string)runtime.Raw_String{data, length}
			fmt.printf("odin recived text : %v\n", msg);
			//panic("did not expect text");
		}
		case .blob: {
			fmt.printf("odin recived blob\n");
		}
		case .array_buffer: {
			fmt.printf("odin recived array_buffer\n");
		}
	}
}

@(export)
sock_error : websock.sock_error_fn : proc "c" (sock : websock.ws_socket_handle) {
	context = default_context
	fmt.eprintf("Socket error\n")
}

@(export)
sock_close : websock.sock_close_fn : proc "c" (sock : websock.ws_socket_handle) {
	context = default_context
	fmt.println("Closing socket\n")
}

// Main function (not exported to WASM)
main :: proc () {
	default_context = context;
	fmt.println("Odin WebAssembly Example 1")
	test_alloc();
	fmt.println("Odin WebAssembly Example 2")
	my_func();
	fmt.println("Odin WebAssembly Example 3")

	sock := websock.create("ws://127.0.0.1:8080", "sock_open", "sock_recv", "sock_error", "sock_close");
	fmt.println("Odin fininshed")
}
