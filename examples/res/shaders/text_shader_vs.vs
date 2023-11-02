#version 330 core

layout (location = 0) in vec3 position;

out vec2 frag_texcoord; 

uniform vec2 texcoords[4];
uniform mat4 mvp;

void main()
{
	frag_texcoord = texcoords[gl_VertexID];
	gl_Position = mvp * vec4(position, 1.0);
};