shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;
varying vec3 scalp_space;
void vertex() { scalp_space = VERTEX; }

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }
void fragment() {
 float fibre = hash(floor(UV.x * 13.0) + floor(scalp_space.x * 231.0));
 float root = smoothstep(0.0, .32, UV.y);
 vec3 blond = mix(vec3(.19,.125,.047), vec3(.57,.435,.215), fibre);
 blond = mix(vec3(.062,.038,.014), blond, root);
 float grime = smoothstep(.2,.85,sin(UV.y*22.0+scalp_space.x*35.0)*.5+.5);
 ALBEDO = blond * mix(.69,1.0,grime);
 ALPHA = smoothstep(0.0,.17,UV.x) * smoothstep(0.0,.17,1.0-UV.x);
 ALPHA_SCISSOR_THRESHOLD = .12;
 ROUGHNESS = .76;
 SPECULAR = .32;
}
