
///Vertex shader begin
@vertex

//// Attributes ////
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;
layout (location = 2) in vec3 normal;

layout (location = 3) in vec3 instance_position;
layout (location = 4) in vec3 instance_scale;
layout (location = 5) in vec3 instance_rotation;
layout (location = 6) in vec4 instance_tex_pos_scale;

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

mat3 rotation_matrix(vec3 euler_angles) {
	float cx = cos(radians(euler_angles.x));
	float sx = sin(radians(euler_angles.x));

	float cy = cos(radians(euler_angles.y));
	float sy = sin(radians(euler_angles.y));
	
	float cz = cos(radians(euler_angles.z));
	float sz = sin(radians(euler_angles.z));

	mat3 rot_x = mat3(	1, 0, 0,
					 	0, cx, sx,
					 	0, -sx, cx);

	mat3 rot_y = mat3(	cy, 0, -sy,
					 	0, 1, 0,
						sy, 0, cy);

	mat3 rot_z = mat3(	cz, sz, 0,
						-sz, cz, 0,
						0, 0, 1);

	return rot_z * rot_y * rot_x;
}

void main() {
	texture_coords = (texcoord * instance_tex_pos_scale.zw) + instance_tex_pos_scale.xy;
	normals = normal;
	vec4 pos = vec4(((rotation_matrix(instance_rotation) * position) * instance_scale) + instance_position, 1.0);
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
	vec4 texColor = texture(texture_diffuse, texture_coords);

	FragColor = color_diffuse * texColor;
}

