shader_type spatial;
render_mode depth_prepass_alpha;
void fragment(){
 float edge=pow(1.-clamp(dot(NORMAL,VIEW),0.,1.),4.);
 ALBEDO=vec3(.06,.12,.105);ALPHA=.055+edge*.25;
 ROUGHNESS=.13;SPECULAR=.7;CLEARCOAT=.8;CLEARCOAT_ROUGHNESS=.16;
}
