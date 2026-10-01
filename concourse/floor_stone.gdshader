// Two-tone tiled stone floor with a border band along the walls and a
// compass-rose inlay at the hall centre. Everything is in hall-local metres,
// centred on the hall origin, so it follows the hall's size and position.
shader_type spatial;

uniform vec2 half_size = vec2(20.0, 15.0);          // half of (hall length, hall width)
uniform float tile_size = 2.0;
uniform vec4 color_a : source_color = vec4(0.74, 0.70, 0.64, 1.0);
uniform vec4 color_b : source_color = vec4(0.60, 0.56, 0.50, 1.0);
uniform float grout_width = 0.03;
uniform float grout_darkening : hint_range(0.0, 1.0) = 0.3;
uniform float border_width = 1.6;                   // band along the walls
uniform vec4 border_color : source_color = vec4(0.46, 0.41, 0.36, 1.0);
uniform vec4 accent_color : source_color = vec4(0.86, 0.80, 0.66, 1.0);
uniform float inlay_radius = 7.0;                   // 0 = no inlay
uniform vec4 inlay_color : source_color = vec4(0.40, 0.31, 0.22, 1.0);

varying vec2 local_xz;

void vertex() {
	local_xz = VERTEX.xz;
}

void fragment() {
	vec2 p = local_xz;

	// Checkerboard with a thin darker grout line.
	vec2 cell = floor(p / tile_size);
	vec3 col = mix(color_a.rgb, color_b.rgb, mod(cell.x + cell.y, 2.0));
	vec2 f = fract(p / tile_size) * tile_size;
	vec2 e = min(f, vec2(tile_size) - f);
	col = mix(col, col * (1.0 - grout_darkening), step(min(e.x, e.y), grout_width));

	// Border band along the walls, with a thin accent line inside it.
	vec2 edge = half_size - abs(p);
	float wall_dist = min(edge.x, edge.y);
	if (wall_dist < border_width) {
		col = border_color.rgb;
		float line = step(abs(wall_dist - border_width * 0.8), border_width * 0.05);
		col = mix(col, accent_color.rgb, line);
	}

	// Compass-rose inlay: outer ring, thin inner ring, 8-point star on a plain disc.
	float R = inlay_radius;
	float r = length(p);
	if (R > 0.0 && r < R) {
		col = color_a.rgb;
		float a = atan(p.y, p.x);
		float da = abs(mod(a + PI * 0.25, PI * 0.5) - PI * 0.25);  // angle off the nearest N/E/S/W
		float db = PI * 0.25 - da;                                  // angle off the nearest diagonal
		float tip = R - 1.3;
		float star_major = step(r, tip * max(1.0 - da / 0.42, 0.0));
		float star_minor = step(r, tip * 0.62 * max(1.0 - db / 0.38, 0.0));
		col = mix(col, inlay_color.rgb, max(star_major, star_minor));
		col = mix(col, accent_color.rgb, step(r, tip * 0.12));      // small centre boss
		float ring_outer = step(R - 0.4, r);
		float ring_inner = step(abs(r - (R - 0.85)), 0.05);
		col = mix(col, inlay_color.rgb, ring_outer);
		col = mix(col, accent_color.rgb, ring_inner);
	}

	ALBEDO = col;
	ROUGHNESS = 0.55;
}
