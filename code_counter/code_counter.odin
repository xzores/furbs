package code_counter;

import "core:mem"
import "core:fmt"
import "core:path/filepath"
import "core:os"
import "../utils"

read_lines_of_code_in_dir :: proc (dir_name : string, level : int) -> (lines : int) {
	
	//Open Directory
	dir, _ := os.open(dir_name);
	defer os.close(dir);
	
	//Get files from directory
	files_info, err := os.read_dir(dir, -1);
	defer os.file_info_slice_delete(files_info);
	
	for f in files_info {
		if f.is_dir {
			dir_lines := read_lines_of_code_in_dir(f.fullpath, level + 1);
			if dir_lines != 0 {
				for l in 0..<level {
					fmt.printf("\t");
				}
				fmt.printf("Lines of odin code in %v: %v\n", f.name, dir_lines);
			}
			lines += dir_lines;
		} else if filepath.ext(f.name) == ".odin" && f.name[0] != '.' {
			
			content, ok := os.read_entire_file_from_filename(f.fullpath);
			defer delete(content);
			if !ok  {
				continue;
			}
			for c in content {
				if c == '\n' {
					lines += 1;
				}
			}
		}
	}
	
	return;
}

code_count :: proc () {
	
	lines := read_lines_of_code_in_dir(".", 0);
	fmt.printf("Total lines of odin code: %v\n", lines);
}


main :: proc () {
	
	context.assertion_failure_proc = utils.init_stack_trace();
	defer utils.destroy_stack_trace();
	
	context.logger = utils.create_console_logger(.Info);
	defer utils.destroy_console_logger(context.logger);
	
	utils.init_tracking_allocators();
	
	{
		tracker : ^mem.Tracking_Allocator;
		context.allocator = utils.make_tracking_allocator(tracker_res = &tracker); //This will use the backing allocator,
		
		code_count();
				
		free_all(context.temp_allocator);
	}
	
	utils.print_tracking_memory_results();
	utils.destroy_tracking_allocators();
}