// The water plane with the same rectangular holes (a stairwell crosses sea level).
shader_type spatial;
render_mode cull_disabled;

uniform vec4 holes[32];
uniform int hole_count = 0;
uniform vec4 albedo : source_color = vec4(0.12, 0.38, 0.62, 0.8);
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
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a;
	ROUGHNESS = 0.1;
}
