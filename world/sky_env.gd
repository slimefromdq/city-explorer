class_name SkyEnv
extends RefCounted
## Blue-dusk mood: warm horizon, cool sky, hazy distance, bloom on lit windows,
## screen-space reflections so wet streets mirror the neon.

static func build(parent: Node) -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.17, 0.42)
	sky_mat.sky_horizon_color = Color(0.85, 0.5, 0.55)
	sky_mat.ground_horizon_color = Color(0.55, 0.38, 0.5)
	sky_mat.ground_bottom_color = Color(0.1, 0.1, 0.2)
	sky_mat.sky_curve = 0.18
	sky_mat.sun_angle_max = 25.0
	var sky := Sky.new()
	sky.sky_material = sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 1.35
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.glow_enabled = true
	env.glow_intensity = 0.65
	env.glow_bloom = 0.12
	env.glow_hdr_threshold = 1.0
	env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SCREEN
	env.fog_enabled = true
	env.fog_light_color = Color(0.5, 0.45, 0.68)
	env.fog_density = 0.0017
	env.fog_aerial_perspective = 0.55
	env.fog_sky_affect = 0.35
	env.ssr_enabled = true
	env.ssr_max_steps = 48
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.5
	env.ssao_enabled = true
	env.ssao_radius = 1.6
	env.ssao_intensity = 1.6
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	env.adjustment_contrast = 1.06
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-33.0, -58.0, 0.0)
	sun.light_color = Color(1.0, 0.72, 0.5)
	sun.light_energy = 1.7
	sun.shadow_enabled = true
	sun.shadow_blur = 0.4
	sun.light_angular_distance = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	parent.add_child(sun)
	return we
