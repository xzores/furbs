#version 330 core

in vec2 frag_texcoord;

out vec4 final_color;

uniform sampler2D texture_diffuse;
uniform vec4 col_diffuse = vec4(1,1,1,1);

void main()
{
	vec4 texelColor = vec4(1, 1, 1, texture(texture_diffuse, frag_texcoord).r); 
	final_color = texelColor; //
}