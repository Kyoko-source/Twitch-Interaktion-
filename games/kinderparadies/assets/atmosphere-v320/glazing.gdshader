shader_type spatial;
render_mode depth_prepass_alpha,cull_disabled;
uniform float clock=0.;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=UV;
 float edge=1.-smoothstep(.025,.15,min(min(p.x,1.-p.x),min(p.y,1.-p.y)));
 vec2 dirt=p+vec2(world.z*.71,world.y*.17);
 float smudge=smoothstep(.56,.84,noise(dirt*vec2(35.,18.))*.45+noise(dirt*vec2(84.,42.))*.55);
 float column=floor(p.x*96.);float drop_phase=fract(clock*(.012+hash(vec2(column,8.))*.023)+hash(vec2(column,3.)));
 float rivulet=exp(-pow((fract(p.x*96.)-.5)*17.,2.))*smoothstep(.0,.07,drop_phase-p.y)*(1.-smoothstep(.28,.40,drop_phase-p.y));
 float grime=clamp(edge*.65+smudge*.40,0.,.85);
 ALBEDO=mix(vec3(.20,.27,.25),vec3(.19,.15,.09),grime);
 ROUGHNESS=mix(.075,.65,grime);SPECULAR=.30;METALLIC=0.;CLEARCOAT=.25;CLEARCOAT_ROUGHNESS=.18;
 float fresnel=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),4.);
 ALPHA=clamp(.035+grime*.28+fresnel*.20+rivulet*.08,.035,.55);
 NORMAL_MAP=normalize(vec3(sin(p.x*603.+noise(p*20.)*2.)*.018*rivulet,cos(p.y*279.)*.008,1.))*.5+.5;
 NORMAL_MAP_DEPTH=.30;
}
