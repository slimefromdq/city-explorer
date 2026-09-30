class_name RailBuilder
extends RefCounted
## Elevated rail: a curved viaduct that follows the street grid (west edge ->
## along z=-123 -> curve south along x=123 -> curve east along z=123), 26 m up.
## The deck is walkable with low barriers - a long sky road for parkour - and
## a train runs along it.

const RAIL_Y := 26.0
const WIDTH := 9.0


static func _fillet(pts: Array, radius: float) -> Array:
	var out: Array = [pts[0]]
	for i in range(1, pts.size() - 1):
		var p: Vector2 = pts[i]
		var a: Vector2 = (pts[i - 1] - p).normalized()
		var b: Vector2 = (pts[i + 1] - p).normalized()
		var t1 := p + a * radius
		var t2 := p + b * radius
		var steps := 10
		for s in steps + 1:
			var u := float(s) / float(steps)
			# quadratic bezier through the corner gives a smooth arc-like bend
			out.append(t1.lerp(p, u).lerp(p.lerp(t2, u), u))
	out.append(pts[pts.size() - 1])
	return out


## Where a pillar would land in an intersection, on the highway, or under the flyover.
static func _blocked(p: Vector2) -> bool:
	if absf(p.y - 41.0) < 11.0 or absf(p.x - 205.0) < 11.0:
		return true
	var on_ave := false
	for ax in CityLayout.avenues_x():
		if absf(p.x - ax) < 11.0:
			on_ave = true
	var on_st := false
	for sz in CityLayout.streets_z():
		if absf(p.y - sz) < 11.0:
			on_st = true
	return on_ave and on_st


static func build(parent: Node) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": []}
	var k := Kit.new(parent, "ElevatedRail")
	var concrete := Mats.toon(Color(0.35, 0.36, 0.42), 0.7)
	var dark := Mats.toon(Color(0.16, 0.17, 0.2), 0.6)
	var pts := _fillet([
		Vector2(-CityLayout.PLAY_X, -123.0), Vector2(123.0, -123.0), Vector2(123.0, 123.0), Vector2(CityLayout.PLAY_X, 123.0)
	], 34.0)
	var path3 := PackedVector3Array()
	var acc := 0.0
	var pillar_acc := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var d := b - a
		var L := d.length()
		if L < 0.2:
			continue
		var dir := d / L
		var mid := (a + b) * 0.5
		var yaw := rad_to_deg(atan2(-dir.y, dir.x))
		k.box(Vector3(mid.x, RAIL_Y - 1.6, mid.y), Vector3(L + 0.5, 1.6, WIDTH), concrete, true, Vector3(0, yaw, 0))
		var n := Vector2(-dir.y, dir.x)
		for s: float in [-1.0, 1.0]:
			var bp: Vector2 = mid + n * (WIDTH * 0.5 - 0.3) * s
			k.box(Vector3(bp.x, RAIL_Y, bp.y), Vector3(L + 0.5, 1.1, 0.6), concrete, true, Vector3(0, yaw, 0))
		for s: float in [-1.0, 1.0]:
			var rp: Vector2 = mid + n * 0.9 * s
			k.box(Vector3(rp.x, RAIL_Y + 0.02, rp.y), Vector3(L + 0.5, 0.12, 0.14), Mats.toon(Color(0.55, 0.56, 0.6)), false, Vector3(0, yaw, 0), false)
		path3.append(Vector3(a.x, RAIL_Y + 0.25, a.y))
		acc += L
		pillar_acc += L
		if pillar_acc > 30.0 and L > 4.0:
			pillar_acc = 0.0
			if not _blocked(mid):
				k.box(Vector3(mid.x, 0.0, mid.y), Vector3(2.6, RAIL_Y - 1.6, 2.6), concrete, true)
				k.box(Vector3(mid.x, RAIL_Y - 4.5, mid.y), Vector3(WIDTH - 1.0, 0.7, 3.4), concrete, false, Vector3(0, yaw, 0))
		if int(acc / 24.0) != int((acc - L) / 24.0):
			var lp: Vector2 = mid + n * (WIDTH * 0.5 - 0.6)
			k.box(Vector3(lp.x, RAIL_Y, lp.y), Vector3(0.2, 5.0, 0.2), dark, false)
			k.box(Vector3(lp.x, RAIL_Y + 5.0, lp.y), Vector3(0.6, 0.3, 0.6), Mats.glow(Color(1.0, 0.85, 0.5), 4.0), false, Vector3.ZERO, false)
	var last: Vector2 = pts[pts.size() - 1]
	path3.append(Vector3(last.x, RAIL_Y + 0.25, last.y))
	var tr := TrainRunner.new()
	tr.name = "ViaductTrain"
	tr.path = path3
	tr.cars = 6
	tr.speed = 26.0
	tr.interval = 30.0
	tr.hazard = false
	tr._wait = 4.0
	tr.body_color = Color(0.85, 0.9, 0.98)
	tr.stripe_color = Color(0.2, 0.55, 0.95)
	parent.add_child(tr)
	info.landmarks.append(["Sky Rail", Vector3(123.0, RAIL_Y + 4.0, -60.0)])
	info.tp.append(["Rail viaduct", Vector3(-100.0, RAIL_Y + 0.4, -123.0), PI * 0.5])
	info.shards.append(Vector3(0.0, RAIL_Y + 1.4, -123.0))
	info.shards.append(Vector3(123.0, RAIL_Y + 1.4, 20.0))
	info.shards.append(Vector3(220.0, RAIL_Y + 1.4, 123.0))
	StaticBatch.merge(k.root)
	return info
