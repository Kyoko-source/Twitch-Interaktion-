shader_type spatial;
render_mode cull_disabled;
// 32 animated support points; every ring is a Catmull-Rom sample between them.
uniform vec4 points[32];
uniform vec3 frames[32];
uniform sampler2D pores : hint_normal, repeat_enable;
varying float along;
varying float dorsal;
varying float ridge;

float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}

vec4 spline(vec4 a,vec4 b,vec4 c,vec4 d,float t){return .5*((2.0*b)+(-a+c)*t+(2.0*a-5.0*b+4.0*c-d)*t*t+(-a+3.0*b-3.0*c+d)*t*t*t);}
vec3 slope(vec3 a,vec3 b,vec3 c,vec3 d,float t){return .5*((-a+c)+2.0*(2.0*a-5.0*b+4.0*c-d)*t+3.0*(-a+3.0*b-3.0*c+d)*t*t);}

void vertex() {
 float s=clamp(UV.y,0.0,1.0)*31.0;
 int i=min(int(floor(s)),30);float f=s-float(i);
 vec4 a=points[max(i-1,0)],b=points[i],c=points[i+1],d=points[min(i+2,31)];
 vec4 centre=spline(a,b,c,d,f);
 vec3 tangent=normalize(slope(a.xyz,b.xyz,c.xyz,d.xyz,f)+vec3(0.0,1e-5,0.0));
 vec3 side=normalize(mix(frames[i],frames[i+1],f));side=normalize(side-tangent*dot(side,tangent)+vec3(1e-5,0.0,0.0));
 vec3 up=normalize(cross(tangent,side));
 float angle=UV.x*6.2831853;
 vec3 radial=side*cos(angle)+up*sin(angle);
 // "Dorsal" is the side of the neck that faces the ceiling, wherever it bends.
 vec3 top=vec3(0.0,1.0,0.0)-tangent*tangent.y;
 top=length(top)<.05?up:normalize(top);
 float facing=dot(radial,top);
 float vertebra=pow(.5+.5*cos(s*6.2831853*1.6),3.0);
 ridge=pow(max(facing,0.0),7.0)*vertebra;
 float cords=pow(max(dot(radial,normalize(top+side*1.6)),0.0),20.0)+pow(max(dot(radial,normalize(top-side*1.6)),0.0),20.0);
 float hollow=pow(max(dot(radial,side),0.0)*max(dot(radial,-side),0.0)*4.0,1.0);
 float sag=max(-facing,0.0);
 float folds=sin(s*23.0+sin(angle*2.0)*1.4)*(.030+.065*sag)+(noise(vec2(UV.x*14.0,s*5.0))-.5)*.10+(noise(vec2(UV.x*5.0,s*1.6))-.5)*.05;
 float radius=centre.w*(.78+.28*ridge+.12*cords+folds-.12*hollow*(1.0-sag));
 VERTEX=centre.xyz+radial*radius-top*sag*sag*centre.w*.10*(.5+.5*sin(s*2.1));
 NORMAL=normalize(radial-tangent*(folds*.6));
 TANGENT=normalize(-side*sin(angle)+up*cos(angle));BINORMAL=tangent;
 along=s;dorsal=facing;
}

void fragment() {
 vec2 q=vec2(UV.x*9.0,along*2.4);
 float mottle=noise(q*1.7)*.6+noise(q*5.3)*.4;
 float mange=smoothstep(.56,.70,noise(q*1.1+vec2(3.1,7.7)));
 float sore=smoothstep(.73,.86,noise(q*2.3+vec2(11.0,2.0)))*(.4+.6*smoothstep(-.2,.6,-dorsal));
 float drip=smoothstep(.83,.97,noise(vec2(UV.x*48.0,along*.7)))*smoothstep(.0,-.7,dorsal);
 vec3 hide=mix(vec3(.050,.042,.034),vec3(.115,.095,.074),mottle);
 hide=mix(hide,vec3(.17,.15,.125)*(.75+.5*mottle),mange*.7);
 hide=mix(hide,vec3(.20,.18,.15),ridge*.45);
 float blood=max(sore,drip*.85);
 ALBEDO=mix(hide,vec3(.10,.006,.008)*(.7+.6*mottle),blood);
 ROUGHNESS=mix(mix(.86,.62,mange),.26,blood);
 SPECULAR=mix(.22,.5,blood);
 NORMAL_MAP=texture(pores,UV*vec2(7.0,52.0)).rgb;NORMAL_MAP_DEPTH=mix(.65,.25,blood);
}
