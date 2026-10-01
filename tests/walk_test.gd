extends Node
## Walks the capsule through the whole journey with real physics: plaza -> entrance -> ticket hall -> hall
## -> stairwell -> platform -> train -> ride -> destination platform -> stairs -> out onto the street.
## Fails (non-zero exit) if it gets stuck anywhere, or ends up somewhere it should not be.
##   godot --headless --fixed-fps 60 --path . res://tests/walk_test.tscn        (LINE=east|west|tower|park, default east)
const HUB := Vector3(762.0, 3.75, 850.0)
const STUCK_TIME := 1.6
const STUCK_DIST := 0.25

var sw: StationWalk
var walker: Walker
var transit: TransitSystem
var fails := 0
var sim_time := 0.0
var line_id := "east"


func _ready() -> void:
	if OS.get_environment("LINE") != "":
		line_id = OS.get_environment("LINE")
	sw = StationWalk.new()
	add_child(sw)
	await get_tree().physics_frame
	await get_tree().physics_frame
	walker = sw.walker
	transit = sw.city.transit
	walker.scripted = true
	if OS.get_environment("TOUR") != "":
		await _tour()
	else:
		await _journey()
	print("walk_test (%s): %s, %.0f s of simulated time" % [line_id, "OK" if fails == 0 else "%d FAILED" % fails, sim_time])
	get_tree().quit(1 if fails > 0 else 0)


## Everything else a visitor can walk to: the three wings, a balcony and a bridge, the west entrance and court.
func _tour() -> void:
	await _go("avenue crossing", Vector3(925.0, 0, 850.0))
	await _go("top of the forecourt steps", F(111.0, 0.0))
	await _go("ramp (south end), bottom", F(122.0, 26.0))
	await _go("ramp, top", F(108.0, 26.0))
	await _go("ticket hall", F(40.0, 0.0))
	await _go("hall doorway", F(30.0, 0.0))
	await _go("axis", F(20.0, 0.0))
	# the three wings, in through their doors from the hall (the long-wall strip |z| ~ 12.5 is free under the balconies)
	await _go("between the wells", F(12.0, 0.0))
	await _go("beside the booth", F(8.0, -1.0))
	await _go("north side of the hall", F(8.0, -8.5))
	await _go("north wall strip", F(12.0, -12.5))
	await _go("waiting room, along the wall", F(-20.0, -12.5))
	await _go("waiting room door", F(-20.0, -14.8))
	await _go("waiting room", F(-21.0, -26.0))
	await _go("back out of the door", F(-20.0, -12.8), 0.4)
	await _go("garden court, along the wall", F(20.0, -12.5))
	await _go("garden court door", F(20.0, -14.8))
	await _go("garden court", F(24.0, -27.0))
	await _go("garden court, by the fountain", F(17.0, -22.0))
	await _go("back out of the door", F(20.0, -12.8), 0.4)
	await _go("north wall strip", F(12.0, -12.5))
	await _go("north side of the hall", F(8.0, -8.5))
	await _go("beside the booth", F(8.0, 1.0))
	await _go("south side of the hall", F(8.0, 8.5))
	await _go("south wall strip", F(12.0, 12.5))
	await _go("shop arcade door", F(12.0, 14.8))
	await _go("shop arcade", F(12.0, 24.0))
	await _go("back out of the door", F(12.0, 12.8), 0.4)
	await _go("south wall strip", F(12.0, 12.5))
	# up the grand stairs at the east end (north flight), along the balcony, over a bridge, down the west stairs
	await _go("south side of the hall", F(8.0, 8.5))
	await _go("beside the booth", F(8.0, 0.0))
	await _go("north side of the hall", F(8.0, -8.5))
	await _go("foot of the north-east stairs", F(14.0, -8.0))
	await _go("stairs, going up", F(23.0, -8.0))
	await _go("east landing", F(30.5, -8.0))
	_expect_y("on the mezzanine", HUB.y + 8.0, 1.0)
	await _go("balcony, north side", F(30.5, -13.5))
	await _go("balcony, to the bridge", F(-8.5, -13.5))
	await _go("onto the bridge", F(-8.5, -8.0))
	await _go("over the bridge", F(-8.5, 8.0))
	await _go("balcony, south side", F(-8.5, 13.5))
	await _go("balcony to the west end", F(-30.5, 13.5))
	await _go("west landing", F(-30.5, 8.0))
	await _go("west stairs, halfway", F(-24.0, 8.0))
	await _go("foot of the west stairs", F(-14.0, 8.0))
	_expect_y("back on the hall floor", HUB.y, 0.3)
	# out of the west portal into the rear court, down its steps and across to the avenue
	await _go("south of the west wells", F(-8.0, 8.5))
	await _go("beside the booth", F(-8.0, 0.0))
	await _go("west axis", F(-20.0, 0.0))
	await _go("west ticket hall", F(-40.0, 0.0))
	await _go("west court", F(-60.0, 0.0))
	await _go("top of the west steps", F(-79.0, 0.0))
	await _go("west apron", F(-86.0, 0.0))
	var wp := walker.global_position
	var street: float = sw.city.terrain.height_at(Vector2(wp.x, wp.z)) + TerrainApron.ROAD_LIFT
	_expect(absf(wp.y - street) < 0.4, "west apron is at street level (y %.2f, street %.2f)" % [wp.y, street])


func F(x: float, z: float) -> Vector3:
	return Vector3(HUB.x + x, 0.0, HUB.z + z)


func _journey() -> void:
	var q: Vector2i = PlatformLevel.QUADRANTS[line_id]
	var sx := float(q.x)
	var sz := float(q.y)
	# ---- from the end of the main street to the forecourt, the facade door and the ticket hall
	await _go("avenue crossing", Vector3(925.0, 0, 850.0))
	await _go("apron by the steps", F(118.0, 0.0))
	await _go("top of the forecourt steps", F(111.0, 0.0))
	_expect_y("on the plaza", 3.75, 0.25)
	await _go("under the clock pediment", F(52.0, 0.0))
	await _go("ticket hall", F(40.0, 0.0))
	await _go("hall doorway", F(31.0, 0.0))
	_expect_y("in the hall", 3.75, 0.25)
	# ---- to this line's stairwell: along the axis between the stair flights, round the booth if the well
	# is on the far side, then in at the well's head (the head is the end nearest the hall centre)
	await _go("hall axis", F(20.0, 0.0))
	await _go("between the wells", F(12.0, 0.0))
	if sx > 0:
		await _go("stair head approach", F(7.5, sz * 1.0))
	else:
		await _go("beside the booth", F(8.0, 0.0))
		await _go("round the booth", F(8.0, sz * 7.5))
		await _go("past the booth", F(-8.0, sz * 7.5))
	await _go("stair head", F(sx * 7.5, sz * 2.7))
	await _go("flight 1 (down)", F(sx * 13.0, sz * 2.7))
	await _go("landing", F(sx * 16.2, sz * 2.7))
	await _go("landing, turn", F(sx * 16.2, sz * 5.5))
	await _go("flight 2 (down)", F(sx * 11.0, sz * 5.5))
	await _go("bottom of the stairs", F(sx * 7.5, sz * 5.5))
	_expect_y("on the platform", -4.25, 0.3)
	# ---- the train: wait for it to stand at the berth with its doors open, then board
	var svc: LineService = transit.services[line_id]
	var berth_x: float = sx * 18.0
	await _go("platform, past the well", F(sx * 7.5, sz * 8.0))
	await _go("platform, by the door", F(berth_x - sx * 6.0, sz * 8.0))
	await _wait_until(func(): return svc.at_hub_boarding() and (svc.train.doors_open_on(1) or svc.train.doors_open_on(-1)), 300.0, "train at the hub with doors open")
	await _go("door", F(berth_x - sx * 6.0, sz * 10.0))
	await _go("inside the train", F(berth_x - sx * 6.0, sz * 11.45))
	_expect(svc.train.player_inside, "the train knows the player is aboard")
	await _wait(1.0)
	# ---- ride: choose the destination exactly as the chooser's button does
	var ride_ui: RideUI = sw.ui
	ride_ui._choose(svc, 1)
	await _wait_until(func(): return walker.riding != null, 20.0, "the train departs with the player")
	var t0 := sim_time
	await _wait_until(func(): return walker.riding == null and svc.stop_index == 1 and svc.state != LineService.State.RUN, 80.0, "the train arrives")
	print("  ride took %.1f s" % (sim_time - t0))
	_expect(sim_time - t0 >= 15.0 and sim_time - t0 <= 30.0, "ride lasts 15-30 s")
	# ---- destination: out of the train, along the platform, up the stairs, onto the street
	var ds: DestinationStation = transit.destinations[svc.line["stops"][1]["stop"]]
	await _wait_until(func(): return svc.train.doors_open_on(1) or svc.train.doors_open_on(-1), 10.0, "doors open at the destination")
	var u0: float = ds._u0
	var D: float = ds._D
	var H: float = ds._H
	await _go_local(ds, "to the door", Vector3(-6.0, 0, 1.0))
	await _go_local(ds, "onto the platform", Vector3(-6.0, 0, 4.5))
	await _go_local(ds, "in front of the stairs", Vector3(u0, 0, 6.0))
	await _go_local(ds, "into the stair opening", Vector3(u0, 0, 9.0))
	await _go_local(ds, "foot of the stairs", Vector3(u0, 0, ds._v_foot + 0.3))
	await _go_local(ds, "top of the stairs", Vector3(u0, 0, D - 0.4), 0.6, 40.0)
	await _go_local(ds, "the entrance plaza", Vector3(u0, 0, D + 10.0))
	await _go_local(ds, "out of the reserved area", Vector3(u0, 0, D + 24.0))
	var wp := walker.global_position
	var street: float = sw.city.terrain.height_at(Vector2(wp.x, wp.z)) + TerrainApron.ROAD_LIFT
	_expect(absf(wp.y - street) < 0.5, "standing at street level (y %.2f, street %.2f)" % [wp.y, street])


# ----------------------------------------------------------------------------- helpers

func _go_local(ds: Node3D, label: String, local: Vector3, tol := 0.7, timeout := 25.0) -> void:
	await _go(label, ds.to_global(Vector3(local.x, 0, local.z)), tol, timeout)


## Walk (straight, with physics) to the horizontal position of `target`. Fails if stuck or too slow.
func _go(label: String, target: Vector3, tol := 0.7, timeout := 25.0) -> void:
	var t_start := sim_time
	var last_check := sim_time
	var last_pos := walker.global_position
	var jumped := false
	while true:
		var here := walker.global_position
		var to := Vector3(target.x - here.x, 0, target.z - here.z)
		if to.length() < tol:
			break
		walker.wish = to.normalized()
		walker.look_at_point(Vector3(target.x, here.y + 1.6, target.z))
		await get_tree().physics_frame
		sim_time += get_physics_process_delta_time()
		if sim_time - last_check >= STUCK_TIME:
			var moved := (walker.global_position - last_pos)
			moved.y = 0
			if moved.length() < STUCK_DIST:
				if not jumped:
					walker.want_jump = true
					jumped = true
				else:
					for i in walker.get_slide_collision_count():
						var c := walker.get_slide_collision(i)
						var col_obj := c.get_collider()
						print("     touching ", col_obj, " ", (col_obj as Node).get_path() if col_obj is Node else "", " at ", c.get_position(), " normal ", c.get_normal())
					_fail("STUCK on the way to '%s' at (%.2f, %.2f, %.2f), target (%.1f, %.1f)" % [label, walker.global_position.x, walker.global_position.y, walker.global_position.z, target.x, target.z])
					return
			last_check = sim_time
			last_pos = walker.global_position
		if sim_time - t_start > timeout:
			_fail("TIMEOUT on the way to '%s' at (%.2f, %.2f, %.2f)" % [label, walker.global_position.x, walker.global_position.y, walker.global_position.z])
			return
	walker.wish = Vector3.ZERO
	print("  ok   %-32s y=%.2f  (%.1f s)" % [label, walker.global_position.y, sim_time - t_start])


func _wait(seconds: float) -> void:
	var t := 0.0
	walker.wish = Vector3.ZERO
	while t < seconds:
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		sim_time += dt


func _wait_until(cond: Callable, timeout: float, label: String) -> void:
	var t := 0.0
	walker.wish = Vector3.ZERO
	while not cond.call():
		await get_tree().physics_frame
		var dt := get_physics_process_delta_time()
		t += dt
		sim_time += dt
		if t > timeout:
			_fail("TIMEOUT waiting for: %s" % label)
			return
	print("  ok   %s (after %.1f s)" % [label, t])


func _expect(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		_fail(msg)


func _expect_y(label: String, y: float, tol: float) -> void:
	_expect(absf(walker.global_position.y - y) <= tol, "%s: y %.2f (expected %.2f)" % [label, walker.global_position.y, y])


func _fail(msg: String) -> void:
	fails += 1
	print("  FAIL ", msg)
