class_name CityBuilder
extends Node3D
## Orchestrates the whole map from CityLayout: ground (with holes for the park
## and the metro pit), one builder per cell type, layered infrastructure,
## street furniture, edge walls, skyline, lights and collectibles. It also
## gathers the landmark / teleport / shard lists every builder reports.

const PLAY_X := CityLayout.PLAY_X
const PLAY_Z := CityLayout.PLAY_Z

var markers := {}
var landmarks: Array = []
var shard_spots: Array[Vector3] = []
var park: ParkBuilder
var _tp: Array = []
var _roofs: Array = []
var _rng := RandomNumberGenerator.new()


func build() -> void:
	_rng.seed = 20260930
	_ground()
	_road_paint()
	for r in CityLayout.ROWS:
		for c in CityLayout.COLS:
			_cell(c, r)
	_absorb(HighwayBuilder.build_highway(self))
	_absorb(HighwayBuilder.build_flyover(self))
	_absorb(RailBuilder.build(self))
	var lb := Leaderboard.new()
	lb.name = "Leaderboard"
	lb.position = Vector3(-228.5, 60.8, -137.0)
	add_child(lb)
	_paifang_gates()
	_street_furniture()
	_edge_walls()
	_skyline()
	_lights()
	_pickups()
	_shards()
	_markers()


func _absorb(info: Dictionary) -> void:
	landmarks.append_array(info.get("landmarks", []))
	_tp.append_array(info.get("tp", []))
	for s in info.get("shards", []):
		shard_spots.append(s)


# --------------------------------------------------------------- ground

func _subtract(rects: Array, hole: Rect2) -> Array:
	var out: Array = []
	for r: Rect2 in rects:
		if not r.intersects(hole):
			out.append(r)
			continue
		var top := Rect2(r.position.x, r.position.y, r.size.x, hole.position.y - r.position.y)
		var bottom := Rect2(r.position.x, hole.end.y, r.size.x, r.end.y - hole.end.y)
		var y0 := maxf(r.position.y, hole.position.y)
		var y1 := minf(r.end.y, hole.end.y)
		var left := Rect2(r.position.x, y0, hole.position.x - r.position.x, y1 - y0)
		var right := Rect2(hole.end.x, y0, r.end.x - hole.end.x, y1 - y0)
		for piece: Rect2 in [top, bottom, left, right]:
			if piece.size.x > 0.01 and piece.size.y > 0.01:
				out.append(piece)
	return out


func _ground() -> void:
	var k := Kit.new(self, "Ground")
	var rects: Array = [Rect2(-1000, -1000, 2000, 2000)]
	rects = _subtract(rects, CityLayout.park_rect())
	rects = _subtract(rects, CityLayout.station_pit())
	for r: Rect2 in rects:
		k.box(Vector3(r.get_center().x, -2.0, r.get_center().y), Vector3(r.size.x, 2.0, r.size.y), Mats.road(), true)


func _road_paint() -> void:
	var p := RoadPaint.new(0.03)
	var yellow := Color(1.0, 0.82, 0.2)
	var white := Color(0.88, 0.9, 0.95)
	var park := CityLayout.park_rect()
	var ax_list := CityLayout.avenues_x()
	var sz_list := CityLayout.streets_z()
	for zc in sz_list:
		var x := -PLAY_X
		while x < PLAY_X:
			var near_ix := false
			for ax in ax_list:
				if absf(x + 1.5 - ax) < 11.0:
					near_ix = true
			if not near_ix and not park.has_point(Vector2(x + 1.5, zc)):
				p.rect(x, zc - 0.1, x + 3.0, zc + 0.1, yellow)
				p.rect(x, zc - 4.6, x + 3.0, zc - 4.5, white)
				p.rect(x, zc + 4.5, x + 3.0, zc + 4.6, white)
			x += 6.0
	for xc in ax_list:
		var z := -PLAY_Z
		while z < PLAY_Z:
			var near_ix := false
			for sz in sz_list:
				if absf(z + 1.5 - sz) < 11.0:
					near_ix = true
			if not near_ix and not park.has_point(Vector2(xc, z + 1.5)):
				p.rect(xc - 0.1, z, xc + 0.1, z + 3.0, yellow)
				p.rect(xc - 4.6, z, xc - 4.5, z + 3.0, white)
				p.rect(xc + 4.5, z, xc + 4.6, z + 3.0, white)
			z += 6.0
	var scramble := [Vector2(-41, -123), Vector2(41, -123), Vector2(-41, 123), Vector2(41, 123), Vector2(123, -41), Vector2(-123, -41)]
	for ax in ax_list:
		for sz in sz_list:
			if absf(ax) > PLAY_X - 5.0 or absf(sz) > PLAY_Z - 5.0:
				continue
			if park.has_point(Vector2(ax, sz)):
				continue
			var ix := Vector2(ax, sz)
			if scramble.has(ix):
				# scramble crossing: zebra on all sides plus two diagonals
				for s in [-1.0, 1.0]:
					var d := 11.2
					for i in 9:
						var x0: float = ax - 8.1 + i * 1.8
						p.rect(x0, sz + s * d - 1.6, x0 + 0.9, sz + s * d + 1.6, white)
						var z0: float = sz - 8.1 + i * 1.8
						p.rect(ax + s * d - 1.6, z0, ax + s * d + 1.6, z0 + 0.9, white)
				for diag in [Vector2(1, 1), Vector2(1, -1)]:
					var dir: Vector2 = (diag as Vector2).normalized()
					var perp := Vector2(-dir.y, dir.x)
					var t := -9.5
					while t < 9.6:
						var mid := ix + dir * t
						p.strip(mid - perp * 1.6, mid + perp * 1.6, 0.8, white)
						t += 1.7
				continue
			for s in [-1.0, 1.0]:
				var d2 := 11.2
				for i in 9:
					var x1: float = ax - 8.1 + i * 1.8
					p.rect(x1, sz + s * d2 - 1.6, x1 + 0.9, sz + s * d2 + 1.6, white)
					var z1: float = sz - 8.1 + i * 1.8
					p.rect(ax + s * d2 - 1.6, z1, ax + s * d2 + 1.6, z1 + 0.9, white)
	p.build(self)


# --------------------------------------------------------------- cells

func _cell(c: int, r: int) -> void:
	var id: String = CityLayout.GRID[r][c]
	var ctr := CityLayout.cell_center(c, r)
	match id:
		"PARK":
			if park == null:
				park = ParkBuilder.new()
				add_child(park)
				park.build(CityLayout.park_rect())
				landmarks.append_array(park.landmarks)
				_tp.append_array(park.tp)
				for s in park.shard_spots:
					shard_spots.append(s)
		"CLOCK":
			_absorb(ClockPlazaBuilder.build(self, ctr))
		"LIBRARY":
			_absorb(LibraryBuilder.build(self, ctr))
		"METRO":
			_absorb(StationBuilder.build(self, ctr))
		_:
			var res := BlockBuilder.build(self, id, ctr, c, r)
			_roofs.append_array(res.roofs)
			landmarks.append_array(res.landmarks)
			_tp.append_array(res.tp)
			if id == "FIN_E":
				landmarks.append(["Skyneedle", ctr3(ctr, 200.0)])


func ctr3(c: Vector2, y: float) -> Vector3:
	return Vector3(c.x + 17.5, y, c.y - 17.5)


func _paifang_gates() -> void:
	var k := Kit.new(self, "PaifangGates")
	ChinatownProps.paifang(k, Vector3(-123.0, 0.0, 12.0), 0.0)
	ChinatownProps.paifang(k, Vector3(-123.0, 0.0, 108.0), 0.0)
	landmarks.append(["Chinatown Gate", Vector3(-123.0, 12.0, 12.0)])
	_tp.append(["Chinatown gate", Vector3(-123.0, 0.4, 20.0), PI])
	StaticBatch.merge(k.root)


# --------------------------------------------------------------- street furniture

func _inside_special(p: Vector2) -> bool:
	if CityLayout.park_rect().grow(1.0).has_point(p):
		return true
	return false


func _street_furniture() -> void:
	var k := Kit.new(self, "StreetFurniture")
	var rng := _rng
	var ax_list := CityLayout.avenues_x()
	var sz_list := CityLayout.streets_z()
	for zc in sz_list:
		if zc == 41.0 or absf(zc) > PLAY_Z - 20.0:
			continue
		var x := -PLAY_X + 30.0
		while x < PLAY_X - 30.0:
			x += rng.randf_range(11.0, 24.0)
			var skip := false
			for ax in ax_list:
				if absf(x - ax) < 12.0:
					skip = true
			if skip or rng.randf() < 0.4 or _inside_special(Vector2(x, zc)):
				continue
			var side := -1.0 if rng.randf() < 0.5 else 1.0
			Props.car(k, Vector3(x, 0.0, zc + side * 6.6), 0.0 if side > 0.0 else 180.0, Props.CAR_COLORS[rng.randi() % Props.CAR_COLORS.size()])
	for ax in ax_list:
		if absf(ax) > PLAY_X - 20.0 or ax == 205.0:
			continue
		var z := -PLAY_Z + 30.0
		while z < PLAY_Z - 30.0:
			z += rng.randf_range(12.0, 26.0)
			var skip2 := false
			for sz in sz_list:
				if absf(z - sz) < 12.0:
					skip2 = true
			if skip2 or rng.randf() < 0.45 or _inside_special(Vector2(ax, z)):
				continue
			var side2 := -1.0 if rng.randf() < 0.5 else 1.0
			Props.car(k, Vector3(ax + side2 * 6.6, 0.0, z), 90.0, Props.CAR_COLORS[rng.randi() % Props.CAR_COLORS.size()])
	StaticBatch.merge(k.root)


# --------------------------------------------------------------- boundary

func _edge_walls() -> void:
	var k := Kit.new(self, "EdgeWalls")
	var rng := RandomNumberGenerator.new()
	rng.seed = 555
	var t := 14.0
	for side in [-1.0, 1.0]:
		var x := -PLAY_X - 20.0
		while x < PLAY_X + 20.0:
			var w := rng.randf_range(24.0, 44.0)
			_edge_box(k, Vector3(x + w * 0.5, 0.0, side * (PLAY_Z + t * 0.5)), Vector3(w, rng.randf_range(60.0, 140.0), t), rng)
			x += w
	for side in [-1.0, 1.0]:
		var z := -PLAY_Z
		while z < PLAY_Z:
			var d := rng.randf_range(24.0, 44.0)
			_edge_box(k, Vector3(side * (PLAY_X + t * 0.5), 0.0, z + d * 0.5), Vector3(t, rng.randf_range(60.0, 140.0), d), rng)
			z += d
	StaticBatch.merge(k.root)


func _edge_box(k: Kit, pos: Vector3, size: Vector3, rng: RandomNumberGenerator) -> void:
	var walls := [Color(0.3, 0.32, 0.4), Color(0.4, 0.3, 0.32), Color(0.28, 0.36, 0.42), Color(0.44, 0.4, 0.36)]
	var mat := Mats.facade(walls[rng.randi() % walls.size()], rng.randf() * 90.0, 0.42, Vector2(3.4, 3.8), Vector2(0.55, 0.6), 5.0)
	k.box(pos, size, mat, true)


func _skyline() -> void:
	var k := Kit.new(self, "Skyline")
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	var walls := [Color(0.25, 0.3, 0.42), Color(0.32, 0.28, 0.4), Color(0.22, 0.32, 0.38), Color(0.4, 0.34, 0.34), Color(0.3, 0.34, 0.44)]
	var placed := 0
	var tries := 0
	while placed < 170 and tries < 2000:
		tries += 1
		var ang := rng.randf() * TAU
		var dist := rng.randf_range(300.0, 1100.0)
		var p := Vector3(cos(ang) * dist * 1.25, 0.0, sin(ang) * dist)
		if absf(p.x) < PLAY_X + 40.0 and absf(p.z) < PLAY_Z + 40.0:
			continue
		placed += 1
		var w := rng.randf_range(34.0, 80.0)
		var d := rng.randf_range(34.0, 80.0)
		var h := rng.randf_range(90.0, 330.0) * (0.6 + dist / 1200.0)
		var mat := Mats.facade(walls[rng.randi() % walls.size()], rng.randf() * 90.0, 0.5, Vector2(3.8, 4.0), Vector2(0.55, 0.6), 0.0)
		k.box(p, Vector3(w, h, d), mat, false)
		if rng.randf() < 0.35:
			k.sphere(p + Vector3(0, h + 1.0, 0), 1.4, Mats.glow(Color(1.0, 0.15, 0.15), 6.0))
		if rng.randf() < 0.18:
			var pal := Props.random_palette(rng)
			var m := Mats.mural(pal[0], pal[1], pal[2], rng.randf() * 30.0, 2.0, 1.6)
			var toward := (Vector3.ZERO - p).normalized()
			k.mural_quad(p + Vector3(toward.x * (w * 0.5 + 0.2), h * 0.75, toward.z * (d * 0.5 + 0.2)), Vector2(minf(w, d) * 0.8, minf(w, d) * 0.4), rad_to_deg(atan2(toward.x, toward.z)), m)
	StaticBatch.merge(k.root)


# --------------------------------------------------------------- lights, pickups, shards

func _lights() -> void:
	var spots: Array[Vector3] = []
	for ax in CityLayout.avenues_x():
		for sz in CityLayout.streets_z():
			if absf(ax) < PLAY_X - 10.0 and absf(sz) < PLAY_Z - 10.0 and not CityLayout.park_rect().has_point(Vector2(ax, sz)):
				spots.append(Vector3(ax, 7.0, sz))
	spots.append(Vector3(0, 8.0, -140))
	spots.append(Vector3(82, 8.0, -140))
	spots.append(Vector3(0, 6.0, 82))
	for p in spots:
		var l := OmniLight3D.new()
		l.position = p
		l.omni_range = 26.0
		l.light_energy = 1.3
		l.light_color = Color(1.0, 0.72, 0.42)
		l.shadow_enabled = false
		add_child(l)


func _pickups() -> void:
	var park := CityLayout.park_rect()
	for ax in CityLayout.avenues_x():
		for sz in CityLayout.streets_z():
			if absf(ax) > PLAY_X - 20.0 or absf(sz) > PLAY_Z - 20.0 or park.grow(4.0).has_point(Vector2(ax, sz)):
				continue
			if absf(sz - 41.0) < 12.0 or absf(ax - 205.0) < 12.0:
				continue
			var pk := Pickup.new()
			pk.position = Vector3(ax + 5.0, 0.0, sz + 5.0)
			add_child(pk)
	for p in [Vector3(82, 3.4, -172), Vector3(0, 0.15, 82), Vector3(-16, -7.7, 82), Vector3(-86, 9.6, 41), Vector3(0, 0.15, -150)]:
		var pk2 := Pickup.new()
		pk2.position = p
		add_child(pk2)


func _shards() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 6
	for roof: Vector3 in _roofs:
		if roof.y > 11.0 and roof.y < 75.0 and rng.randf() < 0.3:
			shard_spots.append(roof + Vector3(-8.0, 1.5, 8.0))
	Shard.collected = 0
	Shard.total = shard_spots.size()
	for p in shard_spots:
		var s := Shard.new()
		s.position = p
		add_child(s)


func _markers() -> void:
	markers = {
		"player": Vector3(0, 0.1, -123),
		"bot_dummy": Vector3(22, 0.1, -123),
		"bot_blocker": Vector3(-60, 0.1, 41),
		"bot_dodger": Vector3(164, 0.2, -164),
		"bot_aggressor": Vector3(-90, 0.1, -123),
		"bot_terrace": Vector3(-275.3, 6.05, -181.0),
		"arena": Vector3(-287, 0.1, -60),
	}
	var tps: Array = [["Start", Vector3(0, 0.1, -123), PI]]
	tps.append_array(_tp)
	tps.append(["Financial terrace", Vector3(-275.3, 6.1, -181.0), 0.0])
	markers["tp"] = tps
