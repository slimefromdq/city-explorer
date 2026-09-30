shader_type spatial;
render_mode blend_mix, depth_draw_always, cull_back, specular_schlick_ggx;

// The big river: shallow teal near the quay (depth fade), deep navy beyond,
// horizon-coloured fresnel reflection, a hot sun glitter path toward the sun
// and slow ripples. `sun_dir` points FROM the world TOWARD the sun.

uniform sampler2D depth_tex : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 sun_dir = vec3(0.07, 0.2, 0.98);
uniform vec4 shallow_color : source_color = vec4(0.24, 0.5, 0.56, 1.0);
uniform vec4 deep_color : source_color = vec4(0.04, 0.11, 0.24, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.98, 0.5, 0.36, 1.0);
uniform vec4 zenith_color : source_color = vec4(0.13, 0.17, 0.42, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.7, 0.38, 1.0);
uniform vec4 foam_color : source_color = vec4(0.92, 0.97, 1.0, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec4 upos = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth, 1.0);
	vec3 pix = upos.xyz / upos.w;
	float thick = max(VERTEX.z - pix.z, 0.0);
	float deepf = smoothstep(0.0, 3.0, thick);
	float foam = 1.0 - smoothstep(0.0, 0.45, thick);

	vec2 w = wpos.xz;
	float a = w.x * 0.35 + TIME * 0.6;
	float b = w.y * 0.5 - TIME * 0.45;
	float c = (w.x + w.y) * 0.8 + TIME * 1.1;
	vec3 N = normalize(vec3(cos(a) * 0.05 + cos(c) * 0.03, 1.0, cos(b) * 0.05 + cos(c) * 0.03));
	vec3 V = normalize(CAMERA_POSITION_WORLD - wpos);
	vec3 R = reflect(-V, N);
	float fres = pow(1.0 - clamp(dot(V, N), 0.0, 1.0), 4.0);

	vec3 sky = mix(horizon_color.rgb, zenith_color.rgb, smoothstep(0.0, 0.55, R.y));
	float d = max(dot(R, normalize(sun_dir)), 0.0);
	float glitter = pow(d, 500.0) * 7.0 + pow(d, 24.0) * 0.7;
	glitter *= 0.6 + 0.4 * sin(a * 3.0 + b * 2.0);

	vec3 col = mix(shallow_color.rgb, deep_color.rgb, deepf);
	col = mix(col, sky, clamp(fres * 1.4 + 0.12, 0.0, 1.0));
	col = mix(col, foam_color.rgb, foam * 0.7);
	ALBEDO = col;
	EMISSION = sun_color.rgb * glitter + sky * fres * 0.5;
	ROUGHNESS = 0.05;
	SPECULAR = 0.8;
	ALPHA = mix(0.55, 1.0, deepf);
}
