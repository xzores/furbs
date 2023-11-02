#version 330 core

out vec3 color;

uniform vec4 col_diffuse = vec4(1,1,1,1); 

void main(){
  	color = col_diffuse.xyz;
}