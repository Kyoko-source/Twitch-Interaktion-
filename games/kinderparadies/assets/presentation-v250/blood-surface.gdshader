shader_type spatial;
render_mode cull_disabled;
uniform sampler2D blood_map : source_color, filter_linear_mipmap_anisotropic;
uniform float dryness : hint_range(0.0,1.0)=0.15;
void fragment(){
 vec4 stain=texture(blood_map,UV);
 ALBEDO=stain.rgb*vec3(.70,.50,.45);
 ALPHA=stain.a;
 ALPHA_SCISSOR_THRESHOLD=.18;
 float crust=dot(stain.rgb,vec3(.21,.72,.07));
 ROUGHNESS=max(mix(.76,.17,smoothstep(.06,.31,crust)),dryness*.86);
 METALLIC=0.0;SPECULAR=.62;
 vec2 pixel=1.0/vec2(textureSize(blood_map,0));
 float x=texture(blood_map,UV+vec2(pixel.x,0)).r-texture(blood_map,UV-vec2(pixel.x,0)).r;
 float y=texture(blood_map,UV+vec2(0,pixel.y)).r-texture(blood_map,UV-vec2(0,pixel.y)).r;
 NORMAL_MAP=normalize(vec3(-x*2.6,-y*2.6,1.0))*.5+.5;
 NORMAL_MAP_DEPTH=.7;
}
