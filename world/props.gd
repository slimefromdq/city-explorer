class_name Props
extends RefCounted
## Reusable street furniture and rooftop dressing. Every function takes a Kit
## and a transform-ish argument; nothing here knows about the city layout.

const CAR_COLORS := [
	Color(0.85, 0.2, 0.22), Color(0.2, 0.35, 0.75), Color(0.9, 0.85, 0.35), Color(0.85, 0.85, 0.88),
	Color(0.15, 0.15, 0.18), Color(0.2, 0.6, 0.5), Color(0.9, 0.5, 0.2),
]
const NEON := [
	Color(1.0, 0.25, 0.55), Color(0.3, 0.9, 1.0), Color(1.0, 0.8, 0.25), Color(0.6, 0.4, 1.0), Color(0.4, 1.0, 0.6),
]


static func car(k: Kit, at: Vector3, yaw: float, color: Color) -> void:
	var c := k.sub("Car", at, yaw)
	var body := Mats.toon(color)
	var dark := Mats.toon(Color(0.05, 0.06, 0.1))
	c.box(Vector3(0, 0.3, 0), Vector3(4.4, 0.75, 1.9), body, true)
	c.box(Vector3(-0.2, 1.05, 0), Vector3(2.3, 0.62, 1.7), dark, true)
	c.box(Vector3(-0.2, 1.06, 0), Vector3(2.32, 0.5, 1.5), Mats.glass(Color(0.3, 0.45, 0.6, 0.6)), false)
	for sx in [-1.45, 1.45]:
		for sz in [-0.95, 0.95]:
			c.cyl(Vector3(sx, 0.0, sz), 0.33, 0.25, dark, false, 10).rotation_degrees.x = 90
	c.box(Vector3(2.19, 0.55, -0.6), Vector3(0.05, 0.16, 0.36), Mats.glow(Color(1.0, 0.95, 0.7), 3.0), false)
	c.box(Vector3(2.19, 0.55, 0.6), Vector3(0.05, 0.16, 0.36), Mats.glow(Color(1.0, 0.95, 0.7), 3.0), false)
	c.box(Vector3(-2.19, 0.55, -0.6), Vector3(0.05, 0.14, 0.34), Mats.glow(Color(1.0, 0.15, 0.15), 2.5), false)
	c.box(Vector3(-2.19, 0.55, 0.6), Vector3(0.05, 0.14, 0.34), Mats.glow(Color(1.0, 0.15, 0.15), 2.5), false)


static func lamp(k: Kit, at: Vector3, yaw: float, height := 7.0, warm := Color(1.0, 0.78, 0.45)) -> void:
	var l := k.sub("Lamp", at, yaw)
	l.cyl(Vector3.ZERO, 0.12, height, Mats.toon(Color(0.12, 0.13, 0.17)), false, 8)
	l.box(Vector3(0.9, height - 0.1, 0), Vector3(1.8, 0.12, 0.12), Mats.toon(Color(0.12, 0.13, 0.17)), false)
	l.box(Vector3(1.7, height - 0.2, 0), Vector3(0.7, 0.14, 0.3), Mats.glow(warm, 5.0), false, Vector3.ZERO, false)


static func dumpster(k: Kit, at: Vector3, yaw: float) -> void:
	var d := k.sub("Dumpster", at, yaw)
	d.box(Vector3.ZERO, Vector3(2.0, 1.25, 1.1), Mats.toon(Color(0.16, 0.36, 0.25)), true)
	d.box(Vector3(0, 1.25, 0), Vector3(2.05, 0.08, 1.15), Mats.toon(Color(0.1, 0.1, 0.12)), false)


static func crates(k: Kit, at: Vector3, yaw: float, rng: RandomNumberGenerator, count := 3) -> void:
	var c := k.sub("Crates", at, yaw)
	var wood := Mats.toon(Color(0.55, 0.38, 0.22), 0.5)
	for i in count:
		var s := rng.randf_range(0.8, 1.15)
		c.box(Vector3(i * 1.05 - count * 0.5, 0.0, rng.randf_range(-0.15, 0.15)), Vector3(s, s, s), wood, true)
	if count > 2:
		c.box(Vector3(0, 1.0, 0), Vector3(0.9, 0.9, 0.9), wood, true)


static func barrel(k: Kit, at: Vector3, color := Color(0.25, 0.3, 0.55)) -> void:
	k.cyl(at, 0.38, 1.0, Mats.toon(color), true, 10)


static func awning(k: Kit, at: Vector3, width: float, yaw: float, color: Color) -> void:
	var a := k.sub("Awning", at, yaw)
	a.box(Vector3(0, 3.3, 0.9), Vector3(width, 0.1, 2.0), Mats.toon(color), false, Vector3(14, 0, 0))
	a.box(Vector3(0, 3.02, 0.02), Vector3(width, 0.35, 0.06), Mats.toon(color.darkened(0.25)), false)
	a.box(Vector3(0, 2.9, 0.1), Vector3(width - 0.4, 0.06, 0.05), Mats.glow(Color(1.0, 0.85, 0.55), 3.0), false, Vector3.ZERO, false)


static func stall(k: Kit, at: Vector3, yaw: float, color: Color, rng: RandomNumberGenerator) -> void:
	var s := k.sub("Stall", at, yaw)
	var wood := Mats.toon(Color(0.4, 0.28, 0.2))
	for sx in [-1.4, 1.4]:
		for sz in [-0.9, 0.9]:
			s.box(Vector3(sx, 0.0, sz), Vector3(0.1, 2.5, 0.1), wood, false)
	s.box(Vector3(0, 2.4, 0), Vector3(3.2, 0.1, 2.2), Mats.toon(color), false, Vector3(0, 0, 6))
	s.box(Vector3(0, 0.0, 0), Vector3(2.8, 0.95, 1.1), wood, true)
	for i in 5:
		var gc: Color = NEON[rng.randi() % NEON.size()]
		s.box(Vector3(-1.1 + i * 0.55, 0.95, rng.randf_range(-0.2, 0.2)), Vector3(0.35, 0.3, 0.35), Mats.toon(gc), false)
	s.box(Vector3(0, 2.2, 0.9), Vector3(2.6, 0.08, 0.06), Mats.glow(Color(1.0, 0.85, 0.5), 3.5), false, Vector3.ZERO, false)


static func ac_unit(k: Kit, at: Vector3, yaw := 0.0) -> void:
	var a := k.sub("AC", at, yaw)
	a.box(Vector3.ZERO, Vector3(2.0, 1.1, 1.4), Mats.toon(Color(0.55, 0.57, 0.6)), true)
	a.cyl(Vector3(0, 1.1, 0), 0.5, 0.15, Mats.toon(Color(0.2, 0.2, 0.24)), false, 12)


static func water_tower(k: Kit, at: Vector3) -> void:
	var w := k.sub("WaterTower", at)
	var wood := Mats.toon(Color(0.42, 0.29, 0.2), 0.6)
	for sx in [-1.2, 1.2]:
		for sz in [-1.2, 1.2]:
			w.box(Vector3(sx, 0.0, sz), Vector3(0.18, 3.0, 0.18), wood, false)
	w.cyl(Vector3(0, 3.0, 0), 1.8, 3.0, wood, true, 16)
	w.cyl(Vector3(0, 6.0, 0), 1.9, 1.0, Mats.toon(Color(0.3, 0.22, 0.17)), false, 16, 0.1)


static func stairhouse(k: Kit, at: Vector3, size: Vector3, mat: Material) -> void:
	k.box(at, size, mat, true)
	k.box(at + Vector3(0, size.y, 0), size + Vector3(0.4, 0.0, 0.4) * Vector3(1, 0, 1) + Vector3(0, 0.2, 0), Mats.toon(Color(0.2, 0.2, 0.24)), false)


static func bench(k: Kit, at: Vector3, yaw: float) -> void:
	var b := k.sub("Bench", at, yaw)
	b.box(Vector3(0, 0.4, 0), Vector3(1.8, 0.1, 0.5), Mats.toon(Color(0.5, 0.33, 0.2)), true)
	b.box(Vector3(0, 0.7, -0.22), Vector3(1.8, 0.4, 0.08), Mats.toon(Color(0.5, 0.33, 0.2)), false)
	for sx in [-0.8, 0.8]:
		b.box(Vector3(sx, 0.0, 0), Vector3(0.08, 0.4, 0.4), Mats.toon(Color(0.15, 0.15, 0.18)), false)


static func planter(k: Kit, at: Vector3, size := Vector3(2.4, 0.9, 1.2)) -> void:
	k.box(at, size, Mats.toon(Color(0.5, 0.48, 0.45), 0.6), true)
	k.box(at + Vector3(0, size.y, 0), size * Vector3(0.9, 0.0, 0.85) + Vector3(0, 0.5, 0), Mats.toon(Color(0.2, 0.5, 0.3)), false)


static func tree(k: Kit, at: Vector3, height := 5.0) -> void:
	k.cyl(at, 0.18, height * 0.5, Mats.toon(Color(0.3, 0.2, 0.14)), false, 8)
	k.sphere(at + Vector3(0, height * 0.7, 0), height * 0.32, Mats.toon(Color(0.22, 0.5, 0.32)))


## Free-standing billboard: two legs, a frame, and a mural panel.
static func billboard(k: Kit, at: Vector3, yaw: float, w: float, h: float, seed_v: float, legs := 3.0, glow_energy := 1.3) -> void:
	var b := k.sub("Billboard", at, yaw)
	var steel := Mats.toon(Color(0.14, 0.15, 0.19))
	for sx in [-w * 0.35, w * 0.35]:
		b.box(Vector3(sx, 0.0, 0), Vector3(0.35, legs, 0.35), steel, false)
	b.box(Vector3(0, legs, 0), Vector3(w + 0.6, h + 0.6, 0.4), steel, false)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_v * 977)
	var pal := _palette(rng)
	var m := Mats.mural(pal[0], pal[1], pal[2], seed_v, w / h, glow_energy)
	b.mural_quad(Vector3(0, legs + h * 0.5 + 0.3, 0.22), Vector2(w, h), 0.0, m)
	b.mural_quad(Vector3(0, legs + h * 0.5 + 0.3, -0.22), Vector2(w, h), 180.0, m)


static func _palette(rng: RandomNumberGenerator) -> Array:
	var sets := [
		[Color(1.0, 0.35, 0.55), Color(0.2, 0.15, 0.6), Color(1.0, 0.92, 0.55)],
		[Color(0.25, 0.85, 1.0), Color(0.15, 0.15, 0.5), Color(1.0, 0.5, 0.7)],
		[Color(1.0, 0.65, 0.2), Color(0.55, 0.12, 0.35), Color(1.0, 0.95, 0.8)],
		[Color(0.5, 1.0, 0.7), Color(0.05, 0.25, 0.45), Color(1.0, 1.0, 0.6)],
		[Color(0.8, 0.5, 1.0), Color(0.1, 0.1, 0.35), Color(0.6, 1.0, 1.0)],
	]
	return sets[rng.randi() % sets.size()]


static func random_palette(rng: RandomNumberGenerator) -> Array:
	return _palette(rng)


## Zig-zag fire escape hung on a wall. `at` is the wall point on the ground,
## `yaw` rotates local +Z to point out of the wall.
static func fire_escape(k: Kit, at: Vector3, yaw: float, height: float, span := 3.4) -> void:
	var f := k.sub("FireEscape", at, yaw)
	var iron := Mats.toon(Color(0.1, 0.11, 0.14))
	var rail := Mats.toon(Color(0.16, 0.17, 0.2))
	var dz := 3.2
	var floors := int(floor((height - 2.0) / dz))
	for i in floors:
		var y := 3.0 + i * dz
		f.box(Vector3(0, y, 0), Vector3(span, 0.12, 1.3), iron, true)
		f.box(Vector3(0, y + 0.12, 1.25), Vector3(span, 1.0, 0.05), rail, false)
		f.box(Vector3(-span * 0.5 + 0.03, y + 0.12, 0.6), Vector3(0.05, 1.0, 1.2), rail, false)
		f.box(Vector3(span * 0.5 - 0.03, y + 0.12, 0.6), Vector3(0.05, 1.0, 1.2), rail, false)
		if i < floors - 1 or floors == 1:
			var left := i % 2 == 0
			var xa := span * 0.5 - 0.1 if left else -span * 0.5 + 0.1
			var xb := -span * 0.5 + 0.1 if left else span * 0.5 - 0.1
			f.ramp(Vector3(xa, y + 0.12, 1.75), Vector3(xb, y + dz + 0.12, 1.75), 0.9, 0.12, iron)
	# drop ladder stub so the first landing is reachable with a dash/jump
	f.box(Vector3(span * 0.5 - 0.3, 1.2, 0.3), Vector3(0.1, 1.8, 0.1), rail, false)
