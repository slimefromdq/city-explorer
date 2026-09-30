shader_type spatial;
render_mode unshaded, cull_back, depth_draw_never, shadows_disabled, blend_add;

uniform vec4 color : source_color = vec4(0.35, 0.85, 1.0, 1.0);
uniform float intensity = 0.0;
uniform float power = 2.2;

void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), power);
	float bands = 0.75 + 0.25 * sin(UV.y * 40.0 - TIME * 6.0);
	ALBEDO = color.rgb * (f * 1.4 + 0.08) * bands * intensity;
	ALPHA = clamp((f + 0.12) * intensity, 0.0, 1.0);
}
