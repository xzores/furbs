package utils;

import "core:math"
import "core:os"
import "core:log"
import "core:fmt"
import "core:strings"
import "core:time"
import "core:path/filepath"

//Can be used to watch files, if they change it will say so see update_file_watcher
//This is meant for debug builds when you have something which might need to recompile on file change
File_watcher :: struct {
	files_to_watch : [dynamic]string,
	last_update : time.Time,
}

make_file_watcher :: proc () -> File_watcher {
	return File_watcher{make([dynamic]string), time.now()};
}

//Adds all exsisting files to the watcher, new files will not trigger an update.
file_watcher_add_file :: proc (fw : ^File_watcher, file_path : string) -> (ok : bool) {

	fs, err := os.stat(file_path);
	if err != nil {
		log.errorf("failed to see file %v (%v)", filepath.abs(file_path));
		return false;
	}

	if fs.modification_time._nsec > fw.last_update._nsec {
		fw.last_update = fs.modification_time;
	}

	append(&fw.files_to_watch, strings.clone(file_path));
	return true;
}

file_watcher_add_folder :: proc (fw : ^File_watcher, dir_path : string, loc := #caller_location) -> (ok : bool) {

	if !os.is_dir(dir_path) {
		log.errorf("not a directory at %v (%v)", filepath.abs(dir_path));
		return false;
	}

	dir_handle, dir_err := os.open(dir_path);
	if dir_err != nil {
		log.errorf("Failed to load %v", dir_path);
		return false;
	}

	file_infos, fi_err := os.read_dir(dir_handle, -1);
	defer os.file_info_slice_delete(file_infos);
	
	for fi in file_infos {
		if fi.is_dir {
			file_watcher_add_folder(fw, fi.fullpath);
		}
		else {
			assert(file_watcher_add_file(fw, fi.fullpath));
		}
	}

	return true;
}

update_file_watcher :: proc (fw : ^File_watcher) -> (any_change : bool) {

	any_change = false;

	for file_path in fw.files_to_watch {
		fs, err := os.stat(file_path);
		if err != nil {
			//likely the file is removed, so we should not watch it anymore or we could just ignore it?
			continue;
		}

		if fs.modification_time._nsec > fw.last_update._nsec {
			any_change = true;
			fw.last_update = fs.modification_time;
		}
	}

	return 
}

destroy_file_watcher :: proc (fw : File_watcher) {
	
	for file_path in fw.files_to_watch {
		delete(file_path);
	}
	delete(fw.files_to_watch);
}