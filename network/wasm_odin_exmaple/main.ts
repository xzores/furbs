let intSize = 4; //for 32 bit intSize=4 for 64 bit intSize = 8

// Manually configure memory
var memory : WebAssembly.Memory;
let wasm : WebAssembly.WebAssemblyInstantiatedSource;

async function run_main () { 
	let wasm_memory_interface = new odin.WasmMemoryInterface();
	wasm_memory_interface.setIntSize(intSize);

	let socket_imports = odinSetupWebSockets(); //here
	let odin_imports = odin.setupDefaultImports(wasm_memory_interface, null, null);
	let exports : WebAssembly.Exports;

	const imports : WebAssembly.Imports = {
		odin_env: {
			...odin_imports.odin_env,
			...socket_imports.odin_env,
		},
		odin_dom: {
			...odin_imports.odin_dom,
		},
		env: {},
	};

	//const response = await fetch("main.wasm");
	//const file = await response.arrayBuffer();
	wasm = await WebAssembly.instantiateStreaming(fetch("main.wasm"), imports);

	exports = wasm.instance.exports;
	wasm_memory_interface.setExports(exports);

	for (const key in wasm.instance.exports) {
		const item = wasm.instance.exports[key];
		if (typeof item === "function" && !key.startsWith("_")) {
			console.log("Function:", key);
			(globalThis as any)[key] = item;
		}
	}

	if (exports.memory instanceof WebAssembly.Memory) {
		if (wasm_memory_interface.memory) {
			console.warn("WASM module exports memory, but `runWasm` was given an interface with existing memory too");
		}

		memory = exports.memory
		wasm_memory_interface.setMemory(memory);
		console.log("memory byte length:", memory.buffer);

		(exports._start as Function)();
		
		window.addEventListener("beforeunload", (event) => {
			(exports._end as Function)();
		});
	}
}

run_main();