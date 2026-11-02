shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D wood : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D micro : hint_normal, repeat_enable, filter_linear_mipmap;
uniform bool cross_grain = false;
varying vec3 local_position;
varying float height;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
void vertex() { local_position=VERTEX; height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y; }
void fragment() {
 vec2 p=vec2(cross_grain ? local_position.x : local_position.y, cross_grain ? local_position.y : local_position.x);
 vec2 uv=vec2(p.x*.65,p.y*3.5+local_position.z*.28);
 vec3 grain=texture(wood,uv).rgb;
 float chipped=noise(p*vec2(9.0,62.0))+noise(p*vec2(24.0,115.0))*.28;
 float coating=smoothstep(.48,.70,chipped);
 float split=pow(clamp(noise(p*vec2(2.4,340.0))-.35,0.0,1.0),3.0);
 float damp=1.0-.48*(1.0-smoothstep(.03,.65,height));
 vec3 bare=grain*vec3(.62,.49,.34);
 ALBEDO=mix(bare,vec3(.30,.30,.24)*(grain*.40+.62),coating)*damp*(1.0-split*.8);
 ROUGHNESS=.94;SPECULAR=.18;
 NORMAL_MAP=texture(micro,uv*5.0).rgb;NORMAL_MAP_DEPTH=.35;
}
