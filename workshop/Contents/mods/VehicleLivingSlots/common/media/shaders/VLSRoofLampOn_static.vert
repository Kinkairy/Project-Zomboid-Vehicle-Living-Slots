#version 330
// Native basicEffect_static vertex layout and depth behavior.
layout(location=0) in vec4 vertex;
layout(location=1) in vec4 normal;
layout(location=2) in vec2 uv;
out vec3 vertNormal;
out vec2 texCoords;
uniform mat4 ModelViewProjection;
uniform mat4 transform;
uniform float targetDepth=0.5;
uniform vec2 UVScale=vec2(1.0);
uniform float HighResDepthMultiplier=0.0;
uniform float FinalScale=1.0;
void main() {
    texCoords=uv*UVScale;
    vertNormal=(transform*vec4(normal.xyz,0.0)).xyz;
    vec4 position=transform*vec4(vertex.xyz,1.0);
    position.xyz*=FinalScale;
    vec4 clip=ModelViewProjection*position;
    vec4 origin=ModelViewProjection*vec4(0.0,0.0,0.0,1.0);
    clip.z+=(origin.z-clip.z)*HighResDepthMultiplier;
    clip.z+=2.0*(targetDepth-0.5);
    gl_Position=clip;
}
