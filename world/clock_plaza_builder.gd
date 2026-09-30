class_name ClockPlazaBuilder
extends RefCounted
## The orientation beacon: a 170 m clock tower in a paved plaza. Ledge rings
## every ~20 m make it a vertical climb (3 chained dashes between rings);
## the floodlit belfry and red spire are visible from anywhere in the city.

static func build(parent: Node, c: Vector2) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": []}
	var k := Kit.new(parent, "ClockPlaza")
	var cx := c.x
	var cz := c.y
	var stone := Mats.facade(Color(0.55, 0.47, 0.4), 77.0, 0.3, Vector2(4.0, 6.0), Vector2(0.4, 0.62), 6.0)
	var stone_m := Mats.toon(Color(0.66, 0.6, 0.53), 0.5)
	var ledge_m := Mats.toon(Color(0.42, 0.36, 0.32), 0.6)
	# plaza paving: light/dark tiles
	k.box(Vector3(cx, 0.0, cz), Vector3(64.0, 0.12, 64.0), Mats.toon(Color(0.7, 0.66, 0.6), 0.3), true)
	var paint := RoadPaint.new(0.14)
	for i in 8:
		for j in 8:
			if (i + j) % 2 == 0:
				paint.rect(cx - 32.0 + i * 8.0, cz - 32.0 + j * 8.0, cx - 24.0 + i * 8.0, cz - 24.0 + j * 8.0, Color(0.55, 0.5, 0.45))
	paint.build(k.root)
	# tower: base, shaft, belfry
	k.box(Vector3(cx, 0.1, cz), Vector3(26.0, 10.0, 26.0), stone, true)
	k.box(Vector3(cx, 10.1, cz), Vector3(16.0, 96.0, 16.0), stone, true)
	k.box(Vector3(cx, 106.1, cz), Vector3(20.0, 20.0, 20.0), stone, true)
	# ledge rings (climbable)
	var ledge_ys := [10.1, 30.0, 50.0, 70.0, 90.0, 106.1, 126.1]
	for y in ledge_ys:
		if y < 12.0:
			continue   # the base roof is the first ledge: flat, so the grand stair steps straight onto it
		var half := 8.0 if y < 106.0 else 10.0
		var d := 2.6
		k.box(Vector3(cx, y, cz - half - d * 0.5), Vector3(half * 2.0 + d * 2.0, 0.5, d), ledge_m, true)
		k.box(Vector3(cx, y, cz + half + d * 0.5), Vector3(half * 2.0 + d * 2.0, 0.5, d), ledge_m, true)
		k.box(Vector3(cx - half - d * 0.5, y, cz), Vector3(d, 0.5, half * 2.0), ledge_m, true)
		# the spiral's east-side flight runs under this ring's east ledge, so leave it open
		if not [30.0, 50.0, 70.0, 90.0].has(y):
			k.box(Vector3(cx + half + d * 0.5, y, cz), Vector3(d, 0.5, half * 2.0), ledge_m, true)
		k.box(Vector3(cx, y + 0.5, cz + half + d - 0.1), Vector3(half * 2.0 + d * 2.0, 0.25, 0.25), Mats.glow(Color(1.0, 0.8, 0.5), 2.5), false, Vector3.ZERO, false)
		if y > 12.0:
			info.shards.append(Vector3(cx + half + 1.4, y + 1.2, cz + (y * 0.1 - int(y * 0.1) - 0.5) * 8.0))
	# grand stair from the plaza up to the first ledge ring (the base's roof), then a spiral of
	# ramps round the shaft (south side, corner landing, east side) between successive rings
	k.stairs(Vector3(cx, 0.1, cz + 31.0), Vector3(0, 0, -1), 10.0, 18.0, 6.0, stone_m)
	var spiral := [10.1, 30.0, 50.0, 70.0, 90.0]
	for i in spiral.size() - 1:
		var y0: float = spiral[i] + (0.0 if i == 0 else 0.5)
		var y1: float = spiral[i + 1] + 0.5
		var ym := (y0 + y1) * 0.5
		var zs := cz + 9.3
		var xe := cx + 9.3
		k.ramp(Vector3(cx - 9.0, y0, zs), Vector3(cx + 8.0, ym, zs), 2.0, 0.3, ledge_m)
		k.box(Vector3(xe, y0, zs), Vector3(2.6, ym - y0 - 0.4, 2.6), ledge_m, true)
		k.box(Vector3(xe, ym - 0.4, zs), Vector3(2.6, 0.4, 2.6), ledge_m, true)
		k.ramp(Vector3(xe, ym, cz + 8.0), Vector3(xe, y1, cz - 8.0), 2.0, 0.3, ledge_m)   # tops out flush with the north ledge (which starts at cz-8)
	# four clock faces
	var face := Mats.glow(Color(1.0, 0.94, 0.72), 2.6)
	var hand := Mats.toon(Color(0.06, 0.06, 0.08))
	for f in 4:
		var yaw := f * 90.0
		var fr := k.sub("Face%d" % f, Vector3(cx, 116.0, cz), yaw)
		var disc := fr.cyl(Vector3(0, 0.0, 10.2), 7.4, 0.4, face, false, 32)
		disc.rotation_degrees.x = 90
		fr.box(Vector3(0, 0.0, 10.55), Vector3(0.5, 5.2, 0.2), hand, false, Vector3.ZERO, false)
		fr.box(Vector3(0, 0.0, 10.6), Vector3(0.4, 6.4, 0.2), hand, false, Vector3(0, 0, -70.0 + f * 12.0), false)
	# roof: pyramid + spire + beacons
	var roof := k.cyl(Vector3(cx, 126.1, cz), 15.0, 24.0, Mats.toon(Color(0.2, 0.34, 0.32)), false, 4, 0.5)
	roof.rotation_degrees.y = 45
	k.cyl(Vector3(cx, 150.1, cz), 0.5, 20.0, Mats.toon(Color(0.75, 0.75, 0.78)), false, 8)
	k.sphere(Vector3(cx, 171.0, cz), 1.2, Mats.glow(Color(1.0, 0.12, 0.12), 9.0))
	k.box(Vector3(cx, 126.0, cz), Vector3(19.0, 0.5, 19.0), Mats.glow(Color(1.0, 0.8, 0.5), 3.0), false, Vector3.ZERO, false)
	# plaza dressing: fountains, planters, benches, lamps
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var p := Vector3(cx + sx * 22.0, 0.12, cz + sz * 22.0)
			k.cyl(p, 4.0, 0.9, stone_m, true, 20)
			k.cyl(p + Vector3(0, 0.9, 0), 3.5, 0.05, Mats.glass(Color(0.3, 0.6, 0.9, 0.7)), false, 20)
			k.sphere(p + Vector3(0, 2.6, 0), 0.7, Mats.glow(Color(0.6, 0.9, 1.0), 3.0))
			Props.bench(k, p + Vector3(sx * -6.0, 0, 0), 90.0)
			Props.tree(k, p + Vector3(sx * 6.0, 0, sz * 3.0), 6.0)
	for i in 8:
		if i == 2:
			continue   # keep the grand stair clear
		var a := i * TAU / 8.0
		Props.lamp(k, Vector3(cx + cos(a) * 15.0, 0.12, cz + sin(a) * 15.0), -rad_to_deg(a), 6.0)
	k.label("CITY HALL PLAZA", Vector3(cx + 13.3, 5.0, cz), 1.2, Color(1.0, 0.9, 0.7), 90.0)
	info.landmarks.append(["Clock Tower", Vector3(cx, 172.0, cz)])
	info.tp.append(["Clock plaza", Vector3(cx + 20.0, 0.4, cz + 18.0), PI])
	info.tp.append(["Clock tower ledge", Vector3(cx, 30.0 + 0.4, cz - 9.4), 0.0])
	info.tp.append(["Clock belfry", Vector3(cx, 106.1 + 0.4, cz - 11.5), 0.0])
	StaticBatch.merge(k.root)
	return info
