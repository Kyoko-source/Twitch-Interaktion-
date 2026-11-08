shader_type spatial;
// A broken, rain-soaked single-track forest road: patched and cracked
// asphalt, potholes full of water, crumbling verges sinking into mud and
// wet leaves. UV.x runs across the road (0..1), UV.y along it in metres/4.
uniform sampler2D albedo_tex: source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_tex: hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 tint: source_color = vec3(.30, .31, .30);

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
float noise(vec2 p) {
	vec2 i = floor(p), f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1, 0)), u.x), mix(hash(i + vec2(0, 1)), hash(i + vec2(1, 1)), u.x), u.y);
}
float fbm(vec2 p) { float s = 0.0, a = .5; for (int i = 0; i < 5; i++) { s += a * noise(p); p *= 2.07; a *= .5; } return s; }

void fragment() {
	vec2 w = vec2(UV.x * 6.0, UV.y * 4.0);   // metres
	vec3 base = texture(albedo_tex, w * .35).rgb * tint * 1.6;
	float n = fbm(w * .45);
	// Crumbling verges: the tarmac edge is eaten into mud.
	float edge = min(UV.x, 1.0 - UV.x) * 6.0 + (fbm(w * 1.3) - .5) * .9;
	float mud = 1.0 - smoothstep(.25, .55, edge);
	// Patched repairs in a darker, fresher tar.
	float patch = step(.68, fbm(w * .22 + 4.0)) * (1.0 - mud);
	// Potholes: irregular holes holding black water.
	float hole = smoothstep(.70, .76, fbm(w * .55 + 11.0)) * (1.0 - mud * .6);
	float rim = smoothstep(.62, .70, fbm(w * .55 + 11.0)) - hole;
	// Cracks.
	float crack = 1.0 - smoothstep(.0, .025, abs(fbm(w * 1.6 + 2.0) - .5));
	vec3 col = base * (.8 + .4 * n);
	col = mix(col, col * .55, patch);
	col *= 1.0 - crack * .6;
	vec3 mud_col = vec3(.11, .085, .06) * (.6 + .6 * fbm(w * 2.5));
	float leaves = step(.62, noise(w * 7.0)) * (mud * .8 + .2);
	mud_col = mix(mud_col, vec3(.22, .13, .05) * (.6 + .8 * hash(floor(w * 7.0))), leaves);
	col = mix(col, mud_col, max(mud, leaves * .7));
	col *= 1.0 - rim * .35;
	// Centre-line ghosts of paint, almost gone.
	float paint = step(abs(UV.x - .5), .012) * step(.5, fract(UV.y * .5)) * step(.45, fbm(w * 3.0));
	col = mix(col, vec3(.55, .53, .45), paint * .6);
	col = mix(col, vec3(.015, .017, .02), hole);
	ALBEDO = col;
	// Everything is wet; puddles and holes are mirrors.
	ROUGHNESS = mix(mix(.34, .22, n), .04, max(hole, step(.6, fbm(w * .3 + 7.0)) * .8));
	ROUGHNESS = mix(ROUGHNESS, .55, mud);
	SPECULAR = .6;
	NORMAL_MAP = mix(texture(normal_tex, w * .35).rgb, vec3(.5, .5, 1.0), max(hole, .3));
	NORMAL_MAP_DEPTH = 1.4;
}
