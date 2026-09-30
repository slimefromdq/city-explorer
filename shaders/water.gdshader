shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// Stylised water: shallow teal fading to deep blue by scene depth, bright foam
// where it meets the bank, slow crossing ripple lines.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec4 deep_color : source_color = vec4(0.04, 0.16, 0.3, 1.0);
uniform vec4 shallow_color : source_color = vec4(0.22, 0.62, 0.68, 1.0);
uniform vec4 foam_color : source_color = vec4(0.9, 0.97, 1.0, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pixel_pos = upos.xyz / upos.w;
	float thick = max(VERTEX.z - pixel_pos.z, 0.0);
	float deep = smoothstep(0.0, 3.5, thick);
	float foam = 1.0 - smoothstep(0.0, 0.45, thick);
	float r1 = sin(wpos.x * 0.55 + TIME * 0.9) + sin(wpos.z * 0.8 - TIME * 0.7);
	float r2 = sin((wpos.x + wpos.z) * 0.9 + TIME * 1.3);
	float ripple = smoothstep(1.6, 2.0, r1 + r2 * 0.6);
	vec3 col = mix(shallow_color.rgb, deep_color.rgb, deep);
	col = mix(col, foam_color.rgb, clamp(foam * 0.8 + ripple * 0.25, 0.0, 1.0));
	ALBEDO = col;
	ROUGHNESS = 0.08;
	SPECULAR = 0.9;
	METALLIC = 0.0;
	EMISSION = col * 0.18 + foam_color.rgb * foam * 0.25;
	ALPHA = mix(0.55, 0.95, deep) * (1.0 - foam * 0.15);
}
