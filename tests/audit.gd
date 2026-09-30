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
const FAIL_AREA := 20        # unexplained HOP/DROP/ORPHAN islands at least this big fail the audit
const THIN := 2.0            # islands no wider than this (rail tops, parapets, kerbs) are never a problem
const ALLOW_PATH := "res://tests/audit_allow.json"
const GROUND_Y := 4.0        # teleport points below this height must be walkable from the spawn
const ELEVATED := 6.0        # islands whose lowest point is above this are aerial (roof networks, rings): parkour by design; the "must_walk" list guards the ones that are meant to be walked
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
var rejects: Array = []  # [a, b, reason] for every refused neighbour pair (<= 0.9 m apart vertically)
var crawl: Array = []  # node positions
var main_node: Node3D
var verbose := OS.get_environment("AUDIT_VERBOSE") == "1"


func _ready() -> void:
	var main: Node3D = load("res://main.tscn").instantiate()
	main_node = main
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
	var probe := OS.get_environment("PROBE").split(",", false)   # PROBE=x0,z0,x1,z1 prints the nodes along a line ('W' = walkable from the spawn)
	if probe.size() == 4:
		var wr := _find(_spawn_node(start))
		var pa := Vector2(float(probe[0]), float(probe[1]))
		var pb := Vector2(float(probe[2]), float(probe[3]))
		for i in int(pa.distance_to(pb)) + 1:
			var pt := pa.lerp(pb, float(i) / maxf(1.0, pa.distance_to(pb)))
			var ci := int((pt.x - X0) / CELL) * nz + int((pt.y - Z0) / CELL)
			var row := ""
			for n in range(col_start[ci], col_start[ci + 1]):
				row += "  %.2f%s" % [ys[n], "W" if _find(n) == wr else "."]
			print("(%.0f,%.0f)%s" % [pt.x, pt.y, row])
	var edge_env := OS.get_environment("EDGE").split(";", false)   # EDGE=x,y,z;x,y,z explains why two neighbouring spots are (not) linked
	if edge_env.size() == 2:
		var pa := edge_env[0].split(",")
		var pb := edge_env[1].split(",")
		var na := _node_near(Vector3(float(pa[0]), float(pa[1]), float(pa[2])))
		var nb := _node_near(Vector3(float(pb[0]), float(pb[1]), float(pb[2])))
		print("EDGE nodes %s -> %s : %s" % [_fmt(_pos(na)) if na >= 0 else "none", _fmt(_pos(nb)) if nb >= 0 else "none", "linked" if (na >= 0 and nb >= 0 and _edge(na, nb) == "") else (_edge(na, nb) if na >= 0 and nb >= 0 else "missing node")])
	var failures := _report(start)
	get_tree().quit(1 if failures > 0 else 0)


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
		if ix % 25 == 0:
			print("  sampling column %d/%d  (%d nodes)" % [ix, nx, ys.size()])
		for iz in nz:
			var ci := ix * nz + iz
			col_start[ci] = ys.size()
			var x := X0 + (ix + 0.5) * CELL
			var z := Z0 + (iz + 0.5) * CELL
			var y := TOP_Y
			var layers := 0
			for iter in 60:
				if layers >= MAX_LAYERS:
					break
				rq.from = Vector3(x, y, z)
				rq.to = Vector3(x, -30.0, z)
				var r := space.intersect_ray(rq)
				if r.is_empty():
					break
				var hp: Vector3 = r.position
				var nrm: Vector3 = r.normal
				if nrm == Vector3.ZERO:
					# the ray started inside a solid: find the underside we exit through
					y = _exit_solid(x, z, hp.y)
					if y < -30.0:
						break
					continue
				var ny := nrm.y
				y = hp.y - 0.04
				if ny < MIN_WALK_NY:
					continue
				layers += 1
				var p := Vector3(x, hp.y, z)
				# on a slope the capsule's round foot needs r*(1/cos - 1) extra clearance to not touch the surface
				var lift := 0.06 + CAP_R * (1.0 / maxf(ny, 0.5) - 1.0)
				if space.intersect_shape(_query(cap, p, lift), 1).is_empty():
					ys.append(hp.y)
					col_of.append(ci)
				elif space.intersect_shape(_query(crouch, p, lift), 1).is_empty():
					crawl.append(p)
	col_start[nx * nz] = ys.size()
	parent.resize(ys.size())
	for i in parent.size():
		parent[i] = i


## y is inside a solid. Probe upward from further and further below until the ray starts in
## clear space; the first thing it hits is an underside, and we continue scanning below it.
func _exit_solid(x: float, z: float, y: float) -> float:
	var d := 0.3
	while y - d > -30.0:
		var rq := PhysicsRayQueryParameters3D.create(Vector3(x, y - d, z), Vector3(x, y, z), Fighter.LAYER_WORLD)
		var r := space.intersect_ray(rq)
		if r.is_empty():
			return y - d
		if (r.normal as Vector3) != Vector3.ZERO:
			return (r.position as Vector3).y - 0.03
		d *= 2.0
	return -99.0


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
		# a ramp is a continuous surface: sample it every 10 cm and reject any jump > 12 cm (~50 deg)
		var prev := pa.y
		for i in 10:
			var sp := pa.lerp(pb, (i + 0.37) / 10.0)   # off the exact midpoint: shape seams sit on cell borders and a ray can slip through
			var rq := PhysicsRayQueryParameters3D.create(Vector3(sp.x, maxf(pa.y, pb.y) + 0.6, sp.z), Vector3(sp.x, minf(pa.y, pb.y) - 0.6, sp.z), Fighter.LAYER_WORLD)
			var r := space.intersect_ray(rq)
			if r.is_empty() or absf((r.position as Vector3).y - prev) > 0.12:
				return "step"
			prev = (r.position as Vector3).y
		if absf(pb.y - prev) > 0.12:
			return "step"
		q = _query(cap, pa, 0.35)   # slopes kink at their feet/tops (a straight chord cuts the corner): give the capsule 35 cm of clearance
	q.motion = Vector3(pb.x - pa.x, 0.0 if ady <= STEP else dy, pb.z - pa.z)
	var res := space.cast_motion(q)
	if res.size() >= 2 and res[0] < 1.0:
		return "blocked"
	return ""


func _link() -> void:
	for ix in nx:
		if ix % 25 == 0:
			print("  linking column %d/%d  (%d lips)" % [ix, nx, lips.size()])
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
						else:
							rejects.append([a, b, why])
							if why == "step" and dy <= 0.6:
								lips.append([a, b, ys[b] - ys[a]])


## Nearest node to the spawn, preferring the right height (the ground under a pillar can be missing).
func _spawn_node(start: Vector3) -> int:
	var sn := -1
	var best := 1e9
	var six := int((start.x - X0) / CELL)
	var siz := int((start.z - Z0) / CELL)
	for dx in range(-6, 7):
		for dz in range(-6, 7):
			var sc := (six + dx) * nz + siz + dz
			for n in range(col_start[sc], col_start[sc + 1]):
				var score := absf(ys[n] - start.y) * 3.0 + Vector2(dx, dz).length()
				if score < best:
					best = score
					sn = n
	return sn


## Nearest node within 2 cells / 1.2 m of a world point, or -1.
func _node_near(pos: Vector3) -> int:
	var best := 1e9
	var found := -1
	var ix := int((pos.x - X0) / CELL)
	var iz := int((pos.z - Z0) / CELL)
	for dx in range(-2, 3):
		for dz in range(-2, 3):
			var sc := (ix + dx) * nz + iz + dz
			if sc < 0 or sc >= nx * nz:
				continue
			for n in range(col_start[sc], col_start[sc + 1]):
				var dy := absf(ys[n] - pos.y)
				if dy <= 1.2 and dy + Vector2(dx, dz).length() * 0.3 < best:
					best = dy + Vector2(dx, dz).length() * 0.3
					found = n
	return found


func _fmt(p: Vector3) -> String:
	return "(%.0f, %.1f, %.0f)" % [p.x, p.y, p.z]


func _report(start: Vector3) -> int:
	# nearest node under the spawn
	var sn := _spawn_node(start)
	var out: PackedStringArray = []
	if sn < 0:
		print("AUDIT FAILED: no walkable node under the spawn!")
		return 1
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
	print("spawn node %s -> walk comp: %d m2, y %.1f..%.1f, x %.0f..%.0f z %.0f..%.0f" % [_fmt(_pos(sn)), comp[walk_root].n, comp[walk_root].y0, comp[walk_root].y1, comp[walk_root].lo.x, comp[walk_root].hi.x, comp[walk_root].lo.z, comp[walk_root].hi.z])
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
	var tier_of := {}
	var counts := {"WALK": 0, "HOP": 0, "DASH": 0, "DROP": 0, "ORPHAN": 0, "TOWER": 0, "OUTSIDE": 0}
	var walk_area := 0
	var rows := {"HOP": [], "DASH": [], "DROP": [], "ORPHAN": [], "TOWER": [], "OUTSIDE": []}
	for r in comp:
		var c: Dictionary = comp[r]
		var tier := "WALK" if r == walk_root else String(reached.get(r, ""))
		if tier == "":
			tier = "DROP" if drops.has(r) else "ORPHAN"
		if tier == "ORPHAN":
			if c.hi.z < -213.0:
				tier = "OUTSIDE"   # skyline backdrop beyond the north wall
			else:
				var nodes: PackedInt32Array = comp_nodes[r]
				var stride := maxi(1, nodes.size() / 8)
				for k in range(0, nodes.size(), stride):
					var pq := PhysicsPointQueryParameters3D.new()
					pq.position = _pos(nodes[k]) + Vector3(0, -0.6, 0)
					pq.collision_mask = Fighter.LAYER_WORLD
					if not space.intersect_point(pq, 1).is_empty():
						tier = "TOWER"   # a solid roof top: reached by wall-run / dash climbing up its walls
						break
		tier_of[r] = tier
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
	print("surface area by tier (m2, islands >= %d): HOP %d  DASH %d  TOWER %d  DROP %d  ORPHAN %d  (outside the walls: %d)" % [MIN_AREA, counts.HOP, counts.DASH, counts.TOWER, counts.DROP, counts.ORPHAN, counts.OUTSIDE])
	for tier: String in ["ORPHAN", "DROP", "HOP", "TOWER"]:
		var list: Array = rows[tier]
		list.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.n > b.n)
		if not verbose:
			continue
		print("\n-- %s: %d islands --" % [tier, list.size()])
		for i in mini(list.size(), 400):
			var c: Dictionary = list[i]
			print("  %5d m2  x %.0f..%.0f  z %.0f..%.0f  y %.1f..%.1f  e.g. %s" % [c.n, c.lo.x, c.hi.x, c.lo.z, c.hi.z, c.y0, c.y1, _fmt(c.sample)])
	print("\n-- DASH-only (parkour) islands: %d, %d m2 (expected: rooftops, canopies, ledges) --" % [rows.DASH.size(), counts.DASH])
	if verbose:
		# LIP: a small step that separates walkable ground from an unreached but big area
		var lip_seen := {}
		print("\n-- LIP: steps of 0.14-0.6 m between walkable ground and a region that is otherwise cut off --")
		for l: Array in lips:
			var ra := _find(l[0])
			var rb := _find(l[1])
			if ra == rb:
				continue
			var wa: bool = reached.get(ra, "") == "WALK" or ra == walk_root
			var wb: bool = reached.get(rb, "") == "WALK" or rb == walk_root
			if wa == wb:
				continue
			var other := rb if wa else ra
			if comp[other].n < 8 or lip_seen.has(other):
				continue
			lip_seen[other] = true
			print("  step %.2f m at %s  (cuts off %d m2)" % [absf(l[2]), _fmt(_pos(l[0])), comp[other].n])
		if lip_seen.is_empty():
			print("  none")
		# BOUNDARY: what separates the spawn's network from the rest?
		var bd := {}
		for rj: Array in rejects:
			var ra2 := _find(rj[0])
			var rb2 := _find(rj[1])
			if ra2 == rb2 or (ra2 != walk_root and rb2 != walk_root):
				continue
			var p2 := _pos(rj[0])
			var key2 := "%s @ %d,%d" % [rj[2], int(floor(p2.x / 12.0)) * 12, int(floor(p2.z / 12.0)) * 12]
			if not bd.has(key2):
				bd[key2] = [0, p2, absf(ys[rj[1]] - ys[rj[0]])]
			bd[key2][0] += 1
		var bk := bd.keys()
		bk.sort_custom(func(a: String, b: String) -> bool: return bd[a][0] > bd[b][0])
		print("\n-- BOUNDARY of the spawn network (refused links out of it): %d spots --" % bk.size())
		for i in mini(bk.size(), 40):
			print("  %4d x %s near %s dy=%.2f" % [bd[bk[i]][0], String(bk[i]).split(" @")[0], _fmt(bd[bk[i]][1]), bd[bk[i]][2]])
		# MAP: '#' = spawn network, 'o' = other ground-level surface (y < 4), ' ' = nothing
		var B := 10.0
		var gw := int((X1 - X0) / B)
		var gh := int((Z1 - Z0) / B)
		var grid := PackedByteArray()
		grid.resize(gw * gh)
		for n in ys.size():
			var pp := _pos(n)
			var gi := int((pp.z - Z0) / B) * gw + int((pp.x - X0) / B)
			if _find(n) == walk_root:
				grid[gi] = 2
			elif pp.y < 4.0 and grid[gi] == 0:
				grid[gi] = 1
		print("\n-- MAP (10 m cells, x -300..300 left to right, z -250..490 top to bottom) --")
		for gz in gh:
			var line := ""
			for gx in gw:
				line += " o#"[grid[gz * gw + gx]]
			print("%4d %s" % [int(Z0 + gz * B), line])
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
	# ---- verdict: every HOP / DROP / ORPHAN island must be explained by the allowlist ----
	var allow: Array = []
	var must: Array = []
	var af := FileAccess.open(ALLOW_PATH, FileAccess.READ)
	if af != null:
		var parsed: Variant = JSON.parse_string(af.get_as_text())
		if parsed is Dictionary:
			allow = parsed.get("allow", [])
			must = parsed.get("must_walk", [])
	var used := PackedInt32Array()
	used.resize(allow.size())
	var failures := 0
	for tier: String in ["HOP", "DROP", "ORPHAN"]:
		for c: Dictionary in rows[tier]:
			if c.n < FAIL_AREA or minf(c.hi.x - c.lo.x, c.hi.z - c.lo.z) <= THIN or c.y0 > ELEVATED:
				continue
			var center := Vector2((c.lo.x + c.hi.x) * 0.5, (c.lo.z + c.hi.z) * 0.5)
			var hit := -1
			for i in allow.size():
				var a: Dictionary = allow[i]
				var rc: Array = a.rect
				var yr: Array = a.get("y", [-1000.0, 1000.0])
				if a.tier == tier and Rect2(rc[0], rc[1], rc[2] - rc[0], rc[3] - rc[1]).has_point(center) and c.y0 <= yr[1] and c.y1 >= yr[0]:
					hit = i
					break
			if hit >= 0:
				used[hit] += 1
			else:
				failures += 1
				print("  UNEXPLAINED %s island: %d m2  x %.0f..%.0f  z %.0f..%.0f  y %.1f..%.1f  e.g. %s" % [tier, c.n, c.lo.x, c.hi.x, c.lo.z, c.hi.z, c.y0, c.y1, _fmt(c.sample)])
	for i in allow.size():
		if used[i] == 0:
			print("  note: allowlist entry matches nothing any more (remove it?): %s" % allow[i].why)
	# ---- every teleport point must have a floor, and ground-level ones must be walkable ----
	var tps: Array = (main_node.get("city") as Object).get("markers")["tp"]
	for t: Array in tps:
		var tp: Vector3 = t[1]
		var n := _node_near(tp)
		if n < 0:
			failures += 1
			print("  BAD teleport point '%s' %s: no walkable floor within reach (inside geometry, or floating)" % [t[0], _fmt(tp)])
		elif tp.y < GROUND_Y and String(tier_of.get(_find(n), "")) != "WALK":
			failures += 1
			print("  BAD teleport point '%s' %s: ground-level but not walkable from the spawn (%s)" % [t[0], _fmt(tp), tier_of.get(_find(n), "?")])
	# ---- places that are designed to be walked (stairs, galleries, rings, decks) must be on the network ----
	for m: Dictionary in must:
		var mp := Vector3.ZERO
		var mname: String = m.get("name", m.get("tp", "?"))
		if m.has("tp"):
			var found_tp := false
			for t: Array in tps:
				if t[0] == m.tp:
					mp = t[1]
					found_tp = true
			if not found_tp:
				failures += 1
				print("  BAD must_walk: no teleport point called '%s'" % m.tp)
				continue
		else:
			mp = Vector3(m.p[0], m.p[1], m.p[2])
		var mn := _node_near(mp)
		if mn < 0:
			failures += 1
			print("  BAD must_walk '%s' %s: no floor there (moved geometry?)" % [mname, _fmt(mp)])
		elif _find(mn) != walk_root:
			failures += 1
			print("  BAD must_walk '%s' %s: not reachable on foot from the spawn (%s)" % [mname, _fmt(mp), tier_of.get(_find(mn), "?")])
	print("teleport points by tier:")
	var tp_line := ""
	for t: Array in tps:
		var tn := _node_near(t[1])
		tp_line += "  %s=%s" % [t[0], tier_of.get(_find(tn), "-") if tn >= 0 else "NONE"]
	print(tp_line)
	print("\n%s: %d unexplained problems, %d allowlisted islands" % ["AUDIT PASSED" if failures == 0 else "AUDIT FAILED", failures, used.size() - used.count(0)])
	return failures
