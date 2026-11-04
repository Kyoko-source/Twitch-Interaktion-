shader_type spatial;
uniform vec4 tint : source_color = vec4(.49,.36,.27,1.0);
uniform float patch_level=.45;
uniform float patch_shade=.8;
varying vec3 local_point;
void vertex(){local_point=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec2 p=UV*vec2(.14,.34);
 float age=noise(p*43.0+local_point.xy*6.0);
 float mottling=noise(p*117.0)*.65+noise(p*291.0)*.35;
 float pore=noise(p*2100.0);
 float crease=pow(abs(sin(UV.y*87.0+noise(p*67.0)*4.0)),18.0)*(.3+.7*noise(p*203.0));
 float edge=pow(abs(UV.x-.5)*2.0,15.0);
 vec3 leather=tint.rgb*mix(.66,1.15,mottling)*mix(1.0,patch_shade,step(patch_level,UV.y));
 leather=mix(leather,vec3(.19,.145,.11),smoothstep(.55,.86,age)*.38);
 leather*=1.0-crease*.16-edge*.24-(1.0-smoothstep(.0,.012,abs(UV.y-patch_level)))*.19;
 ALBEDO=leather;
 ROUGHNESS=clamp(.64+age*.23+crease*.08,.55,.94);
 SPECULAR=.29;
 // Small pores and shallow creases break the flashlight highlight, without
 // a wet plastic finish. These are costume-material surface details.
 NORMAL_MAP=normalize(vec3((noise(p*2100.0+vec2(.17,0))-pore)*.16,
                          (noise(p*2100.0+vec2(0,.17))-pore)*.16+crease*.055,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.65;
}
