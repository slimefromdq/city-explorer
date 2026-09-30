extends Node
## Headless gameplay checks for the shared combat layer and traversal.
##   godot --headless --fixed-fps 60 res://tests/smoke_test.tscn

var main: Node3D
var fails := 0
var passes := 0


func check(name: String, cond: bool, detail := "") -> void:
	if cond:
		passes += 1
		print("  ok   ", name)
	else:
		fails += 1
		print("  FAIL ", name, "  ", detail)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func spawn(name: String, pos: Vector3) -> Fighter:
	var f := Gunslinger.create(name)
	f.respawn_delay = 0.0
	main.add_child(f)
	f.global_position = pos
	f.spawn_transform = f.global_transform
	return f


func face(a: Fighter, b: Fighter) -> void:
	var to := b.center() - a.center()
	a.aim_yaw = atan2(-to.x, -to.z)
	a.face_yaw = a.aim_yaw
	a.aim_dir = to.normalized()
	a.aim_point = b.center()


func hit(attacker: Fighter, victim: Fighter, dmg := 10.0, guard := 10.0, blockable := true, dodgeable := true) -> HitData.Result:
	var h := HitData.new()
	h.attacker = attacker
	h.damage = dmg
	h.guard_damage = guard
	h.blockable = blockable
	h.dodgeable = dodgeable
	h.from_dir = (attacker.center() - victim.center()).normalized()
	h.position = victim.center()
	return victim.receive_hit(h)


func _ready() -> void:
	main = load("res://main.tscn").instantiate()
	main.set("headless_test", true)
	add_child(main)
	await frames(2)
	main.controller.enabled = false
	for b in main.bots:
		b.hurtbox.set_active(false)
	await _movement()
	await _level()
	await _traversal()
	await _combat_matrix()
	await _abilities()
	await _bots()
	await _bounty()
	print("\n%d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _movement() -> void:
	print("movement")
	var p: Fighter = main.player
	main.teleport_player(Vector3(-123, 0.1, -20), 0.0)
	await frames(30)
	check("player stands on the floor", p.is_on_floor(), str(p.global_position))
	p.move_input = Vector2(0, 1)
	p.wants_sprint = true
	await frames(40)
	var sp := Vector2(p.velocity.x, p.velocity.z).length()
	check("sprint reaches ~15 m/s", sp > 13.5 and sp < 16.5, str(sp))
	p.move_input = Vector2.ZERO
	p.wants_sprint = false
	await frames(30)
	var y0 := p.global_position.y
	p.loco.request_jump()
	p.jump_held = true
	var peak := y0
	for i in 60:
		await get_tree().physics_frame
		peak = maxf(peak, p.global_position.y)
	p.jump_held = false
	check("jump apex ~2 m", peak - y0 > 1.6 and peak - y0 < 2.8, str(peak - y0))


func _level() -> void:
	print("level geometry")
	var p: Fighter = main.player
	for t in main.city.markers["tp"]:
		main.teleport_player(t[1], t[2])
		await frames(40)
		check("stand on '%s' at the expected height" % t[0], p.is_on_floor() and absf(p.global_position.y - t[1].y) < 0.7, "y=%.2f expected %.2f" % [p.global_position.y, t[1].y])


func _traversal() -> void:
	print("traversal")
	var p: Fighter = main.player
	# open street at the west avenue, facing the east face of the 24 m concrete lot? use SW lot of block(-82,-41):
	# oldtown h=14 (x -114..-85, z -38..-9): east face at x~-85.3 looking from alley side is cluttered, use avenue x=-123 -> west face x=-113.7
	main.teleport_player(Vector3(-45, 0.1, -58), PI * 0.5)
	await frames(20)
	var start := p.global_position
	# aim up-and-toward the building (east = +x), yaw = -90deg
	p.aim_yaw = PI * 0.5
	p.aim_dir = Vector3(-0.6, 0.8, 0).normalized()
	p.move_input = Vector2(0, 1)
	var pool_before := p.loco.dash_pool.charges
	p.loco.request_dash()
	await frames(1)
	check("dash spends a charge", p.loco.dash_pool.charges < pool_before)
	await frames(14)
	p.loco.try_dash()
	await frames(14)
	p.loco.try_dash()
	await frames(14)
	var best := p.global_position.y
	for i in 120:
		await get_tree().physics_frame
		best = maxf(best, p.global_position.y)
	print("      chained dash reached y=%.1f (x=%.1f)" % [best, p.global_position.x])
	check("3-dash chain gains >15 m of height", best > 15.0, str(best))
	p.move_input = Vector2.ZERO
	# mantle test: walk into a 1.5 m obstacle in the air
	# Dash recharge on ground
	main.teleport_player(Vector3(-119, 0.1, -23.5), 0.0)
	p.loco.dash_pool.charges = 0.0
	await frames(120)
	check("dash charges refill fast on the ground", p.loco.dash_pool.available() >= 2, str(p.loco.dash_pool.charges))


func _combat_matrix() -> void:
	print("combat matrix")
	var a := spawn("A", Vector3(-123, 0.1, 30))
	var v := spawn("V", Vector3(-123, 0.1, 42))
	await frames(10)
	face(v, a)
	face(a, v)
	# light hit, no defence
	var hp := v.health
	check("light hit lands", hit(a, v, 10.0, 5.0) == HitData.Result.HIT and v.health == hp - 10.0)
	# block absorbs light
	v.reset_meters()
	v.wants_block = true
	await frames(15)
	face(v, a)
	hp = v.health
	var res := hit(a, v, 10.0, 8.0)
	check("block stops a light hit", res == HitData.Result.BLOCKED and v.health == hp, str(res))
	check("block drains guard by guard_damage", is_equal_approx(v.guard.value, 92.0), str(v.guard.value))
	# unblockable ignores block
	res = hit(a, v, 10.0, 8.0, false, true)
	check("unblockable beats guard", res == HitData.Result.HIT, str(res))
	# hit from behind ignores block
	var behind := spawn("B", Vector3(-123, 0.1, 54))
	var h := HitData.new()
	h.attacker = behind
	h.damage = 5.0
	h.guard_damage = 5.0
	h.from_dir = (behind.center() - v.center()).normalized()
	check("guard only covers the front arc", v.receive_hit(h) == HitData.Result.HIT)
	# heavies break guard
	v.reset_meters()
	v.wants_block = true
	await frames(15)
	face(v, a)
	var r1 := hit(a, v, 16.0, 40.0)
	var r2 := hit(a, v, 16.0, 40.0)
	var r3 := hit(a, v, 16.0, 40.0)
	check("three heavies break a full guard", r1 == HitData.Result.BLOCKED and r2 == HitData.Result.BLOCKED and r3 == HitData.Result.GUARD_BREAK, "%s %s %s" % [r1, r2, r3])
	check("guard break stuns", v.stun_left > 1.0, str(v.stun_left))
	hp = v.health
	hit(a, v, 10.0, 0.0)
	check("stunned targets take bonus damage", is_equal_approx(hp - v.health, 12.5), str(hp - v.health))
	v.wants_block = false
	# light spam does not break a fresh guard quickly
	v.reset_meters()
	v.wants_block = true
	await frames(15)
	face(v, a)
	var broke := false
	for i in 8:
		if hit(a, v, 5.0, 5.0) == HitData.Result.GUARD_BREAK:
			broke = true
	check("8 light hits (40 guard) don't break block", not broke and v.guard.value > 50.0, str(v.guard.value))
	v.wants_block = false
	await frames(5)
	# dodge
	v.reset_meters()
	await frames(10)
	face(v, a)
	check("dodge starts", v.dodge.try_dodge())
	await frames(6)
	res = hit(a, v, 20.0, 40.0)
	check("dodge i-frames beat a heavy", res == HitData.Result.DODGED, str(res))
	res = hit(a, v, 20.0, 40.0, true, false)
	check("non-dodgeable hit beats i-frames", res == HitData.Result.HIT, str(res))
	await frames(40)
	# exhaust the pool
	v.reset_meters()
	var ok := 0
	for i in 3:
		await frames(25)
		if v.dodge.try_dodge():
			ok += 1
	await frames(25)
	check("3 dodges available", ok == 3, str(ok))
	check("4th dodge fails and exposes", not v.dodge.try_dodge() and v.recovery_left > 0.0)
	await frames(30)
	res = hit(a, v, 10.0, 5.0)
	check("empty dodge pool is punished by light pressure", res == HitData.Result.HIT)
	a.queue_free()
	v.queue_free()
	behind.queue_free()


func _abilities() -> void:
	print("abilities")
	var a := spawn("Shooter", Vector3(-123, 0.1, -60))
	var v := spawn("Target", Vector3(-123, 0.1, -46))
	await frames(10)
	face(a, v)
	face(v, a)
	var hp := v.health
	a.press_ability(1)  # burst
	await frames(45)
	check("burst shot lands damage", v.health < hp, str(v.health))
	check("burst costs 3 rounds", a.gun.ammo == 9, str(a.gun.ammo))
	# M1 combo
	v.reset_meters()
	a.reset_meters()
	await frames(20)
	a.hold_ability(0, true)
	await frames(90)
	a.hold_ability(0, false)
	check("m1 combo damages", v.health < v.max_health, str(v.health))
	# ammo/reload
	a.reset_meters()
	a.gun.ammo = 1
	a.press_ability(0)
	await frames(10)
	check("empty magazine auto-reloads", a.gun.reloading)
	check("cannot shoot while reloading", not a.kit[0].can_use())
	await frames(100)
	check("reload finishes", not a.gun.reloading and a.gun.ammo == a.gun.mag_size, str(a.gun.ammo))
	# snapshot hit
	a.reset_meters()
	v.reset_meters()
	await frames(30)
	face(a, v)
	a.press_ability(4)
	await frames(50)
	check("snapshot channels", a.channel != null)
	check("snapshot slows the caster", a.move_scale() < 0.5, str(a.move_scale()))
	a.release_ability(4)
	await frames(30)
	check("snapshot hits hard", v.max_health - v.health > 20.0 or not v.alive, str(v.health))
	# snapshot miss punishment
	a.reset_meters()
	v.reset_meters()
	await frames(20)
	a.aim_dir = Vector3.UP
	a.aim_point = a.center() + Vector3.UP * 100.0
	a.press_ability(4)
	await frames(50)
	a.release_ability(4)
	await frames(45)
	check("snapshot miss roots and exposes the shooter", a.root_left > 0.3 and a.recovery_left > 0.5, "root %.2f rec %.2f" % [a.root_left, a.recovery_left])
	check("root blocks air-dash", not a.loco.try_dash())
	# getting hit interrupts a charge
	a.reset_meters()
	await frames(20)
	a.press_ability(4)
	await frames(20)
	a.receive_hit(_h(v, a, 5.0, 0.2))
	check("being hit cancels snapshot charge", a.channel == null)
	# slide shot
	a.reset_meters()
	v.reset_meters()
	await frames(30)
	face(a, v)
	a.move_input = Vector2(0, 1)
	a.press_ability(2)
	await frames(6)
	check("slide-shot drives the fighter", a.loco.drive == Locomotion.Drive.SLIDE)
	await frames(60)
	check("slide-shot ends", a.loco.drive == Locomotion.Drive.NONE)
	a.move_input = Vector2.ZERO
	# ricochet bounce
	a.reset_meters()
	await frames(20)
	var wall_dir := Vector3(-1, 0, 0)
	a.aim_dir = wall_dir
	a.aim_point = a.center() + wall_dir * 20.0
	a.press_ability(3)
	await frames(30)
	var found := false
	for n in get_tree().get_nodes_in_group(&"projectiles"):
		var p := n as Projectile
		if p != null and p.tag == &"ricochet":
			found = true
	check("ricochet round is a slow visible projectile", found)
	await frames(90)
	var bounced := false
	for n in get_tree().get_nodes_in_group(&"projectiles"):
		var p2 := n as Projectile
		if p2 != null and p2.tag == &"ricochet" and p2.velocity.x > 0.0:
			bounced = true
	check("ricochet round bounced off the wall", bounced)
	a.queue_free()
	v.queue_free()


func _brain(f: Fighter, target: Fighter, mode: BotBrain.Mode) -> BotBrain:
	var b := BotBrain.new()
	b.fighter = f
	b.target = target
	b.mode = mode
	f.add_child(b)
	return b


func _bots() -> void:
	print("bots")
	var shooter := spawn("Shooter", Vector3(-123, 0.1, -10))
	var bot := spawn("BotB", Vector3(-123, 0.1, 6))
	await frames(10)
	face(shooter, bot)
	var brain := _brain(bot, shooter, BotBrain.Mode.BLOCKER)
	await frames(20)
	check("blocker bot raises its guard", bot.guard.blocking)
	var hp := bot.health
	shooter.press_ability(1)
	await frames(60)
	check("blocker bot absorbs a burst", bot.health == hp and bot.guard.value < 100.0, "hp %s guard %s" % [bot.health, bot.guard.value])
	brain.queue_free()
	await frames(2)
	bot.wants_block = false
	# dodger
	bot.reset_meters()
	shooter.reset_meters()
	brain = _brain(bot, shooter, BotBrain.Mode.DODGER)
	await frames(30)
	face(shooter, bot)
	shooter.press_ability(3)  # ricochet: slow and readable
	await frames(150)
	check("dodger bot spends a dodge on an incoming round", bot.dodge.pool.charges < 3.0 or bot.dodge.active)
	brain.queue_free()
	await frames(2)
	# aggressor shoots the target
	bot.reset_meters()
	shooter.reset_meters()
	shooter.hurtbox.set_active(true)
	brain = _brain(bot, shooter, BotBrain.Mode.AGGRESSOR)
	await frames(360)
	check("aggressor bot fires at its target", bot.gun.ammo < bot.gun.mag_size or shooter.health < shooter.max_health)
	bot.queue_free()
	shooter.queue_free()


func _h(attacker: Fighter, victim: Fighter, dmg: float, flinch := 0.0) -> HitData:
	var h := HitData.new()
	h.attacker = attacker
	h.damage = dmg
	h.guard_damage = 5.0
	h.flinch = flinch
	h.from_dir = (attacker.center() - victim.center()).normalized()
	return h


func _bounty() -> void:
	print("bounty")
	var a := spawn("Killer", Vector3(-123, 0.1, 60))
	var v := spawn("Victim", Vector3(-123, 0.1, 72))
	v.respawn_delay = 1.0
	await frames(10)
	v.bounty.add_streak(4)
	v.bounty.score = 400
	var worth := v.bounty.value()
	hit(a, v, 500.0, 0.0)
	check("kill increments killer streak", a.bounty.streak == 1)
	check("victim loses streak and half its score", v.bounty.streak == 0 and v.bounty.score == 200, str(v.bounty.score))
	check("killer is paid the victim's bounty", a.bounty.score == worth, "%d vs %d" % [a.bounty.score, worth])
	check("victim is dead", not v.alive)
	await frames(90)
	check("victim respawns", v.alive and v.health == v.max_health)
	a.queue_free()
	v.queue_free()
