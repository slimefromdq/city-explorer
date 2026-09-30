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
	await _parkour()
	await _world()
	await _metro_and_rail()
	await _roofs()
	await _harbour()
	await _landmarks_climb()
	await _combat_matrix()
	await _abilities()
	await _bots()
	await _bounty()
	print("\n%d passed, %d failed" % [passes, fails])
	get_tree().quit(1 if fails > 0 else 0)


func _movement() -> void:
	print("movement")
	var p: Fighter = main.player
	main.teleport_player(Vector3(-200, 0.1, -205), -PI * 0.5)
	main.player.aim_yaw = -PI * 0.5
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
	main.teleport_player(Vector3(-20, 0.1, -161), -PI * 0.5)   # plaza, west of the tower base (clear of the grand stair)
	await frames(20)
	var start := p.global_position
	# aim up-and-toward the building (east = +x), yaw = -90deg
	p.aim_yaw = -PI * 0.5
	p.aim_dir = Vector3(0.6, 0.8, 0).normalized()
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
	print("      chained dash reached y=%.1f (z=%.1f)" % [best, p.global_position.z])
	check("3-dash chain from the street reaches the first ledge (>9 m)", best > 9.0, str(best))
	# mantling refunds a dash: keep climbing the shaft toward the 30 m ledge
	await frames(30)
	p.aim_dir = Vector3(0.5, 0.85, 0).normalized()
	for n in 3:
		p.loco.request_dash()
		await frames(12)
	for i in 90:
		await get_tree().physics_frame
		best = maxf(best, p.global_position.y)
	print("      second chain reached y=%.1f" % best)
	check("climbing the clock tower: second chain passes 20 m", best > 20.0, str(best))
	p.move_input = Vector2.ZERO
	# mantle test: walk into a 1.5 m obstacle in the air
	# Dash recharge on ground
	main.teleport_player(Vector3(-200, 0.1, -205), 0.0)
	p.loco.dash_pool.charges = 0.0
	await frames(120)
	check("dash charges refill fast on the ground", p.loco.dash_pool.available() >= 2, str(p.loco.dash_pool.charges))


func _parkour() -> void:
	print("parkour")
	var p: Fighter = main.player
	# wall-run along the long west boundary wall (faces +x)
	main.teleport_player(Vector3(-294.6, 9.0, -60.0), 0.0)
	p.aim_yaw = 0.0
	p.wants_sprint = true
	p.move_input = Vector2(-0.35, 1.0)
	p.loco.run_vel = Vector3(-2.0, 0.0, -14.0)
	var ran := false
	var z0 := p.global_position.z
	for i in 45:
		await get_tree().physics_frame
		if p.loco.wallrunning:
			ran = true
	check("sprinting along a wall while airborne starts a wall-run", ran)
	check("wall-run carries you along the wall", p.global_position.z < z0 - 6.0, "z %.1f -> %.1f" % [z0, p.global_position.z])
	p.wants_sprint = false
	p.move_input = Vector2.ZERO
	await frames(60)
	# ledge mantle: airborne into a 2 m crate-height ledge
	main.teleport_player(Vector3(-287, 0.1, -40), 0.0)
	await frames(10)


func _world() -> void:
	print("world")
	var city: CityBuilder = main.city
	var t: ParkTerrain = city.park.terrain
	var lake := t.lake_c
	check("lake is carved below water level", t.height_at(lake.x + 12.0, lake.y + 6.0) < ParkTerrain.WATER_LEVEL - 1.0, str(t.height_at(lake.x + 12.0, lake.y + 6.0)))
	var hill := t.hills[0]
	check("lookout hill rises above the meadow", t.height_at(hill.x, hill.y) > 6.0, str(t.height_at(hill.x, hill.y)))
	check("map has 30+ landmarks and shards", city.landmarks.size() >= 10 and Shard.total >= 30, "%d landmarks %d shards" % [city.landmarks.size(), Shard.total])
	var p: Fighter = main.player
	var spot := Vector3(-16.0, -7.8 + 0.05, 82.0)
	var before := Shard.collected
	main.teleport_player(spot, 0.0)
	await frames(30)
	check("touching a sky shard collects it and refills dashes", Shard.collected == before + 1 and p.loco.dash_pool.available() == 3, "%d" % Shard.collected)
	for b in main.bots:
		check("bot '%s' spawned on solid ground" % b.display_name, b.is_on_floor(), str(b.global_position))


func _walk(pos: Vector3, yaw: float, seconds: float) -> float:
	var p: Fighter = main.player
	main.teleport_player(pos, yaw)
	p.aim_yaw = yaw
	await frames(20)
	p.move_input = Vector2(0, 1)
	p.wants_sprint = false
	var lowest := p.global_position.y
	var highest := p.global_position.y
	for i in int(seconds * 60.0):
		await get_tree().physics_frame
		lowest = minf(lowest, p.global_position.y)
		highest = maxf(highest, p.global_position.y)
	p.move_input = Vector2.ZERO
	# report the extreme in the direction the walker travelled
	return lowest if lowest < pos.y - 1.0 else highest


func _find(parent: Array, x: int) -> int:
	while parent[x] != x:
		parent[x] = parent[parent[x]]
		x = parent[x]
	return x


func _roofs() -> void:
	print("roof routes")
	var links: Array = main.city.roof_links
	print("      %d catwalks" % links.size())
	check("roof network has 60+ catwalks", links.size() >= 60, str(links.size()))
	# connectivity of the rooftop graph (union-find over lots)
	var total: int = main.city.get("_walks").size()
	var parent := []
	for i in total:
		parent.append(i)
	for l: Dictionary in links:
		var ra := _find(parent, l.ids[0])
		var rb := _find(parent, l.ids[1])
		parent[ra] = rb
	var sizes := {}
	for i in total:
		var r := _find(parent, i)
		sizes[r] = sizes.get(r, 0) + 1
	var biggest := 0
	for v in sizes.values():
		biggest = maxi(biggest, v)
	var szl := sizes.values()
	szl.sort()
	szl.reverse()
	print("      %d roofs, largest connected network %d, all: %s" % [total, biggest, str(szl)])
	check("largest rooftop network links 30+ roofs", biggest >= 30, str(biggest))
	var p: Fighter = main.player
	var step := maxi(1, links.size() / 16)
	var bad := 0
	for i in range(0, links.size(), step):
		var l: Dictionary = links[i]
		for end in ["a", "b"]:
			var y: float = l.yh if end == "a" else l.yl
			main.teleport_player(l[end], 0.0)
			await frames(25)
			if not (p.is_on_floor() and absf(p.global_position.y - y) < 1.3):
				bad += 1
				print("      bad %s end of link %d: y=%.2f expected %.2f at %s" % [end, i, p.global_position.y, y, l[end]])
	check("both ends of sampled catwalks stand on solid roof", bad == 0, "%d bad" % bad)


## Walk a scripted path. Each step is [yaw, axis, target, sign]: walk facing `yaw`
## until the player's x/z coordinate reaches `target` (sign +1: >=, -1: <=).
## Returns the highest y reached.
func _walk_path(pos: Vector3, steps: Array) -> float:
	var p: Fighter = main.player
	main.teleport_player(pos, steps[0][0])
	await frames(15)
	var top := p.global_position.y
	for st in steps:
		p.aim_yaw = st[0]
		p.move_input = Vector2(0, 1)
		for i in 240:
			await get_tree().physics_frame
			top = maxf(top, p.global_position.y)
			var v: float = p.global_position.x if st[1] == "x" else p.global_position.z
			if (st[3] > 0 and v >= st[2]) or (st[3] < 0 and v <= st[2]):
				break
	p.move_input = Vector2.ZERO
	await frames(10)
	return top


func _harbour() -> void:
	print("harbour + fire escapes")
	var p: Fighter = main.player
	# a fire escape built in the open street: two full flights, landing to landing
	var kit := Kit.new(main, "TestEscape")
	kit.box(Vector3(-150.0, 0.0, -209.5), Vector3(24.0, 16.0, 2.0), Mats.toon(Color.WHITE), true)
	Props.fire_escape(kit, Vector3(-150.0, 0.0, -208.5), 0.0, 14.0)
	await frames(5)
	# flight 1: ground -> first landing (walk west up the flight, then north onto the landing)
	await _walk_path(Vector3(-146.0, 0.1, -206.6), [[PI * 0.5, "x", -152.0, -1], [0.0, "z", -207.9, -1]])
	check("fire escape: first flight climbs onto the first landing", p.global_position.y > 2.85, "y=%.2f" % p.global_position.y)
	# landing -> pad -> second flight (east along the landing, south onto the pad, west up the flight)
	await _walk_path(Vector3(-149.5, 3.2, -207.85), [[-PI * 0.5, "x", -148.0, 1], [PI, "z", -207.0, 1], [PI * 0.5, "x", -152.0, -1]])
	check("fire escape: the landing steps level onto the next flight and climbs", p.global_position.y > 5.9, "y=%.2f" % p.global_position.y)
	kit.root.queue_free()

	# walk from the T-pier up a gangway and onto the ship's deck
	await _walk_path(Vector3(30.0, 0.1, 334.0), [[PI, "z", 356.0, 1]])
	check("gangway leads from the pier onto the ship deck", p.global_position.y > 4.3 and p.global_position.z > 352.0, "y=%.1f z=%.1f" % [p.global_position.y, p.global_position.z])
	# ...and from the river shallows up the boarding stair
	await _walk_path(Vector3(-56.0, -2.6, 375.6), [[-PI * 0.5, "x", -36.5, 1], [0.0, "z", 366.0, -1]])
	check("boarding stair leads from the shallows onto the deck", p.global_position.y > 4.2 and p.global_position.z < 372.0, "y=%.1f z=%.1f" % [p.global_position.y, p.global_position.z])
	# wading in the shallows slows you down
	main.teleport_player(Vector3(0.0, -2.5, 420.0), 0.0)
	await frames(30)
	check("river shallows are wadeable and slow you", p.is_on_floor() and p.move_scale() < 0.7, "scale %.2f floor %s" % [p.move_scale(), p.is_on_floor()])
	# the shallows end at an invisible wall + buoy line, not a void
	p.aim_yaw = PI
	p.move_input = Vector2(0, 1)
	await frames(240)
	p.move_input = Vector2.ZERO
	check("the shallows are bounded (z stays < 481)", p.global_position.z < CityLayout.RIVER_MAX_Z + 0.5, "z=%.1f" % p.global_position.z)


func _landmarks_climb() -> void:
	print("landmark stairs")
	var p: Fighter = main.player
	var cz := -164.0
	# clock tower: grand stair to the base roof, then the first spiral flight to the 30 m ring
	await _walk_path(Vector3(0.0, 0.1, cz + 30.0), [[0.0, "z", cz + 11.5, -1]])
	check("clock tower grand stair climbs onto the base roof", p.global_position.y > 10.0, "y=%.1f" % p.global_position.y)
	await _walk_path(Vector3(-9.5, 10.2, cz + 9.3), [[-PI * 0.5, "x", 8.6, 1], [0.0, "z", cz - 9.4, -1]])
	check("clock tower spiral ramps lead ring to ring (walk onto the 30 m ring)", p.global_position.y > 30.4, "y=%.1f" % p.global_position.y)
	# library: up the grand steps, through the door, up the gallery ramp
	var lz := -164.0
	await _walk_path(Vector3(82.0, 0.1, lz + 35.0), [[0.0, "z", lz + 2.0, -1]])
	check("library: grand steps and door lead into the reading hall", p.global_position.y > 2.8 and p.global_position.y < 3.6 and p.global_position.z < lz + 4.0, "y=%.1f z=%.1f" % [p.global_position.y, p.global_position.z])
	await _walk_path(Vector3(63.0, 3.2, lz + 12.5), [[0.0, "z", lz - 3.5, -1]])
	check("library: gallery ramp climbs to the gallery", p.global_position.y > 9.5, "y=%.1f" % p.global_position.y)


func _metro_and_rail() -> void:
	print("metro + rail loop")
	var loop := RailBuilder.densify(RailBuilder.loop_points(), 6.0)
	var worst_turn := 0.0
	var miny := 99.0
	var maxy := -99.0
	var through_pit := 0
	var n := loop.size()
	for i in n:
		var d0 := (loop[(i + 1) % n] - loop[i]).normalized()
		var d1 := (loop[(i + 2) % n] - loop[(i + 1) % n]).normalized()
		worst_turn = maxf(worst_turn, rad_to_deg(d0.angle_to(d1)))
		miny = minf(miny, loop[i].y)
		maxy = maxf(maxy, loop[i].y)
		if CityLayout.station_pit().has_point(Vector2(loop[i].x, loop[i].z)):
			through_pit += 1
	check("rail loop is one closed line with no kinks (max turn %.0f deg)" % worst_turn, worst_turn < 25.0)
	check("loop dives to the metro and climbs to the viaduct", miny <= -8.9 and maxy >= 25.9, "%.1f..%.1f" % [miny, maxy])
	check("loop runs through the station pit on both tracks", through_pit >= 15, str(through_pit))
	var trains := 0
	for t in get_tree().get_nodes_in_group(&"trains"):
		trains += 1
	check("two loop trains are running", trains == 2, str(trains))
	var cz := CityLayout.station_center().y
	# the gate lane leads to the stairs and down to the platform
	var low: float = await _walk(Vector3(-17.4, 0.1, cz - 29.6), PI, 6.0)
	check("walking through the fare gates takes you down the stairs to the platform", low < -7.0, "lowest y %.1f" % low)
	# ...and the open pit edge elsewhere is fenced, so you can't just step onto the tracks
	var edge: float = await _walk(Vector3(0.0, 0.1, cz - 29.0), PI, 3.0)
	check("the pit edge is railed (no accidental drop onto the tracks)", edge > -0.5, "y %.1f" % edge)
	# the maintenance stair reaches the roof girders
	var top: float = await _walk(Vector3(-28.5, 14.2, cz - 24.4), PI, 5.0)
	check("maintenance stair climbs to the roof girders", top > 24.0, "top y %.1f" % top)


func _combat_matrix() -> void:
	print("combat matrix")
	var a := spawn("A", Vector3(-200, 0.1, -205))
	var v := spawn("V", Vector3(-188, 0.1, -205))
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
	var behind := spawn("B", Vector3(-176, 0.1, -205))
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
	var a := spawn("Shooter", Vector3(-200, 0.1, -205))
	var v := spawn("Target", Vector3(-186, 0.1, -205))
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
	var wall_dir := Vector3(0, 0, -1)
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
	var bounced := false
	for i in 140:
		await frames(1)
		for n in get_tree().get_nodes_in_group(&"projectiles"):
			var p2 := n as Projectile
			if p2 != null and p2.tag == &"ricochet" and p2.velocity.z > 0.0:
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
	var shooter := spawn("Shooter", Vector3(-200, 0.1, -205))
	var bot := spawn("BotB", Vector3(-188, 0.1, -205))
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
	var a := spawn("Killer", Vector3(-100, 0.1, -205))
	var v := spawn("Victim", Vector3(-88, 0.1, -205))
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
