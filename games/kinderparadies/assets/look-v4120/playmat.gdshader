shader_type spatial;
// 4.12.0 play-hall floor: interlocking 60 cm EVA foam puzzle mats in faded
// colours, dirt packed into the jigsaw seams, a shiny trodden path where
// thousands of children ran, old chewing gum, black shoe scuffs, foam pores.
uniform float tile=.6;
uniform float tab=.09;
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
float fbm(vec2 p){return noise(p)*.5+noise(p*2.1)*.27+noise(p*4.3)*.15+noise(p*8.9)*.08;}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
// Jigsaw: every seam carries one rounded tab. The shift is a function of the
// nearest seam only, so both neighbours agree on where the edge runs.
vec2 jigsaw(vec2 q){
 vec2 seam=floor(q+.5);vec2 near=q-seam;vec2 f=fract(q);
 float sx=hash(vec2(seam.x,floor(q.y)))<.5?1.:-1.;
 float sy=hash(vec2(floor(q.x),seam.y)+17.)<.5?1.:-1.;
 float dx=tab*sx*exp(-pow((f.y-.5)/.12,2.))*exp(-pow(near.x/.22,2.));
 float dy=tab*sy*exp(-pow((f.x-.5)/.12,2.))*exp(-pow(near.y/.22,2.));
 return q+vec2(dx,dy);
}
void fragment(){
 vec2 q=world.xz/tile;
 vec2 j=jigsaw(q);vec2 id=floor(j);vec2 f=fract(j);
 float seam_d=min(min(f.x,1.-f.x),min(f.y,1.-f.y));
 float seam=1.-smoothstep(.0,.018,seam_d);
 float h=hash(id);
 vec3 palette[4]=vec3[4](vec3(.30,.42,.62),vec3(.66,.30,.28),vec3(.78,.66,.30),vec3(.36,.58,.40));
 vec3 base=palette[int(h*4.)%4];
 base=mix(base,vec3(dot(base,vec3(.3,.59,.11))),.38)*mix(.82,1.,hash(id+7.));   // faded
 // Trodden path: a broad worn band and blotches, shinier and greyer.
 float path=smoothstep(.45,.75,fbm(world.xz*.18+vec2(3.,7.)));
 float grime=fbm(world.xz*1.7)*.6+fbm(world.xz*6.)*.4;
 vec3 col=mix(base,base*.62+vec3(.05,.045,.04),path*.65);
 col*=mix(.82,1.04,grime);
 // Old chewing gum: flat greyish dots.
 vec2 gc=floor(world.xz*2.4);float gum=step(.985,hash(gc+3.1))*(1.-smoothstep(.05,.09,length(fract(world.xz*2.4)-.5)));
 col=mix(col,vec3(.38,.36,.34),gum*.85);
 // Black shoe scuffs: short streaks in random directions.
 vec2 sc=floor(world.xz*1.3);float ang=hash(sc)*6.283;vec2 sf=fract(world.xz*1.3)-.5;
 vec2 dir=vec2(cos(ang),sin(ang));float along=dot(sf,dir);float across=dot(sf,vec2(-dir.y,dir.x));
 float scuff=step(.82,hash(sc+11.))*(1.-smoothstep(.006,.02,abs(across)))*(1.-smoothstep(.12,.25,abs(along)));
 col=mix(col,vec3(.05),scuff*.55);
 col=mix(col,vec3(.07,.06,.05),seam*.85);
 ALBEDO=col;
 float pores=noise(world.xz*140.);
 ROUGHNESS=clamp(mix(.88,.55,path)+pores*.05-gum*.2,.3,.95);
 SPECULAR=.35;
 float gx=noise(world.xz*140.+vec2(.7,0.))-pores;float gz=noise(world.xz*140.+vec2(0.,.7))-pores;
 NORMAL_MAP=normalize(vec3(gx*.6,gz*.6,1.))*.5+.5;NORMAL_MAP_DEPTH=1.;
 // Seams sit lower: darken the ambient light there.
 AO=1.-seam*.6;AO_LIGHT_AFFECT=.6;
}
