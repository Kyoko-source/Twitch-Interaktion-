shader_type spatial;
render_mode unshaded,cull_disabled,depth_draw_never;
uniform float clock=0.;
varying float strength;
void vertex(){
 float fall=mod(INSTANCE_CUSTOM.y*8.-clock*(3.5+INSTANCE_CUSTOM.z*3.),8.);
 VERTEX.y+=fall;VERTEX.x+=fall*.035;
 strength=.12+INSTANCE_CUSTOM.w*.23;
}
void fragment(){
 float line=1.-smoothstep(.0,.5,abs(UV.x-.5));
 float ends=smoothstep(0.,.18,UV.y)*(1.-smoothstep(.65,1.,UV.y));
 ALBEDO=vec3(.48,.62,.66);ALPHA=line*ends*strength;
}
