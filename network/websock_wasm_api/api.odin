#+build js wasm32, js wasm64p32
package furbs_network_wasm_client_api;

//This should only be included by a client running in a browser

foreign import "odin_env"

ws_socket_handle :: distinct i32;
Data_kind :: enum { 
	text = 0,
	blob = 1,
	array_buffer = 2,
}

sock_open_fn :: #type proc "c" (sock : ws_socket_handle)
sock_recv_fn :: #type proc "c" (sock : ws_socket_handle, kind : Data_kind, data : [^]u8, length : int)
sock_error_fn :: #type proc "c" (sock : ws_socket_handle)
sock_close_fn :: #type proc "c" (sock : ws_socket_handle)

//target like as in endpoint, the callbacks are string for the functions which odin should export.
@(require_results)
create :: proc (target : string, connect_cb : string, recv_cb : string, error_cb : string, close_cb : string) -> ws_socket_handle {

	return ws_create(raw_data(target), len(target), raw_data(connect_cb), len(connect_cb),
		raw_data(recv_cb), len(recv_cb), raw_data(error_cb), len(error_cb), raw_data(close_cb), len(close_cb));
}

send :: proc (h : ws_socket_handle, kind : Data_kind, data : []u8) {
	ws_send(h, kind, raw_data(data), len(data));
}

close :: proc (h : ws_socket_handle) {
	ws_close(h);
}

@(default_calling_convention="contextless")
foreign odin_env {
	ws_create    :: proc(target_str_ptr: rawptr, target_str_len: int, onconnect_str_ptr: rawptr, onconnect_str_len: int, onrecv_str_ptr: rawptr, onrecv_str_len: int,
					onerror_str_ptr: rawptr, onerror_str_len: int, onclose_str_ptr: rawptr, onclose_str_len: int) -> ws_socket_handle ---
	ws_send     :: proc(h : ws_socket_handle, kind : Data_kind, data : rawptr, len : int) ---
	ws_close    :: proc(h : ws_socket_handle) ---
}

