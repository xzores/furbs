#version 330 core

// Input from the vertex shader
in vec3 vColor;

// Output color of the fragment
out vec4 FragColor;

void main() {
    // Set the fragment color
    FragColor = vec4(vColor, 1.0);
}
