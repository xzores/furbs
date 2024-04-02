
///Vertex shader begin
@vertex

//// Attributes ////
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;
layout (location = 2) in vec3 normal;

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

//void main() {
//	texture_coords = (texcoord);
//	normals = normal;
//    gl_Position = mvp * vec4(position, 1.0);
//}

void main() {
	texture_coords = texcoord;
	
	vec4 pos = vec4(position, 1);
	
	//TODOs test again
	//float t = (sin(time) + 0.999) / 2;
	//vec4 pos2 = mvp * pos;
	//pos = pos2 * t + (1 - t) * pos;

	gl_Position = mvp * pos;
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
	vec4 tex_color = texture(texture_diffuse, texture_coords);
	
    FragColor = color_diffuse * tex_color;
}

