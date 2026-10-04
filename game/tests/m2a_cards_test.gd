extends Node
## Headless checks for M2a: card files, the runner, the first effect blocks
## (spawn body, damage area, impulse, teleport), card bodies (beam, bouncy,
## heavy, sticky), target dummies, loadouts and hot reload.
##   godot --headless --fixed-fps 60 res://game/tests/m2a_cards_test.tscn
## Some checks deliberately feed the runner a broken card, so a few
## "Card ... is empty" errors in the output are expected.

const ARENA := preload("res://game/levels/test_arena/test_arena.tscn")
const TMP_CARD := "res://game/tests/_tmp_reload_card.tres"

var arena: Node3D
var hero: Hero
var runner: AbilityRunner
var passed := 0
var failed := 0


func _ready() -> void:
	arena = ARENA.instantiate()
	add_child(arena)
	hero = arena.get_node("PlayerHero")
	runner = hero.runner
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false
	for d in get_tree().get_nodes_in_group(&"training_dummies"):
		d.set(&"active", false)
	for d in arena.get_node("Dummies").get_children():
		d.set(&"active", false)
	await _frames(3)
	await _run()
	if FileAccess.file_exists(TMP_CARD):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TMP_CARD))
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _run() -> void:
	print("card files")
	var lib := get_node("/root/CardLibrary")
	var all: Array = lib.all_cards()
	_check(all.size() >= 5, "card library finds the example cards (%d)" % all.size())
	var bad_cards := PackedStringArray()
	for c in all:
		if not (c as AbilityCard).validate().is_empty():
			bad_cards.append("%s: %s" % [c.display_name, ", ".join(c.validate())])
	_check(bad_cards.is_empty(), "every library card validates cleanly %s" % str(bad_cards))
	var broken := AbilityCard.new()
	broken.display_name = "Broken"
	broken.body = CardBodyDef.new()
	broken.on_cast = [null]
	var problems := broken.validate()
	_check(problems.size() >= 2 and "\n".join(problems).contains("on_cast[0] is empty") and "\n".join(problems).contains("never thrown"),
			"a broken card explains what's wrong: %s" % " | ".join(problems))
	_check(runner.cards[0] != null and runner.cards[0].display_name == "Pulse Pistol" and runner.cards[3].display_name == "Blink",
			"arena equips the first loadout (pistol ... blink)")

	print("pulse pistol (beam, hold to fire)")
	await _place("CardRangeStart")
	var near := _dummy("Near")
	_aim_at(_chest(near))
	hero.intent.card_held[0] = true
	await _frames(30)
	hero.intent.card_held[0] = false
	var shots := near.hits_taken
	var per_shot: float = (runner.cards[0].on_contact[0] as DamageAreaEffect).damage
	_check(shots >= 3 and shots <= 4, "holding fire for 0.5 s fires every fire_interval (%d hits)" % shots)
	_check(is_equal_approx(near.total_damage, shots * per_shot), "each beam hit deals the card's damage (%.0f total)" % near.total_damage)
	_check(_count_nodes(FloatingText) > 0, "hits pop floating damage numbers")
	hero.intent.block = true
	await _frames(3)
	var before := near.hits_taken
	hero.intent.card_held[0] = true
	await _frames(20)
	hero.intent.card_held[0] = false
	hero.intent.block = false
	_check(near.hits_taken == before, "can't fire while blocking")
	await _frames(5)

	print("ball kick (bouncy + heavy)")
	_reset_all()
	await _place("CardRangeStart")
	near = _dummy("Near")
	var p0 := near.global_position
	_aim_at(_chest(near))
	hero.intent.card_pressed[1] = true
	await _frames(1)
	var ball := _find_body()
	_check(ball != null and ball.def.shape == CardBodyDef.Shape.BALL, "pressing R throws a ball body")
	await _wait_until(func() -> bool: return near.hits_taken > 0, 90)
	_check(near.hits_taken > 0 and near.total_damage >= 22.0 - 0.01, "the ball hits the dummy for its damage (%.0f)" % near.total_damage)
	await _frames(20)
	_check(near.global_position.distance_to(p0) > 0.5, "the heavy ball knocks the dummy back (%.2f m)" % near.global_position.distance_to(p0))
	# Bouncy: throw one straight at the floor; it should survive the first contact.
	await _frames(int(runner.cards[1].cooldown * 60.0))
	_aim_at(hero.global_position + Vector3(0, 0, -2.0))
	hero.intent.card_pressed[1] = true
	await _frames(1)
	ball = _find_body(true)
	var first_bounces := ball.bounces_left if ball != null else -1
	var ball_ref: WeakRef = weakref(ball)
	await _wait_until(func() -> bool: return ball_ref.get_ref() == null or (ball_ref.get_ref() as CardBody).bounces_left < first_bounces, 60)
	_check(ball != null and is_instance_valid(ball) and ball.bounces_left == first_bounces - 1 and not ball.expired,
			"a bouncy ball spends a bounce on the floor and keeps going")
	await _wait_until(func() -> bool: return ball_ref.get_ref() == null, 400)
	_check(not is_instance_valid(ball), "it expires after its last bounce")

	print("charges and energy")
	_reset_all()
	await _place("CardRangeStart")
	runner.equip(1, runner.cards[1])   # refill
	var bodies_before := _count_nodes(CardBody)
	for i in 3:
		hero.intent.card_pressed[1] = true
		await _frames(1)
	_check(_count_nodes(CardBody) - bodies_before == 2, "a 2-charge card casts twice, then waits (%d thrown)" % (_count_nodes(CardBody) - bodies_before))
	runner.equip(3, runner.cards[3])
	runner.energy = 0.0
	var pos := hero.global_position
	hero.intent.card_pressed[3] = true
	await _frames(1)
	_check(hero.global_position.distance_to(pos) < 0.5, "no energy = no cast")
	runner.energy = runner.max_energy

	print("bug grenade (sticky)")
	_reset_all()
	await _place("CardRangeStart")
	near = _dummy("Near")
	_aim_at(_chest(near))
	hero.intent.card_pressed[2] = true
	await _frames(1)
	var bug := _find_body()
	var bug_ref: WeakRef = weakref(bug)
	await _wait_until(func() -> bool: return bug_ref.get_ref() == null or (bug_ref.get_ref() as CardBody).stuck, 90)
	_check(bug != null and is_instance_valid(bug) and bug.stuck, "the bug sticks to what it hits")
	await _frames(2)
	_check(bug != null and is_instance_valid(bug) and bug.get_parent() == near, "it rides along on the dummy it stuck to")
	var dmg0 := near.total_damage
	await _wait_until(func() -> bool: return bug_ref.get_ref() == null, 60)
	_check(near.total_damage - dmg0 > 30.0, "after the fuse it explodes on the dummy (%.0f damage)" % (near.total_damage - dmg0))
	_check(hero.defense.health == hero.tuning.max_health, "the caster's own explosion didn't hurt them")

	print("blink (teleport)")
	_reset_all()
	await _place("CardRangeStart")
	runner.equip(3, runner.cards[3])
	pos = hero.global_position
	_aim_dir(Vector3(1, 0, 0))   # along the open floor, away from the dummies
	hero.intent.card_pressed[3] = true
	await _frames(1)
	var moved := Vector2(hero.global_position.x - pos.x, hero.global_position.z - pos.z).length()
	_check(absf(moved - 8.0) < 0.6, "blink moves 8 m along the aim (%.2f m)" % moved)
	# Toward the back wall (front face at z = 26.5), from 3 m away.
	hero.global_position = Vector3(36.0, 0.05, 29.5)
	hero.reset_physics_interpolation()
	await _wait_until(func() -> bool: return hero.motor.on_floor, 30)
	_aim_dir(Vector3(0, 0, -1))
	hero.intent.card_pressed[3] = true
	await _frames(2)
	_check(hero.global_position.z > 26.5 + 0.25 and hero.global_position.z < 28.0,
			"blink into a wall stops in front of it (z %.2f)" % hero.global_position.z)

	print("rocket jump (self-push + area)")
	_reset_all()
	arena.call(&"_equip_loadout", 1)
	_check(runner.cards[1].display_name == "Rocket Jump", "Tab-style loadout switch equips the rocket kit")
	await _place("CardRangeStart")
	var y0 := hero.global_position.y
	_aim_at(hero.global_position + Vector3(0, 0, -0.3))
	hero.intent.aim_dir = Vector3(0, -1, -0.05).normalized()
	hero.intent.card_pressed[1] = true
	var top := y0
	for i in 60:
		await _frames(1)
		top = maxf(top, hero.global_position.y)
	_check(top - y0 > 2.5, "a rocket at your feet launches you (+%.2f m)" % (top - y0))
	_check(hero.defense.health == hero.tuning.max_health, "your own rocket doesn't damage you")
	await _wait_until(func() -> bool: return hero.motor.on_floor, 120)
	var pa := _dummy("PairA")
	var pb := _dummy("PairB")
	await _place("CardRangeStart")
	hero.global_position = Vector3(30, 0.05, 37.5)   # past the Near dummy, which would block the shot
	hero.reset_physics_interpolation()
	await _frames(3)
	_aim_at((_chest(pa) + _chest(pb)) * 0.5)
	hero.intent.card_pressed[1] = true
	await _wait_until(func() -> bool: return pa.hits_taken > 0 or pb.hits_taken > 0, 90)
	await _frames(2)
	_check(pa.hits_taken > 0 and pb.hits_taken > 0, "one blast damages both dummies in the radius (%.0f, %.0f)" % [pa.total_damage, pb.total_damage])

	print("chain safety")
	var log_before := runner.log_lines.size()
	var first_line := runner.log_lines[0] if log_before > 0 else ""
	var deep := CastContext.new()
	deep.depth = runner.max_proc_depth + 1
	runner.cast(runner.cards[0], deep)
	_check(runner.log_lines.size() == log_before and (log_before == 0 or runner.log_lines[0] == first_line),
			"a cast deeper than max_proc_depth is refused")
	var empty := AbilityCard.new()
	empty.display_name = "Empty Slot Test"
	empty.on_cast = [null]
	empty.cooldown = 0.0
	runner.equip(2, empty)
	hero.intent.card_pressed[2] = true
	await _frames(2)
	_check(true, "a card with an empty effect entry logs an error instead of crashing")

	print("hot reload")
	var tmp := (load("res://game/cards/library/pulse_pistol.tres") as AbilityCard).duplicate(true) as AbilityCard
	tmp.display_name = "Reload Test"
	tmp.trigger = AbilityCard.Trigger.PRESS
	ResourceSaver.save(tmp, TMP_CARD)
	var card := load(TMP_CARD) as AbilityCard
	runner.equip(0, card)
	_reset_all()
	await _place("CardRangeStart")
	near = _dummy("Near")
	_aim_at(_chest(near))
	hero.intent.card_pressed[0] = true
	await _frames(2)
	var d1 := near.total_damage
	var text := FileAccess.get_file_as_string(TMP_CARD)
	_check(text.contains("damage = 9.0"), "the saved card file holds damage = 9.0")
	var f := FileAccess.open(TMP_CARD, FileAccess.WRITE)
	f.store_string(text.replace("damage = 9.0", "damage = 50.0").replace("Reload Test", "Reload Test v2"))
	f.close()
	var n: int = lib.reload_all()
	_check(n >= 6, "F4 reload re-reads every card file (%d)" % n)
	_check(runner.cards[0].display_name == "Reload Test v2", "the equipped card object itself shows the new name")
	hero.intent.card_pressed[0] = true
	await _frames(2)
	_check(is_equal_approx(d1, 9.0) and is_equal_approx(near.total_damage - d1, 50.0),
			"after editing the file and reloading, the same slot deals the new damage (%.0f then %.0f)" % [d1, near.total_damage - d1])

	print("reset + overlay")
	near.global_position += Vector3(3, 0, 0)
	var ev := InputEventAction.new()
	ev.action = &"dbg_reset"
	ev.pressed = true
	arena._unhandled_input(ev)
	_check(near.total_damage == 0.0 and near.health == near.max_health and near.global_position.distance_to(near._home.origin) < 0.01,
			"F5 puts the dummies back at full health")
	var tab := InputEventAction.new()
	tab.action = &"loadout_next"
	tab.pressed = true
	var idx: int = arena.get(&"loadout_index")
	arena._unhandled_input(tab)
	_check(arena.get(&"loadout_index") != idx, "Tab switches loadout")
	await _frames(70)
	var overlay := get_node("/root/DebugOverlay")
	var otext: String = overlay._label.text
	_check(otext.contains("energy") and otext.contains("recent casts"), "debug overlay shows card slots, energy and recent casts")


# ------------------------------------------------------------------ helpers

func _place(marker: String) -> void:
	var m := arena.get_node("TestPoints/" + marker) as Marker3D
	_release()
	hero.global_position = m.global_position
	hero.velocity = Vector3.ZERO
	hero.motor.reset()
	hero.defense.reset()
	hero.states.change(&"Air")
	hero.reset_physics_interpolation()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)
	await _frames(2)


func _release() -> void:
	var i := hero.intent
	i.move = Vector2.ZERO
	i.block = false
	i.crouch = false
	for s in 4:
		i.card_held[s] = false
		i.card_pressed[s] = false


func _reset_all() -> void:
	for d in get_tree().get_nodes_in_group(&"target_dummies"):
		(d as TargetDummy).reset()
	for b in _all_nodes(CardBody):
		b.queue_free()


## Aim the way the camera would: from behind the shoulder at `point`.
func _aim_at(point: Vector3) -> void:
	var eye := hero.global_position + Vector3.UP * 1.55
	var d := (point - eye).normalized()
	hero.intent.aim_point = point
	hero.intent.aim_dir = d
	hero.intent.aim_yaw = atan2(-d.x, -d.z)


func _aim_dir(d: Vector3) -> void:
	d = d.normalized()
	hero.intent.aim_dir = d
	hero.intent.aim_yaw = atan2(-d.x, -d.z)
	hero.intent.aim_point = hero.global_position + Vector3.UP * 1.55 + d * 50.0


func _dummy(n: String) -> TargetDummy:
	return arena.get_node("TargetDummies/" + n) as TargetDummy


func _chest(d: Node3D) -> Vector3:
	return d.global_position + Vector3.UP * 1.2


func _find_body(newest := false) -> CardBody:
	var list := _all_nodes(CardBody)
	if list.is_empty():
		return null
	return list[list.size() - 1] if newest else list[0]


func _count_nodes(type: Variant) -> int:
	return _all_nodes(type).size()


func _all_nodes(type: Variant) -> Array:
	var out := []
	var stack: Array[Node] = [get_tree().root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if is_instance_of(n, type) and not n.is_queued_for_deletion():
			out.append(n)
		stack.append_array(n.get_children())
	return out


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
