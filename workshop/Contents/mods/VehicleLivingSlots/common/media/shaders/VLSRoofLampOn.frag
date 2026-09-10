#version 330
in vec2 texCoords;
out vec4 fragColour;
uniform sampler2D Texture;
uniform float Alpha;
void main() {
    vec4 lens=texture(Texture,texCoords);
    if(lens.a<0.01) discard;
    // Preserve original lens detail; emission remains visible at night.
    vec3 emission=mix(vec3(0.86),vec3(1.0),lens.rgb);
    fragColour=vec4(Alpha*emission,Alpha*lens.a);
}
