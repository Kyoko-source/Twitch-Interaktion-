shader_type spatial;
render_mode cull_disabled;
uniform sampler2D pores : hint_normal, repeat_enable;
void fragment() {
 vec3 colour=pow(clamp(COLOR.rgb,vec3(0.0),vec3(1.0)),vec3(2.2));
 float blood=smoothstep(.06,.20,COLOR.r-max(COLOR.g,COLOR.b));
 ALBEDO=mix(colour,vec3(.075,.003,.005),blood*.72);
 ROUGHNESS=mix(.91,.48,blood); SPECULAR=mix(.19,.28,blood);
 CLEARCOAT=blood*.08; CLEARCOAT_ROUGHNESS=.55;
 NORMAL_MAP=texture(pores,UV*11.0).rgb; NORMAL_MAP_DEPTH=mix(.28,.16,blood);
}
