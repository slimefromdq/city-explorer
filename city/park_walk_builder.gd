extends RefCounted
## Collision follows existing park paving and wooden decks. Dry shoulders stop
## at the lake/creek; there is no general invisible floor across the water.
const Ribbon := preload("res://city/ribbon_mesh.gd")

static func build(plan, terrain, trees: Array) -> Node3D:
	var root := Node3D.new()
	root.name = "ParkWalk"
	if not plan.errors.is_empty():
		return root
	var body := Greybox.body(root, "PathCollision")
	var empty: Array[Rect2] = []
	for path in plan.paths:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Ribbon.build(path["samples"], path["width"]))
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		var points: PackedVector2Array = path["waypoints"]
		for i in points.size() - 1:
			TerrainApron.build(root, "DryShoulder_%d" % i, terrain, Rect2(points[i], Vector2.ZERO).expand(points[i + 1]).grow(4), empty, true)
		var accent: PackedVector3Array = path["samples"].duplicate()
		for i in accent.size():
			accent[i] += Vector3.UP * 0.008
		var line := MeshInstance3D.new()
		var line_mesh := ArrayMesh.new()
		line_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, Ribbon.build(accent, 0.10))
		line.mesh = line_mesh
		line.material_override = Greybox.mat(Color(0.10, 0.44, 0.46))
		root.add_child(line)
	for tree in trees:
		var p: Vector2 = tree["pos"]
		if plan.distance_to(p) <= 6:
			Greybox.col_box(body, Vector3(0.5, 3, 0.5), Vector3(p.x, terrain.height_at(p) + 1.5, p.y))
	for sign in plan.signs:
		preload("res://city/discovery_walk_builder.gd")._sign(root, body, sign, plan)
	return root
