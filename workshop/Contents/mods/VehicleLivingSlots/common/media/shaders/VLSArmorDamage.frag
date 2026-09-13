#version 330
in vec3 vertNormal;
in vec2 texCoords;
out vec4 fragColour;
uniform sampler2D Texture;
uniform float Alpha;
uniform vec3 TintColour;
uniform vec3 AmbientColour;
uniform vec3 Light0Direction;
uniform vec3 Light0Colour;
uniform vec3 Light1Direction;
uniform vec3 Light1Colour;
uniform vec3 Light2Direction;
uniform vec3 Light2Colour;
uniform vec3 Light3Direction;
uniform vec3 Light3Colour;
uniform vec3 Light4Direction;
uniform vec3 Light4Colour;
vec3 lamp(vec3 n,vec3 direction,vec3 colour) {
    float lengthSquared=dot(direction,direction);
    return lengthSquared>0.000001 ? colour*max(dot(n,direction*inversesqrt(lengthSquared)),0.0) : vec3(0.0);
}
void main() {
    vec4 sampleColour=texture(Texture,texCoords);
    // Native damage atlas alpha blends damage; it must not cut holes in metal.
    vec3 n=normalize(vertNormal);
    // ItemModelRenderer: ambient*0.4, light RGB=ambient*(1.5/4),
    // radius5000 at distance sqrt(29), native direction(0,5,-2).
    float beauty=max(dot(n,normalize(vec3(0.0,5.0,-2.0))),0.0);
    vec3 light=AmbientColour*(0.4+0.374596113*beauty);
    light+=lamp(n,Light0Direction,Light0Colour);
    light+=lamp(n,Light1Direction,Light1Colour);
    light+=lamp(n,Light2Direction,Light2Colour);
    light+=lamp(n,Light3Direction,Light3Colour);
    light+=lamp(n,Light4Direction,Light4Colour);
    light=clamp(light,0.0,1.0);
    // Native vehicle_common addDamage specialized for neutral black paint (HSV 0,0,0.16).
    // S=0 makes the native HSV result grayscale; V adjustment and alpha0.75 are unchanged.
    float damageValue=clamp(max(sampleColour.r,max(sampleColour.g,sampleColour.b))+0.16-0.5,0.0,0.9999);
    vec3 albedo=mix(vec3(0.16),vec3(damageValue),sampleColour.a*0.75);
    fragColour=vec4(Alpha*albedo*TintColour*light,Alpha);
}
