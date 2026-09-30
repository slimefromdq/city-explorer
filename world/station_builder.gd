class_name StationBuilder
extends RefCounted
## Metro station: the most vertical street-level fight in the city.
##   -9 m   sunken platforms + two tracks, tunnels running out both ends
##    0 m   concourse ring with four street entrances
##    7 m   mezzanine balconies + bridges across the pit (escalator ramps)
##   14 m   upper walkways
##   25 m   roof girders under a glass barrel vault
## Everything you can stand on is real collision; ramps/escalators are what
## you actually walk on, the steps are dressing.

const PIT_Y := -9.0
const PLAT_Y := -7.8
const HALL := 30.0        # interior half-size
const WALL_H := 26.0


static func build(parent: Node, c: Vector2) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": [], "trains": []}
	var k := Kit.new(parent, "MetroStation")
	var wall := Mats.facade(Color(0.5, 0.55, 0.64), 12.0, 0.5, Vector2(4.8, 5.6), Vector2(0.6, 0.78), 0.0)
	var conc := Mats.toon(Color(0.5, 0.52, 0.58), 0.7)
	var tile := Mats.toon(Color(0.78, 0.79, 0.84), 0.2)
	var dark := Mats.toon(Color(0.14, 0.15, 0.2))
	var steel := Mats.toon(Color(0.22, 0.26, 0.36))
	var yellow := Mats.paint(Color(1.0, 0.85, 0.2))
	var glowm := Mats.glow(Color(0.95, 0.97, 1.0), 2.5)
	var cx := c.x
	var cz := c.y

	# ---------------------------------------------------------------- shell
	for side in 4:
		var along_x := side < 2
		var line := (-HALL - 1.0) if side % 2 == 0 else (HALL + 1.0)
		for seg in [[-32.0, -5.0], [5.0, 32.0]]:
			_wall(k, cx, cz, along_x, line, seg[0], seg[1], 0.0, WALL_H, 2.0, wall)
		_wall(k, cx, cz, along_x, line, -5.0, 5.0, 9.5, WALL_H, 2.0, wall)
		# door frame glow
		var fp := Vector3(cx, 9.5, cz + line) if along_x else Vector3(cx + line, 9.5, cz)
		var fs := Vector3(10.4, 0.3, 2.2) if along_x else Vector3(2.2, 0.3, 10.4)
		k.box(fp - Vector3(0, 0.3, 0), fs, Mats.glow(Color(0.5, 0.85, 1.0), 3.0), false, Vector3.ZERO, false)

	# glass barrel vault (visual) + steel ribs
	var glass := Mats.glass(Color(0.45, 0.7, 0.9, 0.33))
	for xi: float in [-25.0, -15.0, -5.0, 5.0, 15.0, 25.0]:
		var y_i := WALL_H + 10.0 * (1.0 - pow(xi / 30.0, 2.0))
		var ang := rad_to_deg(atan(-20.0 * xi / 900.0))
		k.box(Vector3(cx + xi, y_i, cz), Vector3(10.4, 0.25, 62.0), glass, false, Vector3(0, 0, ang), false)
		for zi: float in [-24.0, -12.0, 0.0, 12.0, 24.0]:
			k.box(Vector3(cx + xi, y_i + 0.1, cz + zi), Vector3(10.4, 0.45, 0.5), steel, false, Vector3(0, 0, ang))
	# end gables
	for zs: float in [-1.0, 1.0]:
		k.box(Vector3(cx, WALL_H, cz + zs * (HALL + 1.0)), Vector3(62.0, 6.0, 2.0), wall, false)

	# ---------------------------------------------------------------- floor ring (visual)
	var ring := [
		[Vector3(cx - 25.5, 0.0, cz), Vector3(9.0, 0.06, 60.0)],
		[Vector3(cx + 25.5, 0.0, cz), Vector3(9.0, 0.06, 60.0)],
		[Vector3(cx, 0.0, cz - 28.25), Vector3(42.0, 0.06, 3.5)],
		[Vector3(cx, 0.0, cz + 28.25), Vector3(42.0, 0.06, 3.5)],
	]
	for r in ring:
		k.box(r[0], r[1], tile, false, Vector3.ZERO, false)

	# ---------------------------------------------------------------- pit
	k.box(Vector3(cx, PIT_Y - 1.0, cz), Vector3(40.0, 1.0, 52.0), conc, true)
	for sx: float in [-16.0, 16.0]:
		k.box(Vector3(cx + sx, PIT_Y, cz), Vector3(8.0, PLAT_Y - PIT_Y, 48.0), tile, true)
		var edge_x := sx - 3.8 * signf(sx)
		k.box(Vector3(cx + edge_x, PLAT_Y, cz), Vector3(0.4, 0.04, 48.0), yellow, false, Vector3.ZERO, false)
	k.box(Vector3(cx - 20.5, PIT_Y, cz), Vector3(1.0, -PIT_Y, 53.0), conc, true)
	k.box(Vector3(cx + 20.5, PIT_Y, cz), Vector3(1.0, -PIT_Y, 53.0), conc, true)
	for zs: float in [-1.0, 1.0]:
		var zz := cz + zs * 26.5
		k.box(Vector3(cx - 15.5, PIT_Y, zz), Vector3(9.0, -PIT_Y, 1.0), conc, true)
		k.box(Vector3(cx + 15.5, PIT_Y, zz), Vector3(9.0, -PIT_Y, 1.0), conc, true)
		k.box(Vector3(cx, -2.0, zz), Vector3(22.0, 2.0, 1.0), conc, true)
	var glow_strip := Mats.glow(Color(1.0, 0.85, 0.5), 3.0)
	# north turn-back chamber: both tracks join in a U-turn loop under the highway street
	k.box(Vector3(cx, PIT_Y - 1.0, cz - 38.5), Vector3(21.0, 1.0, 23.0), conc, true)
	for sx: float in [-10.5, 10.5]:
		k.box(Vector3(cx + sx, PIT_Y, cz - 38.5), Vector3(1.0, 7.0, 23.0), conc, true)
		k.box(Vector3(cx + sx * 0.96, -4.0, cz - 38.5), Vector3(0.1, 0.25, 22.0), glow_strip, false, Vector3.ZERO, false)
	k.box(Vector3(cx, PIT_Y, cz - 50.0), Vector3(21.0, 7.0, 1.0), dark, true)
	# south junction chamber: the two tracks fan out into the east / west tunnels that climb to the elevated rail
	k.box(Vector3(cx, PIT_Y - 1.0, cz + 38.0), Vector3(21.0, 1.0, 24.0), conc, true)
	for sx: float in [-10.5, 10.5]:
		# wall with a 10 m opening for the side tunnel (tunnel centre = cz + 41)
		k.box(Vector3(cx + sx, PIT_Y, cz + 32.5), Vector3(1.0, 7.0, 11.0), conc, true)
		k.box(Vector3(cx + sx, PIT_Y, cz + 47.5), Vector3(1.0, 7.0, 11.0), conc, true)
		k.box(Vector3(cx + sx * 0.96, -4.0, cz + 32.5), Vector3(0.1, 0.25, 10.0), glow_strip, false, Vector3.ZERO, false)
	k.box(Vector3(cx, PIT_Y, cz + 50.5), Vector3(21.0, 7.0, 1.0), dark, true)
	# side tunnels along the street: floor + walls, roofed by the ground slab until the open cut
	for sx: float in [-1.0, 1.0]:
		var tx0 := cx + sx * 10.5
		var tx1 := cx + sx * RailBuilder.TRENCH_X0
		var mid_x := (tx0 + tx1) * 0.5
		var len := absf(tx1 - tx0)
		k.box(Vector3(mid_x, PIT_Y - 1.0, RailBuilder.ROW_Z), Vector3(len, 1.0, RailBuilder.TRENCH_W + 1.2), conc, true)
		for sz: float in [-1.0, 1.0]:
			k.box(Vector3(mid_x, PIT_Y, RailBuilder.ROW_Z + sz * (RailBuilder.TRENCH_W * 0.5 + 0.3)), Vector3(len, 7.0, 0.6), conc, true)
			k.box(Vector3(mid_x, -4.0, RailBuilder.ROW_Z + sz * (RailBuilder.TRENCH_W * 0.5 - 0.05)), Vector3(len - 2.0, 0.25, 0.1), glow_strip, false, Vector3.ZERO, false)
	# platform signs + light strips
	for sx: float in [-16.0, 16.0]:
		for zi: float in [-16.0, 0.0, 16.0]:
			k.box(Vector3(cx + sx, -3.4, cz + zi), Vector3(0.2, 0.9, 5.0), Mats.glow(Color(0.4, 0.9, 1.0), 2.6), false, Vector3.ZERO, false)
		for zb: float in [-4.0, 4.0]:
			Props.bench(k, Vector3(cx + sx, PLAT_Y, cz + zb), 90.0)
	k.label("PLATFORM 1  >>", Vector3(cx - 11.0, -3.6, cz - 8.0), 1.0, Color(1, 1, 1), 90.0)
	k.label("PLATFORM 2  >>", Vector3(cx + 11.0, -3.6, cz + 8.0), 1.0, Color(1, 1, 1), -90.0)
	# stairs from the concourse down to the platforms (north-west and south-east)
	_stairs_down(k, Vector3(cx - 16.0, 0.0, cz - 26.0), Vector3(0, 0, 1), tile)
	_stairs_down(k, Vector3(cx + 16.0, 0.0, cz + 26.0), Vector3(0, 0, -1), tile)

	# ---------------------------------------------------------------- mezzanine (7 m)
	for sx: float in [-24.0, 24.0]:
		k.box(Vector3(cx + sx, 6.4, cz), Vector3(8.0, 0.6, 28.0), tile, true)
		k.box(Vector3(cx + sx - 3.9 * signf(sx), 7.0, cz), Vector3(0.1, 0.04, 28.0), yellow, false)
		# hole-facing railings
		for rz in [[-14.0, -8.2], [-3.8, 3.8], [8.2, 14.0]]:
			k.box(Vector3(cx + sx - 4.0 * signf(sx), 7.0, cz + (rz[0] + rz[1]) * 0.5), Vector3(0.2, 1.0, rz[1] - rz[0]), steel, true)
		for zz: float in [-13.0, 0.0, 13.0]:
			k.cyl(Vector3(cx + sx, 0.0, cz + zz), 0.6, 6.4, conc, true, 10)
	for zz: float in [-6.0, 6.0]:
		k.box(Vector3(cx, 6.4, cz + zz), Vector3(40.0, 0.6, 4.0), tile, true)
		for s: float in [-1.0, 1.0]:
			k.box(Vector3(cx, 7.0, cz + zz + s * 1.9), Vector3(40.0, 1.0, 0.2), steel, true)
	# escalator ramps up to the mezzanine (four corners). Two of them (north-west, south-east) share
	# a balcony end with a second ramp that continues up to the 14 m walkway and runs back over the
	# escalator's own path; stacked, the upper ramp left < 1.8 m of headroom on the escalator's top
	# 2 m. So those two escalators sit on the outer edge of the balcony (x = +-26, 3 m wide) and the
	# upper ramps on the inner edge (x = +-22.5, 3 m wide): side by side, never above each other.
	for sx: float in [-24.0, 24.0]:
		for zs: float in [-1.0, 1.0]:
			var shared_end := sx * zs > 0.0
			var ex := signf(sx) * 26.0 if shared_end else sx
			k.stairs(Vector3(cx + ex, 0.0, cz + zs * 28.5), Vector3(0, 0, -zs), 7.0, 14.5, 3.0 if shared_end else 4.0, steel)
	# ---------------------------------------------------------------- upper level (14 m)
	for zs: float in [-1.0, 1.0]:
		k.box(Vector3(cx, 13.4, cz + zs * 27.5), Vector3(52.0, 0.6, 5.0), tile, true)
		# pit-edge railing, open (3.4 m) where the mezzanine ramp lands: x = -22.5 north, +22.5 south
		var gap_c := -22.5 if zs < 0.0 else 22.5
		for seg: Array in [[-26.0, gap_c - 1.7], [gap_c + 1.7, 26.0]]:
			if seg[1] > seg[0]:
				k.box(Vector3(cx + (seg[0] + seg[1]) * 0.5, 14.0, cz + zs * 25.2), Vector3(seg[1] - seg[0], 1.0, 0.2), steel, true)
	# ramps from each mezzanine end up to the upper walkways (inner edge of the balcony; see above)
	k.stairs(Vector3(cx - 22.5, 7.0, cz - 14.0), Vector3(0, 0, -1), 7.0, 11.0, 3.0, steel)   # lands flush on the walkway's inner edge (cz - 25)
	k.stairs(Vector3(cx + 22.5, 7.0, cz + 14.0), Vector3(0, 0, 1), 7.0, 11.0, 3.0, steel)
	# ---------------------------------------------------------------- roof girders (25 m)
	for zi: float in [-24.0, -12.0, 0.0, 12.0, 24.0]:
		k.box(Vector3(cx, 24.4, cz + zi), Vector3(60.0, 0.6, 1.4), steel, true)
	k.box(Vector3(cx, 24.4, cz), Vector3(1.4, 0.6, 60.0), steel, true)
	# maintenance stair from the upper walkway up to the roof girders (so they are not a place to nowhere)
	k.stairs(Vector3(cx - 28.5, 14.0, cz - 25.0), Vector3(0, 0, 1), 11.0, 12.3, 1.6, steel)   # tops out flush with the first girder's front face (cz - 12.7)
	k.box(Vector3(cx - 27.25, 13.4, cz - 26.5), Vector3(3.5, 0.6, 3.0), steel, true)
	# hanging light rigs
	for zi: float in [-18.0, 0.0, 18.0]:
		for xi: float in [-10.0, 10.0]:
			k.box(Vector3(cx + xi, 21.0, cz + zi), Vector3(6.0, 0.25, 0.8), glowm, false, Vector3.ZERO, false)

	# ---------------------------------------------------------------- concourse dressing
	# ticket gates guard the two stairs down to the platforms (NOT the pit edge)
	_gates(k, Vector3(cx - 16.0, 0.0, cz - 28.3), dark)
	_gates(k, Vector3(cx + 16.0, 0.0, cz + 28.3), dark)
	# safety railing all round the pit, open only at the two stairs (you can still vault it)
	var rail := Mats.toon(Color(0.85, 0.75, 0.2))
	var rl := 1.1
	k.box(Vector3(cx - 20.4, 0.0, cz), Vector3(0.2, rl, 53.0), rail, true)
	k.box(Vector3(cx + 20.4, 0.0, cz), Vector3(0.2, rl, 53.0), rail, true)
	for seg in [[-20.4, -18.5, -1.0], [-13.5, 20.4, -1.0], [-20.4, 13.5, 1.0], [18.5, 20.4, 1.0]]:
		k.box(Vector3(cx + (seg[0] + seg[1]) * 0.5, 0.0, cz + seg[2] * 26.5), Vector3(seg[1] - seg[0], rl, 0.2), rail, true)
	for i in 4:
		var bx := cx - 27.0 if i < 2 else cx + 27.0
		Props.bench(k, Vector3(bx, 0.0, cz - 20.0 + (i % 2) * 40.0), 90.0)
	# departure boards on the mezzanine fronts
	var rng := RandomNumberGenerator.new()
	rng.seed = 8
	for sx: float in [-19.6, 19.6]:
		var pal := Props.random_palette(rng)
		var m := Mats.mural(pal[0], pal[1], pal[2], rng.randf() * 20.0, 4.0, 1.3, 0.04)
		k.mural_quad(Vector3(cx + sx, 9.0, cz), Vector2(20.0, 4.0), 90.0 if sx < 0.0 else -90.0, m)
	# entrance kiosks
	Props.stall(k, Vector3(cx - 27.0, 0.0, cz - 6.0), 90.0, Color(0.9, 0.3, 0.3), rng)

	# ---------------------------------------------------------------- landmark signage (visible from far away)
	var ring_mat := Mats.glow(Color(0.35, 0.85, 1.0), 4.5)
	for zs: float in [-1.0, 1.0]:
		var tor := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 6.0
		tm.outer_radius = 7.0
		tm.rings = 32
		tm.ring_segments = 8
		tor.mesh = tm
		tor.material_override = ring_mat
		tor.rotation_degrees.x = 90
		tor.position = Vector3(cx, 43.0, cz + zs * 33.5)
		tor.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k.root.add_child(tor)
		k.label("METRO", Vector3(cx, 43.0, cz + zs * 33.7), 5.0, Color(1, 1, 1), 0.0 if zs > 0.0 else 180.0)
		k.box(Vector3(cx - 0.4, WALL_H + 8.0, cz + zs * 33.0), Vector3(0.8, 13.0, 0.8), steel, false)
	info.landmarks.append(["Metro Station", Vector3(cx, 43.0, cz)])
	info.tp.append(["Metro concourse", Vector3(cx - 25.5, 0.3, cz), 0.0])
	info.tp.append(["Metro platform", Vector3(cx - 16.0, PLAT_Y + 0.3, cz + 12.0), 0.0])
	info.tp.append(["Metro mezzanine", Vector3(cx - 24.0, 7.3, cz), 0.0])
	info.tp.append(["Metro girders", Vector3(cx, 25.0 + 0.3, cz - 12.0), 0.0])
	info.shards.append_array([Vector3(cx, 26.0, cz), Vector3(cx - 16.0, PLAT_Y + 1.4, cz), Vector3(cx + 24.0, 8.2, cz), Vector3(cx, 15.2, cz + 27.5)])

	StaticBatch.merge(k.root)
	return info


## A bank of two fare lanes across a stair mouth (centre `at`, lanes run along z).
static func _gates(k: Kit, at: Vector3, mat: Material) -> void:
	for dx: float in [-2.75, 0.0, 2.75]:
		# posts are short (1.2 m) so >= 1 m stays free in front of and behind the gate line: the 3.5 m
		# concourse strip between the wall and the pit railing must still let you walk up to each lane
		k.box(Vector3(at.x + dx, 0.0, at.z), Vector3(0.5, 1.1, 1.2), mat, true)
		k.box(Vector3(at.x + dx, 1.1, at.z), Vector3(0.5, 0.08, 0.8), Mats.glow(Color(0.4, 1.0, 0.6), 3.0), false, Vector3.ZERO, false)
	k.box(Vector3(at.x - 2.75 - 1.2, 0.0, at.z), Vector3(1.4, 1.1, 0.2), mat, true)
	k.box(Vector3(at.x + 2.75 + 1.2, 0.0, at.z), Vector3(1.4, 1.1, 0.2), mat, true)


static func _wall(k: Kit, cx: float, cz: float, along_x: bool, line: float, a0: float, a1: float, y0: float, y1: float, thick: float, mat: Material) -> void:
	var mid := (a0 + a1) * 0.5
	var len := a1 - a0
	if along_x:
		k.box(Vector3(cx + mid, y0, cz + line), Vector3(len, y1 - y0, thick), mat, true)
	else:
		k.box(Vector3(cx + line, y0, cz + mid), Vector3(thick, y1 - y0, len), mat, true)


## Stairs from the street concourse down to platform height: from `top` (y=0)
## heading `dir`, dropping to PLAT_Y over 16 m.
static func _stairs_down(k: Kit, top: Vector3, dir: Vector3, mat: Material) -> void:
	var d := dir.normalized()
	var bottom := top + d * 16.0 + Vector3(0, PLAT_Y, 0)
	k.ramp(top, bottom, 5.0, 0.4, mat)
	var basis := Basis.looking_at(d, Vector3.UP)
	var n := 39
	for i in n:
		var t := float(i) / float(n)
		var y := PLAT_Y * (t + 1.0 / float(n))
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(5.0, 0.12, 16.0 / float(n))
		mi.mesh = bm
		mi.material_override = mat
		mi.transform = Transform3D(basis, top + d * (16.0 * t + 16.0 / float(n) * 0.5) + Vector3(0, y, 0))
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		k.root.add_child(mi)
