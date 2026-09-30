class_name HighwayBuilder
extends RefCounted
## Elevated highway deck over the E-W street at z=0: on-ramp, barriers,
## graffiti-covered pillars, gantry sign and a gas station perched on the deck.
## The station's canopy roof is a third walkable level for showdowns.

const DECK_Y := 9.5
const DECK_T := 1.4
const HALF_W := 7.0
const X_START := -96.0
const X_END := 138.0
const RAMP_START := -138.0
const PILLARS := [-88.0, -70.0, -24.0, 0.0, 24.0, 70.0, 88.0, 110.0, 130.0]


static func build(parent: Node) -> Kit:
	var k := Kit.new(parent, "Highway")
	var concrete := Mats.toon(Color(0.42, 0.43, 0.47), 0.8)
	var dark := Mats.toon(Color(0.2, 0.21, 0.25), 0.8)
	var asphalt := Mats.road()
	var len := X_END - X_START
	# deck slab (asphalt top sits at DECK_Y)
	k.box(Vector3((X_START + X_END) * 0.5, DECK_Y - DECK_T, 0), Vector3(len, DECK_T, HALF_W * 2.0), concrete, true)
	k.box(Vector3((X_START + X_END) * 0.5, DECK_Y - 0.02, 0), Vector3(len, 0.04, HALF_W * 2.0 - 0.4), asphalt, false, Vector3.ZERO, false)
	# on-ramp from the west edge of the map
	k.ramp(Vector3(RAMP_START, 0.0, 0), Vector3(X_START, DECK_Y, 0), HALF_W * 2.0, DECK_T, concrete)
	# barriers
	for sz in [-HALF_W + 0.35, HALF_W - 0.35]:
		k.box(Vector3((X_START + X_END) * 0.5, DECK_Y, sz), Vector3(len, 1.05, 0.7), concrete, true)
		k.box(Vector3((X_START + X_END) * 0.5, DECK_Y + 1.05, sz), Vector3(len, 0.15, 0.4), dark, false)
	# pillars with graffiti
	var rng := RandomNumberGenerator.new()
	rng.seed = 4242
	for px in PILLARS:
		for sz in [-5.0, 5.0]:
			k.box(Vector3(px, 0.0, sz), Vector3(2.2, DECK_Y - DECK_T, 2.2), concrete, true)
			var pal := Props.random_palette(rng)
			var m := Mats.mural(pal[0], pal[1], pal[2], rng.randf() * 50.0, 1.0, 0.85)
			m.set_shader_parameter("graffiti", 1.0)
			k.mural_quad(Vector3(px, 2.6, sz + 1.12 * signf(sz)), Vector2(2.0, 3.4), 0.0 if sz > 0 else 180.0, m)
	# painted lanes
	var paint := RoadPaint.new(DECK_Y + 0.03)
	var x := X_START + 2.0
	while x < X_END - 2.0:
		paint.rect(x, -0.08, x + 3.0, 0.08, Color(1.0, 0.85, 0.2))
		paint.rect(x, -3.6, x + 3.0, -3.5, Color(0.9, 0.9, 0.92))
		paint.rect(x, 3.5, x + 3.0, 3.6, Color(0.9, 0.9, 0.92))
		x += 6.0
	paint.rect(X_START, -HALF_W + 0.9, X_END, -HALF_W + 1.0, Color(0.9, 0.9, 0.92))
	paint.rect(X_START, HALF_W - 1.0, X_END, HALF_W - 0.9, Color(0.9, 0.9, 0.92))
	paint.build(k.root)
	# deck lamps
	for lx in range(-80, 136, 22):
		Props.lamp(k, Vector3(lx, DECK_Y, HALF_W - 0.7), 180.0, 8.0, Color(1.0, 0.7, 0.4))
	_gantry(k, -52.0)
	_gas_station(k, 106.0, rng)
	return k


static func _gantry(k: Kit, x: float) -> void:
	var steel := Mats.toon(Color(0.2, 0.22, 0.27))
	for sz in [-HALF_W + 1.0, HALF_W - 1.0]:
		k.box(Vector3(x, DECK_Y, sz), Vector3(0.5, 7.5, 0.5), steel, false)
	k.box(Vector3(x, DECK_Y + 7.0, 0), Vector3(0.6, 0.5, HALF_W * 2.0 - 1.0), steel, false)
	var sign_mat := Mats.paint(Color(0.05, 0.4, 0.25))
	k.box(Vector3(x, DECK_Y + 4.2, 0), Vector3(0.25, 2.8, 9.0), sign_mat, false)
	k.label("DOWNTOWN  >>  12 km", Vector3(x - 0.16, DECK_Y + 5.6, 0), 0.9, Color(1, 1, 1), -90.0)
	k.label("HANGANG BRIDGE  >>", Vector3(x - 0.16, DECK_Y + 4.7, 0), 0.7, Color(1, 1, 1), -90.0)


static func _gas_station(k: Kit, x: float, rng: RandomNumberGenerator) -> void:
	var g := k.sub("GasStation", Vector3(x, DECK_Y, 0))
	var white := Mats.toon(Color(0.9, 0.9, 0.92))
	var red := Mats.toon(Color(0.85, 0.15, 0.2))
	# canopy slab is a walkable roof (level 4)
	g.box(Vector3(0, 5.0, 0), Vector3(22.0, 0.5, HALF_W * 2.0 - 0.6), white, true)
	g.box(Vector3(0, 5.5, 0), Vector3(22.2, 0.5, 0.4 + HALF_W * 2.0 - 0.6), red, false)
	g.box(Vector3(0, 4.85, 0), Vector3(21.0, 0.1, HALF_W * 2.0 - 1.4), Mats.glow(Color(1.0, 0.95, 0.85), 3.0), false, Vector3.ZERO, false)
	for sx in [-9.5, 9.5]:
		for sz in [-HALF_W + 1.2, HALF_W - 1.2]:
			g.box(Vector3(sx, 0.0, sz), Vector3(0.6, 5.0, 0.6), white, true)
	# pump islands
	for sx in [-4.0, 4.0]:
		g.box(Vector3(sx, 0.0, 0), Vector3(3.6, 0.25, 1.2), Mats.toon(Color(0.45, 0.45, 0.5)), false)
		g.box(Vector3(sx - 1.0, 0.25, 0), Vector3(0.6, 1.5, 0.5), red, true)
		g.box(Vector3(sx + 1.0, 0.25, 0), Vector3(0.6, 1.5, 0.5), red, true)
		g.box(Vector3(sx - 1.0, 1.45, 0.26), Vector3(0.4, 0.3, 0.02), Mats.glow(Color(0.5, 1.0, 0.7), 3.0), false, Vector3.ZERO, false)
		g.box(Vector3(sx + 1.0, 1.45, 0.26), Vector3(0.4, 0.3, 0.02), Mats.glow(Color(0.5, 1.0, 0.7), 3.0), false, Vector3.ZERO, false)
	# shop kiosk beyond the canopy
	g.box(Vector3(15.5, 0.0, -3.0), Vector3(6.0, 3.4, 4.5), Mats.toon(Color(0.8, 0.78, 0.7), 0.4), true)
	g.box(Vector3(15.5, 2.3, -0.7), Vector3(5.6, 0.9, 0.1), Mats.glow(Color(1.0, 0.9, 0.5), 3.0), false, Vector3.ZERO, false)
	g.label("24H  SHELL-24", Vector3(15.5, 6.3, 0), 1.6, Color(1.0, 0.85, 0.3), 0.0)
	g.box(Vector3(15.5, 3.4, -3.0), Vector3(6.4, 0.3, 4.9), red, false)
	# price pylon
	g.box(Vector3(-14.5, 0.0, HALF_W - 1.5), Vector3(0.5, 9.0, 0.5), Mats.toon(Color(0.2, 0.2, 0.25)), false)
	g.box(Vector3(-14.5, 6.5, HALF_W - 1.5), Vector3(0.6, 3.0, 2.2), Mats.glow(Color(1.0, 0.75, 0.2), 3.0), false, Vector3.ZERO, false)
