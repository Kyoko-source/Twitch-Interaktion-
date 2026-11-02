shader_type spatial;
render_mode cull_back;
uniform sampler2D drawings:source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec2 cell=vec2(0.0);
uniform float age=.7;
uniform float seed=0.0;
float grain(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7))+seed*13.1)*43758.5453);}
void fragment(){
 vec2 atlas_uv=(cell+mix(vec2(.005),vec2(.995),UV))/3.0;
 vec4 ink=texture(drawings,atlas_uv);
 float edge=pow(clamp(length((UV-.5)*1.42),0.0,1.0),3.0);
 float fibres=grain(floor(UV*vec2(620.,500.)));
 float stain=exp(-dot((UV-vec2(.82,.84))*vec2(8.,13.),(UV-vec2(.82,.84))*vec2(8.,13.)))*.13;
 vec3 paper=vec3(.70,.63,.45)*(1.-edge*.13-stain)+fibres*.025;
 ALBEDO=mix(paper,ink.rgb*.70+paper*.12,ink.a*age);
 ROUGHNESS=.99;SPECULAR=.06;
}
