package system;

import "core:time"
import "core:fmt"
import "core:math"
import "core:mem"
import "core:strings"
import "core:unicode/utf8"
import "core:unicode/utf16"
import win32 "core:sys/windows"

import "base:intrinsics"

//Ex: file, ok := system.user_pick_file({{"Text files", "*.txt"}, {"Image files", "*.png"}});
@require_results
user_pick_file :: proc (file_types : [][2]string, initial_directory : Maybe(string) = nil, loc := #caller_location) -> (filepath : string, was_picked : bool) {
	
	res := [512]u16{}; // Buffer for the file name
	type_w := make([dynamic]u16);
	defer delete(type_w);
	
	for ft_arr in file_types {
	
		for ft in ft_arr {
			sub_s := make([]u16, strings.rune_count(ft) * 2);
			defer delete(sub_s);
			count := utf16.encode_string(sub_s, ft);
			
			for i in 0..<count {
				append(&type_w, sub_s[i]);
			}
			append(&type_w, 0);	//Escape char
		}
	}
	append(&type_w, 0);	//Escape char
	
	init_dir_pointer : ^u16 = nil;
	
	if dir, ok := initial_directory.?; ok {
		init_dir := make([dynamic]u16); //Will at max be twice the size.
		defer delete(init_dir);
		
		for r in dir {
			r1, r2 := utf16.encode_surrogate_pair(r);
			if r1 != 0 {
				append(&init_dir, cast(u16)r1);
			}
			if r2 != 0 {
				append(&init_dir, cast(u16)r2);
			}
		}
		
		append(&init_dir, 0);
		
		init_dir_pointer = &init_dir[0];
		fmt.printf("init_dir : &v\n", init_dir);
		{
			panic("TODO, not working");
		}
	}
	
	// Initialize the structure for file dialog
	ofn : win32.OPENFILENAMEW = {
		lStructSize 		= size_of(win32.OPENFILENAMEW),
		hwndOwner			= {},
		hInstance			= {},
		lpstrFilter 		= &type_w[0],
		lpstrCustomFilter 	= {},
		nMaxCustFilter 		= {},
		nFilterIndex		= 1,
		lpstrFile         	= &res[0],
		nMaxFile			= len(res),
		lpstrFileTitle    	= {},
		nMaxFileTitle    	= {},
		lpstrInitialDir		= init_dir_pointer,
		lpstrTitle        	= {},
		Flags             	= win32.OFN_PATHMUSTEXIST | win32.OFN_FILEMUSTEXIST,
		nFileOffset			= {},
		nFileExtension		= {},
		lpstrDefExt			= {},
		lCustData			= {},
		lpfnHook 			= {},
		lpTemplateName		= {},
		pvReserved	 		= {},
		dwReserved			= {},
		FlagsEx				= {},
	};
	
	was_selected := win32.GetOpenFileNameW(&ofn);
	
	if was_selected {
		was_picked = true;
	} else {
		was_picked = false;
	}
	
	b_res : [512]byte;
	b_count := utf16.decode_to_utf8(b_res[:], res[:]);
	
	return strings.clone_from_bytes(b_res[:b_count], loc = loc), was_picked;
}


user_pick_files :: proc (file_types : []string) -> (filepath : []string, was_picked : bool) {
	panic("TODO")
}


