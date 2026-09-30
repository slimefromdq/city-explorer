class_name ChinatownProps
extends RefCounted
## Paifang gates and lantern strings: the street-level identity of Chinatown.

static func paifang(k: Kit, at: Vector3, yaw: float) -> void:
	var g := k.sub("Paifang", at, yaw)
	var red := Mats.toon(Color(0.68, 0.1, 0.1))
	var tiles := Mats.toon(Color(0.14, 0.3, 0.32), 0.3)
	var gold := Mats.glow(Color(1.0, 0.78, 0.25), 2.8)
	for x: float in [-8.0, -5.6, 5.6, 8.0]:
		g.cyl(Vector3(x, 0.0, 0), 0.6, 9.0, red, true, 12)
		g.box(Vector3(x, 0.0, 0), Vector3(1.5, 0.7, 1.5), Mats.toon(Color(0.55, 0.52, 0.48)), true)
	g.box(Vector3(0, 8.0, 0), Vector3(17.6, 1.1, 1.3), red, true)
	g.box(Vector3(0, 9.2, 0), Vector3(15.0, 0.9, 1.1), red, true)
	g.box(Vector3(0, 8.05, 0.66), Vector3(17.6, 0.15, 0.1), gold, false, Vector3.ZERO, false)
	g.box(Vector3(0, 10.1, 0), Vector3(17.0, 0.5, 3.6), tiles, true)
	g.box(Vector3(0, 10.6, 0), Vector3(8.0, 0.5, 3.0), tiles, false)
	g.box(Vector3(-8.6, 10.35, 0), Vector3(1.6, 0.35, 3.8), tiles, false, Vector3(0, 0, 22))
	g.box(Vector3(8.6, 10.35, 0), Vector3(1.6, 0.35, 3.8), tiles, false, Vector3(0, 0, -22))
	g.box(Vector3(0, 8.9, 0.6), Vector3(5.2, 1.3, 0.2), Mats.toon(Color(0.06, 0.06, 0.08)), false)
	g.label("CHINATOWN", Vector3(0, 9.5, 0.75), 0.9, Color(1.0, 0.8, 0.3), 0.0)
	g.label("CHINATOWN", Vector3(0, 9.5, -0.75), 0.9, Color(1.0, 0.8, 0.3), 180.0)
	for sx: float in [-1.0, 1.0]:
		g.sphere(Vector3(sx * 6.8, 7.2, 0), 0.5, Mats.glow(Color(1.0, 0.2, 0.15), 4.5))


## A sagging string of glowing lanterns between two points.
static func lantern_string(k: Kit, a: Vector3, b: Vector3, rng: RandomNumberGenerator) -> void:
	var n := maxi(3, int(a.distance_to(b) / 1.7))
	var lantern := Mats.glow(Color(1.0, 0.22, 0.12), 4.5)
	var lantern2 := Mats.glow(Color(1.0, 0.72, 0.2), 4.0)
	for i in n + 1:
		var t := float(i) / float(n)
		var p := a.lerp(b, t)
		p.y -= 1.1 * (1.0 - pow(2.0 * t - 1.0, 2.0))
		if i % 2 == 0:
			k.sphere(p - Vector3(0, 0.4, 0), 0.4, lantern if rng.randf() < 0.7 else lantern2)
	var mid := (a + b) * 0.5
	var d := b - a
	var yaw := rad_to_deg(atan2(-d.z, d.x))
	k.box(Vector3(mid.x, mid.y - 0.6, mid.z), Vector3(Vector2(d.x, d.z).length(), 0.05, 0.05), Mats.toon(Color(0.1, 0.1, 0.1)), false, Vector3(0, yaw, 0), false)
