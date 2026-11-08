shader_type spatial;
// Mummified, rotting skin: tanned leather pulled tight, black-green
// putrefaction in the hollows, split cracks, pale furred mould and a wet
// sheen where fluids still seep. World-space so it needs no UVs.
uniform sampler2D micro: hint_normal, filter_linear_mipmap, repeat_enable;
varying vec3 wpos;
varying vec3 wnrm;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
	vec3 i = floor(p), f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(hash(i), hash(i + vec3(1,0,0)), f.x), mix(hash(i + vec3(0,1,0)), hash(i + vec3(1,1,0)), f.x), f.y),
	           mix(mix(hash(i + vec3(0,0,1)), hash(i + vec3(1,0,1)), f.x), mix(hash(i + vec3(0,1,1)), hash(i + vec3(1,1,1)), f.x), f.y), f.z);
}
float fbm(vec3 p) { float s = 0.0, a = .5; for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.13; a *= .5; } return s; }
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz); }
void fragment() {
	vec3 p = wpos * 9.0;
	float n = fbm(p);
	vec3 leather = mix(vec3(.16, .10, .06), vec3(.33, .24, .15), n);
	leather = mix(leather, vec3(.22, .21, .17), smoothstep(.55, .8, fbm(p * .5 + 3.0)) * .6);
	float rot = smoothstep(.5, .75, fbm(p * .7 + 11.0));
	vec3 col = mix(leather, vec3(.03, .035, .02), rot * .85);
	float crack = 1.0 - smoothstep(.0, .03, abs(fbm(p * 2.2 + 5.0) - .5));
	col *= 1.0 - crack * .65;
	float mould = smoothstep(.7, .82, fbm(p * 1.6 + 21.0)) * (.6 + .4 * noise(p * 30.0));
	col = mix(col, vec3(.55, .58, .48), mould * .75);
	float wet = smoothstep(.62, .78, fbm(p * .9 + 40.0)) * (1.0 - mould);
	ALBEDO = col * .4 * (1.0 - wet * .35);
	ROUGHNESS = mix(.82, .22, wet) + mould * .15;
	SPECULAR = mix(.25, .55, wet);
	vec3 tri = abs(wnrm);
	vec2 uv = tri.y > .6 ? wpos.xz : (tri.x > tri.z ? wpos.zy : wpos.xy);
	NORMAL_MAP = texture(micro, uv * 14.0).rgb;
	NORMAL_MAP_DEPTH = .9 + crack;
}
