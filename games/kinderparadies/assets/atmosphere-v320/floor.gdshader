shader_type spatial;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_map:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 tint:source_color=vec4(.7,.73,.69,1.);
uniform float scale_m=.55;
uniform float dampness=.55;
uniform float fibre=0.;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=world.xz;vec2 uv=p*scale_m;
 vec3 base=texture(albedo_map,uv).rgb;
 float broad=noise(p*.21+vec2(4.,9.));
 float chips=noise(p*2.6)*.65+noise(p*8.1)*.35;
 float wet=smoothstep(.53,.73,broad*.65+chips*.35)*dampness;
 float wear=.84+.16*noise(p*.8);
 float scuff=pow(abs(sin(p.x*1.13+p.y*.19)),32.)*noise(p*9.)*.08;
 ALBEDO=base*tint.rgb*(wear-wet*.24-scuff);
 float rough=texture(rough_map,uv).r;
 ROUGHNESS=mix(clamp(rough*.85+.12+fibre*.18,.25,.98),.085,wet);
 NORMAL_MAP=texture(normal_map,uv).rgb;NORMAL_MAP_DEPTH=mix(.48,.13,wet);
 SPECULAR=mix(.33,.65,wet);CLEARCOAT=wet*.55;CLEARCOAT_ROUGHNESS=.25;
}
