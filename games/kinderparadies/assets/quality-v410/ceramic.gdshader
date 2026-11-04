shader_type spatial;
uniform vec4 glaze:source_color=vec4(.66,.65,.55,1.);
varying vec3 local_position;
void vertex(){local_position=VERTEX;}
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float grain(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 float radius=length(local_position.xz);
 float speck=grain(local_position.xz*1200.);
 float ring=smoothstep(.67,.92,radius)* (1.-smoothstep(.93,.99,radius));
 float grime=smoothstep(.72,.92,grain(local_position.xz*11.))*smoothstep(.25,.7,radius)*.14;
 ALBEDO=glaze.rgb*(.97+speck*.055)*(1.-grime);
 ALBEDO=mix(ALBEDO,vec3(.075,.14,.13),ring*.60);
 ROUGHNESS=.31+grime+speck*.06;SPECULAR=.29;
}
