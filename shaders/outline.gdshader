shader_type spatial;
render_mode cull_front, unshaded, shadows_disabled;

uniform vec4 color : source_color = vec4(0.04, 0.03, 0.08, 1.0);
uniform float thickness = 0.02;

void vertex() {
	VERTEX += NORMAL * thickness;
}

void fragment() {
	ALBEDO = color.rgb;
}
