class_name CityBuilder
extends Node3D
## Assembles the test slice: a 3x2 grid of blocks split by 18 m streets, each
## block cut by a cross-shaped alley into four lots. Layout is DATA (BLOCKS);
## districts differ by shape (heights, footprints, alleys), not by rules.
##
## Levels you can fight on: street (0) - curb/alley (0.12) - podium plaza (3.6)
## - tower terraces (6) - highway deck (9.5) - skybridge (17) - gas-station
## canopy (15) - rooftops (12..70).

const BLOCK := 64.0
const HALF := 32.0
const ALLEY := 6.0
const STREET := 18.0
const COLS := [-82.0, 0.0, 82.0]
const ROWS := [-41.0, 41.0]
const AVENUES_X := [-123.0, -41.0, 41.0, 123.0]
const STREETS_Z := [-82.0, 0.0, 82.0]
const PLAY_X := 140.0
const PLAY_Z := 100.0

## [NW, NE, SW, SE] per block. `plaza` swaps a lot for an open raised plaza.
const BLOCKS := {
	Vector2i(0, 0): [["glass", 58], ["brick", 30], ["oldtown", 14], ["concrete", 24]],
	Vector2i(1, 0): [["billboard", 46], ["glass", 70], ["brick", 26], ["concrete", 34]],
	Vector2i(2, 0): [["brick", 38], ["oldtown", 16], ["glass", 52], ["billboard", 40]],
	Vector2i(0, 1): [["concrete", 30], ["oldtown", 12], ["brick", 22], ["glass", 44]],
	Vector2i(1, 1): [["museum", 18], ["oldtown", 9], ["glass", 62], ["plaza", 0]],
	Vector2i(2, 1): [["brick", 34], ["glass", 48], ["concrete", 26], ["oldtown", 15]],
}

var markers := {}
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 20260930
	_ground()
	_road_paint()
	for key in BLOCKS.keys():
		_block(key)
	HighwayBuilder.build(self)
	var lb := Leaderboard.new()
	lb.name = "Leaderboard"
	lb.position = Vector3(-17.5, 46.0, -46.0)
	add_child(lb)
	_skybridge()
	_street_furniture()
	_landmark_clock_tower()
	_edge_walls()
	_skyline()
	_elevated_rail()
	_lights()
	_pickups()
	_markers()


# --------------------------------------------------------------- ground

func _ground() -> void:
	var k := Kit.new(self, "Ground")
	k.box(Vector3(0, -2.0, 0), Vector3(900, 2.0, 900), Mats.road(), true)


func _road_paint() -> void:
	var p := RoadPaint.new(0.03)
	var yellow := Color(1.0, 0.82, 0.2)
	var white := Color(0.88, 0.9, 0.95)
	# E-W streets
	for zc in STREETS_Z:
		var x := -PLAY_X
		while x < PLAY_X:
			var near_ix := false
			for ax in AVENUES_X:
				if absf(x + 1.5 - ax) < 11.0:
					near_ix = true
			if not near_ix:
				p.rect(x, zc - 0.1, x + 3.0, zc + 0.1, yellow)
				p.rect(x, zc - 4.6, x + 3.0, zc - 4.5, white)
				p.rect(x, zc + 4.5, x + 3.0, zc + 4.6, white)
			x += 6.0
	# N-S avenues
	for xc in AVENUES_X:
		var z := -PLAY_Z
		while z < PLAY_Z:
			var near_ix := false
			for sz in STREETS_Z:
				if absf(z + 1.5 - sz) < 11.0:
					near_ix = true
			if not near_ix:
				p.rect(xc - 0.1, z, xc + 0.1, z + 3.0, yellow)
				p.rect(xc - 4.6, z, xc - 4.5, z + 3.0, white)
				p.rect(xc + 4.5, z, xc + 4.6, z + 3.0, white)
			z += 6.0
	# zebra crossings on every approach + a scramble X at the plaza corner
	for ax in AVENUES_X:
		for sz in STREETS_Z:
			for s in [-1.0, 1.0]:
				var d := 9.0 + 2.2
				# crossing the avenue (stripes run N-S direction, laid across E-W)
				var zc: float = sz + s * d
				for i in 9:
					var x0: float = ax - 8.1 + i * 1.8
					p.rect(x0, zc - 1.6, x0 + 0.9, zc + 1.6, white)
				# crossing the street
				var xc: float = ax + s * d
				for i in 9:
					var z0: float = sz - 8.1 + i * 1.8
					p.rect(xc - 1.6, z0, xc + 1.6, z0 + 0.9, white)
	p.build(self)


# --------------------------------------------------------------- blocks

func _block(key: Vector2i) -> void:
	var cx: float = COLS[key.x]
	var cz: float = ROWS[key.y]
	var slab := Kit.new(self, "Block_%d_%d" % [key.x, key.y])
	# sidewalk / alley floor. 0.12 tall: the capsule rides up it without a step.
	slab.box(Vector3(cx, 0.0, cz), Vector3(BLOCK, 0.12, BLOCK), Mats.toon(Color(0.36, 0.37, 0.42), 0.6), true)
	# alley gutters
	var paint := RoadPaint.new(0.14)
	paint.rect(cx - 0.25, cz - HALF, cx + 0.25, cz + HALF, Color(0.05, 0.06, 0.09))
	paint.rect(cx - HALF, cz - 0.25, cx + HALF, cz + 0.25, Color(0.05, 0.06, 0.09))
	paint.build(slab.root)
	var lots: Array = BLOCKS[key]
	# lot rects: NW, NE, SW, SE
	var a := ALLEY * 0.5
	var rects := [
		Rect2(cx - HALF, cz - HALF, HALF - a, HALF - a),
		Rect2(cx + a, cz - HALF, HALF - a, HALF - a),
		Rect2(cx - HALF, cz + a, HALF - a, HALF - a),
		Rect2(cx + a, cz + a, HALF - a, HALF - a),
	]
	var faces := [
		{"n": true, "w": true, "s": false, "e": false},
		{"n": true, "e": true, "s": false, "w": false},
		{"s": true, "w": true, "n": false, "e": false},
		{"s": true, "e": true, "n": false, "w": false},
	]
	for i in 4:
		var spec := {"style": lots[i][0], "h": float(lots[i][1]), "seed": key.x * 13 + key.y * 7 + i}
		if spec.style == "plaza":
			_plaza(rects[i], key)
		else:
			BuildingFactory.build(self, rects[i], spec, faces[i])
	# dead-end one arm of the cross alley in some blocks: choke points
	if (key.x + key.y) % 2 == 0:
		var g := Kit.new(self, "AlleyGate_%d_%d" % [key.x, key.y])
		g.box(Vector3(cx, 0.12, cz - HALF + 1.0), Vector3(ALLEY - 0.4, 3.2, 0.5), Mats.toon(Color(0.2, 0.22, 0.26), 0.7), true)
		g.box(Vector3(cx - 1.4, 0.12, cz - HALF + 2.3), Vector3(1.9, 1.0, 1.0), Mats.toon(Color(0.16, 0.36, 0.25)), true)


func _plaza(r: Rect2, key: Vector2i) -> void:
	# Raised civic plaza: multi-level "ground" with two grand stair runs.
	var k := Kit.new(self, "Plaza")
	var stone := Mats.toon(Color(0.66, 0.62, 0.56), 0.4)
	var c := BuildingFactory.center(r)
	var plat := BuildingFactory.inset(r, 4.0)
	k.box(Vector3(c.x, 0.0, c.z), Vector3(plat.size.x, 3.6, plat.size.y), stone, true)
	# stairs toward the north street and east street
	k.stairs(Vector3(c.x, 0.0, plat.position.y), Vector3(0, 0, -1), 3.6, 7.0, 9.0, stone)
	k.stairs(Vector3(plat.end.x, 0.0, c.z), Vector3(1, 0, 0), 3.6, 7.0, 9.0, stone)
	# fountain + statue + planters + trees
	k.cyl(Vector3(c.x, 3.6, c.z), 4.2, 0.9, stone, true, 24)
	k.cyl(Vector3(c.x, 4.5, c.z), 3.6, 0.05, Mats.glass(Color(0.3, 0.6, 0.9, 0.7)), false, 24)
	k.cyl(Vector3(c.x, 3.6, c.z), 0.7, 5.5, stone, true, 10, 0.4)
	k.sphere(Vector3(c.x, 9.5, c.z), 0.9, Mats.glow(Color(0.5, 0.9, 1.0), 3.0))
	for i in 4:
		var ang := i * PI * 0.5 + PI * 0.25
		var p := Vector3(c.x + cos(ang) * 9.0, 3.6, c.z + sin(ang) * 9.0)
		Props.planter(k, p, Vector3(2.4, 0.9, 2.4))
		Props.tree(k, p + Vector3(0, 0.9, 0), 5.5)
	for i in 6:
		var ang2 := i * PI / 3.0
		Props.bench(k, Vector3(c.x + cos(ang2) * 6.5, 3.6, c.z + sin(ang2) * 6.5), -rad_to_deg(ang2) + 90.0)
	for i in 8:
		var ang3 := i * PI / 4.0
		Props.lamp(k, Vector3(c.x + cos(ang3) * 11.5, 3.6, c.z + sin(ang3) * 11.5), -rad_to_deg(ang3), 5.5)
	# low kiosks as cover
	k.box(Vector3(plat.position.x + 3.0, 3.6, plat.position.y + 3.0), Vector3(4.0, 3.0, 3.0), Mats.toon(Color(0.35, 0.4, 0.46)), true)
	k.box(Vector3(plat.end.x - 7.0, 3.6, plat.end.y - 6.0), Vector3(4.0, 3.0, 3.0), Mats.toon(Color(0.5, 0.35, 0.3)), true)
	k.label("CITY PLAZA", Vector3(c.x, 8.0, plat.position.y + 0.4), 1.4, Color(1.0, 0.95, 0.8), 180.0)


# --------------------------------------------------------------- skybridge

func _skybridge() -> void:
	var k := Kit.new(self, "Skybridge")
	var y := 17.0
	var z := -58.0
	var x0 := 26.0
	var x1 := 51.0
	var mid := (x0 + x1) * 0.5
	var steel := Mats.toon(Color(0.22, 0.24, 0.3))
	k.box(Vector3(mid, y - 0.6, z), Vector3(x1 - x0, 0.6, 5.0), steel, true)
	for sz in [-2.3, 2.3]:
		k.box(Vector3(mid, y, z + sz), Vector3(x1 - x0, 1.15, 0.3), steel, true)
		for i in 5:
			k.box(Vector3(x0 + 2 + i * 5.0, y, z + sz), Vector3(0.3, 3.2, 0.3), steel, false)
		k.box(Vector3(mid, y + 3.1, z + sz), Vector3(x1 - x0, 0.3, 0.3), steel, false)
	k.box(Vector3(mid, y + 1.15, z + 2.3), Vector3(x1 - x0, 1.9, 0.08), Mats.glass(Color(0.4, 0.7, 0.9, 0.35)), false)
	k.box(Vector3(mid, y + 1.15, z - 2.3), Vector3(x1 - x0, 1.9, 0.08), Mats.glass(Color(0.4, 0.7, 0.9, 0.35)), false)
	k.box(Vector3(mid, y - 1.3, z), Vector3(x1 - x0 - 4.0, 0.7, 1.4), Mats.glow(Color(0.5, 0.8, 1.0), 2.5), false, Vector3.ZERO, false)
	# suspension-style support cables to the towers
	for sx in [x0 + 1.0, x1 - 1.0]:
		k.box(Vector3(sx, y - 6.0, z), Vector3(0.6, 6.0, 5.4), steel, false)


# --------------------------------------------------------------- street furniture

func _street_furniture() -> void:
	var k := Kit.new(self, "StreetFurniture")
	var rng := _rng
	# parked cars = cover at street level
	for zc in STREETS_Z:
		var x := -PLAY_X + 10.0
		while x < PLAY_X - 10.0:
			x += rng.randf_range(11.0, 24.0)
			var skip := false
			for ax in AVENUES_X:
				if absf(x - ax) < 12.0:
					skip = true
			if skip or rng.randf() < 0.35:
				continue
			if zc == 0.0 and x > HighwayBuilder.X_START - 30.0 and x < HighwayBuilder.X_START + 10.0:
				continue  # keep the ramp foot clear
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			var yaw := 0.0 if side > 0.0 else 180.0
			Props.car(k, Vector3(x, 0.0, zc + side * 6.6), yaw, Props.CAR_COLORS[rng.randi() % Props.CAR_COLORS.size()])
	for ax in AVENUES_X:
		var z := -PLAY_Z + 10.0
		while z < PLAY_Z - 10.0:
			z += rng.randf_range(12.0, 26.0)
			var skip2 := false
			for sz in STREETS_Z:
				if absf(z - sz) < 12.0:
					skip2 = true
			if skip2 or rng.randf() < 0.4:
				continue
			var side2 := -1.0 if rng.randf() < 0.5 else 1.0
			Props.car(k, Vector3(ax + side2 * 6.6, 0.0, z), 90.0, Props.CAR_COLORS[rng.randi() % Props.CAR_COLORS.size()])
	# streetlamps along the block curbs
	for key in BLOCKS.keys():
		var cx: float = COLS[key.x]
		var cz: float = ROWS[key.y]
		for t in range(-24, 25, 24):
			Props.lamp(k, Vector3(cx + t, 0.12, cz - HALF + 1.0), 0.0 + 180.0, 7.0)
			Props.lamp(k, Vector3(cx + t, 0.12, cz + HALF - 1.0), 0.0, 7.0)
			Props.lamp(k, Vector3(cx - HALF + 1.0, 0.12, cz + t), -90.0 + 180.0, 7.0)
			Props.lamp(k, Vector3(cx + HALF - 1.0, 0.12, cz + t), -90.0, 7.0)


func _landmark_clock_tower() -> void:
	# Visible from anywhere: the orientation beacon.
	var k := Kit.new(self, "ClockTower", Vector3(0, 0, -114))
	var stone := Mats.facade(Color(0.5, 0.42, 0.36), 77.0, 0.3, Vector2(4.0, 6.0), Vector2(0.4, 0.62), 6.0)
	k.box(Vector3.ZERO, Vector3(26, 26, 22), stone, true)
	k.box(Vector3(0, 26, 0), Vector3(18, 70, 16), stone, true)
	k.box(Vector3(0, 96, 0), Vector3(21, 26, 19), stone, true)
	var clock := Mats.glow(Color(1.0, 0.92, 0.7), 2.4)
	var hand := Mats.toon(Color(0.08, 0.08, 0.1))
	for face in [[0.0, 9.6], [180.0, -9.6]]:
		var yaw: float = face[0]
		var zz: float = face[1]
		var disc := k.cyl(Vector3(0, 108, zz), 7.5, 0.3, clock, false, 32)
		disc.rotation_degrees.x = 90
		k.box(Vector3(0, 108, zz * 1.03), Vector3(0.5, 5.6, 0.2), hand, false)
		var minute := k.box(Vector3(0, 108, zz * 1.03), Vector3(0.35, 7.0, 0.2), hand, false, Vector3(0, 0, 70))
		minute.position.y = 108.0 + 0.0
	# roof: pyramid + spire
	var roof := k.cyl(Vector3(0, 122, 0), 15.0, 22.0, Mats.toon(Color(0.2, 0.32, 0.3)), false, 4, 0.5)
	roof.rotation_degrees.y = 45
	k.cyl(Vector3(0, 144, 0), 0.4, 18.0, Mats.toon(Color(0.7, 0.7, 0.7)), false, 8)
	k.sphere(Vector3(0, 162.5, 0), 1.0, Mats.glow(Color(1.0, 0.15, 0.15), 8.0))
	# warm floodlit belfry
	k.box(Vector3(0, 122.0, 0), Vector3(15.5, 0.6, 14.0), Mats.glow(Color(1.0, 0.8, 0.5), 3.0), false, Vector3.ZERO, false)


func _edge_walls() -> void:
	var k := Kit.new(self, "EdgeWalls")
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var t := 14.0
	# north / south
	for side in [-1.0, 1.0]:
		var x := -PLAY_X - 20.0
		while x < PLAY_X + 20.0:
			var w := rng.randf_range(24.0, 44.0)
			var h := rng.randf_range(55.0, 130.0)
			_edge_box(k, Vector3(x + w * 0.5, 0.0, side * (PLAY_Z + t * 0.5)), Vector3(w, h, t), rng)
			x += w
	for side in [-1.0, 1.0]:
		var z := -PLAY_Z
		while z < PLAY_Z:
			var d := rng.randf_range(24.0, 44.0)
			var h2 := rng.randf_range(55.0, 130.0)
			_edge_box(k, Vector3(side * (PLAY_X + t * 0.5), 0.0, z + d * 0.5), Vector3(t, h2, d), rng)
			z += d


func _edge_box(k: Kit, pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var walls := [Color(0.3, 0.32, 0.4), Color(0.4, 0.3, 0.32), Color(0.28, 0.36, 0.42), Color(0.44, 0.4, 0.36)]
	var mat := Mats.facade(walls[rng.randi() % walls.size()], rng.randf() * 90.0, 0.42, Vector2(3.4, 3.8), Vector2(0.55, 0.6), 5.0)
	# inflate slightly so window cells line up per-building
	k.box(pos, size, mat, true)


func _skyline() -> void:
	var k := Kit.new(self, "Skyline")
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var walls := [Color(0.25, 0.3, 0.42), Color(0.32, 0.28, 0.4), Color(0.22, 0.32, 0.38), Color(0.4, 0.34, 0.34), Color(0.3, 0.34, 0.44)]
	for i in 140:
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(190.0, 700.0)
		var p := Vector3(cos(ang) * dist * 1.25, 0.0, sin(ang) * dist)
		if absf(p.z - 150.0) < 22.0:
			continue  # keep the rail corridor open
		var w := rng.randf_range(30.0, 70.0)
		var d := rng.randf_range(30.0, 70.0)
		var h := rng.randf_range(80.0, 300.0) * (0.6 + dist / 900.0)
		var mat := Mats.facade(walls[rng.randi() % walls.size()], rng.randf() * 90.0, 0.5, Vector2(3.8, 4.0), Vector2(0.55, 0.6), 0.0)
		k.box(p, Vector3(w, h, d), mat, false)
		if rng.randf() < 0.35:
			k.sphere(p + Vector3(0, h + 1.0, 0), 1.2, Mats.glow(Color(1.0, 0.15, 0.15), 6.0))
		if rng.randf() < 0.18:
			var pal := Props.random_palette(rng)
			var m := Mats.mural(pal[0], pal[1], pal[2], rng.randf() * 30.0, 2.0, 1.6)
			var toward := (Vector3.ZERO - p).normalized()
			k.mural_quad(p + Vector3(toward.x * (w * 0.5 + 0.2), h * 0.75, toward.z * (d * 0.5 + 0.2)), Vector2(minf(w, d) * 0.8, minf(w, d) * 0.4), rad_to_deg(atan2(toward.x, toward.z)), m)


func _elevated_rail() -> void:
	# A rail line cutting across the sky behind the south edge.
	var k := Kit.new(self, "ElevatedRail", Vector3(0, 0, 150))
	var concrete := Mats.toon(Color(0.35, 0.36, 0.42), 0.6)
	var y := 30.0
	k.box(Vector3(0, y, 0), Vector3(1100, 1.6, 7.0), concrete, false)
	for x in range(-540, 541, 30):
		k.box(Vector3(x, 0, 0), Vector3(2.4, y, 2.4), concrete, false)
	var train := Node3D.new()
	train.name = "Train"
	k.root.add_child(train)
	for i in 6:
		var car := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(14.0, 3.6, 3.4)
		car.mesh = bm
		car.material_override = Mats.toon(Color(0.85, 0.87, 0.92))
		car.position = Vector3(i * 15.0, y + 3.4, 0)
		train.add_child(car)
		var win := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(13.0, 1.0, 3.5)
		win.mesh = wm
		win.material_override = Mats.glow(Color(1.0, 0.92, 0.7), 3.0)
		win.position = Vector3(i * 15.0, y + 3.7, 0)
		win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		train.add_child(win)
	train.position = Vector3(-500, 0, 0)
	var tw := train.create_tween().set_loops()
	tw.tween_property(train, "position:x", 500.0, 34.0).from(-500.0)
	tw.tween_interval(6.0)


func _lights() -> void:
	# A handful of real lights so puddled streets pick up warm pools.
	var spots := [Vector3(-41, 6.5, 8), Vector3(41, 6.5, -20), Vector3(-41, 6.5, -30), Vector3(0, 6.5, 6), Vector3(0, 7.0, -6), Vector3(41, 6.5, 30), Vector3(-82, 6.0, -41), Vector3(82, 6.0, 41)]
	for p in spots:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 22.0
		l.light_energy = 1.6
		l.light_color = Color(1.0, 0.72, 0.42)
		l.shadow_enabled = false
		add_child(l)
	# under-deck strip light
	var d := OmniLight3D.new()
	d.position = Vector3(20, 6.0, 0)
	d.omni_range = 26.0
	d.light_energy = 1.4
	d.light_color = Color(0.5, 0.75, 1.0)
	add_child(d)


func _pickups() -> void:
	var spots := [
		Vector3(-41, 0.0, 14), Vector3(41, 0.0, -14), Vector3(-82, 0.12, -41), Vector3(0, 0.12, 41),
		Vector3(-10, 0.0, 0), Vector3(82, 0.12, 41), Vector3(-41, 0.0, -60), Vector3(41, 0.0, 60),
		Vector3(30, 9.5, 0), Vector3(0, 3.6, 41),
	]
	for p in spots:
		var pk := Pickup.new()
		pk.position = p
		add_child(pk)


func _markers() -> void:
	markers = {
		"player": Vector3(-41, 0.1, 26),
		"bot_dummy": Vector3(-41, 0.1, -20),
		"bot_blocker": Vector3(-12, 0.1, 2),
		"bot_dodger": Vector3(-82, 0.2, -41),
		"bot_aggressor": Vector3(41, 0.1, -30),
		"bot_terrace": Vector3(-111.0, 6.05, -58),
	}
	markers["tp"] = [
		["Street", Vector3(-41, 0.1, 26), -PI * 0.5],
		["Underpass", Vector3(-8, 0.1, 5), -PI * 0.5],
		["Highway deck", Vector3(-70, 9.6, 0), -PI * 0.5],
		["Gas station roof", Vector3(106, 15.2, 0), PI * 0.5],
		["Alley", Vector3(-82, 0.2, -30), PI],
		["Tower terrace", Vector3(-111, 6.1, -50), 0.0],
		["Skybridge", Vector3(38, 17.1, -58), -PI * 0.5],
	]
