shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

// Hand-painted-looking billboard art, generated. Bold gradient, big sun disc,
// halftone dots and speed streaks. `energy` lets it glow through bloom.

uniform vec4 col_a : source_color = vec4(0.98, 0.35, 0.55, 1.0);
uniform vec4 col_b : source_color = vec4(0.22, 0.2, 0.75, 1.0);
uniform vec4 col_c : source_color = vec4(1.0, 0.9, 0.5, 1.0);
uniform float seed = 1.0;
uniform float aspect = 2.0;
uniform float energy = 1.2;
uniform float scroll = 0.0;
uniform float graffiti = 0.0;

float hash11(float p) { return fract(sin(p * 127.1) * 43758.5453); }

void fragment() {
	vec2 uv = UV;
	uv.x += TIME * scroll;
	vec3 col = mix(col_b.rgb, col_a.rgb, smoothstep(0.0, 1.0, uv.y + 0.12 * sin(uv.x * 5.0 + seed)));
	vec2 c = vec2(0.25 + 0.5 * hash11(seed), 0.5 + 0.15 * hash11(seed + 2.0));
	float d = length((UV - c) * vec2(aspect, 1.0));
	col = mix(col, col_c.rgb, smoothstep(0.34, 0.325, d));
	col = mix(col, col_b.rgb * 0.5, smoothstep(0.36, 0.35, d) * (1.0 - smoothstep(0.34, 0.325, d)));
	vec2 g = fract(UV * vec2(aspect, 1.0) * 22.0) - 0.5;
	float dots = smoothstep(0.32, 0.26, length(g)) * smoothstep(0.75, 0.05, UV.y);
	col = mix(col, col * 0.55, dots * 0.6);
	float streak = smoothstep(0.02, 0.0, abs(fract((UV.x * aspect + UV.y * 1.5) * 1.6 + seed) - 0.5) - 0.44);
	col = mix(col, col_c.rgb, streak * 0.5);
	float edge = step(0.03, UV.x) * step(UV.x, 0.97) * step(0.06, UV.y) * step(UV.y, 0.94);
	col = mix(vec3(0.03), col, edge);
	if (graffiti > 0.5) {
		col = mix(col, col * 0.75 + 0.05, 0.3);
	}
	ALBEDO = col * energy;
}
