shader_type spatial;
render_mode specular_schlick_ggx;

uniform vec4 tint : source_color = vec4(.31,.35,.32,1.);
uniform float surface_kind = 0.;
uniform float metalness = .7;
uniform float base_roughness = .42;
varying vec3 object_position;

float hash(vec3 p) {p=fract(p*.1031);p+=dot(p,p.yzx+33.33);return fract((p.x+p.y)*p.z);}
float noise3(vec3 p) {
 vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);
}
void vertex(){object_position=VERTEX;}
void fragment(){
 vec3 p=object_position;
 float clouds=noise3(p*7.)*.6+noise3(p*22.)*.4;
 float grain=noise3(vec3((p.x+p.z)*3200.,p.y*5.,1.));
 float grime=smoothstep(.54,.86,clouds);
 vec3 color=tint.rgb;float rough=base_roughness;
 if(surface_kind<.5){
  color*=.95+grain*.055;rough+=grain*.06+grime*.14;
 }else if(surface_kind<1.5){
  color*=.83+clouds*.29;rough+=grime*.17;
 }else if(surface_kind<2.5){
  float growth=sin((p.x+p.z)*290.+noise3(vec3((p.x+p.z)*16.,p.y*.6,0.))*12.);
  color*=.77+clouds*.26+growth*.085;rough+=grime*.14;
 }else{
  vec2 tile=fract(vec2(p.x,p.z)*48.)-.5;
  float studs=1.-smoothstep(.29,.39,length(tile));
  color*=.79+clouds*.24+studs*.09;rough=.87;
 }
 ALBEDO=mix(color,color*vec3(.62,.57,.43),grime*.15);
 METALLIC=metalness;ROUGHNESS=clamp(rough,.24,.99);SPECULAR=.42;
}
