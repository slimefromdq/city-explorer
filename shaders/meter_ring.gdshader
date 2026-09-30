shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

// Ground ring readout: outer arc = guard, inner pips = dodge charges,
// innermost thin arc = air-dash charges. Readable on the body, not just HUD.

uniform float guard : hint_range(0.0, 1.0) = 1.0;
uniform float dodge_charges = 3.0;
uniform float dash_charges = 3.0;
uniform float pips = 3.0;
uniform float flash = 0.0;
uniform float blocking = 0.0;
uniform float stunned = 0.0;
uniform float threat = 0.0;
uniform vec4 guard_col : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform vec4 guard_low : source_color = vec4(1.0, 0.3, 0.25, 1.0);
uniform vec4 dodge_col : source_color = vec4(1.0, 0.9, 0.35, 1.0);
uniform vec4 dash_col : source_color = vec4(0.85, 0.5, 1.0, 1.0);

const float TAU_F = 6.28318530718;

void fragment() {
	vec2 p = UV - 0.5;
	float r = length(p) * 2.0;
	float a = fract(atan(p.x, -p.y) / TAU_F);
	float alpha = 0.0;
	vec3 col = vec3(0.0);

	// guard arc
	float gr = smoothstep(0.86, 0.87, r) * smoothstep(1.0, 0.99, r);
	if (gr > 0.0) {
		float fill = step(a, guard);
		vec3 gc = mix(guard_low.rgb, guard_col.rgb, smoothstep(0.1, 0.5, guard));
		gc = mix(gc, vec3(1.0), flash * 0.7);
		col = mix(gc * 0.25, gc, fill);
		alpha = gr * mix(0.28, 0.95, fill);
		alpha = max(alpha, gr * blocking * 0.5);
	}
	// dodge pips
	float dr = smoothstep(0.66, 0.67, r) * smoothstep(0.78, 0.77, r);
	if (dr > 0.0) {
		float seg = floor(a * pips);
		float local = fract(a * pips);
		float gap = step(0.08, local) * step(local, 0.92);
		float amt = clamp(dodge_charges - seg, 0.0, 1.0);
		float fill = step(local, amt) * step(1.0, dodge_charges - seg + 0.0001) + step(local, amt) * (1.0 - step(1.0, dodge_charges - seg + 0.0001)) * 0.45;
		vec3 c = dodge_col.rgb;
		col = mix(col, mix(c * 0.25, c, fill), dr * gap);
		alpha = max(alpha, dr * gap * mix(0.25, 0.9, fill));
	}
	// dash pips (thin inner ring)
	float sr = smoothstep(0.5, 0.51, r) * smoothstep(0.57, 0.56, r);
	if (sr > 0.0) {
		float seg = floor(a * pips);
		float local = fract(a * pips);
		float gap = step(0.12, local) * step(local, 0.88);
		float have = step(seg + 1.0, dash_charges + 0.0001);
		vec3 c = dash_col.rgb;
		col = mix(col, mix(c * 0.2, c, have), sr * gap);
		alpha = max(alpha, sr * gap * mix(0.18, 0.75, have));
	}
	// stun: pulsing red disc
	float disc = smoothstep(0.84, 0.0, r) * stunned * (0.25 + 0.2 * sin(TIME * 18.0));
	col = mix(col, vec3(1.0, 0.25, 0.2), disc);
	alpha = max(alpha, disc);
	// threat halo just outside the guard ring
	float halo = smoothstep(1.0, 0.98, r) * smoothstep(0.86, 1.0, r) * threat * 0.6;
	alpha = max(alpha, halo * 0.4);
	ALBEDO = col;
	EMISSION = col * 1.5;
	ALPHA = clamp(alpha, 0.0, 1.0);
}
