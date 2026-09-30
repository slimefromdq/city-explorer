class_name ParkBuilder
extends Node3D
## Central Park: hills, two rivers, a lake with a pavilion island, arched
## bridges, a climbable Old Oak, canopy-platform trees and dense forest cover.
## Trees are MultiMeshes; the ~70 big ones also get canopy platforms you can
## land on, so the park is a parkour space and not just scenery.

var terrain: ParkTerrain
var landmarks: Array = []
var shard_spots: Array[Vector3] = []
var tp: Array = []
var _rng := RandomNumberGenerator.new()
var _kit: Kit
var _wade_t := 0.0


func build(rect: Rect2) -> void:
	_rng.seed = 31337
	terrain = ParkTerrain.new(rect, 2.0)
	terrain.configure()
	terrain.compute()
	name = "CentralPark"
	# collider + visual
	var body := StaticBody3D.new()
	body.collision_layer = Fighter.LAYER_WORLD
	body.collision_mask = 0
	var cs := CollisionShape3D.new()
	cs.shape = terrain.build_shape()
	cs.scale = Vector3(terrain.step, 1.0, terrain.step)
	body.position = Vector3(rect.get_center().x, 0.0, rect.get_center().y)
	body.add_child(cs)
	add_child(body)
	var mi := MeshInstance3D.new()
	mi.mesh = terrain.build_mesh()
	mi.material_override = Mats.toon_vcolor()
	add_child(mi)
	# water
	var wm := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = rect.size
	q.orientation = PlaneMesh.FACE_Y
	wm.mesh = q
	wm.material_override = Mats.water()
	wm.position = Vector3(rect.get_center().x, ParkTerrain.WATER_LEVEL, rect.get_center().y)
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(wm)

	_kit = Kit.new(self, "ParkProps")
	_landmarks_and_hills()
	_bridges()
	_pavilion()
	_old_oak()
	_paths_furniture()
	_trees()
	StaticBatch.merge(_kit.root)


func _h(x: float, z: float) -> float:
	return terrain.height_at(x, z)


func _stone() -> Material:
	return Mats.toon(Color(0.62, 0.6, 0.56), 0.5)


# ------------------------------------------------------------------ landmarks

func _landmarks_and_hills() -> void:
	var rc := terrain.rect.get_center()
	landmarks.append(["Central Park", Vector3(rc.x, 0, rc.y)])
	var hill := terrain.hills[0]
	var hy := _h(hill.x, hill.y)
	landmarks.append(["Lookout Hill", Vector3(hill.x, hy, hill.y)])
	tp.append(["Lookout Hill", Vector3(hill.x, hy + 0.3, hill.y + 4.0), PI])
	# gazebo on the summit
	var g := _kit.sub("Gazebo", Vector3(hill.x, hy, hill.y))
	var wood := Mats.toon(Color(0.55, 0.32, 0.22))
	g.cyl(Vector3.ZERO, 5.2, 0.5, _stone(), true, 8)
	for i in 6:
		var a := i * TAU / 6.0
		g.box(Vector3(cos(a) * 4.4, 0.5, sin(a) * 4.4), Vector3(0.35, 4.2, 0.35), wood, true)
	var roof := g.cyl(Vector3(0, 4.7, 0), 5.8, 2.6, Mats.toon(Color(0.2, 0.42, 0.4)), false, 6, 0.3)
	roof.rotation_degrees.y = 30
	g.sphere(Vector3(0, 7.5, 0), 0.5, Mats.glow(Color(1.0, 0.85, 0.4), 4.0))
	_steps_onto(g, Vector3(hill.x, hy, hill.y), 5.2, 0.5, [30.0, 150.0, 270.0])
	shard_spots.append(Vector3(hill.x, hy + 1.6, hill.y))
	landmarks.append(["Lake", Vector3(terrain.lake_c.x, 0, terrain.lake_c.y)])


## Stone steps from the surrounding terrain up onto a raised round platform, one flight per
## angle (degrees). The foot of each flight sits exactly on the terrain so there is no lip.
func _steps_onto(g: Kit, origin: Vector3, r: float, top: float, angles: Array, run := 3.4, width := 3.0) -> void:
	for a: float in angles:
		var d := Vector3(cos(deg_to_rad(a)), 0.0, sin(deg_to_rad(a)))
		var bx := origin.x + d.x * (r + run)
		var bz := origin.z + d.z * (r + run)
		var by := _h(bx, bz) - origin.y
		var rise := top - by
		if rise < 0.15:
			continue
		g.stairs(Vector3(d.x * (r + run), by, d.z * (r + run)), -d, rise, run, width, _stone())


func _pavilion() -> void:
	var i := terrain.island
	var y := _h(i.x, i.y)
	var g := _kit.sub("Pavilion", Vector3(i.x, y, i.y))
	var red := Mats.toon(Color(0.75, 0.2, 0.18))
	g.cyl(Vector3.ZERO, 5.0, 0.4, _stone(), true, 10)
	for k in 4:
		var a := k * TAU / 4.0 + PI * 0.25
		g.box(Vector3(cos(a) * 3.2, 0.4, sin(a) * 3.2), Vector3(0.4, 4.0, 0.4), red, true)
	var roof := g.cyl(Vector3(0, 4.4, 0), 5.2, 2.2, Mats.toon(Color(0.16, 0.32, 0.34)), false, 4, 0.2)
	roof.rotation_degrees.y = 45
	g.sphere(Vector3(0, 6.9, 0), 0.4, Mats.glow(Color(1.0, 0.8, 0.3), 4.0))
	for k in 6:
		var a2 := k * TAU / 6.0
		g.sphere(Vector3(cos(a2) * 4.6, 3.6, sin(a2) * 4.6), 0.28, Mats.glow(Color(1.0, 0.25, 0.2), 4.0))
	_steps_onto(g, Vector3(i.x, y, i.y), 5.0, 0.4, [0.0, 90.0, 180.0, 270.0])
	shard_spots.append(Vector3(i.x, y + 1.6, i.y))


# ------------------------------------------------------------------ bridges

func _bridge(a: Vector2, b: Vector2, width := 5.0, rise := 2.4) -> float:
	var ha := _h(a.x, a.y)
	var hb := _h(b.x, b.y)
	var deck := maxf(ha, hb) + rise
	var dir2 := (b - a).normalized()
	var dir := Vector3(dir2.x, 0, dir2.y)
	var length := a.distance_to(b)
	var rl := minf(10.0, length * 0.32)
	var pa := Vector3(a.x, ha, a.y)
	var pb := Vector3(b.x, hb, b.y)
	var k := _kit.sub("Bridge", Vector3.ZERO)
	var st := _stone()
	k.ramp(pa, pa + dir * rl + Vector3(0, deck - ha, 0), width, 0.5, st)
	k.ramp(pb, pb - dir * rl + Vector3(0, deck - hb, 0), width, 0.5, st)
	var mid := (pa + dir * rl + pb - dir * rl) * 0.5
	var flat_len := length - 2.0 * rl
	var yaw := rad_to_deg(atan2(-dir.z, dir.x))
	k.box(Vector3(mid.x, deck - 0.5, mid.z), Vector3(flat_len, 0.5, width), st, true, Vector3(0, yaw, 0))
	var side := Vector3(-dir.z, 0, dir.x)
	for s: float in [-1.0, 1.0]:
		var rp: Vector3 = mid + side * (width * 0.5 - 0.15) * s
		k.box(Vector3(rp.x, deck, rp.z), Vector3(flat_len, 1.0, 0.3), Mats.toon(Color(0.5, 0.48, 0.45), 0.5), true, Vector3(0, yaw, 0))
		k.box(Vector3(rp.x, deck + 1.0, rp.z), Vector3(flat_len, 0.15, 0.4), Mats.toon(Color(0.7, 0.3, 0.25)), false, Vector3(0, yaw, 0))
	# piers into the water + lamp posts
	for t in [0.3, 0.7]:
		var p := pa.lerp(pb, t)
		var ground := _h(p.x, p.z)
		if ground < deck - 1.0:
			k.box(Vector3(p.x, ground - 0.5, p.z), Vector3(width - 1.0, deck - ground - 0.4, 1.6), st, true, Vector3(0, yaw + 90.0, 0))
	for e in [a, b]:
		var pe := Vector3(e.x, _h(e.x, e.y), e.y)
		Props.lamp(k, pe + side * (width * 0.5 + 0.6), rad_to_deg(atan2(side.x, side.z)) + 180.0, 5.0)
	shard_spots.append(mid + Vector3(0, 1.4, 0))
	return deck


func _crossing(river_idx: int, seg: int, span := 15.0) -> void:
	var pts := terrain.rivers[river_idx]
	var a := pts[seg]
	var b := pts[seg + 1]
	var mid := (a + b) * 0.5
	var t := (b - a).normalized()
	var n := Vector2(-t.y, t.x)
	_bridge(mid - n * span, mid + n * span)


func _bridges() -> void:
	_crossing(0, 2)
	_crossing(1, 1)
	# main lake footbridge along the centre path (x = rc - 26 .. across the lake)
	var rc := terrain.rect.get_center()
	var deck := _bridge(Vector2(rc.x - 26, terrain.lake_c.y - 34), Vector2(rc.x - 26, terrain.lake_c.y + 34), 6.0, 3.0)
	landmarks.append(["Lake Bridge", Vector3(rc.x - 26, deck, terrain.lake_c.y)])
	tp.append(["Lake Bridge", Vector3(rc.x - 26, deck + 0.4, terrain.lake_c.y), 0.0])


# ------------------------------------------------------------------ old oak

func _old_oak() -> void:
	var c := terrain.clearings[0]
	var y := _h(c.x, c.y)
	var k := _kit.sub("OldOak", Vector3(c.x, y, c.y))
	var bark := Mats.toon(Color(0.36, 0.25, 0.18), 0.5)
	var leaf := Mats.toon(Color(0.2, 0.52, 0.32))
	var leaf2 := Mats.toon(Color(0.3, 0.6, 0.34))
	k.cyl(Vector3.ZERO, 2.4, 14.0, bark, true, 14, 1.7)
	var tiers := [[13.0, 13.0, leaf], [10.0, 21.0, leaf2], [6.5, 28.0, leaf]]
	for t in tiers:
		var r: float = t[0]
		var cy: float = t[1]
		var mi := k.sphere(Vector3(0, cy, 0), r, t[2])
		mi.scale = Vector3(1, 0.55, 1)
		# flat landing platform just under the visual top
		k.cyl(Vector3(0, cy + r * 0.5 - 0.8, 0), r * 0.75, 0.8, leaf, true, 16)
		shard_spots.append(Vector3(c.x, y + cy + r * 0.5 + 0.9, c.y))
	# branches out of the trunk you can hop along
	for i in 5:
		var a := i * TAU / 5.0
		k.box(Vector3(cos(a) * 7.5, 6.0 + i * 1.6, sin(a) * 7.5), Vector3(5.0, 0.6, 1.4), bark, true, Vector3(0, -rad_to_deg(a), 0))
	landmarks.append(["Old Oak", Vector3(c.x, y + 30.0, c.y)])
	tp.append(["Old Oak crown", Vector3(c.x, y + 28.0 + 6.5 * 0.5 + 0.3, c.y), 0.0])
	tp.append(["Old Oak lawn", Vector3(c.x + 20.0, _h(c.x + 20.0, c.y) + 0.3, c.y + 4.0), PI])


# ------------------------------------------------------------------ paths, lamps, benches

func _paths_furniture() -> void:
	var n := 0
	for pl in terrain.paths:
		var acc := 0.0
		for i in pl.size() - 1:
			var a := pl[i]
			var b := pl[i + 1]
			var seg := a.distance_to(b)
			var dir := (b - a).normalized()
			var s := 8.0 - fposmod(acc, 8.0)
			acc += seg
			while s < seg:
				var p := a + dir * s
				var y := _h(p.x, p.y)
				if y > 0.1:
					var side := Vector2(-dir.y, dir.x) * 2.6
					n += 1
					if n % 3 == 0:
						Props.lamp(_kit, Vector3(p.x + side.x, y, p.y + side.y), rad_to_deg(atan2(-side.x, -side.y)), 5.5)
					elif n % 3 == 1:
						Props.bench(_kit, Vector3(p.x - side.x, y, p.y - side.y), rad_to_deg(atan2(side.x, side.y)))
				s += 14.0


# ------------------------------------------------------------------ trees

func _trees() -> void:
	var rect := terrain.rect
	var small: Array = []
	var big: Array = []
	var tries := 0
	while (small.size() < 340 or big.size() < 70) and tries < 9000:
		tries += 1
		var x := rect.position.x + _rng.randf_range(6.0, rect.size.x - 6.0)
		var z := rect.position.y + _rng.randf_range(6.0, rect.size.y - 6.0)
		var h := _h(x, z)
		if h < 0.2 or terrain.path_distance(Vector2(x, z)) < 3.4:
			continue
		var clear := false
		for c in terrain.clearings:
			if Vector2(x, z).distance_to(Vector2(c.x, c.y)) < c.z:
				clear = true
		if clear or Vector2(x, z).distance_to(Vector2(terrain.island.x, terrain.island.y)) < 12.0:
			continue
		var dens := terrain.forest_density(x, z)
		if _rng.randf() > lerpf(0.12, 1.0, smoothstep(0.42, 0.7, dens)):
			continue
		if big.size() < 70 and _rng.randf() < 0.2:
			big.append(Vector3(x, h, z))
		elif small.size() < 340:
			small.append(Vector3(x, h, z))
	_multimesh(small, false)
	_multimesh(big, true)


func _multimesh(spots: Array, is_big: bool) -> void:
	if spots.is_empty():
		return
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.7
	trunk.bottom_radius = 1.0
	trunk.height = 1.0
	trunk.radial_segments = 6
	trunk.rings = 1
	var crown := SphereMesh.new()
	crown.radius = 1.0
	crown.height = 2.0
	crown.radial_segments = 8
	crown.rings = 4
	var mt := MultiMesh.new()
	mt.transform_format = MultiMesh.TRANSFORM_3D
	mt.use_colors = true
	mt.mesh = trunk
	mt.instance_count = spots.size()
	var mc := MultiMesh.new()
	mc.transform_format = MultiMesh.TRANSFORM_3D
	mc.use_colors = true
	mc.mesh = crown
	mc.instance_count = spots.size()
	var greens := [Color(0.2, 0.5, 0.3), Color(0.26, 0.58, 0.34), Color(0.18, 0.44, 0.34), Color(0.4, 0.62, 0.3), Color(0.9, 0.55, 0.6)]
	var i := 0
	for s: Vector3 in spots:
		var th := _rng.randf_range(5.0, 7.0) if is_big else _rng.randf_range(2.2, 3.4)
		var tr := 0.55 if is_big else 0.26
		var cr := _rng.randf_range(3.8, 5.2) if is_big else _rng.randf_range(1.9, 2.8)
		var cy := s.y + th + cr * (0.35 if is_big else 0.5)
		mt.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(tr, th, tr)), Vector3(s.x, s.y + th * 0.5, s.z)))
		mt.set_instance_color(i, Color(0.4, 0.28, 0.2))
		mc.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(cr, cr * (0.6 if is_big else 0.85), cr)), Vector3(s.x, cy, s.z)))
		var gc: Color = greens[_rng.randi() % 4] if _rng.randf() > 0.06 else greens[4]
		mc.set_instance_color(i, gc)
		if is_big:
			_kit.collision_cyl(Vector3(s.x, s.y, s.z), tr + 0.1, th)
			var top := cy + cr * 0.5
			_kit.collision_cyl(Vector3(s.x, top - 0.8, s.z), cr * 0.72, 0.8)
			if i % 5 == 0:
				shard_spots.append(Vector3(s.x, top + 0.9, s.z))
		i += 1
	var a := MultiMeshInstance3D.new()
	a.multimesh = mt
	a.material_override = Mats.toon_vcolor()
	add_child(a)
	var b := MultiMeshInstance3D.new()
	b.multimesh = mc
	b.material_override = Mats.toon_vcolor()
	add_child(b)


# ------------------------------------------------------------------ wading

func _physics_process(dt: float) -> void:
	_wade_t -= dt
	for n in get_tree().get_nodes_in_group(&"fighters"):
		var f := n as Fighter
		if f == null or not f.alive:
			continue
		var p := f.global_position
		if not terrain.rect.has_point(Vector2(p.x, p.z)):
			continue
		if terrain.height_at(p.x, p.z) < ParkTerrain.WATER_LEVEL - 0.15 and f.is_on_floor():
			f.slow(0.6, 0.12)
			if _wade_t <= 0.0 and Vector2(f.velocity.x, f.velocity.z).length() > 2.0:
				VFX.spark(get_tree(), Vector3(p.x, ParkTerrain.WATER_LEVEL, p.z), Vector3.UP, Color(0.7, 0.9, 1.0), 6, 3.0)
	if _wade_t <= 0.0:
		_wade_t = 0.25
