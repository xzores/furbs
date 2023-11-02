#version 330 core

layout (location = 0) in vec3 position;
layout (location = 1) in vec2 texcoord;

out vec2 frag_texcoord;

uniform mat4 mvp;

void main()
{
	frag_texcoord = texcoord; 
	gl_Position = mvp * vec4(position, 1.0); //TODO mvp*
};