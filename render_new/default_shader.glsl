
@vertex
layout (location = 0) in vec3 position;

uniform mat4 prj_mat;
uniform mat4 inv_prj_mat;

uniform mat4 view_mat;
uniform mat4 inv_view_mat;

uniform mat4 mvp;
uniform mat4 inv_mvp;

uniform mat4 model_mat;
uniform mat4 inv_model_mat;

void main() {
    gl_Position = mvp * vec4(position, 1.0);
}

@fragment
out vec4 FragColor;

void main() {
    FragColor = vec4($red_amount$, 0.0, 0.0, 1.0);
}

