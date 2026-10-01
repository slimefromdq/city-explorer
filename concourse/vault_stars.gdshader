// Dark teal ceiling with small emissive "stars". UV is in metres (x along the
// hall, y along the vault arc), so dot size and spacing are world-scale and
// stay round however the vault is stretched.
shader_type spatial;

uniform vec4 base_color : source_color = vec4(0.02, 0.17, 0.19, 1.0);
uniform float base_glow : hint_range(0.0, 1.0) = 0.25;  // fraction of base_color self-lit, so the vault stays teal where no light reaches
uniform vec4 star_color : source_color = vec4(1.0, 0.93, 0.7, 1.0);
uniform float cell_size = 1.6;      // grid spacing between candidate stars (m)
uniform float density : hint_range(0.0, 1.0) = 0.45;  // fraction of cells holding a star
uniform float star_radius = 0.07;   // (m)
uniform float star_energy = 4.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void fragment() {
	vec2 p = UV / cell_size;
	vec2 id = floor(p);
	vec2 f = fract(p);
	vec2 centre = vec2(hash21(id + 7.1), hash21(id + 13.7)) * 0.6 + 0.2;
	float present = step(hash21(id), density);
	float r = star_radius / cell_size * (0.6 + 0.8 * hash21(id + 3.3));
	float star = present * smoothstep(r, r * 0.35, length(f - centre));
	ALBEDO = base_color.rgb;
	ROUGHNESS = 0.9;
	EMISSION = base_color.rgb * base_glow + star_color.rgb * star * star_energy;
}
