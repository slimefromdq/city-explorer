shader_type spatial;
render_mode cull_back;
#include "res://shaders/toon_light.gdshaderinc"

// Procedural building facade in world space: works on any box size, keeps
// window size constant, lights a random share of windows (warm homes / cool
// offices) so dusk skylines glow.

uniform vec4 wall_color : source_color = vec4(0.45, 0.32, 0.28, 1.0);
uniform vec4 roof_color : source_color = vec4(0.16, 0.16, 0.2, 1.0);
uniform vec4 window_dark : source_color = vec4(0.09, 0.13, 0.24, 1.0);
uniform vec4 lit_warm : source_color = vec4(1.0, 0.72, 0.38, 1.0);
uniform vec4 lit_cool : source_color = vec4(0.6, 0.85, 1.0, 1.0);
uniform vec4 store_glow : source_color = vec4(1.0, 0.8, 0.5, 1.0);
uniform float lit_ratio = 0.35;
uniform float cool_ratio = 0.3;
uniform vec2 cell = vec2(3.2, 3.6);
uniform vec2 win_frac = vec2(0.55, 0.55);
uniform float store_height = 4.6;
uniform float seed = 1.0;
uniform float glow = 0.85;

varying vec3 wpos;
varying vec3 wnorm;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnorm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 n = normalize(wnorm);
	vec3 col;
	vec3 em = vec3(0.0);
	if (abs(n.y) > 0.5) {
		float g = hash21(floor(wpos.xz * 1.5)) * 0.15;
		col = roof_color.rgb * (0.9 + g);
	} else {
		float u = abs(n.z) > abs(n.x) ? wpos.x : wpos.z;
		float salt = seed + floor(n.x * 2.0 + n.z * 5.0);
		col = wall_color.rgb;
		// wall grime toward the street
		col *= 1.0 - 0.3 * smoothstep(6.0, 0.0, wpos.y) * hash21(vec2(floor(u * 0.7), salt));
		if (wpos.y < store_height) {
			// storefront band: wide glazing with mullions
			vec2 sc = vec2(cell.x * 1.8, store_height);
			vec2 f = fract(vec2(u, wpos.y) / sc);
			float inside = step(0.08, f.x) * step(f.x, 0.92) * step(0.06, f.y) * step(f.y, 0.86);
			float id = floor(u / sc.x);
			float on = step(0.25, hash21(vec2(id, salt + 7.0)));
			col = mix(col, window_dark.rgb, inside);
			em = store_glow.rgb * inside * on * 0.55 * glow;
		} else {
			vec2 p = vec2(u, wpos.y - store_height) / cell;
			vec2 id = floor(p);
			vec2 f = fract(p);
			vec2 m = (1.0 - win_frac) * 0.5;
			float inside = step(m.x, f.x) * step(f.x, 1.0 - m.x) * step(m.y, f.y) * step(f.y, 1.0 - m.y);
			float r = hash21(id + salt * 3.7);
			float lit = step(r, lit_ratio);
			float cool = step(hash21(id + salt * 9.1), cool_ratio);
			vec3 lc = mix(lit_warm.rgb, lit_cool.rgb, cool);
			col = mix(col, window_dark.rgb, inside);
			em = lc * inside * lit * glow * (0.7 + 0.5 * hash21(id + 3.3));
			// sill
			col = mix(col, col * 0.6, step(f.y, m.y) * step(m.y - 0.08, f.y) * step(m.x - 0.05, f.x) * step(f.x, 1.0 - m.x + 0.05));
		}
	}
	ALBEDO = col;
	EMISSION = em;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
