///Vertex shader begin
@vertex

//// Attributes ////
layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;
layout (location = 2) in vec3 normal;

//// Uniforms ////
uniform float time;

uniform mat4 prj_mat;
uniform mat4 inv_prj_mat;

uniform mat4 view_mat;
uniform mat4 inv_view_mat;

uniform mat4 view_prj_mat;
uniform mat4 inv_view_prj_mat;

uniform mat4 model_mat;
uniform mat4 inv_model_mat;

uniform mat4 mvp;

//// Outputs ////
out vec2 texture_coords;
out vec3 normals;

//GUI specific
out vec2 rect_pos;
out vec2 rect_size;

void main() {
	texture_coords = (texcoord);
	normals = normal;
	
	rect_pos = (model_mat * vec4(-0.5, -0.5, 0, 1)).xy;
	rect_size = (model_mat * vec4(0.5, 0.5, 0, 1)).xy - rect_pos;
	
	gl_Position = mvp * vec4(position, 1.0);
}

///Fragment shader begin
@fragment

//Inputs
in vec2 texture_coords;
in vec3 normals;

//GUI specific
in vec2 rect_pos;
in vec2 rect_size;

//// Uniforms ////
uniform float time;

uniform sampler2D texture_diffuse;
uniform vec4 color_diffuse = vec4(1,1,1,1);

uniform bool gui_fill; 	//If not fill then use gui_line_thickness
uniform float gui_line_thickness;
uniform float gui_roundness; //0 means sqaure

//// Outputs ////
out vec4 FragColor;

//Returns the distance to the nearest edge of a rectangle, the result is a SDF
float distance_to_sqaure_edge (vec2 rect_pos, vec2 rect_size, vec2 point) {
	float d1 = abs(point.x - rect_pos.x);
	float d2 = abs(point.x - rect_pos.x - rect_size.x);
	
	float d3 = abs(point.y - rect_pos.y);
	float d4 = abs(point.y - rect_pos.y - rect_size.y);
	
	return min(min(d1, d2), min(d3, d4));
}

void main() {
	vec4 tex_color = texture(texture_diffuse, texture_coords);
	
	if (gui_fill == false) {
		
		//check disance to nearest edge
		float dist = distance_to_sqaure_edge(rect_pos, rect_size, gl_FragCoord.xy);
		
		if (dist > gui_line_thickness) {
			//if the distance is less than the line thickness, then we are inside the line
			discard;
		}
	}
	
	FragColor = color_diffuse * tex_color;
}

