shader_type spatial;
render_mode cull_disabled;
uniform vec4 points[32];
uniform vec3 frames[32];
uniform sampler2D pores : hint_normal, repeat_enable;
float hash(vec3 p) { return fract(sin(dot(p,vec3(12.9898,78.233,37.719)))*43758.5453); }
void vertex() {
 int i=int(round(UV.y*31.0));
 vec3 tangent=normalize(points[min(i+1,31)].xyz-points[max(i-1,0)].xyz);
 vec3 side=normalize(frames[i]);
 vec3 up=normalize(cross(tangent,side));
 float angle=UV.x*6.2831853;
 vec3 radial=side*cos(angle)+up*sin(angle);
 float folds=1.0+.038*sin(UV.y*380.0+sin(angle*3.0));
 VERTEX=points[i].xyz+radial*points[i].w*folds;
 NORMAL=radial; TANGENT=normalize(-side*sin(angle)+up*cos(angle)); BINORMAL=tangent;
}
void fragment() {
 float blotch=sin(UV.y*91.0+sin(UV.x*28.0)*2.5)*sin(UV.x*33.0+UV.y*47.0);
 float stain=smoothstep(.5,.91,blotch)*( .35+.65*smoothstep(.1,.8,UV.y));
 vec3 pallor=mix(vec3(.12,.112,.09),vec3(.24,.22,.17),.5+.5*sin(UV.y*19.0+UV.x*8.0));
 ALBEDO=mix(pallor,vec3(.052,.006,.005),stain*.82);
 ROUGHNESS=mix(.93,.55,stain); SPECULAR=.18;
 NORMAL_MAP=texture(pores,UV*vec2(5.0,38.0)).rgb; NORMAL_MAP_DEPTH=.4;
}
