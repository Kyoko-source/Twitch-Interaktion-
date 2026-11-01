shader_type spatial;
uniform sampler2D grain:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 paint:source_color=vec4(.24,.34,.27,1.);
uniform int kind=0;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(91.7,173.3)))*43758.54);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=kind==1?world.xz:world.zy;
 float grit=noise(p*31.)*.6+noise(p*83.)*.4;
 float chipped=smoothstep(.75,.88,grit);
 float damp=(1.-smoothstep(.18,.67,world.y))*exp(-pow((world.z+28.65)*1.35,2.));
 float grease=kind==2?smoothstep(.38,.72,noise(p*3.7))* .8:0.;
 vec3 base=paint.rgb*mix(vec3(.70),vec3(1.10),texture(grain,p*1.5).rgb);
 base=mix(base,vec3(.13,.085,.035),chipped*.8);base*=1.-damp*.55;
 if(kind==1){
  float polish=exp(-pow((world.x+16.3)/.33,2.));
  float lines=pow(abs(sin(p.y*631.+noise(p*5.)*6.)),56.);
  base=mix(base,vec3(.37,.40,.36),polish*.55)+lines*.027;
  ROUGHNESS=mix(.66,.29,polish);METALLIC=.78;
 }else{ROUGHNESS=mix(.78,.35,max(damp,grease));METALLIC=kind==2?.65:.13;}
 ALBEDO=base*(1.-grease*.58);SPECULAR=.32;
 NORMAL_MAP=texture(normal_map,p*2.).rgb;NORMAL_MAP_DEPTH=.18;
}
