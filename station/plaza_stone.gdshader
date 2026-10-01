// The forecourt paving: the hall floor's two-tone checker (same tile grid, in station-frame metres, so
// the two floors line up), with a border band round the rectangle and a compass inlay at `center`.
shader_type spatial;

uniform vec2 center = vec2(81.0, 0.0);
uniform vec2 half_size = vec2(32.0, 42.5);
uniform float tile_size = 2.0;
uniform vec4 color_a : source_color = vec4(0.74, 0.70, 0.64, 1.0);
uniform vec4 color_b : source_color = vec4(0.60, 0.56, 0.50, 1.0);
uniform float grout_width = 0.03;
uniform float grout_darkening : hint_range(0.0, 1.0) = 0.3;
uniform float border_width = 1.6;
uniform vec4 border_color : source_color = vec4(0.46, 0.41, 0.36, 1.0);
uniform vec4 accent_color : source_color = vec4(0.86, 0.80, 0.66, 1.0);
uniform float inlay_radius = 9.0;
uniform vec4 inlay_color : source_color = vec4(0.40, 0.31, 0.22, 1.0);

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	vec2 p = local_xz;
	vec2 cell = floor(p / tile_size);
	vec3 col = mix(color_a.rgb, color_b.rgb, mod(cell.x + cell.y, 2.0));
	vec2 f = fract(p / tile_size) * tile_size;
	vec2 e = min(f, vec2(tile_size) - f);
	col = mix(col, col * (1.0 - grout_darkening), step(min(e.x, e.y), grout_width));

	vec2 q = p - center;
	vec2 edge = half_size - abs(q);
	float wall_dist = min(edge.x, edge.y);
	if (border_width > 0.0 && wall_dist < border_width) {
		col = border_color.rgb;
		float line = step(abs(wall_dist - border_width * 0.8), border_width * 0.05);
		col = mix(col, accent_color.rgb, line);
	}

	float R = inlay_radius;
	float r = length(q);
	if (R > 0.0 && r < R) {
		col = color_a.rgb;
		float a = atan(q.y, q.x);
		float da = abs(mod(a + PI * 0.25, PI * 0.5) - PI * 0.25);
		float db = PI * 0.25 - da;
		float tip = R - 1.3;
		float star_major = step(r, tip * max(1.0 - da / 0.42, 0.0));
		float star_minor = step(r, tip * 0.62 * max(1.0 - db / 0.38, 0.0));
		col = mix(col, inlay_color.rgb, max(star_major, star_minor));
		col = mix(col, accent_color.rgb, step(r, tip * 0.12));
		col = mix(col, inlay_color.rgb, step(R - 0.4, r));
		col = mix(col, accent_color.rgb, step(abs(r - (R - 0.85)), 0.05));
	}
	ALBEDO = col;
	ROUGHNESS = 0.6;
}
