extends Node
## Walkability audit: samples every walkable surface of the built city with the
## real physics world, links surfaces the player capsule can actually walk between,
## and reports what does not add up.
##
##   godot --headless res://tests/audit.tscn          (~1-2 min)
##
## Method: a 1 m grid of downward rays finds every walkable surface layer (roofs, decks,
## floors under bridges...). A node is kept only if the player capsule fits there. Two
## neighbouring nodes are joined when a capsule cast between them is clear and the
## height change is a legal step (<= STEP) or a straight ramp. Flood fill from the spawn
## then classifies every other surface:
##   WALK    reachable on foot from the spawn
##   HOP     one jump (<= HOP_UP) beyond walkable ground
##   DASH    reachable through dash chains from things already reachable (parkour)
##   DROP    only reachable by falling: a trap unless a way back exists
##   ORPHAN  nothing in reach: a floating or sealed-off surface -> probably a bug
## Extra findings: LIP (a 0.14-0.6 m step blocking otherwise-continuous ground), CRAWL
## (spots where the capsule does not fit but a crouched one would).

const X0 := -300.0
const X1 := 300.0
const Z0 := -250.0
const Z1 := 490.0
const CELL := 1.0
const TOP_Y := 260.0
const STEP := 0.14
const HOP_UP := 1.6
const DASH_REACH := 20.0
const DASH_RISE := 18.0
const MIN_AREA := 4          # ignore islands smaller than this many m^2 (bench tops, crates)
const CAP_R := 0.35
const CAP_H := 1.8
const MAX_LAYERS := 14
const MIN_WALK_NY := 0.643   # cos(50 deg), matches Fighter.floor_max_angle

var nx := 0
var nz := 0
var space: PhysicsDirectSpaceState3D
var cap := CapsuleShape3D.new()
var crouch := CapsuleShape3D.new()

var ys := PackedFloat32Array()
var col_of := PackedInt32Array()
var col_start := PackedInt32Array()
var parent := PackedInt32Array()
var lips: Array = []   # [a, b, dy]
var crawl: Array = []  # node positions


func _ready() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("headless_test", true)
	add_child(main)
	await get_tree().physics_frame
	await get_tree().physics_frame
	main.controller.enabled = false
	space = main.get_world_3d().direct_space_state
	cap.radius = CAP_R
	cap.height = CAP_H
	crouch.radius = CAP_R
	crouch.height = 0.9
	var t0 := Time.get_ticks_msec()
	_sample()
	print("sampled %d nodes in %.1fs" % [ys.size(), (Time.get_ticks_msec() - t0) / 1000.0])
	t0 = Time.get_ticks_msec()
	_link()
	print("linked in %.1fs" % ((Time.get_ticks_msec() - t0) / 1000.0))
	var start: Vector3 = main.player.global_position
	_report(start)
	get_tree().quit()


func _pos(n: int) -> Vector3:
	var c := col_of[n]
	return Vector3(X0 + (c / nz + 0.5) * CELL, ys[n], Z0 + (c % nz + 0.5) * CELL)


func _query(shape: Shape3D, p: Vector3, lift: float) -> PhysicsShapeQueryParameters3D:
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.collision_mask = Fighter.LAYER_WORLD
	q.transform = Transform3D(Basis.IDENTITY, p + Vector3(0, lift + (CAP_H if shape == cap else 0.9) * 0.5, 0))
	return q


func _sample() -> void:
	nx = int((X1 - X0) / CELL)
	nz = int((Z1 - Z0) / CELL)
	col_start.resize(nx * nz + 1)
	var rq := PhysicsRayQueryParameters3D.new()
	rq.collision_mask = Fighter.LAYER_WORLD
	for ix in nx:
		for iz in nz:
			var ci := ix * nz + iz
			col_start[ci] = ys.size()
			var x := X0 + (ix + 0.5) * CELL
			var z := Z0 + (iz + 0.5) * CELL
			var y := TOP_Y
			for layer in MAX_LAYERS:
				rq.from = Vector3(x, y, z)
				rq.to = Vector3(x, -30.0, z)
				var r := space.intersect_ray(rq)
				if r.is_empty():
					break
				var hp: Vector3 = r.position
				var ny: float = (r.normal as Vector3).y
				y = hp.y - 0.04
				if ny < MIN_WALK_NY:
					continue
				var p := Vector3(x, hp.y, z)
				if space.intersect_shape(_query(cap, p, 0.06), 1).is_empty():
					ys.append(hp.y)
					col_of.append(ci)
				elif space.intersect_shape(_query(crouch, p, 0.06), 1).is_empty():
					crawl.append(p)
	col_start[nx * nz] = ys.size()
	parent.resize(ys.size())
	for i in parent.size():
		parent[i] = i


func _find(a: int) -> int:
	while parent[a] != a:
		parent[a] = parent[parent[a]]
		a = parent[a]
	return a


func _union(a: int, b: int) -> void:
	var ra := _find(a)
	var rb := _find(b)
	if ra != rb:
		parent[ra] = rb


## Can the player walk from node a to adjacent node b? Returns "" if yes, else a reason.
func _edge(a: int, b: int) -> String:
	var pa := _pos(a)
	var pb := _pos(b)
	var dy := pb.y - pa.y
	var ady := absf(dy)
	var q: PhysicsShapeQueryParameters3D
	if ady <= STEP:
		var lo := maxf(pa.y, pb.y)
		q = _query(cap, Vector3(pa.x, lo, pa.z), 0.06)
	else:
		if ady > 0.9:
			return "cliff"
		var mid := (pa + pb) * 0.5
		var rq := PhysicsRayQueryParameters3D.create(Vector3(mid.x, maxf(pa.y, pb.y) + 0.6, mid.z), Vector3(mid.x, minf(pa.y, pb.y) - 0.6, mid.z), Fighter.LAYER_WORLD)
		var r := space.intersect_ray(rq)
		if r.is_empty() or absf((r.position as Vector3).y - mid.y) > 0.07:
			return "step"
		q = _query(cap, pa, 0.08)
	q.motion = Vector3(pb.x - pa.x, 0.0 if ady <= STEP else dy, pb.z - pa.z)
	var res := space.cast_motion(q)
	if res.size() >= 2 and res[0] < 1.0:
		return "blocked"
	return ""


func _link() -> void:
	for ix in nx:
		for iz in nz:
			var ci := ix * nz + iz
			for a in range(col_start[ci], col_start[ci + 1]):
				for d in 2:
					var jx := ix + (1 - d)
					var jz := iz + d
					if jx >= nx or jz >= nz:
						continue
					var cj := jx * nz + jz
					for b in range(col_start[cj], col_start[cj + 1]):
						var dy := absf(ys[b] - ys[a])
						if dy > 0.9:
							continue
						var why := _edge(a, b)
						if why == "":
							_union(a, b)
						elif why == "step" and dy <= 0.6:
							lips.append([a, b, ys[b] - ys[a]])


func _fmt(p: Vector3) -> String:
	return "(%.0f, %.1f, %.0f)" % [p.x, p.y, p.z]


func _report(start: Vector3) -> void:
	# nearest node under the spawn
	var sn := -1
	var best := 1e9
	var sc := int((start.x - X0) / CELL) * nz + int((start.z - Z0) / CELL)
	for n in range(col_start[sc], col_start[sc + 1]):
		if absf(ys[n] - start.y) < best:
			best = absf(ys[n] - start.y)
			sn = n
	var out: PackedStringArray = []
	if sn < 0:
		print("AUDIT: no walkable node under the spawn!")
		return
	var walk_root := _find(sn)
	# component stats
	var comp := {}   # root -> {n, min, max, sample}
	for n in ys.size():
		var r := _find(n)
		var p := _pos(n)
		if not comp.has(r):
			comp[r] = {"n": 0, "lo": Vector3(p), "hi": Vector3(p), "y0": p.y, "y1": p.y, "sample": p}
		var c: Dictionary = comp[r]
		c.n += 1
		c.lo = Vector3(minf(c.lo.x, p.x), 0.0, minf(c.lo.z, p.z))
		c.hi = Vector3(maxf(c.hi.x, p.x), 0.0, maxf(c.hi.z, p.z))
		c.y0 = minf(c.y0, p.y)
		c.y1 = maxf(c.y1, p.y)
	var reached := {walk_root: "WALK"}
	# HOP: unreached surface within 2 m horizontally of reached surface and <= HOP_UP above
	var drops := {}
	var changed := true
	var round_i := 0
	while changed:
		changed = false
		round_i += 1
		var found := {}
		for n in ys.size():
			var rn := _find(n)
			if reached.has(rn):
				continue
			var p := _pos(n)
			var ix := int((p.x - X0) / CELL)
			var iz := int((p.z - Z0) / CELL)
			for dx in range(-2, 3):
				for dz in range(-2, 3):
					var jx := ix + dx
					var jz := iz + dz
					if jx < 0 or jz < 0 or jx >= nx or jz >= nz:
						continue
					var cj := jx * nz + jz
					for m in range(col_start[cj], col_start[cj + 1]):
						if not reached.has(_find(m)):
							continue
						if p.y - ys[m] <= HOP_UP:
							if p.y - ys[m] >= -0.0:
								found[rn] = "HOP"
							else:
								drops[rn] = true
						elif p.y - ys[m] < 0.0:
							drops[rn] = true
		for r in found:
			reached[r] = found[r]
			changed = true
	# DASH: coarse bins (4 m x 4 m x 3 m bands) of everything reachable so far
	var bins := {}
	var add_bins := func(r: int) -> void:
		pass
	var comp_nodes := {}
	for n in ys.size():
		var r := _find(n)
		if not comp_nodes.has(r):
			comp_nodes[r] = PackedInt32Array()
		comp_nodes[r].append(n)
	for r in reached:
		for n: int in comp_nodes[r]:
			var p := _pos(n)
			var key := Vector2i(int(floor(p.x / 4.0)), int(floor(p.z / 4.0)))
			if not bins.has(key):
				bins[key] = {}
			bins[key][int(floor(p.y / 3.0))] = true
	changed = true
	while changed:
		changed = false
		var found2 := {}
		for r in comp:
			if reached.has(r) or comp[r].n < MIN_AREA:
				continue
			var ok := false
			var stride := maxi(1, comp[r].n / 60)
			var idx := 0
			for n: int in comp_nodes[r]:
				idx += 1
				if idx % stride != 0:
					continue
				var p := _pos(n)
				var bx := int(floor(p.x / 4.0))
				var bz := int(floor(p.z / 4.0))
				for dx in range(-5, 6):
					for dz in range(-5, 6):
						var key := Vector2i(bx + dx, bz + dz)
						if not bins.has(key):
							continue
						for band: int in bins[key]:
							var by := band * 3.0
							if p.y - by <= DASH_RISE and p.y - by >= -4.0 and Vector2(dx, dz).length() * 4.0 <= DASH_REACH:
								ok = true
								break
						if ok:
							break
					if ok:
						break
				if ok:
					break
			if ok:
				found2[r] = "DASH"
		for r in found2:
			reached[r] = "DASH"
			changed = true
			for n: int in comp_nodes[r]:
				var p := _pos(n)
				var key := Vector2i(int(floor(p.x / 4.0)), int(floor(p.z / 4.0)))
				if not bins.has(key):
					bins[key] = {}
				bins[key][int(floor(p.y / 3.0))] = true
	# ---- print ----
	var counts := {"WALK": 0, "HOP": 0, "DASH": 0, "DROP": 0, "ORPHAN": 0}
	var walk_area := 0
	var rows := {"HOP": [], "DASH": [], "DROP": [], "ORPHAN": []}
	for r in comp:
		var c: Dictionary = comp[r]
		var tier := "WALK" if r == walk_root else String(reached.get(r, ""))
		if tier == "":
			tier = "DROP" if drops.has(r) else "ORPHAN"
		if tier == "WALK":
			walk_area = c.n
			counts.WALK = c.n
			continue
		if c.n < MIN_AREA:
			continue
		counts[tier] += c.n
		rows[tier].append(c)
	print("\n=== WALKABILITY AUDIT ===")
	print("spawn %s | walkable network: %d m2 | nodes total %d" % [_fmt(start), walk_area, ys.size()])
	print("surface area by tier (m2, islands >= %d): HOP %d  DASH %d  DROP %d  ORPHAN %d" % [MIN_AREA, counts.HOP, counts.DASH, counts.DROP, counts.ORPHAN])
	for tier: String in ["ORPHAN", "DROP", "HOP"]:
		var list: Array = rows[tier]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.n > b.n)
		print("\n-- %s: %d islands --" % [tier, list.size()])
		for i in mini(list.size(), 40):
			var c: Dictionary = list[i]
			print("  %5d m2  x %.0f..%.0f  z %.0f..%.0f  y %.1f..%.1f  e.g. %s" % [c.n, c.lo.x, c.hi.x, c.lo.z, c.hi.z, c.y0, c.y1, _fmt(c.sample)])
	print("\n-- DASH-only (parkour) islands: %d, %d m2 (expected: rooftops, canopies, ledges) --" % [rows.DASH.size(), counts.DASH])
	# LIP: a small step that separates walkable ground from an unreached but big area
	var lip_seen := {}
	print("\n-- LIP: steps of 0.14-0.6 m between walkable ground and a region that is otherwise cut off --")
	for l: Array in lips:
		var ra := _find(l[0])
		var rb := _find(l[1])
		if ra == rb:
			continue
		var wa := reached.get(ra, "") == "WALK" or ra == walk_root
		var wb := reached.get(rb, "") == "WALK" or rb == walk_root
		if wa == wb:
			continue
		var other := rb if wa else ra
		if comp[other].n < 8 or lip_seen.has(other):
			continue
		lip_seen[other] = true
		print("  step %.2f m at %s  (cuts off %d m2)" % [absf(l[2]), _fmt(_pos(l[0])), comp[other].n])
	if lip_seen.is_empty():
		print("  none")
	# CRAWL clusters
	var cl := {}
	for p: Vector3 in crawl:
		var key := Vector3i(int(p.x / 8.0), int(p.y / 4.0), int(p.z / 8.0))
		if not cl.has(key):
			cl[key] = [0, p]
		cl[key][0] += 1
	print("\n-- CRAWL: places where you'd fit only crouched (headroom < 1.8 m): %d clusters --" % cl.size())
	var ck := cl.keys()
	ck.sort_custom(func(a: Vector3i, b: Vector3i) -> bool: return cl[a][0] > cl[b][0])
	for i in mini(ck.size(), 15):
		print("  %4d cells near %s" % [cl[ck[i]][0], _fmt(cl[ck[i]][1])])
	var text := "audit done"
	print("\n" + text)
	DirAccess.make_dir_recursive_absolute("res://tests/out")
