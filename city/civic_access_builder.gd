extends RefCounted
## Library arrival: two flights, a rest landing, protective rails and matching
## collision. The front retaining wall opening is reserved by ArchitecturePlan.
const ArchitectureBuilder := preload("res://city/architecture_builder.gd")

static func build(plan, terrain, roads, city: Dictionary = {}) -> Node3D:
	var root := Node3D.new()
	root.name = "CivicAccess"
	for site in plan.civic:
		var b: Dictionary = site["building"]
		if b["site_kind"] == "museum":
			_museum(root, site, plan, terrain, city)
			continue
		if b["site_kind"] != "library" or not b.has("base_y"):
			continue
		var holder := Node3D.new()
		holder.name = "LibraryArrival"
		holder.transform = ArchitectureBuilder.building_frame(b, terrain)
		root.add_child(holder)
		var half: float = b["size"].y * 0.5
		var start_z := INF
		# Intersect the entrance axis with the nearest street in front of it.
		var frame := holder.transform.affine_inverse()
		for road in roads.segments:
			if road["kind"] != "street":
				continue
			var points: PackedVector2Array = road["points"]
			for i in points.size() - 1:
				var a: Vector3 = frame * Vector3(points[i].x, 0, points[i].y)
				var c: Vector3 = frame * Vector3(points[i + 1].x, 0, points[i + 1].y)
				if a.x * c.x > 0 or is_equal_approx(a.x, c.x):
					continue
				var z := lerpf(a.z, c.z, -a.x / (c.x - a.x)) - float(road["width"]) * 0.5
				if z > half + 2:
					start_z = minf(start_z, z)
		if not is_finite(start_z):
			push_error("Library has no street arrival")
			continue
		var start_world: Vector3 = holder.transform * Vector3(0, 0, start_z)
		var start_y: float = terrain.height_at(Vector2(start_world.x, start_world.z)) + TerrainApron.ROAD_LIFT - b["base_y"]
		var top_z: float = b["size"].y * 0.38
		var top_y := 1.5
		var landing := 2.0
		var run := (start_z - top_z - landing) * 0.5
		# The street and hillside slope across the stair's width. Raise its toe
		# enough to clear both edges; a graded street apron meets that datum.
		for i in 40:
			var z := lerpf(start_z, top_z, float(i) / 40)
			var t := clampf((start_z - z) / run, 0, 1) * 0.5 if z >= start_z - run else 0.5 + clampf((start_z - run - landing - z) / run, 0, 1) * 0.5
			for x in [-4.9, 0.0, 4.9]:
				var p: Vector3 = holder.transform * Vector3(x, 0, z)
				var ground: float = terrain.height_at(Vector2(p.x, p.z)) + 0.15 - b["base_y"]
				start_y = maxf(start_y, (ground - top_y * t) / (1 - t))
		var rise := (top_y - start_y) * 0.5
		var steps := maxi(1, ceili(rise / 0.18))
		var col := Greybox.body(holder)
		var stone := Greybox.mat(Color(0.78, 0.73, 0.62))
		var metal := Greybox.mat(Color(0.18, 0.26, 0.28))
		var a := Vector3(0, start_y, start_z)
		var mid := StairFlight.build(holder, a, Vector3.FORWARD, 9.8, steps, -rise / steps, run / steps, start_y - 4, stone)
		Greybox.box(holder, Vector3(9.8, 0.4, landing), mid + Vector3(0, -0.2, -landing * 0.5), stone)
		var next := mid + Vector3.FORWARD * landing
		var end := StairFlight.build(holder, next, Vector3.FORWARD, 9.8, steps, -rise / steps, run / steps, start_y - 4, stone)
		var top_depth: float = top_z - b["size"].y * 0.32
		Greybox.box(holder, Vector3(9.8, 0.4, top_depth), end + Vector3(0, -0.2, -top_depth * 0.5), stone)
		# One continuous walking surface avoids overlapping ramp end caps at the
		# landing, which can catch the capsule when descending.
		var stair_surface := ArrayMesh.new()
		stair_surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, preload("res://city/ribbon_mesh.gd").build(PackedVector3Array([a, mid, next, end, end + Vector3.FORWARD * top_depth]), 9.8, 0))
		var stair_collision := CollisionShape3D.new()
		stair_collision.shape = stair_surface.create_trimesh_shape()
		col.add_child(stair_collision)
		for x in [-4.7, 4.7]:
			_sloping_rail(holder, col, a + Vector3(x, 0, 0), mid + Vector3(x, 0, 0), metal)
			Greybox.railing(holder, mid + Vector3(x, 0, 0), next + Vector3(x, 0, 0), metal, col)
			_sloping_rail(holder, col, next + Vector3(x, 0, 0), end + Vector3(x, 0, 0), metal)
			Greybox.railing(holder, end + Vector3(x, 0, 0), end + Vector3(x, 0, -top_depth), metal, col)
		for sign in [-1.0, 1.0]:
			Greybox.railing(holder, Vector3(sign * 5, 1.5, half - 0.15), Vector3(sign * (b["size"].x * 0.5 - 0.15), 1.5, half - 0.15), metal, col)
		var terrace_x: float = b["size"].x * 0.5 - 0.15
		Greybox.railing(holder, Vector3(-terrace_x, 1.5, -half + 0.15), Vector3(terrace_x, 1.5, -half + 0.15), metal, col)
		for side in [-1.0, 1.0]:
			Greybox.railing(holder, Vector3(side * terrace_x, 1.5, -half + 0.15), Vector3(side * terrace_x, 1.5, half - 0.15), metal, col)
		# Terrace and reading-room collision follow the rendered boxes, including
		# the three-piece retaining foundation; the stair opening stays clear.
		for i in range(site["first"], site["first"] + site["count"]):
			var part: Dictionary = plan.parts[i]
			if part["kind"] == "box" and part["color"] != plan.DARK:
				Greybox.col_box(col, part["size"], part["center"])
		var empty: Array[Rect2] = []
		TerrainApron.build(root, "LibraryStreetApron", terrain, Rect2(Vector2(start_world.x - 12, start_world.z - 2), Vector2(24, 16)), empty, true)
		var approach := PackedVector3Array()
		for i in 11:
			var local := Vector3(0, 0, start_z + 10 - i)
			var world: Vector3 = holder.transform * local
			var ground: float = terrain.height_at(Vector2(world.x, world.z)) + TerrainApron.ROAD_LIFT - b["base_y"]
			var road_world: Vector3 = holder.transform * Vector3(0, 0, start_z + 10)
			var road_y: float = terrain.height_at(Vector2(road_world.x, road_world.z)) + TerrainApron.ROAD_LIFT - b["base_y"]
			local.y = maxf(ground, lerpf(road_y, start_y, float(i) / 10))
			approach.append(local)
		var ribbon := ArrayMesh.new()
		ribbon.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, preload("res://city/ribbon_mesh.gd").build(approach, 9.8, 0.15))
		var paving := MeshInstance3D.new()
		paving.name = "StreetApproach"
		paving.mesh = ribbon
		paving.material_override = stone
		holder.add_child(paving)
		var cs := CollisionShape3D.new()
		cs.shape = ribbon.create_trimesh_shape()
		col.add_child(cs)
		holder.set_meta("arrival_start", a)
		holder.set_meta("street_start", approach[0])
		holder.set_meta("arrival_end", end)
		holder.set_meta("arrival_mid", mid)
	return root

static func _museum(root: Node3D, site: Dictionary, plan, terrain, city: Dictionary) -> void:
	var route := PackedVector2Array()
	for spur in city.get("discovery_walk", {}).get("spurs", []):
		if spur["id"] == "museum":
			route = preload("res://city/city_data.gd").to_points(spur["points"])
	if route.is_empty():
		return
	var b: Dictionary = site["building"]
	var holder := Node3D.new()
	holder.name = "MuseumArrival"
	holder.transform = ArchitectureBuilder.building_frame(b, terrain)
	root.add_child(holder)
	var p := route[route.size() - 1]
	var start: Vector3 = holder.transform.affine_inverse() * Vector3(p.x, terrain.height_at(p, false) + 0.16, p.y)
	var end := Vector3(start.x, 1.5, b["size"].y * 0.5 + 0.12)
	var run := start.z - end.z
	var rise := end.y - start.y
	var steps := maxi(1, ceili(rise / 0.18))
	var col := Greybox.body(holder)
	var stone := Greybox.mat(Color(0.78, 0.73, 0.62))
	var metal := Greybox.mat(Color(0.18, 0.26, 0.28))
	StairFlight.build(holder, start, Vector3.FORWARD, 5, steps, -rise / steps, run / steps, start.y - 2, stone)
	Greybox.box(holder, Vector3(5, 0.15, 0.7), end + Vector3(0, -0.075, -0.35), stone)
	var surface := ArrayMesh.new()
	surface.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, preload("res://city/ribbon_mesh.gd").build(PackedVector3Array([start, end, end + Vector3.FORWARD * 0.7]), 5, 0))
	var cs := CollisionShape3D.new()
	cs.shape = surface.create_trimesh_shape()
	col.add_child(cs)
	for x in [-2.35, 2.35]:
		_sloping_rail(holder, col, start + Vector3(x, 0, 0), end + Vector3(x, 0, 0), metal)
	for i in range(site["first"], site["first"] + site["count"]):
		var part: Dictionary = plan.parts[i]
		if part["color"] == plan.DARK or part["color"] == plan.GLASS:
			continue
		if part["kind"] == "box":
			Greybox.col_box(col, part["size"], part["center"])
		elif part["kind"] == "cylinder":
			var cylinder := CollisionShape3D.new()
			var shape := CylinderShape3D.new()
			shape.radius = part["size"].x * 0.5
			shape.height = part["size"].y
			cylinder.shape = shape
			cylinder.position = part["center"]
			col.add_child(cylinder)
	for side in [-1.0, 1.0]:
		Greybox.railing(holder, Vector3(side * 2.5, 1.5, end.z), Vector3(side * (b["size"].x * 0.5 - 0.2), 1.5, end.z), metal, col)
	holder.set_meta("arrival_start", start)
	holder.set_meta("arrival_end", end)
	holder.set_meta("door_stop", Vector3(0, 1.5, b["size"].y * 0.305 + 0.8))

static func _sloping_rail(holder: Node3D, col: StaticBody3D, a: Vector3, b: Vector3, material: Material) -> void:
	var forward := (b - a).normalized()
	var across := Vector3.RIGHT
	var basis := Basis(forward, across.cross(forward), across)
	Greybox.box_basis(holder, Vector3(a.distance_to(b), 1.1, 0.10), (a + b) * 0.5 + Vector3.UP * 0.65, basis, material, col)
