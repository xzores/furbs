package utils;

import "core:fmt"
import "core:mem"
import "core:runtime"
import "core:encoding/json"
import "core:strings"
import "core:os"

load_all_as_txt :: proc(directory_path : string, extension : string, include_extension : bool = false, alloc := context.allocator) -> (res : map[string]string) {

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

load_all_as_json :: proc($T : typeid, directory_path : string, extension : string, include_extension : bool = false) -> (res : map[string]T) {
	
	//Open Directory
	dir, _ := os.open(directory_path);
	defer os.close(dir);
	
	//Get files from directory
	files_info, err := os.read_dir(dir, -1);
	defer os.file_info_slice_delete(files_info);

	full_ex := fmt.tprintf(".%s", extension);

	res = make(map[string]T);

	for fi in files_info {
		
		if !strings.has_suffix(fi.name, full_ex) {
			fmt.printf("Skipping %v\n", fi.name);
			continue;
		}

		data, ok := os.read_entire_file_from_filename(fi.fullpath);
		
		if ok {
			loaded_object : T;
			err := json.unmarshal(data, &loaded_object);

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
			{
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
