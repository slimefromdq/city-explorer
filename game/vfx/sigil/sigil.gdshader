shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never, shadows_disabled;
// A procedural magic circle: two rings, a band of rotating rune ticks, a
// hexagram and a small core. `draw_progress` sweeps it in around the circle,
// `fade` takes it out. Everything is drawn from the quad's UVs, so restyling is
// just editing this file (or swapping the material in sigil.tscn).

uniform vec4 color : source_color = vec4(0.45, 0.85, 1.0, 1.0);
uniform float draw_progress : hint_range(0.0, 1.0) = 1.0;
uniform float fade : hint_range(0.0, 1.0) = 1.0;
uniform float spin = 0.0;
uniform float intensity = 2.2;

float band(float d, float w) {
	float aa = fwidth(d) * 1.2;
	return 1.0 - smoothstep(w - aa, w + aa, abs(d));
}

// Distance from point (r, theta) to the edges of a regular n-gon with apothem ap.
float ngon(float r, float theta, float n, float ap) {
	float seg = TAU / n;
	return r * cos(mod(theta, seg) - seg * 0.5) - ap;
}

void fragment() {
	vec2 p = (UV - 0.5) * 2.0;
	float r = length(p);
	float theta = atan(p.y, p.x) + PI;            // 0..TAU
	float a01 = theta / TAU;

	float rings = band(r - 0.93, 0.025) + band(r - 0.79, 0.012) + band(r - 0.2, 0.02);
	float runes_band = step(0.81, r) * step(r, 0.9);
	float runes = runes_band * step(0.55, fract((a01 + spin) * 36.0)) * step(fract((a01 + spin) * 6.0), 0.85);
	float star = band(ngon(r, theta + spin * 2.0, 3.0, 0.38), 0.012) + band(ngon(r, theta + spin * 2.0 + PI / 3.0, 3.0, 0.38), 0.012);
	star *= step(r, 0.79);
	float glow = smoothstep(1.0, 0.0, r) * 0.12;

	// The draw-in: a sweep around the circle, slightly ahead for the inner parts.
	float reveal = step(a01, draw_progress * 1.02);
	float inner_reveal = step(a01, draw_progress * 1.3 - 0.3);
	float shape = (rings + runes) * reveal + star * inner_reveal + glow * draw_progress;
	shape *= step(r, 1.0);
	ALBEDO = color.rgb * intensity;
	ALPHA = clamp(shape, 0.0, 1.0) * fade * color.a;
}
