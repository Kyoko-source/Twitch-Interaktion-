shader_type spatial;
uniform vec4 paper:source_color=vec4(.21,.36,.35,1.);
uniform sampler2D grain:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform int pattern=0;
float hash(vec2 p){return fract(sin(dot(p,vec2(53.23,91.67)))*43821.54);}
void fragment(){
 vec2 q=fract(UV*8.)-.5;
 float dotprint=1.-smoothstep(.11,.13,length(q));
 float stars=1.-smoothstep(.022,.04,min(abs(q.x)+abs(q.y)*.38,abs(q.y)+abs(q.x)*.38));
 float ink=pattern==0?dotprint:pattern==1?stars:step(.92,fract((UV.x+UV.y)*9.));
 float crease=pow(abs(sin(UV.x*31.+sin(UV.y*19.)*.9)),38.);
 float edge=min(min(UV.x,1.-UV.x),min(UV.y,1.-UV.y));
 vec3 col=mix(paper.rgb,paper.rgb*.64+vec3(.18,.15,.07),ink*.6);
 col*=mix(vec3(.78),vec3(1.08),texture(grain,UV*2.).rgb);
 ALBEDO=mix(col,col*1.23+vec3(.025),crease*.13+(1.-smoothstep(.0,.04,edge))*.23);
 ROUGHNESS=clamp(.67+hash(floor(UV*110.))*.18-crease*.08,.6,.92);SPECULAR=.25;
 NORMAL_MAP=vec3(.5+sin(UV.y*220.)*.018,.5+sin(UV.x*180.)*.018,1.);NORMAL_MAP_DEPTH=.22;
}
