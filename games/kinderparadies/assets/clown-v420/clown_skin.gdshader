shader_type spatial;
uniform sampler2D skin:source_color,filter_linear_mipmap_anisotropic;
uniform sampler2D pores:hint_normal,filter_linear_mipmap_anisotropic;
void fragment(){
 vec3 paint=texture(skin,UV).rgb;
 // Fresh red areas stay wet; the dry greasepaint keeps a dull, powdery surface.
 float wet=clamp((paint.r-max(paint.g,paint.b))*3.2,0.,1.);
 ALBEDO=paint;
 ROUGHNESS=mix(.74,.24,wet);
 SPECULAR=mix(.26,.55,wet);
 NORMAL_MAP=texture(pores,UV).rgb;
 NORMAL_MAP_DEPTH=.62;
}
