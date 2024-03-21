



///Vertex shader begin
@vertex
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;
layout (location = 2) in vec3 normal;

layout (location = 3) in vec3 instance_position;
layout (location = 4) in vec3 instance_scale;
layout (location = 5) in vec2 instance_texcoord;

uniform mat4 prj_mat;
uniform mat4 inv_prj_mat;

uniform mat4 view_mat;
uniform mat4 inv_view_mat;

uniform mat4 mvp;
uniform mat4 inv_mvp;

uniform mat4 model_mat;
uniform mat4 inv_model_mat;

out vec2 texture_coords;
out vec2 texture_coords_instanced;

void main() {
	texture_coords = texcoord;
	texture_coords_instanced = instance_texcoord; 
    gl_Position = mvp * vec4(position + instance_position + vec3(0, gl_InstanceID, 0), 1.0);
}


///Fragment shader begin
@fragment

uniform sampler2D texture_diffuse;
uniform vec4 color_diffuse;

in vec2 texture_coords;
in vec2 texture_coords_instanced;

out vec4 FragColor;

void main() {
	vec4 texColor = texture(texture_diffuse, texture_coords + texture_coords_instanced);

    FragColor = color_diffuse * texColor;
}

