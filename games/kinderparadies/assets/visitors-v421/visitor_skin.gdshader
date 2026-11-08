shader_type spatial;
// Dead, waxy skin for the night visitors' bodies and limbs: grey-yellow base,
// livid bruising, dark branching veins and dried blood around neck and chest.
uniform sampler2D pores:hint_normal,filter_linear_mipmap,repeat_enable;
varying vec3 p;
float hash(vec3 q){return fract(sin(dot(q,vec3(127.1,311.7,74.7)))*43758.5453);}
float noise(vec3 q){vec3 i=floor(q),f=fract(q);f=f*f*(3.-2.*f);
 return mix(mix(mix(hash(i),hash(i+vec3(1,0,0)),f.x),mix(hash(i+vec3(0,1,0)),hash(i+vec3(1,1,0)),f.x),f.y),
            mix(mix(hash(i+vec3(0,0,1)),hash(i+vec3(1,0,1)),f.x),mix(hash(i+vec3(0,1,1)),hash(i+vec3(1,1,1)),f.x),f.y),f.z);}
float fbm(vec3 q){return noise(q)*.5+noise(q*2.1)*.3+noise(q*4.3)*.2;}
void vertex(){p=VERTEX;}
void fragment(){
 vec3 base=mix(vec3(.22,.20,.16),vec3(.31,.28,.22),fbm(p*9.));
 float bruise=smoothstep(.55,.8,fbm(p*3.5+3.1));
 base=mix(base,vec3(.27,.22,.27),bruise*.7);
 base=mix(base,vec3(.30,.33,.22),smoothstep(.6,.85,fbm(p*5.+11.))*.45);
 float vein=1.-smoothstep(.0,.035,abs(fbm(p*13.+7.)-.5));
 base*=1.-vein*.38*smoothstep(.4,.7,fbm(p*2.+1.));
 // Dried blood runs from the neck down the chest and pools in the creases.
 float front=smoothstep(-.01,.05,p.z);
 float run=smoothstep(.55,.85,noise(vec3(p.x*30.,0.,0.)))*smoothstep(1.0,1.62,p.y)*smoothstep(1.85,1.6,p.y)*front;
 float neck=smoothstep(1.52,1.7,p.y)*smoothstep(1.85,1.72,p.y)*smoothstep(.35,.6,fbm(p*11.));
 float blood=clamp(run*.9+neck*.85,0.,1.);
 ALBEDO=mix(base,vec3(.22,.03,.025),blood);
 ROUGHNESS=mix(.62,.45,blood);SPECULAR=.26;
 vec2 uv=abs(NORMAL.y)>.7?p.xz:(abs(NORMAL.x)>abs(NORMAL.z)?p.zy:p.xy);
 NORMAL_MAP=texture(pores,uv*18.).rgb;NORMAL_MAP_DEPTH=.35;
}
