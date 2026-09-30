shader_type spatial;
render_mode cull_back;
#include "res://shaders/toon_light.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 rim_color : source_color = vec4(1.0, 0.85, 0.6, 1.0);
uniform float rim_amount = 0.0;
uniform float rim_power = 3.0;
uniform vec4 emission_color : source_color = vec4(0.0, 0.0, 0.0, 1.0);
uniform float emission_energy = 0.0;
uniform float flash = 0.0;
uniform float grunge = 0.0;
uniform float grunge_scale = 0.8;

varying vec3 wpos;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}
float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash21(i), hash21(i + vec2(1, 0)), f.x), mix(hash21(i + vec2(0, 1)), hash21(i + vec2(1, 1)), f.x), f.y);
}

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec3 col = albedo.rgb;
	if (grunge > 0.0) {
		float n = vnoise(vec2(wpos.x + wpos.z, wpos.y) * grunge_scale) * 0.6 + vnoise(vec2(wpos.x - wpos.z, wpos.y) * grunge_scale * 3.1) * 0.4;
		float stain = smoothstep(5.0, 0.0, wpos.y) * 0.5 + n * 0.5;
		col *= 1.0 - grunge * stain * 0.55;
	}
	ALBEDO = mix(col, vec3(1.0), flash);
	float rim = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), rim_power);
	EMISSION = emission_color.rgb * emission_energy + rim_color.rgb * rim * rim_amount + vec3(flash);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
