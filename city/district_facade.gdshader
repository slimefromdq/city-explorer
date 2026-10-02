shader_type spatial;

// Unit-box coordinates become metres per instance, so rotated lots and slopes
// do not skew the windows. Foundation is excluded from the occupied floors.
uniform float foundation = 2.0;
uniform float floor_height = 3.4;
uniform float bay_width = 3.0;
uniform vec2 window_fraction = vec2(0.55, 0.56);
uniform vec3 glass_color : source_color = vec3(0.12, 0.22, 0.29);
uniform vec3 trim_color : source_color = vec3(0.63, 0.57, 0.46);
uniform vec3 roof_color : source_color = vec3(0.24, 0.26, 0.28);
uniform float curtain_wall = 0.0;
uniform float horizontal_bands = 0.0;
uniform float industrial = 0.0;

varying vec3 local_metres;
varying vec3 local_normal;
varying vec3 wall_tint;
varying float building_seed;
varying float roof_height;

void vertex() {
	vec3 size = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	local_metres = (VERTEX + vec3(0.5)) * size;
	local_metres.y -= foundation;
	roof_height = size.y - foundation;
	local_normal = NORMAL;
	wall_tint = COLOR.rgb;
	building_seed = INSTANCE_CUSTOM.x;
}

// Pixel-footprint filtering fades fine details instead of aliasing at distance.
float rectangle_mask(vec2 cell, vec2 half_size, vec2 pixel) {
	vec2 edge = abs(cell - vec2(0.5));
	vec2 mask = vec2(1.0) - smoothstep(half_size - pixel, half_size + pixel, edge);
	return mask.x * mask.y;
}

void fragment() {
	vec3 col = wall_tint;
	float glazing = 0.0;
	if (abs(local_normal.y) > 0.5) {
		col = roof_color;
	} else {
		float across = abs(local_normal.z) > 0.5 ? local_metres.x : local_metres.z;
		float height = local_metres.y;
		vec2 grid = vec2(across / bay_width, height / floor_height);
		vec2 cell = fract(grid);
		vec2 pixel = max(fwidth(grid), vec2(0.001));
		float resolved = 1.0 - smoothstep(0.2, 0.65, max(pixel.x, pixel.y));
		float windows = rectangle_mask(cell, window_fraction * 0.5, pixel);
		// When a window is smaller than a pixel, use its average coverage.
		windows = mix(window_fraction.x * window_fraction.y, windows, resolved);
		float occupied = smoothstep(0.1, 0.3, height) * (1.0 - smoothstep(roof_height - 0.45, roof_height - 0.15, height));
		glazing = windows * occupied;
		float pane = fract(sin(dot(floor(grid), vec2(12.9898, 78.233)) + building_seed * 91.7) * 43758.5453);
		vec3 glass = glass_color * mix(0.83, 1.15, mix(0.5, pane, resolved));
		col = mix(col, glass, glazing);
		float line = 1.0 - smoothstep(0.025, 0.025 + pixel.y, min(cell.y, 1.0 - cell.y));
		col = mix(col, trim_color, line * horizontal_bands * resolved * occupied);
		// Shop glazing for residential districts; wider loading bays in the harbour.
		float ground_floor = (1.0 - smoothstep(floor_height - 0.2, floor_height, height)) * occupied;
		vec2 shop_grid = vec2(across / (bay_width * 2.0), height / floor_height);
		float shop = rectangle_mask(fract(shop_grid), vec2(0.40, 0.33), max(fwidth(shop_grid), vec2(0.001)));
		col = mix(col, glass_color * 0.78, ground_floor * shop * (1.0 - curtain_wall));
		float plinth = (1.0 - smoothstep(0.25, 0.65, height));
		col = mix(col, trim_color * 0.64, plinth);
		// Industrial ribbing replaces the fine stone trim with broad cladding seams.
		float rib = 1.0 - smoothstep(0.04, 0.04 + pixel.x, min(cell.x, 1.0 - cell.x));
		col = mix(col, trim_color, rib * industrial * resolved * occupied * 0.5);
	}
	ALBEDO = col;
	ROUGHNESS = mix(0.87, 0.3, glazing * curtain_wall);
	METALLIC = glazing * curtain_wall * 0.25;
	SPECULAR = mix(0.25, 0.65, glazing);
}
