extends SceneTree
const Builder := preload("res://city/road_builder.gd")
class Hillside extends RefCounted:
	func height_at(p: Vector2) -> float:
		return p.y * 0.3 + p.x * p.x * 0.001

func _initialize() -> void:
	var terrain := Hillside.new()
	var points := PackedVector2Array([Vector2(0, 0), Vector2(4, 0), Vector2(8, 2)])
	var arrays := Builder.draped_surface(points, 12, terrain, 0.15)
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
	var okay := vertices.size() == 21 and indices.size() == 72
	# A centre-height ribbon would bury its uphill edge by 1.65 m on this slope.
	for v in vertices:
		okay = okay and absf(v.y - terrain.height_at(Vector2(v.x, v.z)) - 0.15) < 0.00001
	for i in range(0, indices.size(), 3):
		var a := vertices[indices[i]]
		var b := vertices[indices[i + 1]]
		var c := vertices[indices[i + 2]]
		okay = okay and (c - a).cross(b - a).y > 0
		var centre := (a + b + c) / 3
		okay = okay and centre.y > terrain.height_at(Vector2(centre.x, centre.z))
	for n in normals:
		okay = okay and n.y > 0 and absf(n.length() - 1) < 0.00001
	# Boundary follows the previous ribbon footprint, including its shared bend.
	var old_points := PackedVector3Array()
	for p in points:
		old_points.append(Vector3(p.x, 0, p.y))
	var old := preload("res://city/ribbon_mesh.gd").build(old_points, 12)
	var edges: PackedVector3Array = old[Mesh.ARRAY_VERTEX]
	for i in points.size():
		for side in 2:
			var v := vertices[i * 7 + side * 6]
			var e := edges[i * 2 + side]
			okay = okay and Vector2(v.x, v.z).distance_to(Vector2(e.x, e.z)) < 0.00001
	print("road_drape_test: ", "OK" if okay else "FAILED")
	quit(0 if okay else 1)
