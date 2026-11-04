shader_type spatial;
uniform sampler2D skin:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D pores:hint_normal,filter_linear_mipmap_anisotropic;
uniform sampler2D blood:source_color,filter_linear_mipmap_anisotropic;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1)),f.x),f.y);}
void fragment(){
 vec3 photo=texture(skin,UV).rgb;
 float gray=dot(photo,vec3(.299,.587,.114));
 vec3 tone=mix(vec3(.055,.039,.028),vec3(.48,.40,.28),smoothstep(.018,.65,gray));
 float mottling=noise(UV*74.)*.6+noise(UV*211.)*.4;
 tone*=.80+.30*mottling;
 vec2 a=(UV-vec2(.425,.300))/vec2(.047,.045),b=(UV-vec2(.575,.300))/vec2(.047,.045);
 float orbit=max(exp(-dot(a,a)*1.6),exp(-dot(b,b)*1.6));
 tone=mix(tone,vec3(.019,.014,.013),orbit*.82);
 float vein=pow(1.-abs(sin(UV.y*255.+noise(UV*42.)*6.)),15.)*smoothstep(.18,.3,UV.y)*(1.-smoothstep(.6,.7,UV.y));
 tone=mix(tone,vec3(.16,.065,.047),vein*.28);
 vec2 q=(UV-vec2(.30,.40))/vec2(.40,.32);
 vec4 stain=texture(blood,clamp(q,0.,1.));
 float bounds=step(0.,q.x)*step(q.x,1.)*step(0.,q.y)*step(q.y,1.);
 float mouth=(1.-smoothstep(.07,.15,abs(UV.x-.5)))*smoothstep(.43,.48,UV.y)*(1.-smoothstep(.64,.72,UV.y));
 float wet=stain.a*bounds*mouth;
 tone=mix(tone,mix(vec3(.085,.006,.009),stain.rgb*vec3(.38,.20,.16),.35),wet*.9);
 ALBEDO=tone;ROUGHNESS=mix(.86,.37,wet);SPECULAR=mix(.23,.38,wet);
 NORMAL_MAP=texture(pores,UV).rgb;NORMAL_MAP_DEPTH=.38;
}
