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
 // Dark walnut stain under a worn varnish: the grain still shows through
 // the colour, the varnish is rubbed back to pale timber on edges and near
 // the floor, with scratches, knocks and grime in the open grain.
 float figure=fbm(vec2(along*.9,across*9.0));
 vec3 stained=grain*vec3(.42,.25,.14)*(.75+.5*figure);
 stained=mix(stained,stained*vec3(.72,.62,.55),smoothstep(.3,.8,fbm(vec2(along*1.3,across*2.0)+4.0)));
 float wear=fbm(vec2(along*3.2,across*7.0)+11.0);
 float floor_wear=1.0-smoothstep(.0,1.3,height);
 float lift=wear+floor_wear*.30;
 float varnish=1.0-smoothstep(.60,.70,lift);
 vec3 bare=grain*vec3(.74,.55,.36);
 vec3 c=mix(bare,stained,varnish);
 // Fine scratches across the member and a few deeper gouges.
 float scratch=step(.985,fract(across*37.0+noise(vec2(along*6.0,across*3.0))*2.0))*step(.55,noise(vec2(along*2.0,across)));
 c=mix(c,bare*1.1,scratch*.6);
 float gouge=1.0-smoothstep(.0,.012,abs(fbm(vec2(along*1.7,across*1.1)+50.0)-.5));
 c*=1.0-gouge*step(.6,noise(vec2(along*.7,across*.4)+9.0))*.6;
 float pores=step(.7,noise(vec2(along*40.0,across*160.0)));
 c*=1.0-pores*.25*varnish;
 float grime=smoothstep(.55,1.0,floor_wear)*.4+fbm(vec2(along*.8,across*4.0)+30.0)*.15;
 c*=1.0-grime;
 float paint=varnish;
 ALBEDO=c;
 ROUGHNESS=mix(.9,.42,paint)+scratch*.2;SPECULAR=mix(.18,.4,paint);
 NORMAL_MAP=texture(micro,uv*4.0).rgb;NORMAL_MAP_DEPTH=mix(.45,.15,paint);
}
