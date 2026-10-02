extends RefCounted
const WalkBuilder := preload("res://city/discovery_walk_builder.gd")

static func build(plan, buildings: Array, trees: Array, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "LibraryWalk"
	var body := Greybox.body(root, "WalkCollision")
	var empty: Array[Rect2] = []
	for i in plan.points.size() - 1:
		TerrainApron.build(root, "DryShoulder_%d" % i, terrain, Rect2(plan.points[i], Vector2.ZERO).expand(plan.points[i + 1]).grow(6), empty, true)
	WalkBuilder._ribbon(root, "Promenade", plan.samples, plan.width, 0.16, WalkBuilder.STONE, body)
	var accent: PackedVector3Array = plan.samples.duplicate()
	for i in accent.size():
		accent[i] += Vector3.UP * 0.008
	WalkBuilder._ribbon(root, "TrailInlay", accent, 0.13, 0, WalkBuilder.ACCENT, null)
	for sign in plan.signs:
		WalkBuilder._sign(root, body, sign, plan)
	WalkBuilder._obstacles(body, plan, buildings, trees, terrain)
	return root
