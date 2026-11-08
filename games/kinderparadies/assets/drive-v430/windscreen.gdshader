shader_type spatial;
// Rain on the windscreen: beaded drops that refract the road behind them and
// are cleared by the two wiper blades as they pass. UV spans the glass.
render_mode unshaded, blend_mix, cull_disabled, depth_draw_never;

uniform sampler2D screen: hint_screen_texture, filter_linear_mipmap;
uniform float clock = 0.0;
uniform float period = 1.35;
uniform float sweep = 1.75;
uniform vec2 pivot_a = vec2(.20, .02);
uniform vec2 pivot_b = vec2(.62, .02);
uniform float blade = .50;
uniform vec2 glass_size = vec2(1.46, .66);
uniform float flash = 0.0;

float hash(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453); }
vec2 hash2(vec2 p) { return vec2(hash(p), hash(p + 17.31)); }

float age_since_wipe(vec2 uv, vec2 pivot) {
	vec2 d = (uv - pivot) * glass_size;
	if (length(d) > blade * 1.02 || d.y < 0.0) return 1e3;
	// Blade rests pointing along +x at the base and sweeps up anticlockwise.
	float theta = clamp(atan(d.y, d.x), 0.0, sweep);
	float tau = mod(clock, period);
	float up = acos(1.0 - 2.0 * theta / sweep) / (2.0 * PI) * period;
	float down = period - up;
	float last = tau >= down ? down : (tau >= up ? up : down - period);
	return tau - last;
}

void fragment() {
	vec2 uv = vec2(UV.x, 1.0 - UV.y);
	float age = min(age_since_wipe(uv, pivot_a), age_since_wipe(uv, pivot_b));
	vec2 cells = vec2(46.0, 22.0);
	vec2 refract_off = vec2(0.0);
	float drop = 0.0;
	for (int layer = 0; layer < 2; layer++) {
		vec2 g = uv * cells * (1.0 + float(layer) * .7);
		vec2 id = floor(g);
		vec2 f = fract(g) - .5;
		vec2 r = hash2(id + float(layer) * 9.1);
		vec2 c = (r - .5) * .6;
		float rad = mix(.08, .24, hash(id + 3.3)) * (layer == 0 ? 1.0 : .7);
		// Each drop lands at its own moment after the blade left this spot.
		float lands = hash(id + 7.7) * period * .9;
		float present = smoothstep(lands, lands + .05, age);
		vec2 q = f - c;
		q.y *= 1.25;
		float m = smoothstep(rad, rad * .55, length(q)) * present * step(.35, hash(id + 1.9));
		drop = max(drop, m);
		refract_off += q * m * .9;
	}
	vec2 suv = SCREEN_UV - refract_off * .04 + vec2(0.0, .006) * drop;
	vec3 behind = textureLod(screen, suv, 1.5 * drop).rgb;
	// Thin smeared film where the blades just passed, plus road grime at the base.
	float smear = (1.0 - smoothstep(0.0, .25, age)) * .25 * step(age, 100.0);
	float grime = smoothstep(.22, 0.0, uv.y) * .35 + (1.0 - smoothstep(0.0, .05, min(uv.x, 1.0 - uv.x))) * .3;
	ALBEDO = behind * (.82 + flash * .5) + vec3(.02, .025, .03) * (smear + grime);
	ALPHA = clamp(drop * .7 + smear * .3 + grime * .8 + .02, 0.0, 1.0);
}
