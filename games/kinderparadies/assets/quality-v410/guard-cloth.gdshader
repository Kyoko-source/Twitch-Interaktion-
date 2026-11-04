shader_type spatial;
uniform vec3 start_point=vec3(-.24,-.50,-.27);
uniform vec3 elbow_point=vec3(-.28,-.36,-.39);
uniform vec3 wrist_point=vec3(-.1,-.2,-.55);
uniform sampler2D weave:hint_normal,repeat_enable,filter_linear_mipmap_anisotropic;
void vertex(){
 float t=UV.y;float angle=UV.x*6.2831853;
 vec3 tangent=normalize((elbow_point-start_point)*(1.-t)+(wrist_point-elbow_point)*t);
 vec3 side=cross(tangent,vec3(0,1,0));
 if(length(side)<.001){side=cross(tangent,vec3(0,0,1));}
 side=normalize(side);vec3 up=normalize(cross(tangent,side));
 vec3 radial=side*cos(angle)+up*sin(angle);
 float radius=mix(.049,.025,t)*(1.+sin(t*46.)*.11*pow(t,3.))+.002*smoothstep(.88,1.,t);
 VERTEX=start_point*pow(1.-t,2.)+2.*elbow_point*(1.-t)*t+wrist_point*t*t+radial*radius;
 NORMAL=radial;
 TANGENT=normalize(-side*sin(angle)+up*cos(angle));BINORMAL=tangent;
}
void fragment(){
 float cuff=smoothstep(.86,.92,UV.y);
 ALBEDO=mix(vec3(.070,.100,.079),vec3(.045,.065,.052),cuff);
 ROUGHNESS=.96;SPECULAR=.12;
 NORMAL_MAP=texture(weave,UV*vec2(2.,6.)).rgb;NORMAL_MAP_DEPTH=.18;
}
