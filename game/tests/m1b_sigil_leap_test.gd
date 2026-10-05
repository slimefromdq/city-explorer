extends Node
## Headless checks for M1b, the sigil leap. Same approach as the M1a test: the
## real arena, keyboard off, the hero driven through its intent.
##   godot --headless --fixed-fps 60 res://game/tests/m1b_sigil_leap_test.tscn

const ARENA := preload("res://game/levels/test_arena/test_arena.tscn")

var arena: Node3D
var hero: Hero
var events: Array = []   # [type, data, physics_frame]
var passed := 0
var failed := 0


func _ready() -> void:
	arena = ARENA.instantiate()
	add_child(arena)
	hero = arena.get_node("PlayerHero")
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false
	hero.movement_event.connect(func(t: int, d: Dictionary) -> void: events.append([t, d, Engine.get_physics_frames()]))
	await _frames(3)
	await _run()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _run() -> void:
	var t := hero.tuning

	print("startup is committed")
	await _place("DashLaneStart")
	events.clear()
	_aim(0.0)
	var charges_before := hero.motor.dash_pool.available()
	hero.intent.dash_pressed = true
	await _frames(1)
	_check(hero.states.current_name == &"DashStartup", "pressing dash enters DashStartup")
	_check(_count(MoveEvent.Type.DASH_START) == 1, "OnDashStart emitted once on commit")
	_check(hero.motor.dash_pool.available() == charges_before - 1, "a charge was spent (%d -> %d)" % [charges_before, hero.motor.dash_pool.available()])
	_check(get_tree().get_nodes_in_group(&"sigils").size() == 1, "a sigil appears behind the hero")
	var start_frame := Engine.get_physics_frames()
	hero.intent.jump_pressed = true
	hero.intent.crouch = true
	hero.intent.move = Vector2(1, 0)
	await _frames(4)
	_check(hero.states.current_name == &"DashStartup" and not _saw(MoveEvent.Type.JUMP), "jump / crouch / move can't cancel the startup")
	hero.intent.crouch = false
	hero.intent.move = Vector2.ZERO
	await _wait_until(func() -> bool: return _saw(MoveEvent.Type.DASH_LAUNCH), 60)
	var formed := _first(MoveEvent.Type.SIGIL_FORMED)
	var launched := _first(MoveEvent.Type.DASH_LAUNCH)
	var startup_s: float = (launched[2] - start_frame + 1) / 60.0
	_check(absf(startup_s - t.dash_startup) <= 1.0 / 60.0 + 0.001, "startup lasts dash_startup (%.3f s vs %.3f s)" % [startup_s, t.dash_startup])
	_check(not formed.is_empty() and formed[2] <= launched[2], "OnSigilFormed fires before OnDashLaunch")

	print("launch distance and direction")
	await _place("DashLaneStart")
	_aim(0.0)
	var p0 := hero.global_position
	hero.intent.dash_pressed = true
	await _wait_until(func() -> bool: return hero.states.current_name == &"DashLaunch", 30)
	var launch_pos := hero.global_position
	await _wait_until(func() -> bool: return hero.states.current_name != &"DashLaunch", 60)
	var flat := Vector2(hero.global_position.x - launch_pos.x, hero.global_position.z - launch_pos.z).length()
	var along := Vector3(hero.global_position - launch_pos).length()
	_check(absf(along - t.dash_distance) < 0.6, "leap covers dash_distance (%.2f m vs %.2f m)" % [along, t.dash_distance])
	_check(hero.global_position.z > p0.z + 5.0, "leap goes where the camera aims (south here, moved %.1f m)" % (hero.global_position.z - p0.z))
	_note("startup drift %.2f m; flat travel during launch %.2f m" % [Vector3(launch_pos - p0).length(), flat])
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 120)

	await _place("DashLaneStart")
	_aim(deg_to_rad(40.0))
	var y0 := hero.global_position.y
	hero.intent.dash_pressed = true
	await _wait_until(func() -> bool: return hero.states.current_name == &"DashLaunch", 30)
	await _wait_until(func() -> bool: return hero.states.current_name != &"DashLaunch", 60)
	_check(hero.global_position.y - y0 > t.dash_distance * 0.5, "aiming up leaps upward (+%.2f m)" % (hero.global_position.y - y0))
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 180)

	print("charges and cooldown")
	await _place("DashLaneStart")
	hero.motor.dash_pool.fill()
	_aim(0.0)
	events.clear()
	for n in t.dash_charges + 1:
		hero.intent.dash_pressed = true
		await _wait_until(func() -> bool: return hero.states.current_name == &"DashLaunch", 30)
		await _wait_until(func() -> bool: return hero.states.current_name != &"DashLaunch" and hero.motor.dash_cd_left <= 0.0, 90)
		hero.intent.aim_yaw += PI   # turn around so the next leap stays in the lane
		_aim(0.0)
	_check(_count(MoveEvent.Type.DASH_START) == t.dash_charges, "only %d leaps with %d charges (got %d)" % [t.dash_charges, t.dash_charges, _count(MoveEvent.Type.DASH_START)])
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 180)
	await _frames(int(t.dash_recharge_time * 60.0) + 5)
	_check(hero.motor.dash_pool.available() >= 1, "a charge comes back after dash_recharge_time")
	events.clear()
	hero.intent.dash_pressed = true
	await _wait_until(func() -> bool: return hero.states.current_name == &"DashLaunch", 30)
	await _wait_until(func() -> bool: return hero.states.current_name != &"DashLaunch", 60)
	hero.motor.dash_pool.fill()
	hero.intent.dash_pressed = true
	await _frames(2)
	_check(_count(MoveEvent.Type.DASH_START) == 1, "dash_cooldown blocks an instant second leap")
	await _wait_until(func() -> bool: return hero.motor.dash_cd_left < t.dash_buffer * 0.5, 60)
	hero.intent.dash_pressed = true
	await _frames(int(t.dash_buffer * 60.0))
	_check(_count(MoveEvent.Type.DASH_START) == 2, "...but a press inside dash_buffer fires once the cooldown ends")
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 180)

	print("geometry: no tunnelling, sigil clips against walls")
	await _place("ThinWallFront")
	hero.motor.dash_pool.fill()
	_aim(0.0)   # north, straight at the 0.2 m wall 3 m away
	hero.intent.dash_pressed = true
	await _wait_until(func() -> bool: return hero.states.current_name == &"DashLaunch", 30)
	var deepest := 99.0
	for i in 40:
		await _frames(1)
		deepest = minf(deepest, hero.global_position.z)
	_check(deepest > 10.1 + t.capsule_radius - 0.05, "full-speed leap stops at the thin wall (closest z %.2f, wall face 10.1)" % deepest)

	await _place("ThinWallBack")
	hero.motor.dash_pool.fill()
	events.clear()
	_aim(0.0)   # the marker faces south, back against the wall
	hero.intent.dash_pressed = true
	await _frames(2)
	var sigils := get_tree().get_nodes_in_group(&"sigils")
	var s: Sigil = sigils[sigils.size() - 1] if sigils.size() > 0 else null
	_check(s != null and s.clipped, "sigil is flagged clipped when a wall is behind the hero")
	_check(s != null and absf(s.global_position.z - 10.13) < 0.05, "clipped sigil sits flat on the wall (z %.3f)" % (s.global_position.z if s else 0.0))
	await _wait_until(func() -> bool: return _saw(MoveEvent.Type.DASH_LAUNCH), 30)
	_check(_saw(MoveEvent.Type.DASH_LAUNCH), "the leap still launches (no fizzle)")
	var sf := _first(MoveEvent.Type.SIGIL_FORMED)
	_check(not sf.is_empty() and sf[1].get("clipped", false), "OnSigilFormed reports clipped = true")
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 180)

	await _place("UnderCeiling")
	hero.motor.dash_pool.fill()
	_aim(deg_to_rad(70.0))
	hero.intent.dash_pressed = true
	var top := 0.0
	for i in 50:
		await _frames(1)
		top = maxf(top, hero.global_position.y + t.stand_height)
	_check(top <= 2.3 + 0.05, "leaping up into a 2.3 m ceiling never pushes the head through it (head %.2f m)" % top)
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 180)

	print("hang and cleanup")
	await _place("DashLaneStart")
	hero.motor.dash_pool.fill()
	hero.intent.jump_pressed = true
	hero.intent.jump_held = true
	await _frames(30)   # falling from the jump apex
	_aim(0.0)
	hero.intent.dash_pressed = true
	await _frames(2)
	var max_vy := 0.0
	while hero.states.current_name == &"DashStartup":
		max_vy = maxf(max_vy, absf(hero.velocity.y))
		await _frames(1)
	_check(max_vy < 3.0, "mid-air startup hangs (vertical speed stays under 3 m/s, max %.2f)" % max_vy)
	_release()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 180)
	await _frames(60)
	_check(get_tree().get_nodes_in_group(&"sigils").is_empty(), "sigils fade out and free themselves")
	var overlay := get_node("/root/DebugOverlay")
	_check(String(overlay._label.text).contains("charges"), "debug overlay shows dash charges")


# ------------------------------------------------------------------ helpers

func _aim(pitch: float) -> void:
	var yaw := hero.intent.aim_yaw
	hero.intent.aim_dir = Basis(Vector3.UP, yaw) * Vector3(0, sin(pitch), -cos(pitch))


func _place(marker: String) -> void:
	var m := arena.get_node("TestPoints/" + marker) as Marker3D
	_release()
	hero.global_position = m.global_position
	hero.velocity = Vector3.ZERO
	hero.motor.reset()
	hero.states.change(&"Air")
	# Read the heading from the marker's forward axis (Euler angles can flip at 180 degrees).
	var fwd := -m.global_basis.z
	hero.intent.aim_yaw = atan2(-fwd.x, -fwd.z)
	hero.face_yaw = hero.intent.aim_yaw
	_aim(0.0)
	hero.reset_physics_interpolation()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)
	await _frames(2)


func _release() -> void:
	var i := hero.intent
	i.move = Vector2.ZERO
	i.sprint = false
	i.crouch = false
	i.jump_held = false
	i.jump_pressed = false
	i.dash_pressed = false


func _saw(type: int) -> bool:
	return events.any(func(e: Array) -> bool: return e[0] == type)


func _count(type: int) -> int:
	return events.filter(func(e: Array) -> bool: return e[0] == type).size()


func _first(type: int) -> Array:
	for e in events:
		if e[0] == type:
			return e
	return []


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
