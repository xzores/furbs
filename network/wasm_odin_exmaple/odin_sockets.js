"use strict";
const sockets = new Map();
let nextHandle = 1;
function odinSetupWebSockets() {
    const socket_imports = {
        odin_env: {
            //Takes in the place to could be "ws://localhost:1234" or "wss://localhost:1234"
            ws_create: (target_str_ptr, target_str_len, onconnect_str_ptr, onconnect_str_len, onrecv_str_ptr, onrecv_str_len, onerror_str_ptr, onerror_str_len, onclose_str_ptr, onclose_str_len) => {
                if (!wasm || !memory)
                    throw new Error("WASM not ready");
                const target_bytes = new Uint8Array(memory.buffer, target_str_ptr, target_str_len);
                const target = new TextDecoder().decode(target_bytes);
                const onconnect_bytes = new Uint8Array(memory.buffer, onconnect_str_ptr, onconnect_str_len);
                const onconnect = new TextDecoder().decode(onconnect_bytes);
                const onrecv_bytes = new Uint8Array(memory.buffer, onrecv_str_ptr, onrecv_str_len);
                const onrecv = new TextDecoder().decode(onrecv_bytes);
                const onerror_bytes = new Uint8Array(memory.buffer, onerror_str_ptr, onerror_str_len);
                const onerror = new TextDecoder().decode(onerror_bytes);
                const onclose_bytes = new Uint8Array(memory.buffer, onclose_str_ptr, onclose_str_len);
                const onclose = new TextDecoder().decode(onclose_bytes);
                const handle = nextHandle++;
                let socket = new WebSocket(target);
                socket.binaryType = "arraybuffer";
                sockets.set(handle, socket);
                socket.onopen = () => {
                    const fn = wasm.instance.exports[onconnect];
                    if (typeof fn === "function") {
                        fn(handle);
                    }
                    else {
                        console.error("Could not find on-connect odin callback : ", onconnect);
                    }
                };
                socket.onmessage = (event) => {
                    const fn = wasm.instance.exports[onrecv];
                    if (typeof fn === "function") {
                        const alloc = wasm.instance.exports.alloc;
                        const free = wasm.instance.exports.free;
                        if (!alloc)
                            throw new Error("Odin does not export alloc");
                        if (!free)
                            throw new Error("Odin does not export free");
                        if (typeof event.data === "string") {
                            const encoder = new TextEncoder();
                            const encoded = encoder.encode(event.data); // Uint8Array
                            const len = encoded.length;
                            const ptr = alloc(len);
                            const mem = new Uint8Array(memory.buffer, ptr, len);
                            mem.set(encoded);
                            fn(handle, 0, ptr, len);
                        }
                        else if (event.data instanceof Blob) {
                            event.data.arrayBuffer().then(buffer => {
                                const data = new Uint8Array(buffer);
                                const ptr = alloc(data.length);
                                const mem = new Uint8Array(memory.buffer, ptr, data.length);
                                mem.set(data);
                                fn(handle, 1, ptr, data.length);
                            });
                        }
                        else if (event.data instanceof ArrayBuffer) {
                            const data = new Uint8Array(event.data);
                            const ptr = alloc(data.length);
                            const mem = new Uint8Array(memory.buffer, ptr, data.length);
                            mem.set(data);
                            fn(handle, 2, ptr, data.length); //Odin now owns the data? should it be like that?
                        }
                        else {
                            throw new Error("unhandled");
                        }
                    }
                    else {
                        console.error("Could not find on-message odin callback : ", onrecv);
                    }
                };
                socket.onerror = () => {
                    console.log("socket error!");
                    const fn = wasm.instance.exports[onerror];
                    if (typeof fn === "function") {
                        fn(handle);
                    }
                    else {
                        console.error("Could not find on-error odin callback : ", onerror);
                    }
                };
                socket.onclose = () => {
                    const fn = wasm.instance.exports[onclose];
                    if (typeof fn === "function") {
                        fn(handle);
                    }
                    else {
                        console.error("Could not find on-close odin callback : ", onclose);
                    }
                };
                return handle;
            },
            ws_send: (handle, kind, data_ptr, data_len) => {
                console.log("sending message!");
                let sock = sockets.get(handle);
                if (!sock) {
                    console.log("Invalid socket handle!");
                    throw new Error("Invalid socket handle");
                }
                const view = new Uint8Array(memory.buffer, data_ptr, data_len);
                if (kind === 0) { // text
                    const text = new TextDecoder().decode(view);
                    sock.send(text);
                }
                else if (kind === 1) { // blob
                    const blob = new Blob([view]);
                    sock.send(blob);
                }
                else if (kind === 2) { // arraybuffer
                    sock.send(view.buffer.slice(view.byteOffset, view.byteOffset + view.byteLength));
                }
                else {
                    throw new Error("Unknown kind: " + kind);
                }
            },
            ws_close: (handle) => {
                let sock = sockets.get(handle);
                if (!sock) {
                    throw new Error("Invalid socket handle");
                }
                sock.close();
            },
        }
    };
    return socket_imports;
}
