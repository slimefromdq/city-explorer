// glass_facade - a glass curtain wall: thin vertical frames, a line at every floor,
// tinted reflective panes in between. Used by the landmark tower.
//
// The mesh supplies UV.x = which "bay" around the tower (0..bays) and UV.y = height in metres,
// so the lines stay evenly spaced however the tower tapers. Line edges are softened using the
// screen-space size of a pixel (fwidth), so from far away the lines melt into an even tint
// instead of shimmering.
shader_type spatial;

uniform vec3 glass_color : source_color = vec3(0.42, 0.58, 0.74);
uniform vec3 frame_color : source_color = vec3(0.82, 0.87, 0.92);
uniform float floor_height = 3.4;
uniform float frame_width = 0.08;      // share of a bay taken by each side of a vertical frame
uniform float floor_line = 0.12;       // thickness of the line at each floor (m)
// lattice = 1: only the frames and diagonal bracing are drawn (an open crown)
uniform float lattice = 0.0;
uniform float emission_strength = 0.0;

float soft_line(float distance_to_line, float half_width, float pixel) {
	return 1.0 - smoothstep(half_width, half_width + pixel * 1.5, distance_to_line);
}

void fragment() {
	float bay = fract(UV.x);
	float across = min(bay, 1.0 - bay);                       // 0 at a vertical frame
	float vertical = soft_line(across, frame_width, fwidth(UV.x));
	float level = fract(UV.y / floor_height);
	float along = min(level, 1.0 - level) * floor_height;     // metres from a floor line
	float horizontal = soft_line(along, floor_line, fwidth(UV.y));
	float frame = clamp(vertical + horizontal, 0.0, 1.0);

	if (lattice > 0.5) {
		float d1 = abs(fract(UV.x * 0.5 + UV.y / 24.0) - 0.5);
		float d2 = abs(fract(UV.x * 0.5 - UV.y / 24.0) - 0.5);
		float diagonal = max(soft_line(0.5 - d1, 0.03, fwidth(UV.y)), soft_line(0.5 - d2, 0.03, fwidth(UV.y)));
		float keep = max(vertical, diagonal);
		if (keep < 0.4) {
			discard;
		}
		ALBEDO = frame_color;
		METALLIC = 0.5;
		ROUGHNESS = 0.4;
		EMISSION = frame_color * emission_strength;
	} else {
		ALBEDO = mix(glass_color, frame_color, frame * 0.8);
		METALLIC = mix(0.6, 0.3, frame);
		ROUGHNESS = mix(0.15, 0.45, frame);
		SPECULAR = 0.7;
	}
}
