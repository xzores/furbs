package sub;

import    "vendor:glfw"
import gl "vendor:OpenGL"
import    "core:time"
import    "core:math"
import 	"core:testing"

@test
basic_opengl_test :: proc(t : ^testing.T) {
	
	// Initialize glfw, specify OpenGL version.
    glfw.Init()
    defer glfw.Terminate()
    glfw.WindowHint(glfw.CONTEXT_VERSION_MAJOR, 3)
    glfw.WindowHint(glfw.CONTEXT_VERSION_MINOR, 3)
    glfw.WindowHint(glfw.OPENGL_PROFILE, glfw.OPENGL_CORE_PROFILE)
    
    // Create render window.
    window := glfw.CreateWindow(800, 600, "Blinking", nil, nil)
    assert(window != nil)
    defer glfw.DestroyWindow(window)
    glfw.MakeContextCurrent(window)

    // Enable Vsync.
    glfw.SwapInterval(1)

    // Load OpenGL function pointers.
    gl.load_up_to(3,3, glfw.gl_set_proc_address)

    // Set normalized device coords to window coords transformation.
    w, h := glfw.GetFramebufferSize(window)
    gl.Viewport(0,0,w,h)
    
    // Start blinking timer.
    watch : time.Stopwatch
    time.stopwatch_start(&watch)

    // Render loop
    for !glfw.WindowShouldClose(window) {
        glfw.PollEvents()
        // Note: glfw.PollEvents will block on Windows during window resize, hence
		// strange rendering occurs during resize. To keep this example simple, we
        // will not fix this here. A partial solution is found in Rainbow-Triangle
        // and subsequent examples.

        // Create oscillating value (osl).
        raw_duration := time.stopwatch_duration(watch)
        secs := f32(time.duration_seconds(raw_duration))
        osl := (math.sin(3 * secs) + 1) * 0.5
        
        // Clear screen with color.
        gl.ClearColor(0.9 * osl, 0.2, 0.8, 1) // Pink: 0.9, 0.2, 0.8
        gl.Clear(gl.COLOR_BUFFER_BIT)
        
        // Render screen with background color.
        glfw.SwapBuffers(window)
    }
}
