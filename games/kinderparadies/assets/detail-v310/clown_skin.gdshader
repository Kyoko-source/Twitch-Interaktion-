shader_type spatial;
uniform sampler2D skin:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D pores:hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D residue:source_color,filter_linear_mipmap_anisotropic;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec3 base=texture(skin,UV).rgb;
 vec2 e1=(UV-vec2(.412,.31))/vec2(.051,.055),e2=(UV-vec2(.585,.31))/vec2(.051,.055);
 float eye=max(exp(-dot(e1,e1)*1.8),exp(-dot(e2,e2)*1.8))*(.78+.18*noise(UV*180.));
 base=mix(base,vec3(.018,.014,.013),eye);
 vec2 q=vec2((UV.x-.34)/.34,(UV.y-.40)/.31);
 float inside=step(0.,q.x)*step(q.x,1.)*step(0.,q.y)*step(q.y,1.);
 vec4 old=texture(residue,clamp(q,0.,1.));
 float lower=smoothstep(.43,.49,UV.y)*(1.-smoothstep(.69,.76,UV.y));
 float stain=old.a*inside*lower*(.72+.28*noise(UV*190.));
 vec2 cheek_uv=(UV-vec2(.29,.29))/vec2(.25,.39);
 vec4 cheek=texture(residue,clamp(cheek_uv,0.,1.));
 float cheek_mask=cheek.a*step(0.,cheek_uv.x)*step(cheek_uv.x,1.)*step(0.,cheek_uv.y)*step(cheek_uv.y,1.)*.80;
 stain=max(stain,cheek_mask);
 float wet=stain*(1.-smoothstep(.50,.66,UV.y));
 ALBEDO=mix(base*.91,mix(old.rgb*vec3(.40,.28,.26),vec3(.17,.008,.014),wet*.36),stain*.92);
 ROUGHNESS=mix(.73,.29,wet);SPECULAR=mix(.28,.48,wet);
 NORMAL_MAP=texture(pores,UV).rgb;NORMAL_MAP_DEPTH=.58;
}
