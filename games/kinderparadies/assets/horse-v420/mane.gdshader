shader_type spatial;
render_mode cull_disabled;
// Long wet strands rooted along the dorsal ridge, hanging with gravity.
// UV: (offset from the ridge in turns, position along the neck)
// UV2: (position along the strand 0..1, across the strand -1..1)
// COLOR.r: strand length / metres, COLOR.g: width / 3 cm.
uniform vec4 points[32];
uniform vec3 frames[32];
uniform float sway=0.0;
varying float tip;

vec4 spline(vec4 a,vec4 b,vec4 c,vec4 d,float t){return .5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t);}
vec3 slope(vec3 a,vec3 b,vec3 c,vec3 d,float t){return .5*((-a+c)+2.0*(2.0*a-5.0*b+4.0*c-d)*t+3.0*(-a+3.0*b-3.0*c+d)*t*t);}

void vertex() {
 float s=clamp(UV.y,0.0,1.0)*31.0;
 int i=min(int(floor(s)),30);float f=s-float(i);
 vec4 a=points[max(i-1,0)],b=points[i],c=points[i+1],d=points[min(i+2,31)];
 vec4 centre=spline(a,b,c,d,f);
 vec3 tangent=normalize(slope(a.xyz,b.xyz,c.xyz,d.xyz,f)+vec3(0.0,1e-5,0.0));
 vec3 side=normalize(mix(frames[i],frames[i+1],f));side=normalize(side-tangent*dot(side,tangent)+vec3(1e-5,0.0,0.0));
 vec3 top=vec3(0.0,1.0,0.0)-tangent*tangent.y;
 top=length(top)<.05?normalize(cross(tangent,side)):normalize(top);
 vec3 across=normalize(cross(tangent,top));
 float turn=UV.x*6.2831853;
 vec3 root=top*cos(turn)+across*sin(turn);
 float t=UV2.x;float len=COLOR.r;
 vec3 hang=vec3(0.0,-1.0,0.0);
 // Lift off the hide first, then fall; clumps swing a little apart.
 vec3 path=root*(centre.w*.92+len*.16*min(t,.45))+hang*len*pow(t,1.25)+across*sign(UV.x)*len*.10*t*t+tangent*sin(UV.y*91.0+sway)*.02*t;
 VERTEX=centre.xyz+path+tangent*UV2.y*COLOR.g*.03*(1.0-t*.85);
 NORMAL=normalize(root+hang*t);
 tip=t;
}

void fragment() {
 ALBEDO=mix(vec3(.012,.009,.007),vec3(.05,.004,.006),smoothstep(.55,1.0,tip)*.6);
 ROUGHNESS=.42;SPECULAR=.4;
}
