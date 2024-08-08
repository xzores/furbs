package utils;

ENABLE_HOT_RELOAD :: #config(ENABLE_HOT_RELOAD, ODIN_DEBUG);

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:time"
import "core:c/libc"

@(require) import "core:dynlib"


when ODIN_OS == .Windows {
	DLL_EXT :: "dll"
} else when ODIN_OS == .Darwin {
	DLL_EXT :: "dynlib"
} else {
	DLL_EXT :: "so"
}

//TODO look at -obfuscate-source-code-locations for release builds.
//Because we cannot read the dll from the place where the compiler uses the file, there must be 2 folders.
//The src folder is where the compiler places the result, the dst folder is where the result is copied to and then read from.
compile_dll :: proc (src_path, filename, dll_src_folder, defines : string) {
	
	debug_enable : string = "";
	when ODIN_DEBUG {
		debug_enable = "-debug";
	}
	
	opti_option : string = "";
	when ODIN_OPTIMIZATION_MODE == .Speed {
		opti_option = "-o:speed";
	}
	else when ODIN_OPTIMIZATION_MODE == .Size {
		opti_option = "-o:size";
	}
	
	assert_enable : string = "";
	when ODIN_DISABLE_ASSERT {
		assert_enable = "-disable-assert";
	}
	
	//might rename the dll to match ODIN_BUILD_PROJECT_NAME.
	
	_ = ensure_folder_exists(dll_src_folder);
	
	{ //call odin
		
		command := fmt.tprintf("odin build ./%v -show-timings -no-entry-point -out:%s/%s.%s -pdb-name:%s/%s.pdb -build-mode:shared -vet-tabs %s %s %s %s",
								 src_path, dll_src_folder, filename, DLL_EXT, dll_src_folder, filename, debug_enable, opti_option, assert_enable, defines);
		
		fmt.printf(DARK_GREY); //Changes the terminal color
		fmt.printf("Calling odin with arguments : %v\n", command);
		libc.system(fmt.ctprintf(command));
		fmt.printf(RESET);
		log.log(.Info, "Called odin compiller");
	}
}

dll_pre_fix : bool = false;
//call this every frame, it will only update if it needs to.
load_api_calls :: proc($Calls : typeid, filename, dll_src_folder, dll_dst_folder : string, last_modification_time : os.File_Time,
						 symbol_prefix := "", dynlib_member_name := "__handle") -> (api: Calls, new_modification_time : os.File_Time, success: bool) {
	
	game_src_dll_name := fmt.tprintf("%v/%v.%v", dll_src_folder, filename, DLL_EXT);
	
	mod_time, mod_time_error := os.last_write_time_by_name(game_src_dll_name);
	
	_ = ensure_folder_exists(dll_dst_folder);
	
	if mod_time_error != os.ERROR_NONE {
		log.logf(.Error, "Failed getting last write time of %v, error code : %v", game_src_dll_name, mod_time_error);
		return {}, last_modification_time, false;
	}
	
	if mod_time == last_modification_time {
		return {}, mod_time, false;
	}
	
	pre_fix : string = "_";
	
	if dll_pre_fix {
		pre_fix = "__";
	}
	
	game_dst_dll_name := fmt.tprintf("%v/%v%v.%v", dll_dst_folder, pre_fix, filename, DLL_EXT);
	when ODIN_OS == .Windows {
		game_dst_pdb_name := fmt.tprintf("%v/%v.pdb", dll_dst_folder, filename);
		game_src_pdb_name := fmt.tprintf("%v/%v.pdb", dll_src_folder, filename);
	}
	
	{ //Copy the DLL and PDB file
		if copy_file(game_src_dll_name, game_dst_dll_name) {
			log.logf(.Info, "Successfully copied DLL file to %v", game_dst_dll_name);
		}
		else {
			log.logf(.Error, "Failed to copy DLL file to %v", game_dst_dll_name);
			return {}, mod_time, false;
		}
		
		when ODIN_OS == .Windows {
			os.remove(game_dst_pdb_name); //VS code will lock it otherwise.
			if copy_file(game_src_pdb_name, game_dst_pdb_name) {
				log.log(.Info, "Successfully copied PDB file");
			}
			else {
				log.logf(.Error, "Failed to copy PDB file : %v", game_src_pdb_name);
			}
		}
		
		dll_pre_fix = !dll_pre_fix;
	}
	
	//Load the symbols from the DLL (This is smart)
	_, ok := dynlib.initialize_symbols(&api, game_dst_dll_name, symbol_prefix, dynlib_member_name)
	if !ok {
		log.logf(.Error, "Failed initializing symbols : %v", dynlib.last_error());
		return {}, mod_time, false;
	}
	else {
		log.log(.Info, "Loaded DLL successfully");
	}
	
	return api, mod_time, true;
}

//This requires the __handle member, might redo later
unload_api_calls :: proc(api: ^$Calls) {
	
	log.logf(.Info, "Unloading api.__handle : %v", api.__handle);
	if api.__handle != nil {
		if !dynlib.unload_library(api.__handle) {
			log.logf(.Error, "Failed unloading lib: %v", dynlib.last_error())
		}
		else {
			log.logf(.Info, "Unloaded lib");
		}
	}
}