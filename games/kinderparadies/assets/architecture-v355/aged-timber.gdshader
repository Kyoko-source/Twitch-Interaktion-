shader_type spatial;
render_mode diffuse_burley;
uniform sampler2D wood : source_color, repeat_enable, filter_linear_mipmap_anisotropic;
uniform sampler2D micro : hint_normal, repeat_enable, filter_linear_mipmap;
uniform bool cross_grain = false;
varying vec3 local_position;
varying vec3 local_normal;
varying float height;
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
float noise(vec2 p) {
 vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
 return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);
}
float fbm(vec2 p){return noise(p)*.55+noise(p*2.3)*.28+noise(p*5.1)*.17;}
void vertex() { local_position=VERTEX; local_normal=NORMAL; height=(MODEL_MATRIX*vec4(VERTEX,1.0)).y; }
void fragment() {
 // Grain always runs along the member; the cross axis is whichever of the
 // remaining two is not the face normal, so side faces never smear.
 vec3 n=abs(local_normal);
 float along=cross_grain?local_position.x:local_position.y;
 float across;
 if(cross_grain) across=n.z>n.y?local_position.y:local_position.z;
 else across=n.z>n.x?local_position.x:local_position.z;
 vec2 uv=vec2(across*1.7+local_position.z*.3,along*.42);
 vec3 grain=texture(wood,uv).rgb;
 // Old cream gloss paint flaking off in coherent patches, worst near the floor
 // and at the edges, with a dark grime line where it lifts.
 float wear=fbm(vec2(along*3.2,across*7.0)+11.0);
 float floor_wear=1.0-smoothstep(.0,1.3,height);
 float lift=wear+floor_wear*.32;
 float paint=1.0-smoothstep(.56,.60,lift);
 float rim=smoothstep(.50,.56,lift)*(1.0-smoothstep(.60,.64,lift));
 vec3 bare=grain*vec3(.70,.58,.44);
 vec3 coat=vec3(.56,.54,.46)*(.82+.18*fbm(vec2(along*14.0,across*30.0)));
 coat=mix(coat,coat*vec3(.80,.74,.62),smoothstep(.2,.8,fbm(vec2(along*1.3,across*2.0)+4.0)));
 vec3 c=mix(bare,coat,paint);
 c*=1.0-rim*.55;
 float grime=smoothstep(.55,1.0,floor_wear)*.45+fbm(vec2(along*.8,across*4.0)+30.0)*.18;
 c*=1.0-grime;
 ALBEDO=c;
 ROUGHNESS=mix(.93,.72,paint);SPECULAR=mix(.16,.28,paint);
 NORMAL_MAP=texture(micro,uv*4.0).rgb;NORMAL_MAP_DEPTH=mix(.45,.15,paint);
}
