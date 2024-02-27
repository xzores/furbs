



///Vertex shader begin
@vertex
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;

uniform mat4 prj_mat;
uniform mat4 inv_prj_mat;

uniform mat4 view_mat;
uniform mat4 inv_view_mat;

uniform mat4 mvp;
uniform mat4 inv_mvp;

uniform mat4 model_mat;
uniform mat4 inv_model_mat;

out vec2 texture_coords;

void main() {
	texture_coords = texcoord;
    gl_Position = mvp * vec4(position, 1.0);
}


///Fragment shader begin
@fragment

uniform sampler2D texture_diffuse;

in vec2 texture_coords;

out vec4 FragColor;

void main() {
	vec4 texColor = texture(texture_diffuse, texture_coords);

    FragColor = texColor;
}

