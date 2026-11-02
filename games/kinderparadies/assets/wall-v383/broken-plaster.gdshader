shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_back;
uniform sampler2D albedo_map:source_color,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D normal_map:hint_normal,filter_linear_mipmap_anisotropic,repeat_enable;
uniform sampler2D rough_map:filter_linear_mipmap_anisotropic,repeat_enable;
uniform vec4 centres[12];
// X = horizontal radius, Y = vertical radius, Z = variation seed.
uniform vec4 shapes[12];
uniform vec3 directions[12];
uniform int patch_count=0;
varying vec3 wall_point;
varying vec3 wall_normal;
float hash(vec2 p){return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453);}
float noise(vec2 p){vec2 i=floor(p);vec2 f=fract(p);f=f*f*(3.-2.*f);return mix(mix(hash(i),hash(i+vec2(1,0)),f.x),mix(hash(i+vec2(0,1)),hash(i+vec2(1,1)),f.x),f.y);}
void vertex(){wall_point=(MODEL_MATRIX*vec4(VERTEX,1.)).xyz;wall_normal=normalize(mat3(MODEL_MATRIX)*NORMAL);}
void fragment(){
 float coverage=0.;float boundary=0.;vec2 sample_uv=vec2(0.);vec3 facing=vec3(0,0,1);vec3 tangent=vec3(1,0,0);
 for(int i=0;i<12;i++){
  if(i>=patch_count)break;
  vec3 normal= directions[i];vec3 relative=wall_point-centres[i].xyz;
  if(dot(normalize(wall_normal),normal)<.94 || abs(dot(relative,normal))>.028)continue;
  vec3 across=abs(normal.x)>.5?vec3(0,0,1):vec3(1,0,0);
  vec2 p=vec2(dot(relative,across),relative.y);
  vec2 q=p/shapes[i].xy;
  if(dot(q,q)>1.8)continue;
  float seed=shapes[i].z;
  float jagged=(noise(p*3.7+seed)-.5)*.24+(noise(p*15.7-seed)-.5)*.08;
  float edge=length(q)+jagged;
  float amount=1.-smoothstep(.83,1.,edge);
  if(amount>coverage){
   coverage=amount;boundary=(1.-smoothstep(.035,.085,abs(edge-.88)))*.18;
   // The scan covers about 1.85 m. Brick courses always remain horizontal.
   sample_uv=vec2(dot(wall_point,across),-wall_point.y)/1.85+vec2(seed*.137,seed*.071);
   tangent=across;facing=normal;
  }
 }
 if(coverage<.004)discard;
 vec3 colour=texture(albedo_map,sample_uv).rgb;
 ALBEDO=mix(colour*.88,vec3(.58,.53,.40),boundary);
 // Godot's VRAM normal import stores RG (BC5). Reconstruct positive Z.
 vec2 xy=(texture(normal_map,sample_uv).rg*2.-1.)*.78;
 vec3 detail=vec3(xy,sqrt(max(.001,1.-dot(xy,xy))));
 NORMAL=normalize((VIEW_MATRIX*vec4(normalize(tangent*detail.x+vec3(0,1,0)*detail.y+facing*detail.z),0.)).xyz);
 ROUGHNESS=clamp(texture(rough_map,sample_uv).r,.72,1.);SPECULAR=.12;
 ALPHA=coverage*.97;
}
