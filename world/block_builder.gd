class_name BlockBuilder
extends RefCounted
## Standard block: a 64 m sidewalk slab cut by a cross-shaped alley into four
## lots, each built by BuildingFactory from LOTS[id]. District flavour (lantern
## strings in Chinatown, dense stalls in the market) is added here.

const ALLEY := 6.0


## Returns {"roofs": [Vector3...]} for collectibles / teleports.
static func build(parent: Node, id: String, c: Vector2, c_idx: int, r_idx: int) -> Dictionary:
	var lots: Array = CityLayout.LOTS[id]
	var district := CityLayout.district_of(id)
	var half := CityLayout.HALF
	# everything in one block shares a node so StaticBatch can merge across lots
	var group := Node3D.new()
	group.name = "Cell_%s" % id
	parent.add_child(group)
	var slab := Kit.new(group, "Block_%s" % id)
	var side_col := Color(0.36, 0.37, 0.42)
	if district == "chinatown":
		side_col = Color(0.42, 0.34, 0.32)
	slab.box(Vector3(c.x, 0.0, c.y), Vector3(CityLayout.BLOCK, 0.12, CityLayout.BLOCK), Mats.toon(side_col, 0.6), true)
	var paint := RoadPaint.new(0.14)
	paint.rect(c.x - 0.25, c.y - half, c.x + 0.25, c.y + half, Color(0.05, 0.06, 0.09))
	paint.rect(c.x - half, c.y - 0.25, c.x + half, c.y + 0.25, Color(0.05, 0.06, 0.09))
	paint.build(slab.root)
	var a := ALLEY * 0.5
	var rects := [
		Rect2(c.x - half, c.y - half, half - a, half - a),
		Rect2(c.x + a, c.y - half, half - a, half - a),
		Rect2(c.x - half, c.y + a, half - a, half - a),
		Rect2(c.x + a, c.y + a, half - a, half - a),
	]
	var faces := [
		{"n": true, "w": true, "s": false, "e": false},
		{"n": true, "e": true, "s": false, "w": false},
		{"s": true, "w": true, "n": false, "e": false},
		{"s": true, "e": true, "n": false, "w": false},
	]
	var out := {"roofs": [], "landmarks": [], "tp": []}
	for i in 4:
		var style: String = lots[i][0]
		var spec := {"style": style, "h": float(lots[i][1]), "seed": c_idx * 13 + r_idx * 7 + i}
		if style == "plaza":
			_plaza(group, rects[i])
			continue
		var kit := BuildingFactory.build(group, rects[i], spec, faces[i], false)
		if kit.root.has_meta(&"roof"):
			out.roofs.append(kit.root.get_meta(&"roof"))
		if kit.root.has_meta(&"landmark"):
			var rf: Vector3 = kit.root.get_meta(&"roof")
			out.landmarks.append([kit.root.get_meta(&"landmark"), rf + Vector3(0, 12, 0)])
			out.tp.append(["Pagoda top", rf + Vector3(0, 0.4, 0), 0.0])
	# choke points: close one arm of the alley in checkerboard blocks
	if (c_idx + r_idx) % 2 == 0:
		var g := Kit.new(group, "AlleyGate_%s" % id)
		g.box(Vector3(c.x, 0.12, c.y - half + 1.0), Vector3(ALLEY - 0.4, 3.2, 0.5), Mats.toon(Color(0.2, 0.22, 0.26), 0.7), true)
		g.box(Vector3(c.x - 1.4, 0.12, c.y - half + 2.3), Vector3(1.9, 1.0, 1.0), Mats.toon(Color(0.16, 0.36, 0.25)), true)
	_district_flavour(group, id, c, district, slab)
	StaticBatch.merge(group)
	return out


static func _district_flavour(parent: Node, id: String, c: Vector2, district: String, slab: Kit) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(c.x * 7 + c.y * 13)
	var k := Kit.new(parent, "Flavour_%s" % id)
	var half := CityLayout.HALF
	if district == "chinatown":
		# lantern strings across the four bounding streets + across the alleys
		for t in range(-24, 25, 12):
			ChinatownProps.lantern_string(k, Vector3(c.x - half - 9.0, 8.5, c.y + t), Vector3(c.x - half, 8.5, c.y + t), rng)
			ChinatownProps.lantern_string(k, Vector3(c.x + half, 8.5, c.y + t), Vector3(c.x + half + 9.0, 8.5, c.y + t), rng)
			ChinatownProps.lantern_string(k, Vector3(c.x + t, 8.5, c.y - half - 9.0), Vector3(c.x + t, 8.5, c.y - half), rng)
			ChinatownProps.lantern_string(k, Vector3(c.x + t, 8.5, c.y + half), Vector3(c.x + t, 8.5, c.y + half + 9.0), rng)
		# street market down the middle of the western avenue
		for t in range(-26, 27, 13):
			Props.stall(k, Vector3(c.x - half - 9.0, 0.0, c.y + t), 90.0, Props.CAR_COLORS[rng.randi() % Props.CAR_COLORS.size()], rng)
	elif district == "market":
		for i in 10:
			var p := Vector3(c.x + rng.randf_range(-26.0, 26.0), 0.12, c.y + rng.randf_range(-26.0, 26.0))
			if absf(p.x - c.x) < 4.0 or absf(p.z - c.y) < 4.0:
				Props.stall(k, p, rng.randi_range(0, 3) * 90.0, BuildingFactory.AWNINGS[rng.randi() % BuildingFactory.AWNINGS.size()], rng)
		for t in range(-24, 25, 12):
			ChinatownProps.lantern_string(k, Vector3(c.x - half, 7.0, c.y + t), Vector3(c.x + half, 7.0, c.y + t), rng)
	# lamps along every block edge
	for t in range(-24, 25, 24):
		Props.lamp(k, Vector3(c.x + t, 0.12, c.y - half + 1.0), 180.0, 7.0)
		Props.lamp(k, Vector3(c.x + t, 0.12, c.y + half - 1.0), 0.0, 7.0)
		Props.lamp(k, Vector3(c.x - half + 1.0, 0.12, c.y + t), 90.0, 7.0)
		Props.lamp(k, Vector3(c.x + half - 1.0, 0.12, c.y + t), -90.0, 7.0)
	pass


## Open raised civic plaza that replaces one lot.
static func _plaza(parent: Node, r: Rect2) -> void:
	var k := Kit.new(parent, "Plaza")
	var stone := Mats.toon(Color(0.66, 0.62, 0.56), 0.4)
	var c := BuildingFactory.center(r)
	var plat := BuildingFactory.inset(r, 4.0)
	k.box(Vector3(c.x, 0.0, c.z), Vector3(plat.size.x, 3.6, plat.size.y), stone, true)
	k.stairs(Vector3(c.x, 0.0, plat.position.y), Vector3(0, 0, -1), 3.6, 7.0, 9.0, stone)
	k.stairs(Vector3(plat.end.x, 0.0, c.z), Vector3(1, 0, 0), 3.6, 7.0, 9.0, stone)
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
	k.box(Vector3(plat.position.x + 3.0, 3.6, plat.position.y + 3.0), Vector3(4.0, 3.0, 3.0), Mats.toon(Color(0.35, 0.4, 0.46)), true)
	k.label("CITY PLAZA", Vector3(c.x, 8.0, plat.position.y + 0.4), 1.4, Color(1.0, 0.95, 0.8), 180.0)
