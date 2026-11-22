shader_type spatial;
// Matted blond locks for the kitchen clown (5.2.7). Every lock is wide enough
// to stay above a pixel; the fibres are stripes inside it and fade out as soon
// as they would get smaller than a pixel, so nothing sparkles in motion.
// UV.x: lock seed (integer part) + across the ribbon (fraction).
// UV.y: 1 at the root, 0 at the tip (glTF flips Blender's V).
render_mode cull_disabled, depth_prepass_alpha;

float hash(float n) { return fract(sin(n * 127.1) * 43758.5453); }

void fragment() {
 float seed = floor(UV.x);
 float across = fract(UV.x);
 float along = 1.0 - UV.y;
 float shade = hash(seed);
 vec3 blond = mix(vec3(.2,.14,.06), vec3(.47,.36,.19), shade);
 // Darker, dirtier roots.
 blond = mix(vec3(.07,.045,.018), blond, smoothstep(0.0, .3, along));
 // Fibre stripes, faded by their on-screen size.
 float stripes = across * 5.0 + shade * 3.0;
 float fade = clamp(1.0 - fwidth(stripes) * 1.5, 0.0, 1.0);
 float fibre = mix(1.0, .78 + .22 * smoothstep(.2, .8, abs(fract(stripes) - .5) * 2.0), fade);
 float grime = mix(1.0, .8 + .2 * sin(along * 14.0 + seed), fade);
 ALBEDO = blond * fibre * grime;
 // Soft, rounded lock edge, cut cleanly so it does not crawl.
 float edge = 1.0 - abs(across - .5) * 2.0;
 ALPHA = smoothstep(0.0, .35, edge) * (1.0 - smoothstep(.9, 1.0, along) * .6);
 ALPHA_SCISSOR_THRESHOLD = .35;
 ROUGHNESS = .95;
 SPECULAR = .04;
}
