shader_type spatial;
render_mode cull_disabled;
uniform sampler2D cloth_map:source_color,filter_linear_mipmap;
uniform float clock=0.;
varying float fold;
void vertex(){
 float loose=pow(UV.y,1.8);
 fold=sin(UV.x*40.);
 VERTEX.y+=.022*fold+.024*loose*sin(clock*.62+UV.x*5.);
 VERTEX.x+=.009*loose*sin(clock*.47+UV.y*3.);
}
void fragment(){
 vec3 weave=texture(cloth_map,UV*vec2(3.,7.)).rgb;
 ALBEDO=mix(vec3(.18,.067,.055),vec3(.39,.18,.13),weave.r)*(.87+.13*fold);
 ROUGHNESS=.98;
}
