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
	print("discovery_walk_test: %s (%.0f simulated seconds)" % ["OK" if failures == 0 else "FAILED", elapsed])
	quit(1 if failures > 0 else 0)

func _go(label: String, target: Vector2, check_height: bool) -> bool:
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
		if check_height and absf(walker.global_position.y - scene.city.discovery_walk.height_at(Vector2(walker.global_position.x, walker.global_position.z))) > 0.45:
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
