class_name WaterfrontBuilder
extends RefCounted
## The south edge of the map is a working harbour on a massive river:
##   quay (z 214-251): paving, warehouses (their roofs join the roof network),
##     container yard, two portal cranes with climbable jibs, slipways
##   river (z>251): shallow wadeable shallows out to a buoy line, then deep water
##     that runs to a hazy far bank with the sun setting over it
##   docks: a T-pier and two finger piers (solid, timber-decked)
##   MV Aurora: a 130 m ship berthed at the T-pier with gangways, a superstructure
##     you can climb, container stacks for cover and a forecastle.
## Every level change is a ramp or a stair that lands on real surface.

const QUAY_Z := 251.0
const Z0 := 214.0
const XM := 296.0


static func build(parent: Node) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": [], "walks": []}
	var k := Kit.new(parent, "Waterfront")
	var conc := Mats.toon(Color(0.5, 0.52, 0.57), 0.7)
	var rng := RandomNumberGenerator.new()
	rng.seed = 2468
	_river(parent, k)
	_quay(k, conc, rng)
	_warehouses(k, info, rng)
	_yard(k, info, rng)
	_cranes(k, info)
	_piers(k, info, rng)
	ShipBuilder.build(k, info)
	_bounds(k)
	StaticBatch.merge(k.root)
	_far_bank(parent)
	info.landmarks.append(["Harbour", Vector3(0.0, 20.0, 300.0)])
	info.tp.append(["Quay", Vector3(0.0, 0.4, 232.0), PI])
	info.tp.append(["Harbour pier", Vector3(-100.0, 0.4, 339.0), PI])
	return info


# ------------------------------------------------------------------ river

static func _river(parent: Node, k: Kit) -> void:
	var conc := Mats.toon(Color(0.42, 0.44, 0.5), 0.8)
	# quay wall (solid down to the river bed, faces the water at z = QUAY_Z)
	k.box(Vector3(0.0, CityLayout.BED_Y, QUAY_Z - 1.0), Vector3(2000.0, -CityLayout.BED_Y, 2.0), conc, true)
	# wadeable shallows out to the buoy line
	var mid := (QUAY_Z + CityLayout.RIVER_MAX_Z) * 0.5
	k.box(Vector3(0.0, CityLayout.BED_Y - 2.0, mid), Vector3(602.0, 2.0, CityLayout.RIVER_MAX_Z - QUAY_Z + 2.0), Mats.toon(Color(0.36, 0.34, 0.3), 0.6), true)
	var wm := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(7000.0, 3600.0)
	q.orientation = PlaneMesh.FACE_Y
	wm.mesh = q
	wm.material_override = Mats.river()
	wm.position = Vector3(0.0, CityLayout.WATER_Y, QUAY_Z + 1750.0)
	wm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	wm.name = "River"
	parent.add_child(wm)
	var wz := WaterZone.new()
	wz.name = "RiverShallows"
	wz.rect = Rect2(-300.0, QUAY_Z, 600.0, CityLayout.RIVER_MAX_Z - QUAY_Z)
	wz.surface_y = CityLayout.WATER_Y
	parent.add_child(wz)


# ------------------------------------------------------------------ quay

static func _quay(k: Kit, conc: Material, rng: RandomNumberGenerator) -> void:
	var stone := Mats.toon(Color(0.58, 0.55, 0.5), 0.5)
	k.box(Vector3(0.0, 0.0, (Z0 + QUAY_Z - 1.0) * 0.5), Vector3(XM * 2.0, 0.06, QUAY_Z - 1.0 - Z0), stone, false, Vector3.ZERO, false)
	var paint := RoadPaint.new(0.08)
	var x := -XM
	while x < XM:
		var z := Z0
		while z < QUAY_Z - 1.0:
			if (int((x + XM) / 8.0) + int((z - Z0) / 8.0)) % 2 == 0:
				paint.rect(x, z, x + 8.0, minf(z + 8.0, QUAY_Z - 1.0), Color(0.5, 0.47, 0.43))
			z += 8.0
		x += 8.0
	paint.rect(-XM, QUAY_Z - 2.0, XM, QUAY_Z - 1.6, Color(1.0, 0.82, 0.15))
	paint.build(k.root)
	# bollards, lamps and rubber fenders along the edge
	var iron := Mats.toon(Color(0.12, 0.13, 0.16))
	var xb := -XM + 8.0
	while xb < XM:
		k.cyl(Vector3(xb, 0.0, QUAY_Z - 3.0), 0.35, 0.85, iron, true, 10)
		xb += 16.0
	var xl := -XM + 20.0
	while xl < XM:
		Props.lamp(k, Vector3(xl, 0.0, QUAY_Z - 5.0), 0.0, 7.0)
		xl += 40.0
	# crane rails
	for zr: float in [241.0, 248.0]:
		k.box(Vector3(0.0, 0.06, zr), Vector3(XM * 2.0, 0.08, 0.3), Mats.toon(Color(0.55, 0.56, 0.6)), false, Vector3.ZERO, false)
	# slipways: concrete ramps down into the shallows so nobody is stranded in the river
	for sx: float in [-215.0, 215.0]:
		k.ramp(Vector3(sx, 0.0, QUAY_Z), Vector3(sx, CityLayout.BED_Y, QUAY_Z + 8.5), 8.0, 1.0, conc)
		k.box(Vector3(sx - 4.3, CityLayout.BED_Y, QUAY_Z + 4.0), Vector3(0.6, 3.0, 8.5), conc, true)
		k.box(Vector3(sx + 4.3, CityLayout.BED_Y, QUAY_Z + 4.0), Vector3(0.6, 3.0, 8.5), conc, true)
		k.label("SLIPWAY", Vector3(sx, 3.4, QUAY_Z - 6.5), 0.9, Color(1.0, 0.85, 0.2), 180.0)
	k.label("HARBOUR", Vector3(0.0, 6.0, 216.5), 2.6, Color(1.0, 0.85, 0.5), 0.0)


# ------------------------------------------------------------------ warehouses

static func _warehouses(k: Kit, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var xs := [-262.0, -202.0, -142.0, 142.0, 202.0, 262.0]
	var hs := [14.0, 16.0, 14.0, 16.0, 14.0, 18.0]
	var cols := [Color(0.3, 0.45, 0.4), Color(0.5, 0.4, 0.3), Color(0.35, 0.4, 0.5), Color(0.45, 0.3, 0.28)]
	for i in xs.size():
		var cx: float = xs[i]
		var h: float = hs[i]
		var wall := Mats.facade(cols[i % cols.size()], float(i), 0.12, Vector2(5.0, 4.5), Vector2(0.28, 0.2), 0.0)
		k.box(Vector3(cx, 0.0, 230.0), Vector3(46.0, h, 24.0), wall, true)
		k.box(Vector3(cx, h, 230.0), Vector3(46.6, 0.5, 24.6), Mats.toon(Color(0.2, 0.22, 0.26)), false)
		for dz: float in [-12.15, 12.15]:
			for dx: float in [-12.0, 12.0]:
				k.box(Vector3(cx + dx, 0.0, 230.0 + dz), Vector3(7.0, 5.5, 0.3), Mats.toon(Color(0.14, 0.15, 0.18)), false)
				k.box(Vector3(cx + dx, 5.7, 230.0 + dz + signf(dz) * 0.2), Vector3(0.8, 0.3, 0.3), Mats.glow(Color(1.0, 0.8, 0.3), 4.0), false, Vector3.ZERO, false)
		k.label("WAREHOUSE %d" % (i + 1), Vector3(cx, 9.5, 242.2), 1.4, Color(0.95, 0.95, 0.9), 0.0)
		var clut: Array = []
		for j in 2:
			var ap := Vector3(cx + rng.randf_range(-14.0, 14.0), h, 230.0 + rng.randf_range(-6.0, 6.0))
			Props.ac_unit(k, ap, rng.randf_range(0, 90))
			clut.append(Rect2(ap.x - 2.2, ap.z - 2.2, 4.4, 4.4))
		info.walks.append({"rect": Rect2(cx - 22.6, 218.4, 45.2, 23.2), "y": h, "avoid": Rect2(), "clutter": clut})
		if i % 2 == 0:
			info.shards.append(Vector3(cx + 6.0, h + 1.5, 236.0))


# ------------------------------------------------------------------ container yard

static func _yard(k: Kit, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var cols := [Color(0.75, 0.2, 0.18), Color(0.2, 0.4, 0.7), Color(0.85, 0.65, 0.15), Color(0.2, 0.55, 0.4), Color(0.8, 0.8, 0.82), Color(0.9, 0.4, 0.15)]
	var pattern := [1, 2, 3, 2, 1, 2, 3, 3, 2, 1]
	var col_i := 0
	for zr: float in [223.0, 238.0]:
		var xi := -105.0
		var pi := int(rng.randi() % 4)
		while xi < 106.0:
			if absf(xi) < 12.0 or (absf(xi) > 60.0 and absf(xi) < 78.0):
				xi += 15.0
				continue
			var n: int = pattern[pi % pattern.size()]
			pi += 1
			var color: Color = cols[rng.randi() % cols.size()]
			for lv in n:
				k.box(Vector3(xi, lv * 2.6, zr), Vector3(12.0, 2.6, 2.4), Mats.toon(color if lv % 2 == 0 else color.lightened(0.12), 0.4), true)
				k.box(Vector3(xi, lv * 2.6 + 1.2, zr + 1.21), Vector3(11.0, 0.12, 0.04), Mats.toon(color.darkened(0.3)), false, Vector3.ZERO, false)
			if col_i % 6 == 0:
				info.shards.append(Vector3(xi, n * 2.6 + 1.4, zr))
			col_i += 1
			xi += 15.0
	# forklift lane markings
	var paint := RoadPaint.new(0.1)
	paint.rect(-115.0, 229.8, 115.0, 230.0, Color(1.0, 0.85, 0.2))
	paint.build(k.root)


# ------------------------------------------------------------------ quay cranes

static func _cranes(k: Kit, info: Dictionary) -> void:
	for cx: float in [-95.0, 95.0]:
		_crane(k, cx, info)


static func _crane(k: Kit, cx: float, info: Dictionary) -> void:
	var red := Mats.toon(Color(0.78, 0.16, 0.14))
	var white := Mats.toon(Color(0.88, 0.88, 0.9))
	var dark := Mats.toon(Color(0.12, 0.13, 0.16))
	var leg_h := 24.2   # walkway top = 25.4 = the fire escape's top landing
	for lx: float in [-9.0, 9.0]:
		for lz: float in [241.0, 248.0]:
			k.box(Vector3(cx + lx, 0.0, lz), Vector3(2.4, leg_h, 2.4), red, true)
	for lz: float in [241.0, 248.0]:
		k.box(Vector3(cx, leg_h, lz), Vector3(25.0, 1.2, 2.4), white, true)
	for lx: float in [-9.0, 9.0]:
		k.box(Vector3(cx + lx, leg_h, 244.5), Vector3(2.4, 1.2, 7.0), white, true)
	# jib over the water
	k.box(Vector3(cx, leg_h, 269.0), Vector3(3.0, 1.2, 42.0), white, true)
	k.box(Vector3(cx, leg_h + 1.2, 269.0), Vector3(0.15, 0.9, 42.0), Mats.glow(Color(1.0, 0.3, 0.2), 2.0), false, Vector3.ZERO, false)
	# braces + machinery house (visual)
	for lz: float in [241.0, 248.0]:
		k.box(Vector3(cx, 12.0, lz), Vector3(18.0, 0.5, 0.5), dark, false)
	k.box(Vector3(cx, leg_h + 1.2, 244.5), Vector3(5.0, 3.0, 4.0), Mats.toon(Color(0.86, 0.86, 0.88)), false)
	# hoist cable and a container hanging from the tip
	k.box(Vector3(cx, 8.0, 286.0), Vector3(0.12, 17.5, 0.12), dark, false)
	k.box(Vector3(cx, 6.6, 286.0), Vector3(2.4, 0.7, 12.0), dark, false, Vector3.ZERO, false)
	k.box(Vector3(cx, 4.0, 286.0), Vector3(2.4, 2.6, 12.0), Mats.toon(Color(0.2, 0.4, 0.7)), false)
	# climbable: zig-zag fire escape up the west-front leg to the walkway
	Props.fire_escape(k, Vector3(cx - 10.2, 0.0, 241.0), -90.0, 30.5)
	k.label("PORT OF AURORA", Vector3(cx, 26.0, 249.3), 1.1, Color(1, 1, 1), 0.0)
	info.tp.append(["Crane walkway" if cx < 0.0 else "Crane walkway E", Vector3(cx, leg_h + 1.2 + 0.4, 241.0), PI])
	info.shards.append(Vector3(cx, leg_h + 2.6, 285.0))
	info.landmarks.append(["Quay Crane" if cx < 0.0 else "Quay Crane E", Vector3(cx, 30.0, 245.0)])


# ------------------------------------------------------------------ piers

static func _piers(k: Kit, info: Dictionary, rng: RandomNumberGenerator) -> void:
	var wood := Mats.toon(Color(0.52, 0.36, 0.24), 0.3)
	var conc := Mats.toon(Color(0.42, 0.44, 0.5), 0.8)
	var dark := Mats.toon(Color(0.12, 0.13, 0.16))
	var paint := RoadPaint.new(0.03)
	var plank := Color(0.33, 0.22, 0.14)
	# T-pier: stem + crossbar (solid to the river bed, timber deck flush with the quay)
	_pier_block(k, wood, conc, Rect2(-8.0, 250.0, 16.0, 81.0))
	_pier_block(k, wood, conc, Rect2(-150.0, 331.0, 300.0, 16.0))
	for fx: float in [-180.0, 180.0]:
		_pier_block(k, wood, conc, Rect2(fx - 6.0, 250.0, 12.0, 101.0))
	var z := 251.0
	while z < 331.0:
		paint.rect(-8.0, z, 8.0, z + 0.07, plank)
		z += 1.2
	var x := -150.0
	while x < 150.0:
		paint.rect(x, 331.0, x + 0.07, 347.0, plank)
		x += 1.2
	for fx: float in [-180.0, 180.0]:
		var zf := 251.0
		while zf < 351.0:
			paint.rect(fx - 6.0, zf, fx + 6.0, zf + 0.07, plank)
			zf += 1.2
	paint.build(k.root)
	# bollards, lamps and fenders along the T-bar's river face
	var xb := -144.0
	while xb <= 144.0:
		k.cyl(Vector3(xb, 0.0, 345.2), 0.4, 0.9, dark, true, 10)
		xb += 12.0
	for xf: float in [-120.0, -90.0, -60.0, -30.0, 0.0, 30.0, 60.0, 90.0, 120.0]:
		k.box(Vector3(xf, -1.2, 347.3), Vector3(1.4, 1.6, 0.5), dark, false)
	for xl: float in [-140.0, -100.0, 100.0, 140.0]:
		Props.lamp(k, Vector3(xl, 0.0, 333.0), 0.0, 7.0)
	for zl: float in [270.0, 300.0]:
		Props.lamp(k, Vector3(-7.0, 0.0, zl), 90.0, 7.0)
		Props.lamp(k, Vector3(7.0, 0.0, zl), -90.0, 7.0)
	# dock clutter: crates and a harbour office at the head of the stem
	Props.crates(k, Vector3(-100.0, 0.0, 337.0), 0.0, rng, 3)
	Props.crates(k, Vector3(-125.0, 0.0, 341.0), 0.0, rng, 3)
	Props.crates(k, Vector3(110.0, 0.0, 337.0), 0.0, rng, 3)
	k.box(Vector3(-100.0, 0.0, 310.0), Vector3(6.0, 3.6, 5.0), Mats.toon(Color(0.86, 0.84, 0.78), 0.4), true)
	k.box(Vector3(-100.0, 3.6, 310.0), Vector3(6.6, 0.3, 5.6), Mats.toon(Color(0.7, 0.2, 0.15)), false)
	k.label("HARBOUR MASTER", Vector3(-100.0, 2.4, 307.4), 0.5, Color(0.1, 0.1, 0.1), 0.0)
	for fx: float in [-180.0, 180.0]:
		k.box(Vector3(fx, 0.0, 346.0), Vector3(3.0, 3.0, 3.0), Mats.toon(Color(0.5, 0.42, 0.34), 0.5), true)
		k.label("FISH", Vector3(fx, 3.4, 344.4), 0.7, Color(1.0, 0.9, 0.5), 0.0)
	info.shards.append(Vector3(0.0, 1.4, 340.0))
	info.shards.append(Vector3(-180.0, 1.4, 349.0))


## Solid pier (concrete to the bed) with a timber cap so the surface reads as a deck.
static func _pier_block(k: Kit, wood: Material, conc: Material, r: Rect2) -> void:
	var c := r.get_center()
	k.box(Vector3(c.x, CityLayout.BED_Y, c.y), Vector3(r.size.x, -CityLayout.BED_Y - 0.15, r.size.y), conc, true)
	k.box(Vector3(c.x, -0.15, c.y), Vector3(r.size.x, 0.15, r.size.y), wood, true)


# ------------------------------------------------------------------ boundary

static func _bounds(k: Kit) -> void:
	var zmax := CityLayout.RIVER_MAX_Z
	k.collision_box(Vector3(0.0, -4.0, zmax + 0.5), Vector3(604.0, 14.0, 1.0))
	for sx: float in [-300.5, 300.5]:
		k.collision_box(Vector3(sx, -4.0, (QUAY_Z + zmax) * 0.5), Vector3(1.0, 14.0, zmax - QUAY_Z))
	# buoy line so the edge of the shallows is readable
	var buoy := Mats.glow(Color(1.0, 0.45, 0.2), 3.5)
	var line := Mats.toon(Color(0.1, 0.1, 0.12))
	var x := -296.0
	while x <= 296.0:
		k.sphere(Vector3(x, CityLayout.WATER_Y + 0.15, zmax - 2.0), 0.7, buoy)
		x += 20.0
	var z := QUAY_Z + 20.0
	while z <= zmax:
		k.sphere(Vector3(-296.0, CityLayout.WATER_Y + 0.15, z), 0.7, buoy)
		k.sphere(Vector3(296.0, CityLayout.WATER_Y + 0.15, z), 0.7, buoy)
		z += 20.0
	k.box(Vector3(0.0, CityLayout.WATER_Y, zmax - 2.0), Vector3(592.0, 0.06, 0.06), line, false, Vector3.ZERO, false)


# ------------------------------------------------------------------ far bank

static func _far_bank(parent: Node) -> void:
	var k := Kit.new(parent, "FarBank")
	var rng := RandomNumberGenerator.new()
	rng.seed = 1357
	k.box(Vector3(0.0, -3.0, 1450.0), Vector3(5000.0, 3.5, 600.0), Mats.toon(Color(0.1, 0.12, 0.17)), false, Vector3.ZERO, false)
	var walls := [Color(0.25, 0.3, 0.42), Color(0.32, 0.28, 0.4), Color(0.22, 0.32, 0.38), Color(0.4, 0.34, 0.34)]
	var x := -2200.0
	while x < 2200.0:
		var w := rng.randf_range(30.0, 80.0)
		var d := rng.randf_range(30.0, 70.0)
		var edge := 1.0 - absf(x) / 2400.0
		var h := rng.randf_range(20.0, 60.0) + rng.randf() * rng.randf() * 130.0 * edge
		var mat := Mats.facade(walls[rng.randi() % walls.size()], rng.randf() * 90.0, 0.55, Vector2(3.8, 4.0), Vector2(0.55, 0.6), 0.0)
		k.box(Vector3(x, 0.0, 1220.0 + rng.randf_range(0.0, 260.0)), Vector3(w, h, d), mat, false)
		if rng.randf() < 0.3:
			k.sphere(Vector3(x, h + 1.0, 1230.0), 1.4, Mats.glow(Color(1.0, 0.15, 0.15), 6.0))
		x += w + rng.randf_range(2.0, 24.0)
	StaticBatch.merge(k.root)
