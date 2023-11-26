package sub;

import "core:fmt"

import "vendor:glfw"
import "vendor:vulkan"
import 	"core:testing"

/*
@test
basic_vulkanl_test :: proc(t : ^testing.T) {
*/

main :: proc() {
	// Initialize glfw, specify OpenGL version.
    glfw.Init();
   	
	glfw.WindowHint(glfw.CLIENT_API, glfw.NO_API);
	glfw.WindowHint(glfw.RESIZABLE, 0);
	
	monitor : glfw.MonitorHandle = nil;

    // Create render window.
    window := glfw.CreateWindow(800, 800, "Hello vulkan!", monitor, nil);

	//We can also create an opengl window.
	//glfw.DefaultWindowHints();
	//window2 := glfw.CreateWindow(800, 800, "Hello vulkan! 2", monitor, nil);
    
	assert(window != nil);
    glfw.MakeContextCurrent(window);

    // Enable Vsync.
    glfw.SwapInterval(1);

    // Set normalized device coords to window coords transformation.
    w, h := glfw.GetFramebufferSize(window);

    // Render loop
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents();
		
        // Render screen with background color.
        glfw.SwapBuffers(window);
    }

	glfw.DestroyWindow(window);
	glfw.Terminate();
}

