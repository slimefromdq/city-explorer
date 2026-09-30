shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled, blend_mix;

uniform float health : hint_range(0.0, 1.0) = 1.0;
uniform vec4 fill : source_color = vec4(0.4, 1.0, 0.5, 1.0);

void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(INV_VIEW_MATRIX[0], INV_VIEW_MATRIX[1], INV_VIEW_MATRIX[2], MODEL_MATRIX[3]);
}

void fragment() {
	float edge = step(0.02, UV.x) * step(UV.x, 0.98) * step(0.15, UV.y) * step(UV.y, 0.85);
	float on = step(UV.x, health);
	vec3 c = mix(vec3(0.05, 0.05, 0.08), fill.rgb, on);
	ALBEDO = c;
	ALPHA = edge * 0.9;
}
