shader_type spatial;
render_mode cull_disabled, depth_draw_opaque;

// Scratches are fine, fixed surface marks. They never animate like an anomaly.
float hash(vec2 p) { return fract(sin(dot(p,vec2(127.1,311.7)))*43758.5453); }
void fragment() {
 vec2 p=UV;
 float hairline=step(.987,fract((p.x+p.y*.27)*137.0));
 float scratch=hairline*step(.87,hash(floor(vec2(p.x*9.0,p.y*17.0))))*.22;
 float grime=hash(floor(p*19.0))*.045;
 ALBEDO=mix(vec3(.43,.53,.42),vec3(.74,.72,.53),scratch);
 ALPHA=.095+grime+scratch;
 ROUGHNESS=.32+grime+scratch;
 SPECULAR=.28;
}
