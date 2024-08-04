package utils;

import odin_libc "core:c/libc"

when ODIN_OS == .Windows {
	foreign import libc "system:libucrt.lib"
} else when ODIN_OS == .Darwin {
	foreign import libc "system:System.framework"
} else {
	foreign import libc "system:c"
}

FILE    :: odin_libc.FILE;

@(default_calling_convention="c")
foreign libc {
	perror :: proc(str: cstring) ---
}

when ODIN_OS == .Windows {
	popen :: _popen;
	pclose :: _pclose;

	@(default_calling_convention="c")
	foreign libc {
		_popen  :: proc(command : cstring, mode : cstring) -> ^FILE ---
		_pclose :: proc(stream: ^FILE) -> int ---
	}
}
else {
	@(default_calling_convention="c")
	foreign libc {
		popen  :: proc(command : cstring, mode : cstring) -> ^FILE ---
		pclose :: proc(stream: ^FILE) -> int ---
	}
}