extends SceneTree
## Real capsule traversal in both directions, without jumping or teleporting
## between checkpoints. Also proves the river crossing has protective collision.
## godot --headless --fixed-fps 60 --path . --script res://tests/discovery_walk_test.gd
var scene: StationWalk
var walker: Walker
var elapsed := 0.0
var failures := 0
const WalkPlan := preload("res://city/discovery_walk_plan.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	scene = StationWalk.new()
	scene.with_ui = false
	root.add_child(scene)
	await physics_frame
	await physics_frame
	walker = scene.walker
	walker.scripted = true
	var plan = scene.city.discovery_walk
	var problems: Array = plan.validate(scene.city.building_plan.buildings, scene.city.city)
	if not problems.is_empty():
		_fail("Invalid route: %s" % problems)
		quit(1)
		return
	# Prove the validator rejects a plausible but blocked shortcut through the mall.
	var shortcut: Dictionary = scene.city.city.duplicate(true)
	for feature in shortcut["precinct"]["features"]:
		if feature["kind"] == "podium":
			shortcut["discovery_walk"]["points"][7] = feature["center"].duplicate()
	var invalid := WalkPlan.new(shortcut, scene.city.terrain)
	if invalid.validate(scene.city.building_plan.buildings, shortcut).is_empty():
		_fail("Validator accepted a route through Meridian Mall")
		quit(1)
		return
	print("  ok   blocked mall shortcut rejected")
	var detached: Dictionary = scene.city.city.duplicate(true)
	detached["discovery_walk"]["spurs"][0]["points"][0] = [400, 200]
	if WalkPlan.new(detached, scene.city.terrain).validate(scene.city.building_plan.buildings, detached).is_empty():
		_fail("Validator accepted a detached museum spur")
		quit(1)
		return
	print("  ok   detached museum spur rejected")
	for i in 30:
		await physics_frame
	if not await _go("crossing approach", plan.approach, false):
		quit(1)
		return
	if not await _go("station forecourt crossing", plan.points[0], false):
		quit(1)
		return
	for i in range(1, plan.points.size()):
		if not await _go("outbound checkpoint %d" % i, plan.points[i], true):
			quit(1)
			return
	print("  ok   station -> bridge -> tower -> park without jumping")
	for spur in plan.spurs:
		var branch: PackedVector2Array = spur["points"]
		for i in range(1, branch.size()):
			if not await _go("museum spur %d" % i, branch[i], false):
				quit(1)
				return
		var arrival: Node3D = scene.city.get_node("CivicAccess/MuseumArrival")
		var door: Vector3 = arrival.transform * arrival.get_meta("door_stop")
		if not await _go("museum front terrace", Vector2(door.x, door.z), false):
			quit(1)
			return
		if absf(walker.global_position.y - door.y) > 0.15:
			_fail("Museum arrival did not reach the terrace elevation")
			quit(1)
			return
		print("  ok   museum entrance reached from station without jumping")
		for i in range(branch.size() - 1, -1, -1):
			if not await _go("museum return %d" % i, branch[i], false):
				quit(1)
				return
	var park = scene.city.park_walk
	var park_problems: Array = park.validate(scene.city.building_plan.buildings, scene.city.city)
	if not park_problems.is_empty() or park.paths.size() != 1 or park.bridges.size() != 2:
		_fail("Invalid park loop: %s" % [park_problems])
		quit(1)
		return
	# A real walk from the museum branch into the full loop and back to its
	# junction, in both directions; no teleports between route checkpoints.
	for path in park.paths:
		var points: PackedVector2Array = path["points"]
		for i in range(1, points.size()):
			if not await _go("lake loop clockwise %d" % i, points[i], true, park):
				quit(1)
				return
		for i in range(points.size() - 2, -1, -1):
			if not await _go("lake loop counterclockwise %d" % i, points[i], true, park):
				quit(1)
				return
	print("  ok   complete lake loop in both directions without jumping")
	# Reach the west-bank branch along the loop, then climb the library's two
	# flights and return. Keep the actual capsule connected to the station route.
	var lake_points: PackedVector2Array = park.paths[0]["points"]
	var library = scene.city.library_walk
	var detached_library: Dictionary = scene.city.city.duplicate(true)
	detached_library["discovery_walk"]["library_walk"]["points"][0] = [350,285]
	var bad_library = preload("res://city/library_walk_plan.gd").new(detached_library, scene.city.terrain, park)
	if bad_library.validate(scene.city.building_plan.buildings, detached_library).is_empty():
		_fail("Validator accepted a detached library connection")
		quit(1)
		return
	print("  ok   detached library connection rejected")
	if library.validate(scene.city.building_plan.buildings, scene.city.city).size() > 0 or scene.city.get_node_or_null("LibraryWalk") == null:
		_fail("Invalid library connection")
		quit(1)
		return
	var junction := -1
	for i in lake_points.size():
		if lake_points[i].distance_to(library.points[0]) < 0.01:
			junction = i
			break
	if junction < 0:
		_fail("Library junction is not a park checkpoint")
		quit(1)
		return
	for i in range(1, junction + 1):
		if not await _go("library park approach %d" % i, lake_points[i], true, park):
			quit(1)
			return
	for i in range(1, library.points.size()):
		if not await _go("library route %d" % i, library.points[i], true, library):
			quit(1)
			return
	var library_arrival: Node3D = scene.city.get_node("CivicAccess/LibraryArrival")
	var library_top: Vector3 = library_arrival.transform * library_arrival.get_meta("arrival_end")
	if not await _go("library front terrace", Vector2(library_top.x, library_top.z), false) or absf(walker.global_position.y - library_top.y) > 0.25:
		_fail("Library terrace was not reached from station")
		quit(1)
		return
	var street: Vector3 = library_arrival.transform * library_arrival.get_meta("street_start")
	if not await _go("library stair return", Vector2(street.x, street.z), false):
		quit(1)
		return
	for i in range(library.points.size() - 2, -1, -1):
		if not await _go("library route return %d" % i, library.points[i], true, library):
			quit(1)
			return
	for i in range(junction - 1, -1, -1):
		if not await _go("library park return %d" % i, lake_points[i], true, park):
			quit(1)
			return
	print("  ok   station -> library terrace -> park without jumping")
	for i in range(plan.points.size() - 2, -1, -1):
		if not await _go("return checkpoint %d" % i, plan.points[i], true):
			quit(1)
			return
	print("  ok   park -> tower -> bridge -> station without jumping")
	for rest in plan.rest_points:
		var p := Vector2(rest["position"][0], rest["position"][1])
		var front := p + Vector2(rest["facing"][0], rest["facing"][1])
		var start: Vector2 = plan.closest_point(front)
		walker.global_position = Vector3(start.x, plan.height_at(start) + 0.05, start.y)
		walker.velocity = Vector3.ZERO
		if not await _go("bench access", front, false):
			quit(1)
			return
		var expected: float = scene.city.terrain.height_at(p, false) + TerrainApron.ROAD_LIFT
		if absf(walker.global_position.y - expected) > 0.20:
			_fail("Bench pad is not at its walking height")
		if not await _go("bench return", start, false):
			quit(1)
			return
	# A separate safety probe: stand mid-bridge and walk into each barrier.
	var a := Vector2(plan.bridge["from"][0], plan.bridge["from"][1])
	var b := Vector2(plan.bridge["to"][0], plan.bridge["to"][1])
	var mid: Vector2 = plan.points[3].lerp(plan.points[4], 0.5)
	var right := Vector3((b - a).y, 0, -(b - a).x).normalized()
	for side in [-1.0, 1.0]:
		walker.global_position = Vector3(mid.x, plan.height_at(mid) + 0.1, mid.y)
		walker.velocity = Vector3.ZERO
		walker.wish = right * side
		for frame in 180:
			await physics_frame
		var lateral := absf((walker.global_position - Vector3(mid.x, walker.global_position.y, mid.y)).dot(right))
		if lateral > plan.width * 0.5 or absf(walker.global_position.y - plan.height_at(mid)) > 0.3:
			_fail("Bridge barrier did not retain the capsule on side %s" % side)
		else:
			print("  ok   bridge barrier retains capsule on side ", side)
	walker.wish = Vector3.ZERO
	for bridge in park.bridges:
		var points: PackedVector2Array = bridge["points"]
		var middle := points.size() / 2
		var p := points[middle]
		var across := (points[middle + 1] - points[middle - 1]).normalized().orthogonal()
		for side in [-1.0, 1.0]:
			walker.global_position = Vector3(p.x, park.height_at(p) + 0.05, p.y)
			walker.velocity = Vector3.ZERO
			walker.wish = Vector3(across.x, 0, across.y) * side
			for frame in 180:
				await physics_frame
			if not park.bridge_at(Vector2(walker.global_position.x, walker.global_position.z)).is_empty() and absf(walker.global_position.y - park.height_at(p)) < 0.15:
				print("  ok   park bridge rail retains capsule on side ", side)
			else:
				_fail("Park bridge rail failed at %s" % walker.global_position)
		walker.wish = Vector3.ZERO
	# Removing both bridge reservations must invalidate the wet crossing.
	var saved: Array = scene.city.greenery_plan.footbridges
	scene.city.greenery_plan.footbridges = []
	var unsafe = preload("res://city/park_walk_plan.gd").new(scene.city.city, scene.city.greenery_plan, scene.city.terrain, plan)
	scene.city.greenery_plan.footbridges = saved
	if unsafe.validate(scene.city.building_plan.buildings, scene.city.city).is_empty():
		_fail("Park validator accepted a wet loop without bridges")
	else:
		print("  ok   park validator rejects missing footbridges")
	var lake: Array = scene.city.city["terrain"]["ponds"][0]["center"]
	var ray := PhysicsRayQueryParameters3D.create(Vector3(lake[0], 6, lake[1]), Vector3(lake[0], -0.05, lake[1]))
	if not scene.get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		_fail("An invisible floor crosses the lake centre")
	else:
		print("  ok   lake centre has no invisible walking floor")
	print("discovery_walk_test: %s (%.0f simulated seconds)" % ["OK" if failures == 0 else "FAILED", elapsed])
	quit(1 if failures > 0 else 0)

func _go(label: String, target: Vector2, check_height: bool, surface = null) -> bool:
	var start := elapsed
	var last := walker.global_position
	var last_check := elapsed
	var timeout := Vector2(last.x, last.z).distance_to(target) / Walker.WALK_SPEED + 12.0
	while true:
		var here := walker.global_position
		var delta := Vector3(target.x - here.x, 0, target.y - here.z)
		if delta.length() < 0.3:
			break
		walker.wish = delta.normalized()
		await physics_frame
		elapsed += 1.0 / 60.0
		var provider = scene.city.discovery_walk if surface == null else surface
		if check_height and absf(walker.global_position.y - provider.height_at(Vector2(walker.global_position.x, walker.global_position.z))) > 0.45:
			_fail("Fell or left the walking surface during %s at %s" % [label, walker.global_position])
			return false
		if elapsed - last_check >= 2.0:
			if Vector2(last.x, last.z).distance_to(Vector2(walker.global_position.x, walker.global_position.z)) < 0.2:
				_fail("Stuck during %s at %s" % [label, walker.global_position])
				return false
			last = walker.global_position
			last_check = elapsed
		if elapsed - start > timeout:
			_fail("Timeout during %s at %s" % [label, walker.global_position])
			return false
	walker.wish = Vector3.ZERO
	print("  ok   %s at %s" % [label, walker.global_position])
	return true

func _fail(message: String) -> void:
	failures += 1
	print("  FAIL ", message)
