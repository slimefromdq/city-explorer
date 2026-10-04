extends Node
## Headless checks for M1a. Loads the real test arena, switches off the keyboard
## input and drives the hero by writing its intent directly (the same way a bot
## or network client would). Run:
##   godot --headless --fixed-fps 60 res://game/tests/m1a_movement_test.tscn
## Exit code 0 = all passed.

const ARENA := preload("res://game/levels/test_arena/test_arena.tscn")

var arena: Node3D
var hero: Hero
var events: Array = []   # [type, data]
var passed := 0
var failed := 0


func _ready() -> void:
	arena = ARENA.instantiate()
	add_child(arena)
	hero = arena.get_node("PlayerHero")
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false
	hero.movement_event.connect(func(t: int, d: Dictionary) -> void: events.append([t, d]))
	await _frames(3)
	await _run()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _run() -> void:
	var t := hero.tuning
	print("settle")
	await _frames(60)
	_check(hero.states.current_name == &"Ground", "hero lands and is in Ground (got %s)" % hero.states.current_name)
	_check(_saw(MoveEvent.Type.LAND), "OnLand was emitted on landing")

	print("walk / sprint / stop")
	await _place("Spawn")
	_set_move(Vector2(0, 1))
	await _frames(45)
	_check(absf(hero.horizontal_speed() - t.walk_speed) < 0.3, "walk reaches walk_speed (%.2f vs %.2f)" % [hero.horizontal_speed(), t.walk_speed])
	await _place("Spawn")
	_set_move(Vector2(0, 1), true)
	await _frames(45)
	_check(absf(hero.horizontal_speed() - t.sprint_speed) < 0.3, "sprint reaches sprint_speed (%.2f vs %.2f)" % [hero.horizontal_speed(), t.sprint_speed])
	_set_move(Vector2.ZERO)
	await _frames(int(ceil(t.sprint_speed / t.ground_brake * 60.0)) + 5)
	_check(hero.horizontal_speed() < 0.5, "letting go stops the hero (%.2f m/s)" % hero.horizontal_speed())

	print("jump")
	await _place("Spawn")
	events.clear()
	var y0 := hero.global_position.y
	var apex := await _jump_apex(true)
	var expect := t.jump_speed * t.jump_speed / (2.0 * t.gravity)
	_check(absf(apex - y0 - expect) < 0.15, "held jump peaks near %.2f m (got %.2f)" % [expect, apex - y0])
	_check(_saw(MoveEvent.Type.JUMP), "OnJump was emitted")
	await _place("Spawn")
	y0 = hero.global_position.y
	var hop := await _jump_apex(false)
	_check(hop - y0 < expect * 0.6, "tapped jump is a short hop (%.2f m)" % (hop - y0))

	print("coyote time")
	await _place("GapStart")
	_set_move(Vector2(0, 1))
	events.clear()
	var left_ground := false
	for i in 120:
		await _frames(1)
		if hero.states.current_name == &"Air":
			left_ground = true
			break
	_check(left_ground and not _saw(MoveEvent.Type.JUMP), "walked off the platform edge without jumping")
	await _frames(3)
	hero.intent.jump_pressed = true
	hero.intent.jump_held = true
	await _frames(2)
	_check(_saw(MoveEvent.Type.JUMP) and hero.velocity.y > 0.0, "jump still works %.2f s after leaving the edge (coyote)" % (4.0 / 60.0))
	_release_all()

	print("mantle")
	for ledge in [["Ledge_1_5", 1.5], ["Ledge_2_5", 2.5], ["Ledge_4_0", 4.0]]:
		await _place(ledge[0])
		events.clear()
		_set_move(Vector2(0, 1))
		hero.intent.jump_pressed = true
		hero.intent.jump_held = true
		var on_top := await _reached_ground_at(ledge[1], 110)
		if ledge[1] <= 2.5:
			_check(on_top, "jump + run gets onto the %.1f m ledge (y = %.2f)" % [ledge[1], hero.global_position.y])
		else:
			_note("4.0 m ledge from a standing jump: %s (y = %.2f)" % ["reached" if on_top else "not reached (expected: out of reach)", hero.global_position.y])
		if ledge[1] >= 2.5:
			_check(_saw(MoveEvent.Type.MANTLE) == on_top, "OnMantle emitted for the %.1f m ledge" % ledge[1])
		_release_all()

	print("crouch tunnel")
	await _place("TunnelEntry")
	_set_move(Vector2(0, 1))
	await _frames(150)
	_check(hero.global_position.z > -2.0, "standing hero can't enter the 1.4 m tunnel (z = %.2f)" % hero.global_position.z)
	await _place("TunnelEntry")
	hero.intent.crouch = true
	_set_move(Vector2(0, 1))
	await _frames(60)
	_check(hero.states.current_name == &"Crouch" and hero.motor.crouched, "holding crouch enters Crouch with a short capsule")
	_check(absf(hero.horizontal_speed() - t.crouch_speed) < 0.3, "crouch speed is crouch_speed (%.2f)" % hero.horizontal_speed())
	await _wait_until(func() -> bool: return hero.global_position.z < -5.0, 180)
	hero.intent.crouch = false
	await _frames(10)
	_check(hero.motor.crouched and hero.states.current_name == &"Ground", "releasing crouch under the roof keeps you crouched")
	_check(hero.horizontal_speed() < t.crouch_speed + 0.3, "still crouch speed under the roof (%.2f)" % hero.horizontal_speed())
	await _wait_until(func() -> bool: return hero.global_position.z < -12.8, 240)
	await _frames(5)
	_check(not hero.motor.crouched, "stands up automatically after leaving the tunnel")
	_release_all()

	print("ramps, stairs, curbs")
	await _place("Ramp_30")
	_set_move(Vector2(0, 1))
	await _frames(120)
	_check(hero.global_position.y > 3.0, "walks up the 30 degree ramp (y = %.2f)" % hero.global_position.y)
	await _place("Ramp_55")
	_set_move(Vector2(0, 1), true)
	await _frames(120)
	_check(hero.global_position.y < 1.5, "can't walk up the 55 degree ramp (y = %.2f)" % hero.global_position.y)
	await _place("Stairs")
	events.clear()
	_set_move(Vector2(0, 1))
	var f0 := Engine.get_physics_frames()
	_check(await _reached_ground_at(1.8, 150), "walks up 0.18 m stairs to the landing without jumping")
	_note("stairs took %.2f s for ~5.7 m of travel (flat walking would take %.2f s)" % [(Engine.get_physics_frames() - f0) / 60.0, 5.7 / t.walk_speed])
	_check(not _saw(MoveEvent.Type.JUMP), "no jump was needed on the stairs")
	for curb in [["Curb_0_1", 0.1], ["Curb_0_2", 0.2], ["Curb_0_3", 0.3]]:
		await _place(curb[0])
		_set_move(Vector2(0, 1))
		_check(await _reached_ground_at(curb[1], 90), "steps onto a %.1f m curb without jumping" % curb[1])
	await _place("Curb_0_45")
	_set_move(Vector2(0, 1))
	_check(not await _reached_ground_at(0.45, 90), "a 0.45 m block needs a jump")
	_release_all()

	print("wall kick")
	await _place("ShaftBottom")
	events.clear()
	_set_move(Vector2(0, 1))
	# Low air control: walk up to the wall first, then jump against it.
	await _wait_until(func() -> bool: return hero.motor.wall_left > 0.0, 120)
	hero.intent.jump_pressed = true
	hero.intent.jump_held = true
	var best_y := 0.0
	for i in 300:
		await _frames(1)
		best_y = maxf(best_y, hero.global_position.y)
		if hero.states.current_name == &"Air" and hero.motor.wall_left > 0.0 and hero.velocity.y < 3.0:
			hero.intent.jump_pressed = true
		if hero.states.current_name == &"Ground" and i > 20:
			break
	var kicks := events.filter(func(e: Array) -> bool: return e[0] == MoveEvent.Type.WALL_KICK).size()
	_check(kicks == t.wall_kicks_per_air, "wall kicks stop at %d per airtime (got %d)" % [t.wall_kicks_per_air, kicks])
	_note("highest point reached with wall kicks: %.2f m" % best_y)
	_release_all()

	print("respawn + overlay")
	hero.global_position = Vector3(0, -40, 0)
	await _frames(2)
	_check(hero.global_position.distance_to(hero.spawn_transform.origin) < 1.0, "falling below the kill height respawns instantly")
	await _frames(70)
	var overlay := get_node("/root/DebugOverlay")
	var text: String = overlay._label.text
	_check(text.contains("state") and text.contains("OnLand"), "debug overlay shows state and recent events")
	_check(MoveEvent.NAMES.size() == MoveEvent.Type.size(), "every movement event has a display name")


# ------------------------------------------------------------------ helpers

func _place(marker: String) -> void:
	var m := arena.get_node("TestPoints/" + marker) as Marker3D
	_release_all()
	hero.global_position = m.global_position
	hero.velocity = Vector3.ZERO
	hero.motor.reset()
	hero.states.change(&"Air")
	# Read the heading from the marker's forward axis (Euler angles can flip at 180 degrees).
	var fwd := -m.global_basis.z
	hero.intent.aim_yaw = atan2(-fwd.x, -fwd.z)
	hero.face_yaw = hero.intent.aim_yaw
	hero.reset_physics_interpolation()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)
	await _frames(2)


## Keeps doing whatever the intent says for up to `max_frames`; true if at any
## point the hero stood on the ground at height `h` (+/- 0.12 m).
func _reached_ground_at(h: float, max_frames: int) -> bool:
	for i in max_frames:
		await _frames(1)
		if hero.states.current_name == &"Ground" and absf(hero.global_position.y - h) < 0.12:
			return true
	return false


func _jump_apex(hold: bool) -> float:
	hero.intent.jump_pressed = true
	hero.intent.jump_held = hold
	var top := hero.global_position.y
	for i in 90:
		await _frames(1)
		top = maxf(top, hero.global_position.y)
		if i > 5 and hero.states.current_name == &"Ground":
			break
	hero.intent.jump_held = false
	return top


func _set_move(v: Vector2, sprint := false) -> void:
	hero.intent.move = v
	hero.intent.sprint = sprint


func _release_all() -> void:
	hero.intent.move = Vector2.ZERO
	hero.intent.sprint = false
	hero.intent.crouch = false
	hero.intent.jump_held = false
	hero.intent.jump_pressed = false


func _saw(type: int) -> bool:
	return events.any(func(e: Array) -> bool: return e[0] == type)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _wait_until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("  ok   ", what)
	else:
		failed += 1
		print("  FAIL ", what)


func _note(what: String) -> void:
	print("  note ", what)
