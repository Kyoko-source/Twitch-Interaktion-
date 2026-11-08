shader_type spatial;
render_mode depth_prepass_alpha,cull_disabled;
uniform float clock=0.;
// A punched-through pane: jagged hole plus radial and concentric cracks.
uniform bool broken=false;
uniform vec2 hole=vec2(.5);
uniform vec2 pane_size=vec2(1.09,2.35);
varying vec3 world;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p),f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+1.),f.x),f.y);}
void vertex(){world=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;}
void fragment(){
 vec2 p=UV;
 float crack=0.;
 if(broken){
  vec2 q=(p-hole)*pane_size;float r=length(q);float a=atan(q.y,q.x);
  float rim=.075+.035*noise(vec2(a*2.6,1.7))+.02*noise(vec2(a*9.,4.2));
  if(r<rim)discard;
  // Radial cracks: a dozen jittered spokes that thin out and stop at random lengths.
  for(int i=0;i<13;i++){
   float fi=float(i);float spoke=fi*.4833+hash(vec2(fi,2.))*.32;
   float bend=a+.06*sin(r*14.+fi);float da=abs(mod(bend-spoke*1.0+3.14159,6.28318)-3.14159);
   float reach=.18+hash(vec2(fi,7.))*.42;
   crack=max(crack,(1.-smoothstep(.0,.0035/max(r,.02),da))*(1.-smoothstep(reach*.7,reach,r)));
  }
  // Two broken concentric rings around the impact.
  for(int k=0;k<2;k++){
   float ring=.13+float(k)*.1+.012*sin(a*5.+float(k));
   crack=max(crack,(1.-smoothstep(.0,.0025,abs(r-ring)))*step(.45,noise(vec2(a*3.+float(k)*9.,0.))));
  }
  crack*=step(rim,r);
 }
 float edge=1.-smoothstep(.025,.15,min(min(p.x,1.-p.x),min(p.y,1.-p.y)));
 vec2 dirt=p+vec2(world.z*.71,world.y*.17);
 float smudge=smoothstep(.56,.84,noise(dirt*vec2(35.,18.))*.45+noise(dirt*vec2(84.,42.))*.55);
 float column=floor(p.x*96.);float drop_phase=fract(clock*(.012+hash(vec2(column,8.))*.023)+hash(vec2(column,3.)));
 float rivulet=exp(-pow((fract(p.x*96.)-.5)*17.,2.))*smoothstep(.0,.07,drop_phase-p.y)*(1.-smoothstep(.28,.40,drop_phase-p.y));
 float grime=clamp(edge*.65+smudge*.40,0.,.85);
 ALBEDO=mix(mix(vec3(.20,.27,.25),vec3(.19,.15,.09),grime),vec3(.78,.80,.76),crack);
 ROUGHNESS=mix(mix(.075,.65,grime),.25,crack);SPECULAR=mix(.30,.6,crack);METALLIC=0.;CLEARCOAT=.25;CLEARCOAT_ROUGHNESS=.18;
 float fresnel=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),4.);
 ALPHA=clamp(.035+grime*.28+fresnel*.20+rivulet*.08+crack*.65,.035,.8);
 NORMAL_MAP=normalize(vec3(sin(p.x*603.+noise(p*20.)*2.)*.018*rivulet,cos(p.y*279.)*.008,1.))*.5+.5;
 NORMAL_MAP_DEPTH=.30;
}
