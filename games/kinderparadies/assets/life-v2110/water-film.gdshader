shader_type spatial;
render_mode cull_disabled,depth_draw_never;
uniform vec2 span=vec2(1.,1.);
void fragment(){
 float radius=length(UV/span);
 ALBEDO=vec3(.13,.18,.15);
 ROUGHNESS=.075;METALLIC=.04;CLEARCOAT=.9;CLEARCOAT_ROUGHNESS=.1;
 ALPHA=(1.-smoothstep(.52,.91,radius))*.32;
}
