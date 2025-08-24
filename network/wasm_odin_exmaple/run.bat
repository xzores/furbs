@echo off
REM NOTE: changing this requires changing the same values in the `web/index.html`.
set INITIAL_MEMORY_PAGES=2000
set MAX_MEMORY_PAGES=65536

set PAGE_SIZE=65536
set /a INITIAL_HEAP_BYTES=64 * 65536
set /a INITIAL_MEMORY_BYTES=128 * 65536
set /a MAX_MEMORY_BYTES=32767 * 65536
 
set LINKER_FLAGS=--initial-memory=%INITIAL_MEMORY_BYTES% --max-memory=%MAX_MEMORY_BYTES% --initial-heap=%INITIAL_HEAP_BYTES%
call odin build . -target:js_wasm32 -out:main.wasm -debug -extra-linker-flags:"%LINKER_FLAGS%" && ^
tsc && ^
python -m http.server 80
