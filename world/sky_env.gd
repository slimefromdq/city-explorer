class_name SkyEnv
extends RefCounted
## Blue-dusk mood: warm horizon, cool sky, hazy distance, bloom on lit windows,
## screen-space reflections so wet streets mirror the neon.

static func build(parent: Node) -> WorldEnvironment:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.12, 0.17, 0.42)
	sky_mat.sky_horizon_color = Color(0.98, 0.52, 0.36)
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
	sun.rotation_degrees = Vector3(-12.0, 4.0, 0.0)
	sun.light_color = Color(1.0, 0.62, 0.4)
	sun.light_energy = 1.9
	sun.shadow_enabled = true
	sun.shadow_blur = 0.4
	sun.light_angular_distance = 0.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 260.0
	sun.directional_shadow_blend_splits = false
	sun.shadow_bias = 0.04
	sun.shadow_normal_bias = 1.2
	parent.add_child(sun)
	# The sun sits low over the river to the SOUTH. A cool fill light keeps the
	# shaded sides of buildings readable instead of black.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-32.0, 190.0, 0.0)
	fill.light_color = Color(0.4, 0.55, 0.95)
	fill.light_energy = 0.4
	fill.shadow_enabled = false
	parent.add_child(fill)
	var to_sun := sun.transform.basis.z
	Mats.river().set_shader_parameter("sun_dir", to_sun)
	# a big visible sun disc + halo over the far bank (fog-exempt so it glows through the haze)
	var disc := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 110.0
	sm.height = 220.0
	sm.radial_segments = 32
	sm.rings = 16
	disc.mesh = sm
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.albedo_color = Color(3.0, 1.8, 0.8)
	dm.disable_fog = true
	disc.material_override = dm
	disc.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	disc.position = to_sun * 2900.0
	parent.add_child(disc)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 520.0
	hm.height = 1040.0
	hm.radial_segments = 24
	hm.rings = 12
	halo.mesh = hm
	var hmat := StandardMaterial3D.new()
	hmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hmat.albedo_color = Color(1.0, 0.55, 0.25, 0.22)
	hmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hmat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hmat.disable_fog = true
	halo.material_override = hmat
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	halo.position = to_sun * 3000.0
	parent.add_child(halo)
	return we
