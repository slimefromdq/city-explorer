shader_type spatial;
// World-space grid for greybox geometry: thin lines every metre, bold lines
// every 5 m. Lets you read distances, heights and speed at a glance.

uniform vec3 tint : source_color = vec3(0.6, 0.62, 0.66);
uniform float line_strength = 0.35;

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

float grid_line(vec2 p, float spacing, float width) {
	vec2 g = abs(fract(p / spacing - 0.5) - 0.5) * spacing;
	vec2 fw = fwidth(p);
	vec2 l = 1.0 - smoothstep(vec2(width) - fw, vec2(width) + fw, g);
	return max(l.x, l.y);
}

void fragment() {
	// Pick the two world axes that lie across this face.
	vec3 n = abs(world_normal);
	vec2 p = n.y > 0.5 ? world_pos.xz : (n.x > n.z ? world_pos.zy : world_pos.xy);
	float minor = grid_line(p, 1.0, 0.015);
	float major = grid_line(p, 5.0, 0.04);
	float shade = 1.0 - line_strength * max(minor * 0.55, major);
	ALBEDO = tint * shade;
	ROUGHNESS = 0.85;
}
