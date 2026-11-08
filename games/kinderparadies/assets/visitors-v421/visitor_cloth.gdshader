shader_type spatial;
// Woven, filthy, blood-soaked clothing for the rebuilt night visitors.
uniform sampler2D textile:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D fibres:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D blood_map:source_color,filter_linear_mipmap_anisotropic;
uniform vec4 tint:source_color=vec4(.6,.58,.53,1.);
varying vec3 p;
varying vec3 n;
float hash(vec2 q){return fract(sin(dot(q,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 q){vec2 i=floor(q),f=fract(q);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){p=VERTEX;n=NORMAL;}
void fragment(){
 vec3 an=abs(n);
 vec2 uv=an.x>an.z?vec2(p.z,p.y):vec2(p.x,p.y);uv*=6.5;
 vec3 weave=texture(textile,uv).rgb;
 float grey=dot(weave,vec3(.299,.587,.114));
 vec3 cloth=tint.rgb*(.55+grey*.75);
 // Pale shirts and shrouds are never clean: yellowed, sweat- and dirt-stained.
 float pale=smoothstep(.4,.62,dot(tint.rgb,vec3(.333)));
 float stains=smoothstep(.35,.8,noise(vec2(p.x*7.,p.y*5.)+p.z*4.));
 cloth*=mix(vec3(1.),mix(vec3(.62,.55,.42),vec3(.42,.36,.27),stains),pale);
 // Filth climbs up from the hem; wet patches darken the cloth.
 float hem=1.-smoothstep(.35,1.25,p.y);
 float wet=smoothstep(.52,.75,noise(vec2(p.x*3.,p.y*2.2)+vec2(p.z*3.,0.)));
 cloth*=1.-hem*.45-wet*.3;
 cloth=mix(cloth,vec3(.16,.12,.08),hem*.35);
 // Blood pours from the neck down the front and drips in streaks.
 vec2 su=vec2(p.x/.62+.5,(1.72-p.y)/.95);
 float inside=step(0.,su.x)*step(su.x,1.)*step(0.,su.y)*step(su.y,1.);
 float front=smoothstep(-.02,.06,p.z);
 float drip=smoothstep(.62,.9,noise(vec2(p.x*38.,0.)))*smoothstep(.75,1.45,p.y)*front;
 vec4 stain=texture(blood_map,su);
 float blood=clamp(stain.a*inside*front*(.9+pale*.3)+drip*smoothstep(.2,1.,noise(vec2(p.x*20.,p.y*3.)))*(.8+pale*.2),0.,1.);
 vec3 dried=vec3(.20,.03,.025)*(.7+.5*stain.r);
 ALBEDO=mix(cloth,dried,blood);
 ROUGHNESS=mix(.96,.42,blood*(1.-hem));
 SPECULAR=mix(.12,.38,blood);
 NORMAL_MAP=texture(fibres,uv).rgb;NORMAL_MAP_DEPTH=mix(.45,.15,blood);
}
