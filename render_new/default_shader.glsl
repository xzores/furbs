
@vertex
in vec3 position;

void main() {
    gl_Position = vec4(position, 1.0);
}

@fragment
out vec4 FragColor;

void main() {
    FragColor = vec4($red_amount$, 0.0, 0.0, 1.0);
}

