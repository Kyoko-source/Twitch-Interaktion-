shader_type canvas_item;
uniform float strength=0.065;
void fragment(){
 vec2 uv=UV;
 uv.x+=sin(uv.y*91.0+TIME*2.0)*0.0007;
 vec3 c=texture(TEXTURE,uv).rgb;
 float l=dot(c,vec3(.299,.587,.114));
 c=mix(c,vec3(l*.82,l,l*.88),.68);
 float n=fract(sin(dot(floor(UV*vec2(640.,360.))+floor(TIME*19.),vec2(12.9898,78.233)))*43758.5453);
 c=c*1.32+(n-.5)*strength;
 c*=.92+.08*sin(UV.y*360.*3.14159);
 float v=1.-.25*pow(length((UV-.5)*1.4),2.);
 COLOR=vec4(c*v,1.);
}
