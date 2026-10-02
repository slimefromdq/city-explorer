extends SceneTree
## Check coverage and stitched boundary heights on a curved surface, where
## resampling the coarse edge would leave visible cracks.
const Builder := preload("res://city/terrain_builder.gd")
class Hill extends RefCounted:
	var sea_level := 0.0
	func height_at(p: Vector2) -> float:
		return p.length_squared() * 0.03

func _initialize() -> void:
	var terrain := Hill.new()
	var mesh := Builder.build(terrain, Rect2(0, 0, 24, 24), 8, Rect2(8, 8, 8, 8), 2)
	var arrays := mesh.surface_get_arrays(0)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var area := 0.0
	var coarse_inside := false
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		var pa := Vector2(a.x, a.z)
		var pb := Vector2(b.x, b.z)
		var pc := Vector2(c.x, c.z)
		area += absf((pb - pa).cross(pc - pa)) * 0.5
		if indices[i] < 16 and Rect2(8, 8, 8, 8).has_point((pa + pb + pc) / 3):
			coarse_inside = true
	var stitched := true
	for i in range(16, vertices.size()):
		var v := vertices[i]
		var p := Vector2(v.x, v.z)
		var a := p
		var b := p
		if p.x == 8 or p.x == 16:
			a.y = 8
			b.y = 16
		elif p.y == 8 or p.y == 16:
			a.x = 8
			b.x = 16
		else:
			continue
		var expected := lerpf(terrain.height_at(a), terrain.height_at(b), p.distance_to(a) / 8)
		stitched = stitched and absf(v.y - expected) < 0.0001
	if absf(area - 576) > 0.001 or coarse_inside or not stitched:
		push_error("Terrain patch failed: area=%s overlap=%s stitched=%s" % [area, coarse_inside, stitched])
		quit(1)
	else:
		print("[PASS] terrain detail covers the full area once and stitches to coarse edges")
		quit()
