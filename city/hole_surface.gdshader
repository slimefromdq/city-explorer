// Opaque city surface (vertex-coloured ground, lot patches) that can have rectangular holes cut in it,
// so a stairwell can pass through. Holes are world-space (min x, min z, max x, max z).
shader_type spatial;

uniform vec4 holes[32];
uniform int hole_count = 0;
varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	for (int i = 0; i < hole_count; i++) {
		vec4 h = holes[i];
		if (world_pos.x > h.x && world_pos.x < h.z && world_pos.z > h.y && world_pos.z < h.w) {
			discard;
		}
	}
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
