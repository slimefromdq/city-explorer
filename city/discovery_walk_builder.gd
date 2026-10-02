extends RefCounted
## A continuous promenade with matching physics, two bridge barriers and street furniture.
const RibbonMesh := preload("res://city/ribbon_mesh.gd")
const BuildingPlan := preload("res://city/building_plan.gd")
const STONE := Color(0.73, 0.68, 0.56)
const ACCENT := Color(0.10, 0.44, 0.46)
const METAL := Color(0.12, 0.20, 0.23)
const WOOD := Color(0.40, 0.27, 0.16)

static func build(plan, buildings: Array, trees: Array, terrain, holes: Array[Rect2]) -> Node3D:
	var root := Node3D.new()
	root.name = "DiscoveryWalk"
	if not plan.errors.is_empty() or plan.samples.is_empty():
		return root
	var body := Greybox.body(root, "WalkCollision")
	# A dry shoulder supports stepping off the promenade and reaching benches.
	# Entrance holes remain open, and no invisible floor is added under the river.
	for i in plan.points.size() - 1:
		var area := Rect2(plan.points[i], Vector2.ZERO).expand(plan.points[i + 1]).grow(6.0)
		TerrainApron.build(root, "Shoulder_%d" % i, terrain, area, holes, true)
	var paving := _ribbon(root, "Promenade", plan.samples, plan.width, 0.16, STONE, body)
	paving.set_meta("length_metres", plan.length)
	_ribbon(root, "StationCrossing", plan.approach_samples, plan.width, 0.16, STONE, body)
	for spur in plan.spurs:
		var branch: PackedVector2Array = spur["points"]
		for i in branch.size() - 1:
			TerrainApron.build(root, "SpurShoulder_%s_%d" % [spur["id"], i], terrain, Rect2(branch[i], Vector2.ZERO).expand(branch[i + 1]).grow(6), holes, true)
		_ribbon(root, "Spur_%s" % spur["id"], spur["samples"], plan.width, 0.16, STONE, body)
		var accent: PackedVector3Array = spur["samples"].duplicate()
		for i in accent.size():
			accent[i] += Vector3.UP * 0.008
		_ribbon(root, "SpurInlay_%s" % spur["id"], accent, 0.13, 0, ACCENT, null)
		if not spur["sign"].is_empty():
			_sign(root, body, spur["sign"], plan)
	# A narrow teal inlay runs along the promenade, connecting the decision signs.
	var line := PackedVector3Array()
	for p in plan.samples:
		line.append(p + Vector3.UP * 0.008)
	_ribbon(root, "TrailInlay", line, 0.13, 0.0, ACCENT, null)
	_bridge_barriers(root, body, plan)
	for sign in plan.signs:
		_sign(root, body, sign, plan)
	for rest in plan.rest_points:
		_rest(root, body, rest, plan, terrain)
	_obstacles(body, plan, buildings, trees, terrain)
	return root

static func _ribbon(root: Node3D, label: String, points: PackedVector3Array, width: float, thickness: float, color: Color, body: StaticBody3D) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, RibbonMesh.build(points, width, thickness))
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = Greybox.mat(color)
	root.add_child(node)
	if body != null:
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
	return node

static func _bridge_barriers(root: Node3D, body: StaticBody3D, plan) -> void:
	for side in [-1.0, 1.0]:
		var rail := PackedVector3Array()
		for i in plan.samples.size():
			var p: Vector3 = plan.samples[i]
			if not plan.bridge_contains(Vector2(p.x, p.z)):
				continue
			var forward: Vector3 = plan.samples[mini(i + 1, plan.samples.size() - 1)] - plan.samples[maxi(i - 1, 0)]
			var right := Vector3(forward.x, 0, forward.z).normalized().cross(Vector3.UP)
			rail.append(p + right * side * (plan.width * 0.5 - 0.08) + Vector3.UP * 1.1)
		if rail.size() >= 2:
			_ribbon(root, "BridgeBarrier_%s" % side, rail, 0.16, 1.1, METAL, body)

static func _holder(root: Node3D, data: Dictionary, plan, label: String) -> Node3D:
	var p := Vector2(data["position"][0], data["position"][1])
	var holder := Node3D.new()
	holder.name = label
	holder.position = Vector3(p.x, plan.height_at(p), p.y)
	holder.rotation.y = atan2(float(data["facing"][0]), float(data["facing"][1]))
	root.add_child(holder)
	return holder

static func _sign(root: Node3D, body: StaticBody3D, data: Dictionary, plan) -> void:
	var holder := _holder(root, data, plan, "WalkSign")
	var size := Vector3(1.8, 2.5 + plan.LIFT, 0.18)
	var center := Vector3(0, (2.5 - plan.LIFT) * 0.5, 0)
	Greybox.box(holder, size, center, Greybox.mat(METAL))
	Greybox.box(holder, Vector3(1.8, 0.12, 0.20), Vector3(0, 2.44, 0), Greybox.mat(ACCENT))
	for face in [1, -1]:
		Greybox.label(holder, data["forward"] if face == 1 else data["back"], Vector3(0, 1.78, face * 0.10), 0.0 if face == 1 else PI, 0.12, Color(0.96, 0.94, 0.85))
		Greybox.label(holder, "MERIDIA  /  ON FOOT", Vector3(0, 0.52, face * 0.10), 0.0 if face == 1 else PI, 0.09, Color(0.40, 0.79, 0.76))
	Greybox.col_box(body, size, holder.position + center, holder.basis)

static func _rest(root: Node3D, body: StaticBody3D, data: Dictionary, plan, terrain) -> void:
	var holder := _holder(root, data, plan, "RestPoint")
	var p := Vector2(holder.position.x, holder.position.z)
	holder.position.y = terrain.height_at(p, false) + TerrainApron.ROAD_LIFT
	# Each bench gets a short graded spur so its pad can be reached without jumping.
	var facing := Vector2(data["facing"][0], data["facing"][1])
	var end := p + facing
	var start: Vector2 = plan.closest_point(end)
	# Stay level through the promenade's edge before descending; a ramp
	# starting at its centre would run into the side of the raised paving.
	var shoulder := start.move_toward(end, minf(plan.width * 0.5 + 0.1, start.distance_to(end) * 0.7))
	var points := PackedVector3Array([Vector3(start.x, plan.height_at(start), start.y), Vector3(shoulder.x, plan.height_at(start), shoulder.y), Vector3(end.x, holder.position.y, end.y)])
	_ribbon(root, "RestAccess", points, 1.8, 0.15, STONE, body)
	var col := Greybox.body(holder, "FurnitureCollision")
	Greybox.box(holder, Vector3(3.4, TerrainApron.ROAD_LIFT, 2.6), Vector3(0, -TerrainApron.ROAD_LIFT * 0.5, 0), Greybox.mat(STONE), col)
	Greybox.box(holder, Vector3(2.2, 0.14, 0.65), Vector3(0, 0.47, 0), Greybox.mat(WOOD), col)
	Greybox.box(holder, Vector3(2.2, 0.5, 0.12), Vector3(0, 0.83, -0.28), Greybox.mat(WOOD), col)
	for x in [-0.8, 0.8]:
		Greybox.box(holder, Vector3(0.12, 0.4, 0.5), Vector3(x, 0.2, 0), Greybox.mat(METAL), col)
	Greybox.box(holder, Vector3(0.14, 4.0, 0.14), Vector3(1.5, 2, -0.8), Greybox.mat(METAL), col)
	Greybox.box(holder, Vector3(0.55, 0.14, 0.55), Vector3(1.5, 4, -0.8), Greybox.mat(Color(0.95, 0.85, 0.61), 0.5, 0.4))

static func _obstacles(body: StaticBody3D, plan, buildings: Array, trees: Array, terrain) -> void:
	# Nearby walls and trunks are solid, so leaving the path cannot pass through
	# the visible environment. This does not add collision to distant city blocks.
	for b in buildings:
		if b.get("site_kind", "") in ["museum", "library"]:
			# CivicAccess follows civic walls, stairs and open terraces instead
			# of filling the whole reservation with one invisible solid box.
			continue
		if plan.distance_to(b["center"]) > b["size"].length() * 0.5 + 10.0:
			continue
		var base: float = BuildingPlan.base_elevation(b["center"], b["u"], b["size"], terrain)
		var u: Vector2 = b["u"]
		var along := Vector3(u.x, 0, u.y)
		Greybox.col_box(body, Vector3(b["size"].x, b["height"] + 2.0, b["size"].y), Vector3(b["center"].x, base - 2.0 + (b["height"] + 2.0) * 0.5, b["center"].y), Basis(along, Vector3.UP, along.cross(Vector3.UP)))
	for tree in trees:
		var p: Vector2 = tree["pos"]
		if plan.distance_to(p) <= 10.0:
			Greybox.col_box(body, Vector3(0.5, 3.0, 0.5), Vector3(p.x, terrain.height_at(p) + 1.5, p.y))
