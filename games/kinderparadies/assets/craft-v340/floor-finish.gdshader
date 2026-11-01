shader_type spatial;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_map:filter_linear_mipmap_anisotropic,repeat_enable;
uniform int finish=0;
uniform vec4 bounds=vec4(-6.275,-34.15,3.675,-25.55);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world.xz;
 vec3 detail=texture(albedo_map,p*.72).rgb;
 vec3 normal=texture(normal_map,p*.72).rgb;
 float rough=texture(rough_map,p*.72).r;
 float edge=min(min(p.x-bounds.x,bounds.z-p.x),min(p.y-bounds.y,bounds.w-p.y));
 float fleck=noise(p*16.)*.55+noise(p*57.)*.45;
 float worn=exp(-pow((p.y+29.65)/.75,2.))*.55+exp(-pow((p.x+5.35)/.5,2.))*.6;
 vec3 base;float wet=0.;
 if(finish==0){
  vec2 q=abs(fract(p*2.4)-.5);float diamond=abs(q.x+q.y-.32);
  float pattern=(1.-smoothstep(.012,.035,diamond))*.75+(1.-smoothstep(.015,.035,abs(q.x+q.y-.47)))*.25;
  float border=(1.-smoothstep(.035,.055,abs(edge-.13)))+(1.-smoothstep(.012,.024,abs(edge-.24)))*.6;
  base=mix(vec3(.115,.055,.063),vec3(.29,.20,.13),pattern*(1.-worn*.68));
  base=mix(base,vec3(.36,.28,.17),clamp(border,0.,1.)*.7);
  base*=mix(vec3(.58),vec3(1.20),detail)*(.77+fleck*.23);base=mix(base,base*1.3+vec3(.025),clamp(worn,0.,1.)*.45);
  ROUGHNESS=clamp(.89+rough*.13,.9,1.);SPECULAR=.17;NORMAL_MAP_DEPTH=.36;
 }else if(finish==1){
  vec2 tile=fract(p/.32);float grout=1.-smoothstep(.012,.028,min(min(tile.x,1.-tile.x),min(tile.y,1.-tile.y)));
  float stain=exp(-length((p-vec2(-13.25,-31.25))*vec2(1.1,.82)))*.7+exp(-length((p-vec2(-16.2,-28.65))*vec2(1.7,1.1)))*.65;
  wet=clamp(stain*(.55+noise(p*3.2)*.5),0.,.8);
  base=mix(vec3(.31,.34,.27),vec3(.065,.075,.055),grout)*mix(vec3(.60),vec3(1.17),detail);
  base=mix(base,base*vec3(.48,.43,.27),wet);
  ROUGHNESS=mix(clamp(.65+rough*.25,.65,.96),.16,wet);SPECULAR=mix(.3,.55,wet);NORMAL_MAP_DEPTH=.36;
 }else{
  vec2 cell=fract(p/.065)-.5;float stud=1.-smoothstep(.18,.29,length(cell));
  vec2 joint=fract((p-bounds.xy)/.72);float seam=1.-smoothstep(.002,.012,min(min(joint.x,1.-joint.x),min(joint.y,1.-joint.y)));
  float tracks=smoothstep(.43,.72,noise(p*1.8+vec2(7,3)));
  base=mix(vec3(.055,.10,.085),vec3(.14,.17,.12),fleck*.7)*(1.-seam*.55);
  base=mix(base,base*1.3,tracks*.6);base*=.85+stud*.15;
  ROUGHNESS=.92;SPECULAR=.22;NORMAL_MAP_DEPTH=.25;
  normal.xy+=(cell*stud)*.13;
 }
 ALBEDO=base;NORMAL_MAP=normal;CLEARCOAT=wet*.32;CLEARCOAT_ROUGHNESS=.23;
}
