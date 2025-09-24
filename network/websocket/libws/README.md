# Odin-wsServer

Odin bindings for the [wsServer](https://github.com/Theldus/wsServer) C WebSocket library.

## Overview

**Odin-wsServer** provides bindings to the lightweight and efficient [wsServer](https://github.com/Theldus/wsServer) WebSocket server library, enabling seamless WebSocket support in Odin applications. This library allows Odin developers to create WebSocket servers with minimal overhead and strong performance.

## Features

- Lightweight and efficient WebSocket server implementation.
- Direct bindings to `wsServer`, maintaining C-level performance.
- Supports multiple concurrent connections.
- Easy-to-use API for handling WebSocket messages.

## Installation

To use **odin-wsServer**, ensure that you have a copy of the static `wsServer` library (`libws.a`) in your working directory.

Follow these instructions to compile the library: [wsServer CMake Instructions](https://github.com/Theldus/wsServer/tree/master?tab=readme-ov-file#cmake)

## Usage

### Example WebSocket Server

- [Echo Server](./examples/echo/echo.odin) - `odin run examples/echo`
- [Chat Server](./examples/chat/chat.odin) - `odin run examples/chat`
- [Sample Server](./examples/complete/complete.odin) - `odin run examples/complete`

### Sample

<details>
<summary>Click to expand code sample</summary>

```odin
package complete

import ws "../.."
import "core:fmt"
import "core:time"

PORT :: 8080

on_open :: proc(client: ws.Client_Connection) {
	client_addr := ws.getaddress(client)
	client_port := ws.getport(client)

	fmt.printf("Connection opened, addr: %s, port: %s\n", client_addr, client_port)
	ws.send_text_frame(client, "you are now connected!")
}


on_close :: proc(client: ws.Client_Connection) {
	client_addr := ws.getaddress(client)
	fmt.printf("Connection closed, addr: %s\n", client_addr)
}

on_message :: proc(client: ws.Client_Connection, msg: []u8, type: ws.Frame_Type) {
	client_addr := ws.getaddress(client)

	message := "<not parsed>"
	if type == .Text {
		message = string(msg)
	}

	fmt.printf(
		"I received a message '%s', size %d, type %s from client %s\n",
		message,
		len(msg),
		type,
		client_addr,
	)


	ws.send_text_frame(client, "hello")
	time.sleep(2 * time.Second)
	ws.send_text_frame(client, "world")
	time.sleep(2 * time.Second)

	out_msg := fmt.tprintf("you sent a %s message", type)

	ws.send_text_frame(client, out_msg)
	time.sleep(2 * time.Second)

	ws.send_text_frame(client, "closing connection in 2 seconds")
	time.sleep(2 * time.Second)

	ws.send_text_frame(client, "bye!")
	ws.close_client(client)
}

main :: proc() {
	server := ws.Server {
		host = "0.0.0.0",
		port = PORT,
		timeout_ms = 1000,
		evs = {onmessage = on_message, onclose = on_close, onopen = on_open},
	}

	fmt.printfln("Listening on port %d", PORT)
	ws.listen(&server)
	fmt.printfln("Socket closed")
}
```
</details>

## API Documentation

For API details, I recommend checking the [ws.odin](./ws.odin) file and reading the source code of the underlying library.

### Structures

#### `Server`
Represents the WebSocket server configuration.

```odin
Server :: struct {
    host:        string, // Server hostname or IP
    port:        u16,    // Port to listen on
    thread_loop: bool,   // Run accept loop in a separate thread
    timeout_ms:  u32,    // Connection timeout in milliseconds
    evs:         Events, // Event handlers
    ctx:         rawptr, // User-defined context
}
```

### Enumerations

#### `Connection_State`
Represents the state of a WebSocket connection.

```odin
Connection_State :: enum (c.int) {
    Invalid_Client = -1,
    Connecting     = 0,
    Open           = 1,
    Closing        = 2,
    Closed         = 3,
}
```

#### `Frame_Type`
Defines the different WebSocket frame types.

```odin
Frame_Type :: enum (c.int) {
    Continuation = 0,
    Text         = 1,
    Binary       = 2,
    Close        = 8,
    Ping         = 9,
    Pong         = 10,
}
```

### Functions

#### `listen`
Starts the WebSocket server and listens for connections.

```odin
listen :: proc(server: ^Server) -> int
```

#### `send_frame`
Sends a WebSocket frame to a specific client.

```odin
send_frame :: proc(client: Client_Connection, data: []byte, type: Frame_Type) -> int
```

#### `send_frame_broadcast`
Broadcasts a WebSocket frame to all clients on a specified port.

```odin
send_frame_broadcast :: proc(port: u16, data: []byte, type: Frame_Type) -> int
```

#### `send_text_frame`
Sends a text message frame to a specific client.

```odin
send_text_frame :: proc(client: Client_Connection, msg: string) -> int
```

#### `send_text_frame_broadcast`
Broadcasts a text message frame to all clients on a specified port.

```odin
send_text_frame_broadcast :: proc(port: u16, msg: string) -> int
```

#### `send_binary_frame`
Sends a binary data frame to a specific client.

```odin
send_binary_frame :: proc(client: Client_Connection, data: []byte) -> int
```

#### `send_binary_frame_broadcast`
Broadcasts a binary data frame to all clients on a specified port.

```odin
send_binary_frame_broadcast :: proc(port: u16, data: []byte) -> int
```

#### `get_global_context`
Retrieves the user-defined context from the `Server` struct.

```odin
get_global_context :: proc(client: Client_Connection, $T: typeid) -> ^T
```

#### `get_connection_context`
Retrieves the user-defined context of the current connection.

**TODO:** Create a wrapper function that auto casts.

```odin
get_connection_context :: proc(client: Client_Connection) -> rawptr
```

#### `set_connection_context`
Sets the user-defined context of the current connection.

```odin
set_connection_context :: proc(client: Client_Connection, ptr: rawptr)
```

### Event Handling

Events can be set in the `Server` struct to handle client interactions.

**Note:** The temporary allocator is always freed after each event call. Feel free to allocate and not free.

```odin
Events :: struct {
    onopen:    proc(client: Client_Connection),
    onclose:   proc(client: Client_Connection),
    onmessage: proc(client: Client_Connection, msg: []u8, type: Frame_Type),
}
```

### Example Usage

```odin
server := Server{
    host = "0.0.0.0",
    port = 8080,
    thread_loop = false,
    timeout_ms = 5000,
    evs = Events{
        onopen = proc(client: Client_Connection) {
            fmt.println("Client connected")
        },
        onclose = proc(client: Client_Connection) {
            fmt.println("Client disconnected")
        },
        onmessage = proc(client: Client_Connection, msg: []u8, type: Frame_Type) {
            fmt.println("Received message: ", string(msg))
        },
    },
}
listen(&server)
```

## Contributing

Contributions are welcome! Feel free to submit issues and pull requests to improve this library.

## License

This project is licensed under the MIT License. See [LICENSE](LICENSE) for details.

---

For more details on `wsServer`, visit the official repository: [Theldus/wsServer](https://github.com/Theldus/wsServer).
