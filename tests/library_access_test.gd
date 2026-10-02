extends SceneTree
## Real capsule ascends and returns to the street without jumping. Also checks
## the treads clear the actual hillside, including both edges of the wide stair.
func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene := StationWalk.new()
	scene.with_ui = false
	root.add_child(scene)
	await physics_frame
	await physics_frame
	var arrival: Node3D = scene.city.get_node("CivicAccess/LibraryArrival")
	var start: Vector3 = arrival.get_meta("arrival_start")
	var end: Vector3 = arrival.get_meta("arrival_end")
	var mid: Vector3 = arrival.get_meta("arrival_mid")
	print("Library stair coordinates: ", start, " / ", mid, " / ", end)
	var slope := (end.y - start.y) / (start.z - end.z - 2)
	if rad_to_deg(atan(slope)) > 44:
		push_error("Library stair exceeds walkable grade")
		quit(1)
		return
	for i in 41:
		var p := start.lerp(end, float(i) / 40)
		# Landing pauses the climb; calculate the actual ramp height.
		if p.z > mid.z:
			p.y = lerpf(start.y, mid.y, (start.z - p.z) / (start.z - mid.z))
		elif p.z >= mid.z - 2:
			p.y = mid.y
		else:
			p.y = lerpf(mid.y, end.y, (mid.z - 2 - p.z) / (mid.z - 2 - end.z))
		for x in [-4.8, 0.0, 4.8]:
			var world := arrival.transform * (p + Vector3(x, 0, 0))
			if world.y < scene.city.terrain.height_at(Vector2(world.x, world.z)) - 0.12:
				push_error("Library stair intersects hillside at %s" % world)
				quit(1)
				return
	var walker := scene.walker
	walker.scripted = true
	var street: Vector3 = arrival.get_meta("street_start")
	walker.global_position = arrival.transform * (street + Vector3.UP * 0.05)
	walker.velocity = Vector3.ZERO
	for i in 30:
		await physics_frame
	for destination in [end, street]:
		var target: Vector3 = arrival.transform * destination
		for frame in 2400:
			var delta := Vector3(target.x - walker.global_position.x, 0, target.z - walker.global_position.z)
			if delta.length() < 0.2:
				break
			walker.wish = delta.normalized()
			await physics_frame
			if frame == 2399:
				push_error("Library traversal stuck at %s toward %s" % [walker.global_position, target])
				quit(1)
				return
		walker.wish = Vector3.ZERO
		if absf(walker.global_position.y - target.y) > 0.25:
			push_error("Library traversal reached wrong elevation: %s vs %s" % [walker.global_position, target])
			quit(1)
			return
		print("[PASS] library arrival traversed without jumping: ", walker.global_position)
	print("library_access_test: OK")
	quit()
