class_name ShipBuilder
extends RefCounted
## MV Aurora, a 130 m ship berthed on the south face of the T-pier. Built from
## solid boxes so every deck you see is a deck you can stand on:
##   main deck (y=4.5)  - reached by two gangways from the pier, or by the
##                        boarding stair from the river shallows
##   forecastle (7.7)   - ramp up from the main deck
##   accommodation roof (17.3) - fire-escape flights up the bow-facing side
##   bridge roof (20.5) - short ramp from the accommodation roof
## Container stacks and deck cranes are cover; bulwarks keep you from tumbling
## off by accident (and are open exactly at gangways and the boarding stair).

const X0 := -65.0
const X1 := 45.0
const CZ := 361.5
const HB := 12.0          # half beam
const DECK := 4.5
const KEEL := -2.7


static func build(k: Kit, info: Dictionary) -> void:
	var navy := Mats.toon(Color(0.1, 0.15, 0.3), 0.4)
	var red := Mats.toon(Color(0.62, 0.12, 0.1), 0.4)
	var deckm := Mats.toon(Color(0.44, 0.46, 0.5), 0.5)
	var white := Mats.toon(Color(0.9, 0.9, 0.93), 0.2)
	var steel := Mats.toon(Color(0.2, 0.22, 0.28), 0.4)
	var conc := Mats.toon(Color(0.42, 0.44, 0.5), 0.8)
	var glowm := Mats.glow(Color(1.0, 0.86, 0.55), 3.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 909

	# ---- hull: red antifouling below the waterline, navy above; stepped bow
	var hull_len := X1 - X0
	k.box(Vector3((X0 + X1) * 0.5, KEEL, CZ), Vector3(hull_len, 2.1, HB * 2.0), red, true)
	k.box(Vector3((X0 + X1) * 0.5, KEEL + 2.1, CZ), Vector3(hull_len, DECK - KEEL - 2.1, HB * 2.0), navy, true)
	for step in [[X1, 9.0, 20.0], [X1 + 9.0, 6.0, 12.0], [X1 + 15.0, 3.0, 5.0]]:
		var bx: float = step[0]
		var bl: float = step[1]
		var bw: float = step[2]
		k.box(Vector3(bx + bl * 0.5, KEEL, CZ), Vector3(bl, 2.1, bw), red, true)
		k.box(Vector3(bx + bl * 0.5, KEEL + 2.1, CZ), Vector3(bl, DECK - KEEL - 2.1, bw), navy, true)
	k.label("MV AURORA", Vector3(0.0, 1.6, CZ + HB + 0.12), 3.0, Color(1, 1, 1), 0.0)
	k.label("MV AURORA", Vector3(0.0, 1.6, CZ - HB - 0.12), 3.0, Color(1, 1, 1), 180.0)
	# deck plating + painted walkway lines (visual)
	var paint := RoadPaint.new(DECK + 0.03)
	paint.rect(X0 + 1.0, CZ - 4.6, X1 - 1.0, CZ - 4.4, Color(1.0, 0.85, 0.2))
	paint.rect(X0 + 1.0, CZ + 4.4, X1 - 1.0, CZ + 4.6, Color(1.0, 0.85, 0.2))
	paint.build(k.root)
	k.box(Vector3((X0 + X1) * 0.5, DECK, CZ), Vector3(hull_len - 0.4, 0.04, HB * 2.0 - 0.4), deckm, false, Vector3.ZERO, false)

	# ---- bulwarks (open at the gangways and the boarding stair)
	var bw_z_dock := CZ - HB + 0.15
	var bw_z_river := CZ + HB - 0.15
	_rail_x(k, navy, bw_z_dock, X0, X1, [[-32.2, -27.8], [27.8, 32.2]])
	_rail_x(k, navy, bw_z_river, X0, X1, [[-38.0, -34.0]])
	k.box(Vector3(X0 + 0.15, DECK, CZ), Vector3(0.3, 1.1, HB * 2.0), navy, true)
	# bow bulwarks follow the steps
	for step in [[X1, 9.0, 20.0], [X1 + 9.0, 6.0, 12.0], [X1 + 15.0, 3.0, 5.0]]:
		for sgn: float in [-1.0, 1.0]:
			k.box(Vector3(step[0] + step[1] * 0.5, DECK, CZ + sgn * (step[2] * 0.5 - 0.15)), Vector3(step[1], 1.1, 0.3), navy, true)
	k.box(Vector3(X1 + 18.0 - 0.15, DECK, CZ), Vector3(0.3, 1.1, 5.0), navy, true)

	# ---- gangways from the pier (two) - ramp on the pier deck, landing over the gap, onto the hull deck
	for gx: float in [-30.0, 30.0]:
		k.ramp(Vector3(gx, 0.0, 337.5), Vector3(gx, DECK, 346.6), 3.0, 0.4, steel)
		k.box(Vector3(gx, DECK - 0.5, 348.2), Vector3(3.0, 0.5, 3.2), steel, true)
		k.box(Vector3(gx, KEEL, 348.2), Vector3(3.0, DECK - 0.5 - KEEL, 3.2), conc, true)
		for sgn: float in [-1.0, 1.0]:
			k.ramp(Vector3(gx + sgn * 1.45, 1.0, 337.5), Vector3(gx + sgn * 1.45, DECK + 1.0, 346.6), 0.08, 0.06, steel, false)
			k.box(Vector3(gx + sgn * 1.45, DECK, 348.2), Vector3(0.08, 1.0, 3.2), steel, false)
		k.label("GANGWAY", Vector3(gx, 6.6, 347.9), 0.5, Color(1.0, 0.9, 0.3), 180.0)
	# boarding stair from the shallows on the river side
	k.ramp(Vector3(-52.0, KEEL, CZ + HB + 2.0), Vector3(-38.0, DECK, CZ + HB + 2.0), 2.4, DECK - KEEL + 0.4, steel)
	k.box(Vector3(-36.0, KEEL, CZ + HB + 1.8), Vector3(4.0, DECK - KEEL, 3.6), conc, true)

	# ---- accommodation block at the stern, with fire-escape flights to its roof
	var acc := Vector3(-51.0, DECK, CZ)
	k.box(acc, Vector3(22.0, 12.6, 19.0), white, true)
	k.box(acc + Vector3(0.0, 12.3, 0.0), Vector3(22.6, 0.3, 19.6), steel, false)
	for fl in 4:
		k.box(acc + Vector3(11.05, 1.6 + fl * 3.2, 0.0), Vector3(0.1, 1.2, 15.0), glowm, false, Vector3.ZERO, false)
		k.box(acc + Vector3(-11.05, 1.6 + fl * 3.2, 0.0), Vector3(0.1, 1.2, 15.0), glowm, false, Vector3.ZERO, false)
	# fire escape on the bow-facing side (yaw 90: local +Z -> +X)
	Props.fire_escape(k, Vector3(-40.0, DECK, CZ + 5.0), 90.0, 16.0)
	# bridge cabin above, reached by a ramp along the roof
	var roof_y := DECK + 12.6
	k.box(Vector3(-56.0, roof_y, CZ), Vector3(9.0, 3.2, 14.0), white, true)
	k.box(Vector3(-56.0, roof_y + 3.2, CZ), Vector3(10.0, 0.3, 15.0), steel, true)
	k.box(Vector3(-51.4, roof_y + 1.6, CZ), Vector3(0.12, 1.1, 12.0), glowm, false, Vector3.ZERO, false)
	k.ramp(Vector3(-44.0, roof_y, CZ - 3.0), Vector3(-51.5, roof_y + 3.5, CZ - 3.0), 2.4, 3.8, steel)
	# funnel + mast
	k.cyl(Vector3(-44.0, roof_y, CZ + 4.5), 1.9, 7.0, Mats.toon(Color(0.85, 0.2, 0.15)), true, 16)
	k.cyl(Vector3(-44.0, roof_y + 6.0, CZ + 4.5), 2.0, 1.0, Mats.toon(Color(0.1, 0.1, 0.12)), false, 16)
	k.cyl(Vector3(-56.0, roof_y + 3.5, CZ), 0.25, 9.0, steel, false, 8)
	k.sphere(Vector3(-56.0, roof_y + 12.8, CZ), 0.4, Mats.glow(Color(1.0, 0.15, 0.15), 6.0))

	# ---- cargo: container stacks in two rows either side of the central aisle
	var cols := [Color(0.75, 0.2, 0.18), Color(0.2, 0.4, 0.7), Color(0.85, 0.65, 0.15), Color(0.2, 0.55, 0.4), Color(0.8, 0.8, 0.82), Color(0.9, 0.4, 0.15)]
	var bay := 0
	var bx := -34.0
	while bx < 26.0:
		for sgn: float in [-1.0, 1.0]:
			var n := 1 + (bay + int(sgn > 0.0) * 2) % 3
			var color: Color = cols[rng.randi() % cols.size()]
			for lv in n:
				k.box(Vector3(bx + 6.0, DECK + lv * 2.6, CZ + sgn * 7.6), Vector3(12.0, 2.6, 2.4), Mats.toon(color if lv % 2 == 0 else color.lightened(0.12), 0.4), true)
			if bay % 2 == 0 and sgn > 0.0:
				info.shards.append(Vector3(bx + 6.0, DECK + n * 2.6 + 1.4, CZ + 7.6))
		bx += 12.6
		bay += 1
	# hatch covers along the aisle and two deck cranes as cover
	for hx: float in [-30.0, -8.0, 14.0]:
		k.box(Vector3(hx, DECK, CZ), Vector3(9.0, 0.7, 5.0), Mats.toon(Color(0.3, 0.32, 0.36)), true)
	for cxp: float in [-19.0, 3.0]:
		k.box(Vector3(cxp, DECK, CZ - 2.6), Vector3(2.2, 8.5, 2.2), Mats.toon(Color(0.85, 0.72, 0.15)), true)
		k.box(Vector3(cxp + 5.0, DECK + 8.5, CZ - 2.6), Vector3(12.0, 0.6, 1.0), Mats.toon(Color(0.85, 0.72, 0.15)), false, Vector3(0, 0, 12))
	# ---- forecastle
	k.box(Vector3(43.0, DECK, CZ), Vector3(11.0, 3.2, 17.0), deckm, true)
	k.box(Vector3(43.0, DECK + 3.2, CZ), Vector3(11.0, 0.05, 17.0), Mats.toon(Color(0.4, 0.42, 0.46)), false, Vector3.ZERO, false)
	k.ramp(Vector3(32.5, DECK, CZ), Vector3(37.5, DECK + 3.2, CZ), 3.0, 3.6, deckm)
	k.box(Vector3(51.5, DECK, CZ), Vector3(6.0, 3.2, 9.0), deckm, true)
	k.cyl(Vector3(47.0, DECK + 3.2, CZ), 0.9, 1.4, steel, true, 12)
	k.cyl(Vector3(58.5, DECK, CZ), 0.25, 8.0, steel, false, 8)
	k.sphere(Vector3(58.5, DECK + 8.2, CZ), 0.35, Mats.glow(Color(0.2, 1.0, 0.4), 5.0))
	# ---- lighting: deck lamps + string lights
	for lx: float in [-30.0, -5.0, 20.0]:
		for sgn: float in [-1.0, 1.0]:
			k.cyl(Vector3(lx, DECK, CZ + sgn * (HB - 0.6)), 0.08, 3.4, steel, false, 6)
			k.sphere(Vector3(lx, DECK + 3.5, CZ + sgn * (HB - 0.6)), 0.3, glowm)
	for sgn: float in [-1.0, 1.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(-10.0 + sgn * 25.0, DECK + 6.0, CZ)
		l.omni_range = 34.0
		l.light_energy = 1.4
		l.light_color = Color(1.0, 0.8, 0.5)
		l.shadow_enabled = false
		k.root.add_child(l)

	info.landmarks.append(["MV Aurora", Vector3(-52.0, 30.0, CZ)])
	info.tp.append(["Ship deck", Vector3(6.0, DECK + 0.4, CZ), PI * 0.5])
	info.tp.append(["Ship bridge roof", Vector3(-56.0, roof_y + 3.5 + 0.4, CZ), 0.0])
	info.tp.append(["Ship forecastle", Vector3(43.0, DECK + 3.6, CZ), 0.0])
	info.shards.append(Vector3(-56.0, roof_y + 4.9, CZ))
	info.shards.append(Vector3(43.0, DECK + 4.8, CZ))


static func _rail_x(k: Kit, mat: Material, z: float, x0: float, x1: float, gaps: Array) -> void:
	var edges: Array = [x0]
	for g in gaps:
		edges.append(g[0])
		edges.append(g[1])
	edges.append(x1)
	var i := 0
	while i < edges.size():
		var a: float = edges[i]
		var b: float = edges[i + 1]
		if b - a > 0.2:
			k.box(Vector3((a + b) * 0.5, DECK, z), Vector3(b - a, 1.1, 0.3), mat, true)
		i += 2
