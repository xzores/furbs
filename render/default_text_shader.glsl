
///Vertex shader begin
@vertex

//// Attributes ////
layout (location = 0) in vec3 position;

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

void main() {
	//texture_coords = (texcoord * instance_texcoord.zw) + instance_texcoord.xy;
	
	if (gl_VertexID == 0) {
		texture_coords = instance_texcoord.xw;
	}
	if (gl_VertexID == 1) {
		texture_coords = instance_texcoord.xy;
	}
	if (gl_VertexID == 3) {
		texture_coords = instance_texcoord.zw;
	}
	if (gl_VertexID == 2) {
		texture_coords = instance_texcoord.zy;
	}
	
    gl_Position = mvp * vec4((position * instance_scale) + instance_position, 1.0);
}


///Fragment shader begin
@fragment

//Inputs
in vec2 texture_coords;

//// Uniforms ////
uniform sampler2D texture_diffuse;
uniform vec4 color_diffuse = vec4(1,1,1,1);

//// Outputs ////
out vec4 FragColor;

void main() {
	vec4 tex_color = texture(texture_diffuse, texture_coords);
	
    FragColor = color_diffuse * vec4(1, 1, 1, tex_color.r);
}

