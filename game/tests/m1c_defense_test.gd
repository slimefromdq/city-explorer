extends Node
## Headless checks for M1c: dodge roll, block / perfect block / guard break,
## hits and hitstun, and the attacking training dummies.
##   godot --headless --fixed-fps 60 res://game/tests/m1c_defense_test.tscn

const ARENA := preload("res://game/levels/test_arena/test_arena.tscn")

var arena: Node3D
var hero: Hero
var events: Array = []
var passed := 0
var failed := 0


func _ready() -> void:
	arena = ARENA.instantiate()
	add_child(arena)
	hero = arena.get_node("PlayerHero")
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false
	hero.movement_event.connect(func(t: int, d: Dictionary) -> void: events.append([t, d]))
	_dummies_active(false)
	await _frames(3)
	await _run()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _run() -> void:
	var t := hero.tuning

	print("roll")
	await _place("Spawn")
	events.clear()
	var p0 := hero.global_position
	hero.intent.move = Vector2(1, 0)
	hero.intent.roll_pressed = true
	await _frames(1)
	_check(hero.states.current_name == &"Roll" and _saw(MoveEvent.Type.ROLL), "roll press enters Roll and emits OnRoll")
	_check(hero.motor.crouched, "roll is low to the ground (crouch-height capsule)")
	await _wait_until(func() -> bool: return hero.states.current_name != &"Roll", 60)
	var dist := Vector3(hero.global_position - p0).length()
	_check(dist > 3.0 and dist < 6.5, "roll travels a short distance (%.2f m)" % dist)
	_check(hero.global_position.x > p0.x + 2.0, "roll goes in the movement direction (right)")
	hero.intent.move = Vector2.ZERO
	events.clear()
	hero.intent.roll_pressed = true
	await _frames(2)
	_check(not _saw(MoveEvent.Type.ROLL), "roll cooldown blocks an immediate second roll")
	await _frames(int(t.roll_cooldown * 60.0) + 2)
	hero.intent.roll_pressed = true
	await _frames(1)
	_check(_saw(MoveEvent.Type.ROLL), "rolls again after roll_cooldown")
	var back_dir: Vector3 = events[events.size() - 1][1]["direction"]
	_check(back_dir.z > 0.9, "no direction held = roll backwards from the camera (dir z %.2f)" % back_dir.z)
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)

	print("roll i-frames")
	await _frames(int(t.roll_cooldown * 60.0) + 2)
	hero.intent.roll_pressed = true
	await _frames(int((t.roll_iframe_start + t.roll_iframe_end) * 0.5 * 60.0))
	var hp := hero.defense.health
	_check(hero.take_hit(_hit(10.0)) == HitData.Result.DODGED and hero.defense.health == hp, "hit inside the i-frame window is DODGED, no damage")
	_check(hero.take_hit(_hit(10.0, Vector3.FORWARD, true, false)) == HitData.Result.HIT, "an undodgeable hit still lands mid-roll")
	await _wait_until(func() -> bool: return hero.states.current_name != &"Roll", 60)
	await _place("Spawn")
	_check(hero.take_hit(_hit(10.0)) == HitData.Result.HIT and hero.defense.health < t.max_health, "standing still, a hit lands (HIT)")

	print("roll vs air and tunnel")
	await _place("Spawn")
	await _frames(int(t.roll_cooldown * 60.0) + 2)
	events.clear()
	hero.intent.jump_pressed = true
	hero.intent.jump_held = true
	await _frames(10)
	hero.intent.roll_pressed = true
	await _frames(2)
	_check(hero.states.current_name == &"Air" and not _saw(MoveEvent.Type.ROLL), "no roll in the air")
	await _wait_until(func() -> bool: return hero.motor.on_floor, 120)
	hero.intent.jump_held = false
	hero.intent.roll_pressed = true   # pressed just before landing would be buffered; here right at landing
	await _frames(3)
	_check(_saw(MoveEvent.Type.ROLL), "a roll pressed as you land fires (buffered)")
	await _place("TunnelEntry")
	hero.intent.move = Vector2(0, 1)
	await _wait_until(func() -> bool: return hero.global_position.z < -0.6, 60)
	hero.intent.roll_pressed = true
	await _frames(30)
	_check(hero.global_position.z < -2.2, "a roll fits into the 1.4 m crouch tunnel (z = %.2f)" % hero.global_position.z)
	_release()

	print("block")
	await _place("Spawn")
	events.clear()
	hero.intent.block = true
	await _frames(1)
	_check(hero.states.current_name == &"Block" and _saw(MoveEvent.Type.BLOCK_START), "holding block enters Block and emits OnBlockStart")
	var guard0 := hero.defense.guard
	_check(hero.take_hit(_hit(20.0, Vector3.FORWARD)) == HitData.Result.PERFECT_BLOCK, "a front hit right away is a PERFECT block")
	_check(_saw(MoveEvent.Type.PERFECT_BLOCK), "OnPerfectBlock emitted")
	_check(hero.defense.health == t.max_health and hero.defense.guard == guard0, "perfect block: no damage, no guard loss")
	await _frames(int(t.perfect_block_window * 60.0) + 2)
	var r := hero.take_hit(_hit(20.0, Vector3.FORWARD))
	_check(r == HitData.Result.BLOCKED, "after the window, a front hit is BLOCKED")
	_check(absf(hero.defense.health - (t.max_health - 20.0 * t.block_damage_mult)) < 0.01, "blocked damage is reduced to %.0f%%" % (t.block_damage_mult * 100))
	_check(hero.defense.guard < guard0, "blocking drains the guard meter")
	_check(hero.take_hit(_hit(10.0, Vector3.BACK)) == HitData.Result.HIT, "a hit from behind gets through the guard")
	hero.intent.block = true
	await _wait_until(func() -> bool: return hero.states.current_name == &"Block", 60)
	_check(hero.take_hit(_hit(10.0, Vector3.FORWARD, false)) == HitData.Result.HIT, "an unblockable hit gets through the guard")
	await _place("Spawn")
	hero.intent.block = true
	hero.intent.move = Vector2(0, 1)
	await _frames(60)
	_check(absf(hero.horizontal_speed() - t.walk_speed * t.block_move_scale) < 0.3, "blocking slows you to %.1f m/s (got %.2f)" % [t.walk_speed * t.block_move_scale, hero.horizontal_speed()])
	hero.intent.move = Vector2.ZERO
	hero.intent.block = false
	await _frames(2)
	hero.intent.block = true
	await _frames(1)
	_check(hero.defense.blocking and hero.defense.perfect_window_left == 0.0, "re-raising the guard instantly gives no perfect window (anti-mash)")
	hero.intent.roll_pressed = true
	hero.intent.move = Vector2(1, 0)
	await _frames(1)
	_check(hero.states.current_name == &"Roll" and not hero.defense.blocking, "roll cancels out of block")
	_release()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)

	print("guard break, hitstun, death")
	await _place("Spawn")
	hero.intent.block = true
	await _frames(int(t.perfect_block_window * 60.0) + 2)
	var guard_hit := _hit(5.0, Vector3.FORWARD)
	guard_hit.guard_damage = t.guard_max + 1.0
	_check(hero.take_hit(guard_hit) == HitData.Result.GUARD_BREAK, "emptying the guard is a GUARD BREAK")
	_check(hero.states.current_name == &"Hitstun", "guard break stuns the hero")
	await _frames(int(t.guard_break_stun * 60.0) - 6)
	_check(hero.states.current_name == &"Hitstun", "...for guard_break_stun seconds")
	await _frames(12)
	_check(hero.states.current_name != &"Hitstun", "...then recovers")
	_release()
	await _place("DashLaneStart")
	hero.intent.dash_pressed = true
	await _frames(4)
	var flinch_hit := _hit(5.0)
	flinch_hit.flinch = 0.3
	hero.take_hit(flinch_hit)
	_check(hero.states.current_name == &"Hitstun", "a flinching hit interrupts the sigil leap windup (it's the vulnerable window)")
	await _frames(40)
	_check(get_tree().get_nodes_in_group(&"sigils").is_empty(), "the interrupted sigil fades away")
	await _place("Spawn")
	var kill := _hit(t.max_health + 5.0)
	hero.take_hit(kill)
	_check(hero.defense.dead, "zero health = down")
	await _frames(int(t.death_respawn_delay * 60.0) + 5)
	_check(not hero.defense.dead and hero.defense.health == t.max_health, "respawns with full health")

	print("dummies")
	await _dummy_round("Swinger", "SwingerFront", false, HitData.Result.HIT, "Swinger hits a hero standing in front of it")
	await _dummy_round("Swinger", "SwingerFront", true, HitData.Result.BLOCKED, "Swinger's swing is blocked when guarding")
	await _perfect_round()
	await _dummy_round("Shooter", "ShooterFront", false, HitData.Result.HIT, "Shooter's orb hits from 10 m")
	await _dummy_round("Shooter", "ShooterFront", true, HitData.Result.BLOCKED, "Shooter's orb is blocked when guarding")
	await _dummy_round("Slammer", "SlammerFront", true, HitData.Result.HIT, "Slammer's slam goes through block (unblockable)")
	await _roll_round()
	var overlay := get_node("/root/DebugOverlay")
	var text := String(overlay._label.text)
	_check(text.contains("guard") and text.contains("roll") and text.contains("last hit"), "debug overlay shows health/guard, roll and block")


## Stand in front of one dummy (others off) and see what its next attack does.
func _dummy_round(dummy_name: String, marker: String, guard: bool, expect: int, what: String) -> void:
	await _place(marker)
	var dm := _dummy(dummy_name)
	dm._to_idle()
	dm._cd = 0.2
	dm.active = true
	hero.intent.block = guard
	var results: Array = []
	var cb := func(_h: HitData, res: int, _a: float) -> void: results.append(res)
	hero.defense.hit_taken.connect(cb)
	if guard:
		# Raise the guard early so the hit lands after the perfect window.
		await _frames(int(hero.tuning.perfect_block_window * 60.0) + 4)
	await _wait_until(func() -> bool: return results.size() > 0, 300)
	hero.defense.hit_taken.disconnect(cb)
	dm.active = false
	_release()
	_check(results.size() > 0 and results[0] == expect, "%s (got %s)" % [what, _res_name(results[0] if results.size() > 0 else -1)])


func _perfect_round() -> void:
	await _place("SwingerFront")
	var dm := _dummy("Swinger")
	dm._to_idle()
	dm._cd = 0.1
	dm.active = true
	# Raise the guard just before the swing lands.
	await _wait_until(func() -> bool: return dm.phase == TrainingDummy.Phase.WINDUP and dm._t >= dm.windup - 0.07, 300)
	hero.intent.block = true
	await _frames(8)
	_check(hero.defense.last_result == HitData.Result.PERFECT_BLOCK, "timing the guard against the swing is a PERFECT block")
	_check(dm.phase == TrainingDummy.Phase.STAGGERED, "a perfect block staggers the dummy")
	dm.active = false
	_release()


func _roll_round() -> void:
	await _place("SlammerFront")
	var dm := _dummy("Slammer")
	dm._to_idle()
	dm._cd = 0.1
	dm.active = true
	var results: Array = []
	var cb := func(_h: HitData, res: int, _a: float) -> void: results.append(res)
	hero.defense.hit_taken.connect(cb)
	await _wait_until(func() -> bool: return dm.phase == TrainingDummy.Phase.WINDUP and dm._t >= dm.windup - 0.1, 300)
	# Roll sideways, staying inside the slam radius, so only the i-frames save us.
	hero.intent.move = Vector2(1, 0)
	hero.intent.roll_pressed = true
	await _wait_until(func() -> bool: return results.size() > 0 or dm.phase != TrainingDummy.Phase.WINDUP, 60)
	await _frames(2)
	hero.defense.hit_taken.disconnect(cb)
	dm.active = false
	_release()
	_check(results.size() > 0 and results[0] == HitData.Result.DODGED, "rolling as the slam lands DODGES it (got %s)" % _res_name(results[0] if results.size() > 0 else -1))


# ------------------------------------------------------------------ helpers

## A test hit coming from `from` (relative to the hero's facing: FORWARD = in front).
func _hit(dmg: float, from := Vector3.FORWARD, blockable := true, dodgeable := true) -> HitData:
	var h := HitData.new()
	h.damage = dmg
	h.guard_damage = 20.0
	h.blockable = blockable
	h.dodgeable = dodgeable
	h.from_dir = Basis(Vector3.UP, hero.face_yaw) * from
	return h


func _dummy(n: String) -> TrainingDummy:
	return arena.get_node("Dummies/" + n) as TrainingDummy


func _dummies_active(on: bool) -> void:
	for d in get_tree().get_nodes_in_group(&"dummies"):
		(d as TrainingDummy).active = on


func _res_name(r: int) -> String:
	return HitData.Result.keys()[r] if r >= 0 else "nothing"


func _place(marker: String) -> void:
	var m := arena.get_node("TestPoints/" + marker) as Marker3D
	_release()
	hero.global_position = m.global_position
	hero.velocity = Vector3.ZERO
	hero.motor.reset()
	hero.defense.reset()
	hero.states.change(&"Air")
	var fwd := -m.global_basis.z
	hero.intent.aim_yaw = atan2(-fwd.x, -fwd.z)
	hero.intent.aim_dir = fwd
	hero.face_yaw = hero.intent.aim_yaw
	hero.reset_physics_interpolation()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)
	await _frames(2)


func _release() -> void:
	var i := hero.intent
	i.move = Vector2.ZERO
	i.sprint = false
	i.crouch = false
	i.block = false
	i.jump_held = false
	i.jump_pressed = false
	i.dash_pressed = false
	i.roll_pressed = false


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
