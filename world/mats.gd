class_name Mats
extends RefCounted
## Material factory + cache. Everything stylized goes through here so the whole
## look (cel bands, outlines, facade lights) can be retuned in one place.

static var _cache := {}
static var _outline: ShaderMaterial


static func _sh(path: String) -> Shader:
	return load(path) as Shader


static func outline_mat(thickness := 0.018) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sh("res://shaders/outline.gdshader")
	m.set_shader_parameter("thickness", thickness)
	return m


## Shared (cached) cel material. Use toon_unique when the material's
## parameters will be animated per-instance.
static func toon(color: Color, grunge := 0.0) -> ShaderMaterial:
	var key := "toon_%s_%s" % [color.to_html(), grunge]
	if not _cache.has(key):
		_cache[key] = toon_unique(color, grunge, false)
	return _cache[key]


static func toon_unique(color: Color, grunge := 0.0, outline := false, outline_size := 0.018) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sh("res://shaders/toon.gdshader")
	m.set_shader_parameter("albedo", color)
	m.set_shader_parameter("grunge", grunge)
	if outline:
		m.next_pass = outline_mat(outline_size)
	return m


static func glow(color: Color, energy := 2.5) -> StandardMaterial3D:
	var key := "glow_%s_%s" % [color.to_html(), energy]
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color * 0.15
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = energy
		_cache[key] = m
	return _cache[key]


static func facade(wall: Color, seed := 1.0, lit := 0.35, cell := Vector2(3.2, 3.6), win := Vector2(0.55, 0.55), store := 4.6) -> ShaderMaterial:
	var key := "fac_%s_%s_%s_%s_%s_%s" % [wall.to_html(), seed, lit, cell, win, store]
	if not _cache.has(key):
		var m := ShaderMaterial.new()
		m.shader = _sh("res://shaders/facade.gdshader")
		m.set_shader_parameter("wall_color", wall)
		m.set_shader_parameter("seed", seed)
		m.set_shader_parameter("lit_ratio", lit)
		m.set_shader_parameter("cell", cell)
		m.set_shader_parameter("win_frac", win)
		m.set_shader_parameter("store_height", store)
		_cache[key] = m
	return _cache[key]


static func mural(a: Color, b: Color, c: Color, seed: float, aspect: float, energy := 1.2, scroll := 0.0) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = _sh("res://shaders/mural.gdshader")
	m.set_shader_parameter("col_a", a)
	m.set_shader_parameter("col_b", b)
	m.set_shader_parameter("col_c", c)
	m.set_shader_parameter("seed", seed)
	m.set_shader_parameter("aspect", aspect)
	m.set_shader_parameter("energy", energy)
	m.set_shader_parameter("scroll", scroll)
	return m


static func road() -> StandardMaterial3D:
	if not _cache.has("road"):
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.frequency = 0.03
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.noise = noise
		tex.width = 512
		tex.height = 512
		tex.seamless = true
		var ramp := Gradient.new()
		ramp.set_color(0, Color(0.55, 0.55, 0.6))
		ramp.set_color(1, Color(1, 1, 1))
		tex.color_ramp = ramp
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.16, 0.17, 0.22)
		m.albedo_texture = tex
		m.roughness = 0.55
		m.roughness_texture = tex
		m.metallic = 0.2
		m.metallic_specular = 0.9
		m.uv1_triplanar = true
		m.uv1_scale = Vector3(0.08, 0.08, 0.08)
		_cache["road"] = m
	return _cache["road"]


static func paint(color: Color) -> StandardMaterial3D:
	var key := "paint_%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.roughness = 0.25
		m.metallic_specular = 0.8
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_cache[key] = m
	return _cache[key]


static func glass(color := Color(0.25, 0.4, 0.55, 0.5)) -> StandardMaterial3D:
	var key := "glass_%s" % color.to_html()
	if not _cache.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = color
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.roughness = 0.05
		m.metallic_specular = 1.0
		_cache[key] = m
	return _cache[key]
