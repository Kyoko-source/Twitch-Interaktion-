shader_type spatial;
// Dark wet forest floor: needles, leaf litter, moss and standing water.
float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0, a = .5; for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.1; a *= .5; } return s; }
varying vec3 wpos;
void vertex() { wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
void fragment() {
	vec2 p = wpos.xz;
	float n = fbm(p * .3);
	vec3 col = mix(vec3(.05, .04, .03), vec3(.11, .08, .05), n);
	col = mix(col, vec3(.05, .07, .035), smoothstep(.55, .75, fbm(p * .12 + 3.0)));
	float leaf = step(.6, noise(p * 6.0));
	col = mix(col, vec3(.20, .11, .04) * (.5 + hash(floor(p * 6.0))), leaf * .5);
	float puddle = smoothstep(.66, .7, fbm(p * .2 + 9.0));
	ALBEDO = mix(col, vec3(.01), puddle);
	ROUGHNESS = mix(.75, .05, puddle);
}
