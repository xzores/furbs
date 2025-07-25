package utils;

import "core:fmt"
import "core:mem"
import "base:runtime"
import "core:encoding/json"
import "core:strings"
import "core:os"
import "core:log"
import "core:path/filepath"


// ensure_path ensures all directories in 'path' exist, creating them if needed.
// It handles paths ending in either a directory or a filename.
ensure_path :: proc(path: string) -> (err: os.Error) {
    // Normalize the path (removes redundant separators, etc.)
    path, alc_err := filepath.clean(path)           // normalizes OS separators:contentReference[oaicite:6]{index=6}
	assert(alc_err == nil);
	defer delete(path);

    // If the path has a file extension, treat it as a filename
    if filepath.ext(path) != "" {            // ext(path) returns the file extension or "":contentReference[oaicite:7]{index=7}
        path, _ = filepath.split(path)       // splits off the last element (dir, file):contentReference[oaicite:8]{index=8}
    }
    // If nothing remains, there is no directory to create
    if path == "" || path == "." {
        return 0
    }

    // Recursively ensure parent directories exist
    parent := filepath.dir(path)            // get parent directory:contentReference[oaicite:9]{index=9}
	defer delete(parent);
    if parent != "" && parent != path {
        err = ensure_path(parent)
        if err != 0 {
            return err
        }
    }
	
    // Create the directory itself
    err = os.make_directory(path)           // creates the directory:contentReference[oaicite:10]{index=10}
    // If it already exists, ignore the error (mimic mkdir -p)
    if err != 0 && err != os.ERROR_ALREADY_EXISTS {
        return err
    }
    return 0
}



load_all_in_dir_as_txt :: proc(directory_path : string, extension : string, include_extension : bool = false, alloc := context.allocator) -> (res : map[string]string) {

	context.allocator = alloc;

	//Open Directory
	dir, _ := os.open(directory_path);
	defer os.close(dir);
	
	//Get files from directory
	files_info, err := os.read_dir(dir, -1);
	defer os.file_info_slice_delete(files_info);

	full_ex := fmt.tprintf(".%s", extension);
	
	res = make(map[string]string);
	
	for fi in files_info {
		
		if !strings.has_suffix(fi.name, full_ex) {
			continue;
		}

		data, ok := os.read_entire_file_from_filename(fi.fullpath);
		
		if ok {
			name : string;
			was_allocation : bool;

			if include_extension {
				name = fmt.aprintf(fi.name);
			}
			else {
				name, was_allocation = strings.replace_all(fi.name, full_ex, "");
				assert(was_allocation);
			}
			res[name] = strings.clone_from_bytes(data);
		}
		else {
			fmt.printf("Could not %s info : %v", extension, data);
		}

		delete(data); //fi.name is deleted here.
	}

	return;
} 

load_all_in_dir_as_json :: proc($T : typeid, directory_path : string, extension : string, include_extension : bool = false, resave : bool = false, specification := json.DEFAULT_SPECIFICATION, allocator := context.allocator) -> (res : map[string]T, e : os.Error) {
	
	context.allocator = allocator;
	
	//Open Directory
	dir, dir_err := os.open(directory_path);
	defer os.close(dir);
	
	if dir_err != nil {
		return {}, dir_err;
	}
	
	//Get files from directory
	files_info, err := os.read_dir(dir, -1);
	defer os.file_info_slice_delete(files_info);
	
	if err != nil {
		return {}, err;
	}

	full_ex := fmt.tprintf(".%s", extension);

	res = make(map[string]T);

	for fi in files_info {
		
		if !strings.has_suffix(fi.name, full_ex) {
			//fmt.printf("Skipping %v, '%v', does not have suffix '%v'\n", fi.name, fi.name, full_ex);
			continue;
		}

		data, ok := os.read_entire_file_from_filename(fi.fullpath);
		
		if ok {
			loaded_object : T;
			err := json.unmarshal(data, &loaded_object, specification);
			
			fmt.assertf(err == nil, "Could not load %s : %v", extension, fi.name);
			
			name : string;
			was_allocation : bool;

			if include_extension {
				name = fmt.aprintf(fi.name);
			}
			else {
				name, was_allocation = strings.replace_all(fi.name, full_ex, "");
				assert(was_allocation);
			}
			
			res[name] = loaded_object;

			fmt.printf("Loaded %s : %s\n", extension, fi.name);

			//Re save the files, to correct any ivalid/missing entires.
			if resave {
				data, err := json.marshal(loaded_object, {pretty = true});
				defer delete(data);
				
				assert(err == nil);
				file_name := fmt.tprintf("%s/%s.%s", directory_path, name, extension);
				os.write_entire_file(file_name, data);
			}
		}
		else {
			fmt.printf("Could not %s info : %v", extension, data);
		}

		delete(data); //fi.name is deleted here.
	}

	return;
}

ensure_folder_exists :: proc(folder_path : string) -> (err: os.Errno) {

	// Check if the folder exists
	if !os.exists(folder_path) {
		// Folder does not exist, so create it
		err = os.make_directory(folder_path)
	}
	return;
}

// Recursive function to delete directory contents
delete_directory_contents :: proc(dir_path: string, loc := #caller_location) -> (success : bool) {
	
	dir_handle, dir_err := os.open(dir_path);
	if dir_err != 0 {
		log.logf(.Error, "Error opening directory : %v", dir_err, location = loc);
		return false;
	}
	
	files, err := os.read_dir(dir_handle, 0); //get all files
	defer os.file_info_slice_delete(files);
	os.close(dir_handle);
	
	if err != 0 {
		log.logf(.Error, "Error reading directory : %v", err, location = loc);
		return false;
	}
	
	for file in files {
		
		full_path := fmt.aprintf("%v/%v", dir_path, file.name);
		defer delete(full_path);
		
		if file.is_dir {
			if file.name != "." && file.name != ".." {
				if !delete_directory_contents(full_path) {
					return false
				}
				if os.remove_directory(full_path) != 0 {
					log.logf(.Error, "Error removing directory: %v", full_path, location = loc)
					return false
				}
			}
		} else {
			if os.remove(full_path) != 0 {
				log.logf(.Error, "Error removing file : %v", full_path, location = loc)
				return false
			}
		}
	}
	
	return true
}

// Function to delete a directory and its contents
remove_directory_recursive :: proc(dir_path: string, loc := #caller_location) -> (success : bool) {
	
	if !delete_directory_contents(dir_path, loc) {
		return false;
	}
	if os.remove_directory(dir_path) != 0 {
		log.logf(.Error, "Error removing directory:", dir_path, location = loc);
		return false;
	}
	
	return true;
}

copy_file :: proc (from : string, to : string) -> (success : bool) {
	
	data, suc := os.read_entire_file(fmt.tprintf(from));
	defer delete(data);
	
	if !suc {
		return false;
	}
	
	if !os.write_entire_file(to, data) {
		return false;
	}
	
	return true;
}