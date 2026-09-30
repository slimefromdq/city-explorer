// Shared cel-shading light function: two hard bands, no gradient.
void light() {
	float ndl = dot(NORMAL, LIGHT);
	float band = smoothstep(0.0, 0.04, ndl) * 0.6 + smoothstep(0.5, 0.54, ndl) * 0.4;
	DIFFUSE_LIGHT += band * ATTENUATION * LIGHT_COLOR / PI;
}
