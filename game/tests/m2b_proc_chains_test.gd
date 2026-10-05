extends Node
## Headless checks for M2b: proc chains (Cast card) and their safety limits,
## movement-event cards (Sigil Volley on OnDashLaunch, Riposte on
## OnPerfectBlock), the RELEASE trigger, status effects (burn, slow),
## modifiers (Overclock) and Transform (Hatchling Ball -> Bug Grenade).
##   godot --headless --fixed-fps 60 res://game/tests/m2b_proc_chains_test.tscn
## The runaway-chain checks are SUPPOSED to print "Proc chain stopped" warnings.

const ARENA := preload("res://game/levels/test_arena/test_arena.tscn")
const LIB := "res://game/cards/library/"

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
	for d in arena.get_node("Dummies").get_children():
		d.set(&"active", false)
	await _frames(3)
	await _run()
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _run() -> void:
	print("library")
	var all: Array = get_node("/root/CardLibrary").all_cards()
	var bad := PackedStringArray()
	for c in all:
		for p in (c as AbilityCard).validate():
			bad.append("%s: %s" % [c.display_name, p])
	_check(all.size() >= 12 and bad.is_empty(), "all %d library cards validate cleanly %s" % [all.size(), str(bad)])

	print("proc chain: Splitter Shot -> Shrapnel")
	_equip(2)
	_check(runner.cards[1].display_name == "Splitter Shot", "chains loadout equipped")
	_reset_all()
	await _place("CardRangeStart")
	hero.global_position = Vector3(30, 0.05, 37.5)
	hero.reset_physics_interpolation()
	await _frames(3)
	var pa := _dummy("PairA")
	_aim_at(_chest(pa))
	var bodies_before := _count_nodes(CardBody)
	hero.intent.card_pressed[1] = true
	await _wait_until(func() -> bool: return pa.hits_taken > 0, 60)
	await _frames(1)
	var shards := _all_nodes(CardBody).filter(func(b: CardBody) -> bool: return b.ctx.card.display_name == "Shrapnel")
	_check(pa.hits_taken == 1 and is_equal_approx(pa.total_damage, 18.0), "the slug hits PairA for 18")
	_check(shards.size() == 5, "the hit casts Shrapnel: 5 shards (%d)" % shards.size())
	_check(shards.size() > 0 and (shards[0] as CardBody).ctx.depth == 1, "shrapnel is chain depth 1")
	_check(_log_has("Shrapnel  depth 1"), "the cast log shows the chain")
	await _frames(40)
	_check(pa.hits_taken == 1, "shrapnel passes out of the dummy it burst from instead of hitting it again")
	var others := 0.0
	for d in get_tree().get_nodes_in_group(&"target_dummies"):
		if d != pa:
			others += (d as TargetDummy).total_damage
	_note("shrapnel damage to dummies behind: %.0f" % others)

	print("runaway chains are stopped")
	var loop := AbilityCard.new()
	loop.display_name = "Ouroboros"
	loop.trigger = AbilityCard.Trigger.PROC_ONLY
	var self_cast := CastCardEffect.new()
	self_cast.card = loop
	loop.on_cast = [self_cast]
	var n0 := _casts_named("Ouroboros")
	runner.cast(loop, _ctx())
	_check(_casts_named("Ouroboros") - n0 == runner.max_proc_depth + 1,
			"a card that casts itself stops after max_proc_depth (%d casts)" % (_casts_named("Ouroboros") - n0))
	self_cast.card = null   # break the self-reference so it can be freed
	var leaf := AbilityCard.new()
	leaf.display_name = "Leaf"
	var mid := AbilityCard.new()
	mid.display_name = "Mid"
	var fan := CastCardEffect.new()
	fan.card = leaf
	fan.times = 16
	mid.on_cast = [fan]
	var root := AbilityCard.new()
	root.display_name = "Root"
	var fan2 := CastCardEffect.new()
	fan2.card = mid
	fan2.times = 16
	root.on_cast = [fan2]
	var counter := {"n": 0}
	var cb := func(_c: AbilityCard, _s: int, _d: int) -> void: counter.n += 1
	runner.card_cast.connect(cb)
	runner._casts_this_frame = 0
	runner.cast(root, _ctx())
	runner.card_cast.disconnect(cb)
	_check(counter.n == runner.max_casts_per_frame, "a fan-out of 1 + 16 + 256 casts is capped at %d per frame (%d)" % [runner.max_casts_per_frame, counter.n])

	print("movement event: Sigil Volley on OnDashLaunch")
	_reset_all()
	await _place("CardRangeStart")
	runner.equip(2, runner.cards[2])
	_aim_dir(Vector3(1, 0.15, 0))
	var vb := _count_named_bodies("Sigil Volley")
	hero.intent.dash_pressed = true
	await _wait_until(func() -> bool: return hero.states.current_name == &"DashLaunch", 40)
	await _frames(1)
	var volley := _all_nodes(CardBody).filter(func(b: CardBody) -> bool: return b.ctx.card.display_name == "Sigil Volley")
	_check(volley.size() - vb == 3, "leaping fires 3 Sigil Volley bolts by itself (%d)" % (volley.size() - vb))
	var along := 0.0
	for b in volley:
		along += (b as CardBody).linear_velocity.normalized().dot(Vector3(1, 0.15, 0).normalized())
	_check(volley.size() > 0 and along / volley.size() > 0.85, "the bolts fly the way you leapt (%.2f)" % (along / maxf(volley.size(), 1)))
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 120)

	print("movement event: Riposte on OnPerfectBlock")
	_reset_all()
	await _place("CardRangeStart")
	hero.global_position = Vector3(30, 0.05, 44.5)
	hero.reset_physics_interpolation()
	await _frames(3)
	var near := _dummy("Near")
	_aim_at(_chest(near))
	hero.intent.block = true
	await _frames(2)
	var hit := HitData.new()
	hit.damage = 10.0
	hit.attacker = near
	hit.from_dir = Vector3(0, 0, -1)
	hit.position = hero.global_position + Vector3(0, 1, -0.5)
	var res := hero.take_hit(hit)
	await _frames(2)
	hero.intent.block = false
	_check(res == HitData.Result.PERFECT_BLOCK, "a hit at the start of a block is a perfect block")
	_check(near.total_damage > 15.0 and _log_has("Riposte"), "the perfect block fires Riposte, even mid-block (Near took %.0f)" % near.total_damage)
	await _frames(10)

	print("RELEASE: Ember Bomb")
	_equip(3)
	_reset_all()
	await _place("CardRangeStart")
	_aim_dir(Vector3(1, 0, 0))
	hero.intent.card_held[1] = true
	hero.intent.card_pressed[1] = true
	await _frames(30)
	var mid_charge := runner.charge_of(1)
	_check(mid_charge > 0.4 and mid_charge < 0.6, "holding charges it (%.2f after 0.5 s)" % mid_charge)
	_check(_count_named_bodies("Ember Bomb") == 0, "nothing is thrown while still holding")
	await _frames(40)
	hero.intent.card_held[1] = false
	await _frames(1)
	var full := _newest_named("Ember Bomb")
	var full_speed := full.linear_velocity.length() if full != null else 0.0
	await _frames(int(runner.cards[1].cooldown * 60.0 / 1.25) + 5)
	hero.intent.card_held[1] = true
	hero.intent.card_pressed[1] = true
	await _frames(1)
	hero.intent.card_held[1] = false
	await _frames(1)
	var tap := _newest_named("Ember Bomb")
	var tap_speed := tap.linear_velocity.length() if tap != null and tap != full else 0.0
	_check(full_speed > 0.0 and tap_speed > 0.0 and absf(tap_speed / full_speed - runner.cards[1].min_charge_power) < 0.12,
			"a tap throws at min power, a full hold at full power (%.1f vs %.1f m/s)" % [tap_speed, full_speed])

	print("status: burn")
	_reset_all()
	near = _dummy("Near")
	var ember := runner.cards[1]
	var c := _ctx()
	c.position = _chest(near) + Vector3(0, 1.2, 0)
	c.direction = Vector3.DOWN
	runner.cast(ember, c)
	await _wait_until(func() -> bool: return near.statuses.has(StatusSet.Kind.BURN), 60)
	_check(near.statuses.has(StatusSet.Kind.BURN), "Ember Bomb sets the dummy burning")
	var hits0 := near.hits_taken
	var dmg0 := near.total_damage
	await _frames(62)
	_check(near.hits_taken - hits0 >= 2 and near.total_damage - dmg0 > 8.0, "burning deals damage over time (%d ticks, %.1f in 1 s)" % [near.hits_taken - hits0, near.total_damage - dmg0])
	await _frames(150)
	_check(not near.statuses.has(StatusSet.Kind.BURN), "the burn wears off after its duration")

	print("status: slow (on the hero)")
	await _place("CardRangeStart")
	_aim_dir(Vector3(1, 0, 0))
	hero.apply_status(StatusSet.Kind.SLOW, 2.0, 0.5, null)
	hero.intent.move = Vector2(0, 1)
	await _frames(40)
	_check(absf(hero.horizontal_speed() - hero.tuning.walk_speed * 0.5) < 0.4, "a 50%% slow halves walking speed (%.2f m/s)" % hero.horizontal_speed())
	hero.intent.move = Vector2.ZERO
	hero.statuses.clear()

	print("modifier: Overclock (passive)")
	_check(runner.modifiers.size() == 3 and is_equal_approx(runner.stat_mult(ModifierEffect.Stat.DAMAGE), 1.25) and is_equal_approx(runner.stat_add(ModifierEffect.Stat.EXTRA_BOUNCES), 1.0),
			"equipping Overclock adds its 3 modifiers (+25% damage, +1 bounce, faster cooldowns)")
	_reset_all()
	await _place("CardRangeStart")
	near = _dummy("Near")
	_aim_at(_chest(near))
	hero.intent.card_pressed[0] = true
	hero.intent.card_held[0] = true
	await _frames(1)
	hero.intent.card_held[0] = false
	await _frames(2)
	_check(is_equal_approx(near.total_damage, 9.0 * 1.25), "the pistol now deals 9 x 1.25 = %.2f (%.2f)" % [9.0 * 1.25, near.total_damage])

	print("transform: Hatchling Ball -> Bug Grenade")
	_reset_all()
	await _place("CardRangeStart")
	_aim_at(hero.global_position + Vector3(4, 0, -2))
	hero.intent.card_pressed[2] = true
	await _frames(1)
	var ball := _newest_named("Hatchling Ball")
	_check(ball != null and ball.bounces_left == 3, "Overclock gives the bouncy ball an extra bounce (%d)" % (ball.bounces_left if ball != null else -1))
	var ref: WeakRef = weakref(ball)
	await _wait_until(func() -> bool: return ref.get_ref() == null or (ref.get_ref() as CardBody).ctx.card.display_name == "Bug Grenade", 400)
	var b := ref.get_ref() as CardBody
	_check(b != null and b.ctx.card.display_name == "Bug Grenade" and b.def.sticky, "after its last bounce the same body becomes a Bug Grenade")
	_check(b != null and b.ctx.depth == 1 and _log_has("transformed into Bug Grenade"), "the transform is logged as chain depth 1")
	await _wait_until(func() -> bool: return ref.get_ref() == null or (ref.get_ref() as CardBody).stuck, 120)
	_check(ref.get_ref() != null and (ref.get_ref() as CardBody).stuck, "then it sticks like a bug grenade")
	await _wait_until(func() -> bool: return ref.get_ref() == null, 120)
	_check(ref.get_ref() == null, "and explodes")

	print("unequip clears passives")
	_equip(0)
	_check(runner.modifiers.is_empty(), "switching loadout removes Overclock's modifiers")
	await _frames(70)
	var otext: String = get_node("/root/DebugOverlay")._label.text
	_check(otext.contains("recent casts"), "overlay still renders")


func _equip(i: int) -> void:
	arena.call(&"_equip_loadout", i)


func _ctx() -> CastContext:
	var c := CastContext.new()
	c.position = hero.hand_position()
	c.direction = Vector3.FORWARD
	return c


func _log_has(text: String) -> bool:
	for l in runner.log_lines:
		if l.contains(text):
			return true
	return false


var _cast_counts := {}


func _casts_named(n: String) -> int:
	if not runner.card_cast.is_connected(_count_cast):
		runner.card_cast.connect(_count_cast)
	return _cast_counts.get(n, 0)


func _count_cast(card: AbilityCard, _slot: int, _depth: int) -> void:
	_cast_counts[card.display_name] = _cast_counts.get(card.display_name, 0) + 1


func _count_named_bodies(n: String) -> int:
	return _all_nodes(CardBody).filter(func(b: CardBody) -> bool: return b.ctx.card.display_name == n).size()


func _newest_named(n: String) -> CardBody:
	var list := _all_nodes(CardBody).filter(func(b: CardBody) -> bool: return b.ctx.card.display_name == n)
	return list[list.size() - 1] if not list.is_empty() else null


func _note(what: String) -> void:
	print("  note ", what)


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
