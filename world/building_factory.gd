class_name BuildingFactory
extends RefCounted
## Builds one lot's building from a small spec {style, h, seed}. Styles are
## just recipes over Kit + Props, so adding a new district look = one function.
## `faces` says which sides of the lot border a street ("n","s","e","w");
## the others border alleys and get fire escapes / clutter instead of shops.

const YAW := {"n": 180.0, "s": 0.0, "e": 90.0, "w": -90.0}
const WORDS := ["CAFE", "RAMEN", "BAR 24", "NOODLE", "KARAOKE", "PC BANG", "CHICKEN", "COFFEE", "PIZZA", "HOTEL", "SOJU", "BOOKS", "PHARMACY", "TEA"]
const BRICKS := [Color(0.5, 0.3, 0.26), Color(0.42, 0.34, 0.3), Color(0.55, 0.42, 0.32), Color(0.36, 0.3, 0.34)]
const CONCRETES := [Color(0.48, 0.5, 0.54), Color(0.55, 0.53, 0.5), Color(0.4, 0.43, 0.48)]
const CHINA_AWN := [Color(0.75, 0.12, 0.1), Color(0.9, 0.7, 0.2), Color(0.55, 0.1, 0.12)]
const AWNINGS := [Color(0.85, 0.25, 0.3), Color(0.2, 0.5, 0.45), Color(0.9, 0.7, 0.25), Color(0.25, 0.35, 0.7), Color(0.9, 0.9, 0.85)]


static func build(parent: Node, r: Rect2, spec: Dictionary, faces: Dictionary, do_merge := true) -> Kit:
	var k := Kit.new(parent, "Lot_%s" % spec.style)
	var rng := RandomNumberGenerator.new()
	rng.seed = int(spec.get("seed", 1)) * 7919 + int(r.position.x * 31 + r.position.y * 17)
	var h: float = spec.h
	match spec.style:
		"glass": _glass(k, r, h, rng, spec)
		"brick": _brick(k, r, h, rng, spec, faces, true)
		"concrete": _brick(k, r, h, rng, spec, faces, false)
		"oldtown": _oldtown(k, r, h, rng, spec)
		"billboard": _billboard(k, r, h, rng, spec, faces)
		"museum": _museum(k, r, h, rng, spec, faces)
		"chinese": _chinese(k, r, h, rng, spec)
		"pagoda": _pagoda(k, r, rng, spec)
		"round": _round(k, r, h, rng, spec)
		_: _brick(k, r, h, rng, spec, faces, true)
	_street_level(k, r, faces, rng, spec)
	_alley_level(k, r, h, faces, rng, spec)
	if not k.root.has_meta(&"roof"):
		var c := center(r)
		k.root.set_meta(&"roof", Vector3(c.x, h, c.z))
	if do_merge:
		StaticBatch.merge(k.root)
	return k


# ---------------------------------------------------------------- helpers

static func center(r: Rect2) -> Vector3:
	return Vector3(r.position.x + r.size.x * 0.5, 0.0, r.position.y + r.size.y * 0.5)


static func inset(r: Rect2, m: float) -> Rect2:
	return Rect2(r.position + Vector2(m, m), r.size - Vector2(m, m) * 2.0)


static func _slab(k: Kit, r: Rect2, y: float, h: float, mat: Material, collide := true) -> MeshInstance3D:
	var c := center(r)
	return k.box(Vector3(c.x, y, c.z), Vector3(r.size.x, h, r.size.y), mat, collide)


## Thin parapet curbs around a roof edge (visual only so you can't snag on them).
static func _parapet(k: Kit, r: Rect2, y: float, mat: Material) -> void:
	var c := center(r)
	var t := 0.35
	var ht := 0.5
	k.box(Vector3(c.x, y, r.position.y + t * 0.5), Vector3(r.size.x, ht, t), mat, false)
	k.box(Vector3(c.x, y, r.position.y + r.size.y - t * 0.5), Vector3(r.size.x, ht, t), mat, false)
	k.box(Vector3(r.position.x + t * 0.5, y, c.z), Vector3(t, ht, r.size.y), mat, false)
	k.box(Vector3(r.position.x + r.size.x - t * 0.5, y, c.z), Vector3(t, ht, r.size.y), mat, false)


static func _roof_clutter(k: Kit, r: Rect2, y: float, rng: RandomNumberGenerator, mat: Material, extras := true) -> void:
	var c := center(r)
	var w := r.size.x
	var d := r.size.y
	Props.stairhouse(k, Vector3(c.x + rng.randf_range(-0.2, 0.2) * w, y, c.z + rng.randf_range(-0.2, 0.2) * d), Vector3(4.5, 3.2, 3.5), mat)
	for i in rng.randi_range(2, 4):
		Props.ac_unit(k, Vector3(r.position.x + rng.randf_range(2.0, w - 2.0), y, r.position.y + rng.randf_range(2.0, d - 2.0)), rng.randf_range(0, 90))
	if extras and rng.randf() < 0.6 and w > 12.0:
		Props.water_tower(k, Vector3(r.position.x + w * rng.randf_range(0.25, 0.75), y, r.position.y + d * rng.randf_range(0.25, 0.75)))


static func _mural_on_face(k: Kit, r: Rect2, face: String, y_center: float, size: Vector2, seed_v: float, energy := 1.2) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(seed_v * 131)
	var pal := Props.random_palette(rng)
	var m := Mats.mural(pal[0], pal[1], pal[2], seed_v, size.x / size.y, energy)
	var c := center(r)
	var off := 0.08
	match face:
		"s": k.mural_quad(Vector3(c.x, y_center, r.position.y + r.size.y + off), size, 0.0, m)
		"n": k.mural_quad(Vector3(c.x, y_center, r.position.y - off), size, 180.0, m)
		"e": k.mural_quad(Vector3(r.position.x + r.size.x + off, y_center, c.z), size, 90.0, m)
		"w": k.mural_quad(Vector3(r.position.x - off, y_center, c.z), size, -90.0, m)


# ---------------------------------------------------------------- styles

static func _glass(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var wall := Color(0.2, 0.32, 0.4).lerp(Color(0.3, 0.3, 0.42), rng.randf())
	var tower_mat := Mats.facade(wall, seed_v, 0.55, Vector2(2.4, 3.2), Vector2(0.88, 0.8), 0.0)
	var podium_mat := Mats.facade(Color(0.45, 0.47, 0.52), seed_v + 3.0, 0.4, Vector2(3.6, 3.6), Vector2(0.7, 0.6), 4.6)
	var podium := inset(r, 0.5)
	_slab(k, podium, 0.0, 6.0, podium_mat)
	# stepped setbacks: every ledge is a walkable terrace (dash-reset spots)
	var cuts := [0.0, 0.34, 0.68] if h > 95.0 else [0.0, 0.7]
	var insets := [5.0, 8.0, 11.0] if h > 95.0 else [5.0, 8.5]
	var top_rect := podium
	for i in cuts.size():
		var y0: float = 6.0 if i == 0 else h * cuts[i]
		var y1: float = h * cuts[i + 1] if i + 1 < cuts.size() else h
		top_rect = inset(r, insets[i])
		_slab(k, top_rect, y0, y1 - y0, tower_mat)
	var c := center(r)
	# crown: glowing ring band + mast; supertalls get a lit halo
	k.box(Vector3(c.x, h - 3.0, c.z), Vector3(top_rect.size.x + 0.6, 0.5, top_rect.size.y + 0.6), Mats.glow(Color(0.5, 0.85, 1.0), 3.0), false, Vector3.ZERO, false)
	k.cyl(Vector3(c.x, h, c.z), 0.35, 12.0 if h < 110.0 else 26.0, Mats.toon(Color(0.7, 0.7, 0.75)), false, 8)
	k.sphere(Vector3(c.x, h + (12.3 if h < 110.0 else 26.3), c.z), 0.5, Mats.glow(Color(1.0, 0.1, 0.1), 6.0))
	_parapet(k, podium, 6.0, Mats.toon(Color(0.35, 0.36, 0.4)))
	Props.planter(k, Vector3(podium.position.x + 1.6, 6.0, podium.position.y + 8.0), Vector3(1.2, 0.9, 3.0))
	Props.planter(k, Vector3(podium.end.x - 1.6, 6.0, podium.end.y - 8.0), Vector3(1.2, 0.9, 3.0))
	Props.ac_unit(k, Vector3(top_rect.position.x + 2.0, h, top_rect.position.y + 2.0))
	k.root.set_meta(&"roof", Vector3(c.x, h, c.z))


static func _brick(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary, faces: Dictionary, is_brick: bool) -> void:
	var seed_v := float(spec.get("seed", 1))
	var wall: Color = BRICKS[rng.randi() % BRICKS.size()] if is_brick else CONCRETES[rng.randi() % CONCRETES.size()]
	var mat := Mats.facade(wall, seed_v, 0.38, Vector2(3.0, 3.4), Vector2(0.5, 0.58), 4.6)
	var body := inset(r, 0.3)
	_slab(k, body, 0.0, h, mat)
	var cor := Rect2(body.position - Vector2(0.4, 0.4), body.size + Vector2(0.8, 0.8))
	_slab(k, cor, h - 0.9, 0.9, Mats.toon(wall.lightened(0.12), 0.5), false)
	_parapet(k, body, h, Mats.toon(wall.darkened(0.2)))
	_roof_clutter(k, inset(body, 1.5), h, rng, Mats.toon(wall.darkened(0.15), 0.4))
	# roof billboard on some brick towers
	if rng.randf() < 0.55:
		var c := center(body)
		Props.billboard(k, Vector3(c.x, h, body.position.y + 3.0), 180.0, 12.0, 5.0, seed_v + 1.0, 2.5)
	if not is_brick:
		for f in faces.keys():
			if faces[f]:
				_mural_on_face(k, Rect2(body.position, body.size), f, 3.0, Vector2(9.0, 3.2), seed_v + 5.0, 0.9)
				break


static func _oldtown(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var parts := 3
	var seg := r.size.x / parts
	for i in parts:
		var hh := h * rng.randf_range(0.65, 1.15)
		var wall: Color = BRICKS[rng.randi() % BRICKS.size()].lerp(Color(0.6, 0.5, 0.4), 0.25)
		var mat := Mats.facade(wall, seed_v + i, 0.3, Vector2(2.6, 3.0), Vector2(0.45, 0.55), 4.0)
		var pr := Rect2(Vector2(r.position.x + i * seg + 0.15, r.position.y + 0.3), Vector2(seg - 0.3, r.size.y - 0.6))
		_slab(k, pr, 0.0, hh, mat)
		_parapet(k, pr, hh, Mats.toon(wall.darkened(0.25)))
		var pc := center(pr)
		Props.ac_unit(k, Vector3(pc.x, hh, pc.z + rng.randf_range(-3, 3)), rng.randf_range(0, 90))
		if rng.randf() < 0.6:
			# rooftop laundry / shack
			k.box(Vector3(pc.x + 2.0, hh, pc.z - 2.0), Vector3(3.0, 2.4, 2.6), Mats.toon(Color(0.35, 0.4, 0.42), 0.7), true)
		# neighbouring roofs step up/down like a real old-town skyline


static func _billboard(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary, faces: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var wall := Color(0.28, 0.3, 0.38)
	var mat := Mats.facade(wall, seed_v, 0.5, Vector2(2.8, 3.4), Vector2(0.6, 0.6), 4.6)
	var body := inset(r, 1.0)
	_slab(k, body, 0.0, h, mat)
	_parapet(k, body, h, Mats.toon(wall.darkened(0.2)))
	# Seoul-style: giant murals on street faces, high above eye level
	var n := 0
	for f in faces.keys():
		if faces[f]:
			var b := Rect2(body.position, body.size)
			_mural_on_face(k, b, f, h - 11.0 - n * 3.0, Vector2(minf(body.size.x, body.size.y) - 3.0, 12.0), seed_v + n * 3.0, 1.5)
			n += 1
	# vertical neon strips
	var c := center(body)
	for i in 3:
		var col: Color = Props.NEON[rng.randi() % Props.NEON.size()]
		var word: String = WORDS[rng.randi() % WORDS.size()]
		for f in faces.keys():
			if faces[f]:
				var p := _face_point(body, f, 0.2 + i * 0.3)
				var yaw: float = YAW[f]
				var out := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
				k.box(p + out * 0.4 + Vector3(0, 8.0 + i * 1.5, 0), Vector3(0.9, 5.0, 0.35), Mats.glow(col, 4.0), false, Vector3.ZERO, false)
				k.label(word, p + out * 0.7 + Vector3(0, 10.5 + i * 1.5, 0), 1.6, Color.WHITE, yaw)
				break
	Props.billboard(k, Vector3(c.x, h, c.z), 0.0, 16.0, 7.0, seed_v + 9.0, 3.5, 1.6)
	Props.stairhouse(k, Vector3(c.x + 6.0, h, c.z + 5.0), Vector3(4.0, 3.0, 3.0), Mats.toon(wall.darkened(0.15)))


static func _museum(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary, faces: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var stone := Color(0.72, 0.66, 0.56)
	var mat := Mats.facade(stone, seed_v, 0.25, Vector2(5.0, 6.5), Vector2(0.5, 0.7), 3.0)
	var body := Rect2(r.position + Vector2(0.3, 7.0), r.size - Vector2(0.6, 7.3))
	# open porch in front (north side): platform + grand stairs
	_slab(k, body, 0.0, h, mat)
	var porch := Rect2(r.position + Vector2(0.3, 0.3), Vector2(r.size.x - 0.6, 6.7))
	_slab(k, porch, 0.0, 3.0, Mats.toon(stone.darkened(0.05), 0.4))
	# columns
	for i in 6:
		var x := porch.position.x + 2.2 + i * ((porch.size.x - 4.4) / 5.0)
		k.cyl(Vector3(x, 3.0, porch.position.y + 5.5), 0.5, 9.0, Mats.toon(stone.lightened(0.1)), true, 12)
	k.box(Vector3(porch.position.x + porch.size.x * 0.5, 12.0, porch.position.y + 4.8), Vector3(porch.size.x, 1.6, 3.4), Mats.toon(stone), false)
	# grand staircase toward the street (north side): rises from z = lot edge
	var cx := porch.position.x + porch.size.x * 0.5
	k.stairs(Vector3(cx, 0.0, porch.position.y + 0.3), Vector3(0, 0, 1), 3.0, 6.0, 10.0, Mats.toon(stone.lightened(0.05), 0.3))
	# skylights on the roof
	var c := center(body)
	k.box(Vector3(c.x, h, c.z), Vector3(body.size.x * 0.45, 1.2, body.size.y * 0.45), Mats.glass(Color(0.5, 0.75, 0.9, 0.55)), true)
	_parapet(k, body, h, Mats.toon(stone.darkened(0.2)))
	# balcony strip along the porch roof
	k.box(Vector3(cx, 9.0, body.position.y - 0.8), Vector3(body.size.x - 4.0, 0.25, 1.6), Mats.toon(stone.darkened(0.1)), true)
	k.label("MUSEUM", Vector3(cx, 13.2, porch.position.y + 6.55), 3.2, Color(1.0, 0.9, 0.7), 0.0)


static func _eave(k: Kit, e: Rect2, y: float, tiles: Material, gold: Material) -> void:
	_slab(k, e, y, 0.4, tiles)
	var c := center(e)
	k.box(Vector3(c.x, y + 0.4, e.position.y + 0.15), Vector3(e.size.x, 0.18, 0.3), gold, false, Vector3.ZERO, false)
	k.box(Vector3(c.x, y + 0.4, e.end.y - 0.15), Vector3(e.size.x, 0.18, 0.3), gold, false, Vector3.ZERO, false)
	k.box(Vector3(e.position.x + 0.15, y + 0.4, c.z), Vector3(0.3, 0.18, e.size.y), gold, false, Vector3.ZERO, false)
	k.box(Vector3(e.end.x - 0.15, y + 0.4, c.z), Vector3(0.3, 0.18, e.size.y), gold, false, Vector3.ZERO, false)
	# upturned corner tips + hanging lanterns
	var lantern := Mats.glow(Color(1.0, 0.22, 0.15), 4.0)
	for cxn in [e.position.x, e.end.x]:
		for czn in [e.position.y, e.end.y]:
			k.box(Vector3(cxn, y + 0.3, czn), Vector3(0.9, 0.25, 0.9), tiles, false, Vector3(18, 45, 18))
			k.sphere(Vector3(cxn, y - 0.7, czn), 0.38, lantern)
	var n := int(e.size.x / 5.0)
	for i in n:
		var t := (i + 0.5) / n
		k.sphere(Vector3(e.position.x + e.size.x * t, y - 0.7, e.position.y), 0.32, lantern)
		k.sphere(Vector3(e.position.x + e.size.x * t, y - 0.7, e.end.y), 0.32, lantern)


static func _chinese(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var red := Color(0.6, 0.14, 0.13).lerp(Color(0.5, 0.2, 0.12), rng.randf() * 0.6)
	var wallmat := Mats.facade(red, seed_v, 0.6, Vector2(2.8, 3.2), Vector2(0.5, 0.6), 4.6)
	var tiles := Mats.toon(Color(0.15, 0.32, 0.34), 0.4)
	var gold := Mats.glow(Color(1.0, 0.78, 0.25), 2.6)
	var body := inset(r, 2.0)
	var tier_h := 5.4
	var tiers := maxi(2, int(h / tier_h))
	var y := 0.0
	var tr := body
	for i in tiers:
		tr = inset(body, i * 0.8)
		_slab(k, tr, y, tier_h, wallmat)
		var e := Rect2(tr.position - Vector2(1.7, 1.7), tr.size + Vector2(3.4, 3.4))
		_eave(k, e, y + tier_h - 0.4, tiles, gold)
		y += tier_h
	var c := center(tr)
	# hipped pavilion roof on top
	var roof := k.cyl(Vector3(c.x, y, c.z), minf(tr.size.x, tr.size.y) * 0.62, 3.6, tiles, false, 4, 0.6)
	roof.rotation_degrees.y = 45
	k.sphere(Vector3(c.x, y + 3.8, c.z), 0.45, gold)
	Props.ac_unit(k, Vector3(tr.position.x + 2.0, y, tr.position.y + 2.0))
	k.root.set_meta(&"roof", Vector3(c.x, y, c.z))
	# vertical shop signs with lantern glow
	var col := Color(1.0, 0.8, 0.25)
	var word: String = ["TEA HOUSE", "DIM SUM", "NOODLES", "HERBS", "LUCKY"][rng.randi() % 5]
	k.box(Vector3(r.position.x + 1.0, 5.5, r.position.y + r.size.y * 0.5), Vector3(0.4, 4.0, 1.4), Mats.toon(Color(0.7, 0.12, 0.1)), false)
	k.label(word, Vector3(r.position.x + 0.7, 8.0, r.position.y + r.size.y * 0.5), 1.1, col, -90.0)


static func _pagoda(k: Kit, r: Rect2, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var red := Color(0.6, 0.13, 0.12)
	var wallmat := Mats.facade(red, seed_v, 0.7, Vector2(3.0, 3.4), Vector2(0.4, 0.55), 0.0)
	var tiles := Mats.toon(Color(0.14, 0.3, 0.32), 0.4)
	var gold := Mats.glow(Color(1.0, 0.78, 0.25), 3.0)
	var stone := Mats.toon(Color(0.62, 0.58, 0.52), 0.5)
	var c := center(r)
	# paved courtyard, low wall, gate, lions, trees
	_slab(k, inset(r, 0.5), 0.0, 0.5, stone)
	var court := inset(r, 0.5)
	for side in [[Vector3(c.x, 0.5, court.position.y + 0.3), Vector3(court.size.x, 1.6, 0.6)], [Vector3(c.x, 0.5, court.end.y - 0.3), Vector3(court.size.x, 1.6, 0.6)],
			[Vector3(court.position.x + 0.3, 0.5, c.z), Vector3(0.6, 1.6, court.size.y)], [Vector3(court.end.x - 0.3, 0.5, c.z), Vector3(0.6, 1.6, court.size.y)]]:
		k.box(side[0], side[1], Mats.toon(Color(0.7, 0.2, 0.18), 0.3), true)
	# 7-tier pagoda
	var y := 0.5
	var w := 13.0
	for i in 7:
		var body := Rect2(Vector2(c.x - w * 0.5, c.z - w * 0.5), Vector2(w, w))
		_slab(k, body, y, 5.4, wallmat)
		_eave(k, Rect2(body.position - Vector2(2.2, 2.2), body.size + Vector2(4.4, 4.4)), y + 5.0, tiles, gold)
		y += 5.4
		w -= 1.3
	var roof := k.cyl(Vector3(c.x, y, c.z), w * 0.5 + 3.4, 3.4, tiles, false, 4, 0.4)
	roof.rotation_degrees.y = 45
	k.cyl(Vector3(c.x, y + 3.4, c.z), 0.3, 9.0, gold, false, 8)
	k.sphere(Vector3(c.x, y + 12.6, c.z), 0.8, gold)
	for sx in [-1.0, 1.0]:
		Props.tree(k, Vector3(c.x + sx * 10.5, 0.5, c.z + 11.0), 6.0)
		k.box(Vector3(c.x + sx * 3.0, 0.5, court.end.y - 2.5), Vector3(1.4, 1.5, 1.4), stone, true)
	k.root.set_meta(&"roof", Vector3(c.x, y, c.z))
	k.root.set_meta(&"landmark", "Pagoda")


static func _round(k: Kit, r: Rect2, h: float, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	var seed_v := float(spec.get("seed", 1))
	var c := center(r)
	var R := minf(r.size.x, r.size.y) * 0.5 - 2.0
	var base := Mats.toon(Color(0.2, 0.22, 0.3), 0.6)
	# storefront drum
	k.cyl(Vector3(c.x, 0.0, c.z), R + 1.0, 6.0, base, true, 32)
	k.cyl(Vector3(c.x, 3.2, c.z), R + 1.05, 0.9, Mats.glow(Color(1.0, 0.8, 0.5), 2.2), false, 32)
	# mural-wrapped shaft (Seoul-style giant painted tower)
	var pal := Props.random_palette(rng)
	var mural := Mats.mural(pal[0], pal[1], pal[2], seed_v * 3.1, TAU * R / maxf(h - 6.0, 1.0), 1.0)
	var shaft := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = R
	cm.bottom_radius = R
	cm.height = h - 6.0
	cm.radial_segments = 40
	cm.rings = 1
	shaft.mesh = cm
	shaft.material_override = mural
	shaft.position = Vector3(c.x, 6.0 + (h - 6.0) * 0.5, c.z)
	k.root.add_child(shaft)
	var cs := CylinderShape3D.new()
	cs.radius = R
	cs.height = h - 6.0
	k._add_shape(cs, Transform3D(Basis.IDENTITY, shaft.position))
	# ring ledges every ~14 m: climbable balconies with a glowing lip
	var y := 6.0
	while y < h - 8.0:
		k.cyl(Vector3(c.x, y, c.z), R + 2.4, 0.5, base, true, 32)
		k.cyl(Vector3(c.x, y + 0.5, c.z), R + 2.4, 0.15, Mats.glow(Color(pal[2].r, pal[2].g, pal[2].b), 3.0), false, 32)
		y += 14.0
	k.cyl(Vector3(c.x, h, c.z), R + 1.2, 0.8, base, true, 32)
	Props.billboard(k, Vector3(c.x, h + 0.8, c.z - R + 2.0), 0.0, 12.0, 6.0, seed_v + 4.0, 2.5, 1.5)
	k.root.set_meta(&"roof", Vector3(c.x, h + 0.8, c.z))


# ---------------------------------------------------------------- street level (calm, warm)

static func _face_point(r: Rect2, face: String, t: float) -> Vector3:
	match face:
		"n": return Vector3(r.position.x + r.size.x * t, 0.0, r.position.y)
		"s": return Vector3(r.position.x + r.size.x * t, 0.0, r.position.y + r.size.y)
		"e": return Vector3(r.position.x + r.size.x, 0.0, r.position.y + r.size.y * t)
		_: return Vector3(r.position.x, 0.0, r.position.y + r.size.y * t)


static func _street_level(k: Kit, r: Rect2, faces: Dictionary, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	if spec.style in ["museum", "pagoda", "round"]:
		return
	var awn: Array = CHINA_AWN if spec.style == "chinese" else AWNINGS
	for f in faces.keys():
		if not faces[f]:
			continue
		var length: float = r.size.x if (f == "n" or f == "s") else r.size.y
		var n := int(length / 7.0)
		for i in n:
			if rng.randf() < 0.55:
				var t := (i + 0.5) / n
				var p := _face_point(r, f, t)
				var yaw: float = YAW[f]
				Props.awning(k, p + Vector3(0, 0.0, 0), 5.2, yaw, awn[rng.randi() % awn.size()])
				if rng.randf() < 0.45:
					var out := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
					var side := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
					var tp := p + out * 1.5
					Props.bench(k, tp + side * 1.0, yaw + 90.0)
		# sign strip well above eye level
		if spec.style != "glass" and rng.randf() < 0.8:
			var col: Color = Props.NEON[rng.randi() % Props.NEON.size()]
			var p2 := _face_point(r, f, rng.randf_range(0.25, 0.75))
			var yaw2: float = YAW[f]
			var out2 := Vector3(sin(deg_to_rad(yaw2)), 0, cos(deg_to_rad(yaw2)))
			k.box(p2 + out2 * 0.45 + Vector3(0, 5.6, 0), Vector3(0.8, 3.2, 0.3), Mats.glow(col, 3.5), false, Vector3.ZERO, false)
			k.label(WORDS[rng.randi() % WORDS.size()], p2 + out2 * 0.68 + Vector3(0, 7.2, 0), 1.3, Color(1, 1, 1), yaw2)


static func _alley_level(k: Kit, r: Rect2, h: float, faces: Dictionary, rng: RandomNumberGenerator, spec: Dictionary) -> void:
	if spec.style in ["glass", "museum", "pagoda", "round"]:
		return
	for f in faces.keys():
		if faces[f]:
			continue
		var yaw: float = YAW[f]
		var length: float = r.size.x if (f == "n" or f == "s") else r.size.y
		var p := _face_point(r, f, 0.5)
		var out := Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
		var side := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
		if h > 16.0 and spec.style != "oldtown" and spec.style != "chinese" and rng.randf() < 0.85:
			Props.fire_escape(k, _face_point(r, f, rng.randf_range(0.3, 0.7)) + out * 0.3, yaw, minf(h, 22.0))
		if rng.randf() < 0.7:
			Props.dumpster(k, p + out * 0.9 + side * rng.randf_range(-length * 0.35, length * 0.35), yaw + 90.0)
		if rng.randf() < 0.6:
			Props.crates(k, p + out * 0.9 + side * rng.randf_range(-length * 0.35, length * 0.35), yaw, rng, 3)
		if rng.randf() < 0.5:
			Props.barrel(k, p + out * 0.8 + side * rng.randf_range(-length * 0.4, length * 0.4))
		# warm alley lamp mid-height
		var col: Color = Props.NEON[rng.randi() % Props.NEON.size()]
		k.box(p + out * 0.2 + side * rng.randf_range(-6, 6) + Vector3(0, 4.2, 0), Vector3(0.3, 0.3, 0.3), Mats.glow(Color(1.0, 0.75, 0.4), 5.0), false, Vector3.ZERO, false)
		if spec.style == "oldtown":
			for i in 2:
				Props.stall(k, p + out * 2.2 + side * (i * 5.0 - 5.0), yaw + 90.0, AWNINGS[rng.randi() % AWNINGS.size()], rng)
		# laundry hung across the alley: visual only, above dash height clutter
		var line_col := Color(0.9, 0.9, 0.95) if rng.randf() < 0.5 else col
		k.box(p + out * 2.6 + Vector3(0, 6.0, 0) - side * 2.0, Vector3(0.05, 0.05, 0.05) + Vector3(abs(side.x), 0, abs(side.z)) * 6.0, Mats.toon(Color(0.2, 0.2, 0.2)), false)
		k.box(p + out * 2.6 + Vector3(0, 4.9, 0) - side * 1.0, Vector3(0.9, 1.1, 0.06) if abs(out.z) > 0.5 else Vector3(0.06, 1.1, 0.9), Mats.toon(line_col), false)
