shader_type spatial;
uniform vec4 paint:source_color=vec4(.26,.34,.30,1.);
uniform float metal=.65;
uniform float scale_m=2.;
uniform sampler2D detail:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
varying vec3 world;
varying vec3 object_point;
varying vec3 world_normal;
float hash(vec3 p){return fract(sin(dot(p,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 p){vec3 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+1.),f.x),f.y),f.z);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;object_point=VERTEX;world_normal=normalize(MODEL_NORMAL_MATRIX*NORMAL);}
void fragment(){
 vec3 weights=pow(abs(world_normal),vec3(4.));weights/=max(weights.x+weights.y+weights.z,.001);
 vec3 p=world*scale_m;
 vec3 grain=texture(detail,p.zy).rgb*weights.x+texture(detail,p.xz).rgb*weights.y+texture(detail,p.xy).rgb*weights.z;
 float scratch=pow(abs(sin(p.x*113.+sin(p.z*6.)*.8)),24.)*noise(p*21.);
 float oxide=smoothstep(.58,.76,noise(p*1.4)*.70+noise(p*7.7)*.30);
 ALBEDO=mix(paint.rgb*(.80+grain*.30),vec3(.13,.065,.026),oxide*.70);
 ALBEDO+=vec3(.05,.045,.03)*scratch*metal;
 METALLIC=mix(metal,.12,oxide);ROUGHNESS=clamp(.38+oxide*.5+noise(p*12.)*.12-scratch*.15,.22,.94);SPECULAR=.45;
}
