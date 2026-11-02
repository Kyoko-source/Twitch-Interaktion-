shader_type spatial;
render_mode blend_mix,depth_draw_never,cull_back,shadows_disabled;
uniform sampler2D drawings:source_color,filter_linear_mipmap_anisotropic,repeat_disable;
uniform vec2 cell=vec2(0.0);
uniform float age=.7;
uniform float seed=0.0;
void fragment(){
 vec4 ink=texture(drawings,(cell+mix(vec2(.005),vec2(.995),UV))/3.0);
 float rubbed=.86+.14*sin(UV.y*127.+seed)*sin(UV.x*91.);
 ALBEDO=ink.rgb*.68;ALPHA=ink.a*age*rubbed;ROUGHNESS=1.;SPECULAR=.04;
}
