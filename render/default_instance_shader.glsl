
///Vertex shader begin
@vertex

//// Attributes ////
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;
layout (location = 2) in vec3 normal;

layout (location = 3) in vec3 instance_position;
layout (location = 4) in vec3 instance_scale;
layout (location = 5) in vec4 instance_texcoord;

//// Uniforms ////
uniform float time;
uniform mat4 delta_time;

uniform mat4 prj_mat;
uniform mat4 inv_prj_mat;

uniform mat4 view_mat;
uniform mat4 inv_view_mat;

uniform mat4 view_prj_mat;
uniform mat4 inv_view_prj_mat;

uniform mat4 model_mat;
uniform mat4 inv_model_mat;

uniform mat4 mvp;
uniform mat4 inv_mvp;

//// Outputs ////
out vec2 texture_coords;
out vec3 normals;

void main() {
	texture_coords = (texcoord * instance_texcoord.zw) + instance_texcoord.xy;
	normals = normal;
    gl_Position = mvp * vec4((position * instance_scale) + instance_position, 1.0);
}


///Fragment shader begin
@fragment

//Inputs
in vec2 texture_coords;
in vec3 normals;

//// Uniforms ////
uniform sampler2D texture_diffuse;
uniform vec4 color_diffuse = vec4(1,1,1,1);

//// Outputs ////
out vec4 FragColor;

void main() {
	vec4 texColor = texture(texture_diffuse, texture_coords);

    FragColor = color_diffuse * texColor;
}

