shader_type spatial;
uniform sampler2D textile:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fibres:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D blood_map:source_color,filter_linear_mipmap_anisotropic;
uniform vec4 tint:source_color=vec4(.8,.74,.65,1.);
uniform bool apron=false;
varying vec3 p;
void vertex(){p=VERTEX;}
void fragment(){vec2 grain_uv=vec2(p.x,p.y)*7.;vec3 cloth=texture(textile,grain_uv).rgb*tint.rgb;float grey=dot(cloth,vec3(.299,.587,.114));if(apron){cloth=vec3(.36,.33,.25)*( .82+grey*.35);}else{cloth=mix(cloth,vec3(grey)*vec3(.85,.66,.58),.82);}vec2 stain_uv=vec2(p.x/.55+.5,1.-(p.y-.72)/.85);float inside=step(0.,stain_uv.x)*step(stain_uv.x,1.)*step(0.,stain_uv.y)*step(stain_uv.y,1.);vec4 stain=texture(blood_map,stain_uv);float mask=stain.a*inside*smoothstep(.06,.15,p.z);if(!apron)mask*=.38;ALBEDO=mix(cloth,stain.rgb*vec3(.45,.32,.30),mask*.95);ROUGHNESS=mix(.96,.48,mask);SPECULAR=mix(.14,.42,mask);NORMAL_MAP=texture(fibres,grain_uv).rgb;NORMAL_MAP_DEPTH=.36;}
