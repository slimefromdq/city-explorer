class_name HighwayBuilder
extends RefCounted
## Layered infrastructure: an elevated E-W highway deck (9.5 m) with a gas
## station perched on it, a higher N-S flyover (19 m) crossing over it, ramps,
## graffiti-covered pillars and a lane-sign gantry. Decks are authored in a
## local frame (deck runs along +X) so the same code builds both roads.

const DECK_T := 1.4
const HALF_W := 7.0


## E-W highway along the street at z=41. Returns landmarks/teleports.
static func build_highway(parent: Node) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": []}
	var z := 41.0
	var y := 9.5
	var k := Kit.new(parent, "Highway", Vector3(0, 0, z))
	var x0 := -CityLayout.PLAY_X + 47.0
	var x1 := CityLayout.PLAY_X - 4.0
	_deck(k, x0, x1, y, -CityLayout.PLAY_X, true, CityLayout.avenues_x())
	_gantry(k, -175.0, y)
	_gas_station(k, -86.0, y)
	info.landmarks.append(["Gas Station", Vector3(-86.0, y + 6.0, z)])
	info.tp.append(["Highway deck", Vector3(-200.0, y + 0.4, z), -PI * 0.5])
	info.tp.append(["Gas station roof", Vector3(-86.0, y + 5.5 + 0.6, z), PI * 0.5])
	info.shards.append(Vector3(-86.0, y + 6.6, z))
	info.shards.append(Vector3(30.0, y + 1.4, z))
	StaticBatch.merge(k.root)
	return info


## N-S flyover along the avenue at x=205, crossing above the highway.
static func build_flyover(parent: Node) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": []}
	var y := 19.0
	var k := Kit.new(parent, "Flyover", Vector3(205.0, 0, 0), -90.0)
	var half := CityLayout.PLAY_Z - 4.0
	var streets: Array = CityLayout.streets_z()
	# deck spans world z -130..50 (over the highway at z=41); it ramps down both ends.
	# The south ramp lands before the rail ramp at z=123 so the rail crosses OVER it.
	_deck(k, -half + 80.0, 50.0, y, -half, false, [], true, [streets, 41.0])
	var conc := Mats.toon(Color(0.42, 0.43, 0.47), 0.8)
	k.ramp(Vector3(-half, 0.0, 0.0), Vector3(-half + 80.0, y, 0.0), HALF_W * 2.0, DECK_T, conc)
	k.ramp(Vector3(130.0, 0.0, 0.0), Vector3(50.0, y, 0.0), HALF_W * 2.0, DECK_T, conc)
	info.tp.append(["Flyover", Vector3(205.0, y + 0.4, 0.0), 0.0])
	info.shards.append(Vector3(205.0, y + 1.4, 41.0))
	info.landmarks.append(["Flyover", Vector3(205.0, y + 3.0, -60.0)])
	StaticBatch.merge(k.root)
	return info


static func _deck(k: Kit, x0: float, x1: float, y: float, ramp_x: float, with_ramp: bool, avenues: Array, flyover := false, cross: Array = []) -> void:
	var concrete := Mats.toon(Color(0.42, 0.43, 0.47), 0.8)
	var dark := Mats.toon(Color(0.2, 0.21, 0.25), 0.8)
	var asphalt := Mats.road()
	var len := x1 - x0
	var mid := (x0 + x1) * 0.5
	k.box(Vector3(mid, y - DECK_T, 0), Vector3(len, DECK_T, HALF_W * 2.0), concrete, true)
	k.box(Vector3(mid, y - 0.02, 0), Vector3(len, 0.04, HALF_W * 2.0 - 0.4), asphalt, false, Vector3.ZERO, false)
	if with_ramp:
		k.ramp(Vector3(ramp_x, 0.0, 0), Vector3(x0, y, 0), HALF_W * 2.0, DECK_T, concrete)
	for sz in [-HALF_W + 0.35, HALF_W - 0.35]:
		k.box(Vector3(mid, y, sz), Vector3(len, 1.05, 0.7), concrete, true)
		k.box(Vector3(mid, y + 1.05, sz), Vector3(len, 0.15, 0.4), dark, false)
	# graffiti fascia on both edges + pillars
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242 + int(y)
	var gx := x0 + 6.0
	while gx < x1 - 6.0:
		if rng.randf() < 0.6:
			var pal := Props.random_palette(rng)
			var m := Mats.mural(pal[0], pal[1], pal[2], rng.randf() * 50.0, 6.0, 0.8)
			m.set_shader_parameter("graffiti", 1.0)
			var s := -1.0 if rng.randf() < 0.5 else 1.0
			k.mural_quad(Vector3(gx, y - 0.75, s * (HALF_W + 0.03)), Vector2(rng.randf_range(6.0, 12.0), 1.3), 0.0 if s > 0.0 else 180.0, m)
		gx += 14.0
	var px := x0 + 10.0
	while px < x1 - 10.0:
		var skip := false
		for a in avenues:
			if absf(px - a) < 11.0:
				skip = true
		if flyover:
			# skip pillars inside intersections and right over the highway underneath
			for sz: float in cross[0]:
				if absf(px - sz) < 11.0:
					skip = true
			if absf(px - (cross[1] as float)) < 12.0:
				skip = true
		if not skip:
			for sz: float in [-5.0, 5.0]:
				k.box(Vector3(px, 0.0, sz), Vector3(2.2, y - DECK_T, 2.2), concrete, true)
				if rng.randf() < 0.7:
					var pal2 := Props.random_palette(rng)
					var m2 := Mats.mural(pal2[0], pal2[1], pal2[2], rng.randf() * 50.0, 1.0, 0.85)
					m2.set_shader_parameter("graffiti", 1.0)
					var face := 1.0 if rng.randf() < 0.5 else -1.0
					k.mural_quad(Vector3(px + face * 1.12, minf(3.0, y * 0.35), sz), Vector2(2.0, 3.4), 90.0 * face, m2)
		px += 24.0
	# painted lanes
	var paint := RoadPaint.new(y + 0.03)
	var lx := x0 + 2.0
	while lx < x1 - 2.0:
		paint.rect(lx, -0.08, lx + 3.0, 0.08, Color(1.0, 0.85, 0.2))
		paint.rect(lx, -3.6, lx + 3.0, -3.5, Color(0.9, 0.9, 0.92))
		paint.rect(lx, 3.5, lx + 3.0, 3.6, Color(0.9, 0.9, 0.92))
		lx += 6.0
	paint.rect(x0, -HALF_W + 0.9, x1, -HALF_W + 1.0, Color(0.9, 0.9, 0.92))
	paint.rect(x0, HALF_W - 1.0, x1, HALF_W - 0.9, Color(0.9, 0.9, 0.92))
	paint.build(k.root)
	var lamp_x := x0 + 12.0
	while lamp_x < x1 - 8.0:
		Props.lamp(k, Vector3(lamp_x, y, HALF_W - 0.7), 180.0, 8.0, Color(1.0, 0.7, 0.4))
		lamp_x += 24.0


static func _gantry(k: Kit, x: float, y: float) -> void:
	var steel := Mats.toon(Color(0.2, 0.22, 0.27))
	for sz in [-HALF_W + 1.0, HALF_W - 1.0]:
		k.box(Vector3(x, y, sz), Vector3(0.5, 7.5, 0.5), steel, false)
	k.box(Vector3(x, y + 7.0, 0), Vector3(0.6, 0.5, HALF_W * 2.0 - 1.0), steel, false)
	k.box(Vector3(x, y + 4.2, 0), Vector3(0.25, 2.8, 9.0), Mats.paint(Color(0.05, 0.4, 0.25)), false)
	k.label("DOWNTOWN  >>  12 km", Vector3(x - 0.16, y + 5.6, 0), 0.9, Color(1, 1, 1), -90.0)
	k.label("HANGANG BRIDGE  >>", Vector3(x - 0.16, y + 4.7, 0), 0.7, Color(1, 1, 1), -90.0)
	# lane-arrow sign on a second gantry
	var x2 := x + 60.0
	for sz in [-HALF_W + 1.0, HALF_W - 1.0]:
		k.box(Vector3(x2, y, sz), Vector3(0.4, 7.0, 0.4), steel, false)
	k.box(Vector3(x2, y + 5.0, 0), Vector3(0.25, 2.4, 6.4), Mats.paint(Color(0.95, 0.95, 0.95)), false)
	k.label("<  ONLY    ^  ONLY    >  ONLY", Vector3(x2 - 0.16, y + 6.0, 0), 0.55, Color(0.05, 0.05, 0.05), -90.0)


static func _gas_station(k: Kit, x: float, y: float) -> void:
	var g := k.sub("GasStation", Vector3(x, y, 0))
	var white := Mats.toon(Color(0.9, 0.9, 0.92))
	var red := Mats.toon(Color(0.85, 0.12, 0.16))
	var neon_red := Mats.glow(Color(1.0, 0.12, 0.14), 5.0)
	# big red canopy that overhangs the deck: also a walkable roof (level 4)
	g.box(Vector3(0, 5.0, 0), Vector3(26.0, 0.6, HALF_W * 2.0 + 3.0), red, true)
	g.box(Vector3(0, 5.6, 0), Vector3(26.4, 0.9, HALF_W * 2.0 + 3.4), Mats.toon(Color(0.1, 0.1, 0.12)), false)
	g.box(Vector3(0, 4.85, 0), Vector3(25.0, 0.1, HALF_W * 2.0 - 0.6), Mats.glow(Color(1.0, 0.95, 0.85), 3.0), false, Vector3.ZERO, false)
	for sx: float in [-11.5, 11.5]:
		for sz in [-HALF_W + 1.0, HALF_W - 1.0]:
			g.box(Vector3(sx, 0.0, sz), Vector3(0.7, 5.0, 0.7), white, true)
	# huge lit lettering along the canopy fascia, both sides
	g.label("NOVA  GAS", Vector3(0, 6.2, HALF_W + 1.85), 3.2, Color(1.0, 0.25, 0.25), 0.0)
	g.label("NOVA  GAS", Vector3(0, 6.2, -HALF_W - 1.85), 3.2, Color(1.0, 0.25, 0.25), 180.0)
	g.box(Vector3(0, 6.9, HALF_W + 1.7), Vector3(22.0, 0.15, 0.15), neon_red, false, Vector3.ZERO, false)
	# pump islands
	for sx: float in [-5.0, 5.0]:
		g.box(Vector3(sx, 0.0, 0), Vector3(4.4, 0.25, 1.4), Mats.toon(Color(0.45, 0.45, 0.5)), false)
		for px: float in [-1.3, 1.3]:
			g.box(Vector3(sx + px, 0.25, 0), Vector3(0.7, 1.6, 0.55), red, true)
			g.box(Vector3(sx + px, 1.5, 0.29), Vector3(0.45, 0.35, 0.02), Mats.glow(Color(0.5, 1.0, 0.7), 3.0), false, Vector3.ZERO, false)
	# graffiti-covered kiosk with stacked signs
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	g.box(Vector3(13.6, 0.0, -2.2), Vector3(7.0, 3.6, 5.0), Mats.toon(Color(0.86, 0.84, 0.78), 0.5), true)
	for i in 3:
		var pal := Props.random_palette(rng)
		var m := Mats.mural(pal[0], pal[1], pal[2], rng.randf() * 30.0, 1.4, 1.0)
		m.set_shader_parameter("graffiti", 1.0)
		g.mural_quad(Vector3(13.6 - 2.2 + i * 2.2, 1.9, 0.31), Vector2(2.0, 3.0), 0.0, m)
	g.box(Vector3(13.6, 3.6, -2.2), Vector3(7.4, 0.35, 5.4), red, false)
	g.label("24H  SNACKS", Vector3(13.6, 4.6, 0.6), 0.8, Color(1.0, 0.9, 0.4), 0.0)
	# price pylon: stacked red digits
	g.box(Vector3(-15.5, 0.0, HALF_W - 1.4), Vector3(0.5, 10.0, 0.5), Mats.toon(Color(0.2, 0.2, 0.25)), false)
	g.box(Vector3(-15.5, 6.0, HALF_W - 1.4), Vector3(0.7, 4.2, 2.6), Mats.toon(Color(0.12, 0.12, 0.14)), false)
	g.label("1.45\n1.37\n1.26", Vector3(-15.2, 8.0, HALF_W - 1.4), 0.9, Color(1.0, 0.2, 0.2), 90.0)
	# sagging cables from the canopy to the deck edge
	for i in 4:
		var cx := -9.0 + i * 6.0
		g.box(Vector3(cx, 1.6, HALF_W + 1.2), Vector3(0.05, 3.6, 0.05), Mats.toon(Color(0.05, 0.05, 0.06)), false, Vector3(18, 0, 0))
	Props.car(g, Vector3(-2.0, 0.0, 4.0), 90.0, Color(0.2, 0.6, 0.5))
