class_name SurfaceHoles
extends RefCounted
## Swaps the city's ground, lot patches and water plane for hole-capable materials and cuts the given
## world rectangles (x, z) out of them, so stairwells and trenches can pass through the surface.

const SURFACE := preload("res://city/hole_surface.gdshader")
const WATER := preload("res://city/hole_water.gdshader")
const MAX_HOLES := 32


static func apply(city_root: Node, ground_rects: Array[Rect2], water_rects: Array[Rect2]) -> void:
	var packed := _pack(ground_rects)
	var water_packed := _pack(water_rects)
	var rects := ground_rects
	for node_name in ["Ground", "Lots"]:
		var mi := city_root.get_node_or_null(node_name) as MeshInstance3D
		if mi != null:
			mi.material_override = _material(SURFACE, packed, rects.size())
	var water := city_root.get_node_or_null("Water") as MeshInstance3D
	if water != null:
		var old := water.material_override as StandardMaterial3D
		var m := _material(WATER, water_packed, water_rects.size())
		if old != null:
			m.set_shader_parameter("albedo", old.albedo_color)
		water.material_override = m


static func _pack(rects: Array[Rect2]) -> PackedVector4Array:
	var packed := PackedVector4Array()
	for r in rects:
		packed.append(Vector4(r.position.x, r.position.y, r.end.x, r.end.y))
	if packed.size() > MAX_HOLES:
		push_warning("SurfaceHoles: %d holes, only %d are used" % [packed.size(), MAX_HOLES])
	packed.resize(MAX_HOLES)
	return packed


static func _material(shader: Shader, packed: PackedVector4Array, count: int) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = shader
	m.set_shader_parameter("holes", packed)
	m.set_shader_parameter("hole_count", mini(count, MAX_HOLES))
	return m
