class_name RailBuilder
extends RefCounted
## The city rail LOOP. One closed track that:
##   station east track (southbound) -> south junction chamber -> east tunnel ->
##   open-cut trench (climbing) -> ramp up the east side of the street -> viaduct
##   (26 m) round the whole map edge -> west ramp down -> west trench -> west
##   tunnel -> south junction -> station west track (northbound) -> north
##   turn-back U-loop -> east track again.
## The track is authored as ONE polyline; geometry (viaduct, embankment, trench,
## rails, sleepers, pillars) is derived from it, so train and structure can
## never disagree.

const RAIL_Y := 26.0
const WIDTH := 9.0
const TRACK_X := 7.5
const ROW_Z := 123.0
const EDGE_X := 287.0
const NORTH_Z := -123.0
const U_Z := 44.0
const DECK_MIN := 4.2
const TRENCH_W := 10.0
const TRENCH_X0 := 52.0
const TRENCH_X1 := 100.0
const UNDER_Y := -9.0
const PAD := 12.0        # flat, street-level stretch at the foot of each ramp so you can walk on and off the line
const PAD_Y := 0.05


static func trench_holes() -> Array:
	return [
		Rect2(TRENCH_X0, ROW_Z - TRENCH_W * 0.5, TRENCH_X1 - TRENCH_X0, TRENCH_W),
		Rect2(-TRENCH_X1, ROW_Z - TRENCH_W * 0.5, TRENCH_X1 - TRENCH_X0, TRENCH_W),
	]


## Closed loop, one point per vertex (last connects back to first).
static func loop_points() -> PackedVector3Array:
	var nodes := [
		[TRACK_X, UNDER_Y, U_Z, 0.0],
		[TRACK_X, UNDER_Y, ROW_Z, 14.0],
		[TRENCH_X0, UNDER_Y, ROW_Z, 0.0],
		[TRENCH_X1, PAD_Y, ROW_Z, 0.0],
		[TRENCH_X1 + PAD, PAD_Y, ROW_Z, 0.0],
		[EDGE_X - 25.0, RAIL_Y, ROW_Z, 0.0],
		[EDGE_X, RAIL_Y, ROW_Z, 20.0],
		[EDGE_X, RAIL_Y, NORTH_Z, 20.0],
		[-EDGE_X, RAIL_Y, NORTH_Z, 20.0],
		[-EDGE_X, RAIL_Y, ROW_Z, 20.0],
		[-(EDGE_X - 25.0), RAIL_Y, ROW_Z, 0.0],
		[-(TRENCH_X1 + PAD), PAD_Y, ROW_Z, 0.0],
		[-TRENCH_X1, PAD_Y, ROW_Z, 0.0],
		[-TRENCH_X0, UNDER_Y, ROW_Z, 0.0],
		[-TRACK_X, UNDER_Y, ROW_Z, 14.0],
		[-TRACK_X, UNDER_Y, U_Z, 0.0],
	]
	var out := PackedVector3Array()
	for i in nodes.size():
		var n: Array = nodes[i]
		var p := Vector3(n[0], n[1], n[2])
		var r: float = n[3]
		if r <= 0.0:
			out.append(p)
			continue
		var prev: Array = nodes[(i - 1 + nodes.size()) % nodes.size()]
		var next: Array = nodes[(i + 1) % nodes.size()]
		var a := (Vector3(prev[0], p.y, prev[2]) - p).normalized()
		var b := (Vector3(next[0], p.y, next[2]) - p).normalized()
		var t1 := p + a * r
		var t2 := p + b * r
		for s in 13:
			var u := float(s) / 12.0
			out.append(t1.lerp(p, u).lerp(p.lerp(t2, u), u))
	# turn-back U-loop at the north end of the station: west track -> east track
	for s in range(1, 12):
		var ang := PI * float(s) / 12.0
		out.append(Vector3(-TRACK_X * cos(ang), UNDER_Y, U_Z - TRACK_X * sin(ang)))
	return out


static func densify(pts: PackedVector3Array, max_len: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var n := pts.size()
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var steps := maxi(1, int(ceil(a.distance_to(b) / max_len)))
		for s in steps:
			out.append(a.lerp(b, float(s) / float(steps)))
	return out


static func _in_intersection(p: Vector2) -> bool:
	var on_ave := false
	for ax in CityLayout.avenues_x():
		if absf(p.x - ax) < 11.0:
			on_ave = true
	var on_st := false
	for sz in CityLayout.streets_z():
		if absf(p.y - sz) < 11.0:
			on_st = true
	return on_ave and on_st


## Where a pillar would land in an intersection or on the highway deck.
static func _blocked(p: Vector2) -> bool:
	return absf(p.y - 41.0) < 11.0 or _in_intersection(p)


static func build(parent: Node) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": [], "loop": loop_points()}
	var k := Kit.new(parent, "RailLoop")
	var concrete := Mats.toon(Color(0.35, 0.36, 0.42), 0.7)
	var dark := Mats.toon(Color(0.16, 0.17, 0.2), 0.6)
	var steel := Mats.toon(Color(0.55, 0.56, 0.6))
	var sleeper := Mats.toon(Color(0.25, 0.2, 0.17))
	var pts := densify(info.loop, 6.0)
	var n := pts.size()
	var acc := 0.0
	var pillar_acc := 20.0
	var lamp_acc := 0.0
	var warn_done := [false, false]
	for i in n:
		var a := pts[i]
		var b := pts[(i + 1) % n]
		var d := b - a
		var L := d.length()
		if L < 0.05:
			continue
		var dir := d / L
		var mid := (a + b) * 0.5
		var flat := Vector3(dir.x, 0.0, dir.z).normalized()
		var side := Vector3(-flat.z, 0.0, flat.x)
		var a2 := a - dir * 0.25
		var b2 := b + dir * 0.25
		var y_avg := mid.y
		var in_trench := false
		for h: Rect2 in trench_holes():
			if h.grow(1.0).has_point(Vector2(mid.x, mid.z)):
				in_trench = true
		var kind := "tunnel"
		if y_avg >= DECK_MIN:
			kind = "viaduct"
		elif y_avg >= -0.3:
			kind = "embankment"
		elif in_trench:
			kind = "trench"
		match kind:
			"viaduct":
				k.ramp(a2, b2, WIDTH, 1.6, concrete)
			"embankment":
				k.ramp(a2, b2, WIDTH, maxf(a.y, b.y) + 2.0, concrete)
			"trench":
				k.ramp(a2, b2, TRENCH_W, 1.0, concrete)
				for sz: float in [-1.0, 1.0]:
					k.box(Vector3(mid.x, -10.0, ROW_Z + sz * (TRENCH_W * 0.5 + 0.3)), Vector3(L + 0.3, 11.0, 0.6), concrete, true)
		if kind == "viaduct" or (kind == "embankment" and y_avg >= 1.0):
			for sgn: float in [-1.0, 1.0]:
				var off := side * (WIDTH * 0.5 - 0.3) * sgn + Vector3.UP * 1.1
				k.ramp(a2 + off, b2 + off, 0.6, 1.1, concrete)
		if kind == "viaduct":
			pillar_acc += L
			lamp_acc += L
			if pillar_acc >= 30.0 and not _blocked(Vector2(mid.x, mid.z)):
				pillar_acc = 0.0
				k.box(Vector3(mid.x, 0.0, mid.z), Vector3(2.6, mid.y - 1.6, 2.6), concrete, true)
				k.box(Vector3(mid.x, mid.y - 4.6, mid.z), Vector3(WIDTH - 1.0, 0.8, 3.4), concrete, false, Vector3(0, rad_to_deg(atan2(-flat.z, flat.x)), 0))
			if lamp_acc >= 24.0:
				lamp_acc = 0.0
				var lp := mid + side * (WIDTH * 0.5 - 0.6)
				k.box(Vector3(lp.x, mid.y, lp.z), Vector3(0.2, 5.0, 0.2), dark, false)
				k.box(Vector3(lp.x, mid.y + 5.0, lp.z), Vector3(0.6, 0.3, 0.6), Mats.glow(Color(1.0, 0.85, 0.5), 4.0), false, Vector3.ZERO, false)
		# rails and sleepers along the whole loop (also through the station and tunnels)
		for sgn: float in [-1.0, 1.0]:
			var ro := side * 0.9 * sgn + Vector3.UP * 0.02
			k.ramp(a2 + ro, b2 + ro, 0.14, 0.12, steel, false)
		acc += L
		if int(acc / 2.0) != int((acc - L) / 2.0):
			k.ramp(mid - dir * 0.17 + Vector3.UP * 0.01, mid + dir * 0.17 + Vector3.UP * 0.01, 2.4, 0.1, sleeper, false)
		# danger sign where the ramp meets the street (trains run at ground level here)
		if kind == "embankment" and y_avg < 1.2:
			var idx := 0 if mid.x > 0.0 else 1
			if not warn_done[idx]:
				warn_done[idx] = true
				var sp := mid + side * (WIDTH * 0.5 + 1.2)
				k.box(Vector3(sp.x, 0.0, sp.z), Vector3(0.2, 3.0, 0.2), dark, false)
				k.box(Vector3(sp.x, 3.0, sp.z), Vector3(0.15, 1.6, 3.0), Mats.paint(Color(1.0, 0.85, 0.1)), false)
				k.label("DANGER  TRAINS", Vector3(sp.x + 0.12 * signf(sp.x - 0.01), 3.8, sp.z), 0.42, Color(0.1, 0.1, 0.1), 90.0 if mid.x > 0.0 else -90.0)
	# two trains half a lap apart, both on the same loop
	for ti in 2:
		var tr := TrainRunner.new()
		tr.name = "LoopTrain%d" % ti
		tr.path = info.loop
		tr.loop = true
		tr.phase = 0.5 * float(ti)
		tr.cars = 5
		tr.car_len = 9.0
		tr.gap = 1.0
		tr.speed = 24.0
		tr.hazard = true
		tr.body_color = Color(0.85, 0.9, 0.98)
		tr.stripe_color = Color(0.2, 0.55, 0.95)
		parent.add_child(tr)
	info.landmarks.append(["Sky Rail", Vector3(0.0, RAIL_Y + 4.0, NORTH_Z)])
	var ramp_y := (150.0 - TRENCH_X1 - PAD) / (EDGE_X - 25.0 - TRENCH_X1 - PAD) * RAIL_Y
	info.tp.append(["Rail viaduct", Vector3(-100.0, RAIL_Y + 0.4, NORTH_Z), PI * 0.5])
	info.tp.append(["Rail ramp", Vector3(150.0, ramp_y + 0.4, ROW_Z), PI * 0.5])
	info.tp.append(["Metro east portal", Vector3(75.0, lerpf(UNDER_Y, 0.0, (75.0 - TRENCH_X0) / (TRENCH_X1 - TRENCH_X0)) + 0.4, ROW_Z), PI * 0.5])
	info.shards.append_array([Vector3(0.0, RAIL_Y + 1.4, NORTH_Z), Vector3(EDGE_X, RAIL_Y + 1.4, 0.0), Vector3(-EDGE_X, RAIL_Y + 1.4, 0.0), Vector3(200.0, 16.0 + 1.4, ROW_Z)])
	StaticBatch.merge(k.root)
	return info
