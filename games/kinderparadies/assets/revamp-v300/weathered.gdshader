shader_type spatial;
uniform vec4 paint:source_color=vec4(.38,.43,.34,1.);
uniform sampler2D grain:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D roughness_map:filter_linear_mipmap_anisotropic,repeat_enable;
uniform float metres=1.0;
uniform float metalness=.3;
uniform float polish=.36;
varying vec3 p;
varying vec3 n;
void vertex(){p=VERTEX;n=NORMAL;}
vec3 sample_surface(sampler2D tex){vec3 w=pow(abs(n),vec3(5.));w/=max(w.x+w.y+w.z,.0001);return texture(tex,p.zy*metres).rgb*w.x+texture(tex,p.xz*metres).rgb*w.y+texture(tex,p.xy*metres).rgb*w.z;}
void fragment(){vec3 photo=sample_surface(grain);float value=dot(photo,vec3(.3,.59,.11));float grime=1.-smoothstep(.05,.32,value);float chip=smoothstep(.76,.98,grime);ALBEDO=mix(paint.rgb*(.55+value*1.7),vec3(.105,.045,.021),chip*.68);float r=sample_surface(roughness_map).r;ROUGHNESS=clamp(mix(polish,.96,grime*.72+r*.28),.1,1.);METALLIC=metalness*(1.-chip*.7);SPECULAR=.45;}
