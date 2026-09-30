class_name RoofRoutes
extends RefCounted
## Rooftop network. Every lot registers its walkable roof (rect, height, clutter).
## Neighbouring roofs across an alley (6 m) or a street (18 m) whose heights are
## within 14 m get a steel catwalk: it leaves the higher roof at its own level,
## spans the gap with rails, sits on the lower roof on a solid support and
## finishes in a ramp DOWN onto the lower roof surface. So every route lands on
## walkable roof at both ends - no dead ends, no floating stubs.

const MAX_GAP := 26.0
const MAX_DY := 20.0
const WIDTH := 3.0
const EXT := 2.2
const RAMP_RATIO := 1.25       # metres of ramp run per metre of drop (~39 degrees)


static func build(parent: Node, walks: Array) -> Array:
	var links: Array = []
	var k := Kit.new(parent, "RoofRoutes")
	var steel := Mats.toon(Color(0.2, 0.22, 0.28), 0.5)
	var paint := Mats.paint(Color(1.0, 0.82, 0.15))
	var lightm := Mats.glow(Color(0.6, 0.9, 1.0), 2.4)
	var rng := RandomNumberGenerator.new()
	rng.seed = 424242
	var n := walks.size()
	for i in n:
		walks[i]["id"] = i
	for i in n:
		for j in range(i + 1, n):
			var made := _try_pair(k, walks[i], walks[j], walks, steel, paint, lightm, rng, links)
			if made > 0:
				continue
	StaticBatch.merge(k.root)
	return links


static func _try_pair(k: Kit, a: Dictionary, b: Dictionary, walks: Array, steel: Material, paint: Material, lightm: Material, rng: RandomNumberGenerator, links: Array) -> int:
	var ra: Rect2 = a.rect
	var rb: Rect2 = b.rect
	var ya: float = a.y
	var yb: float = b.y
	if absf(ya - yb) > MAX_DY:
		return 0
	var ox0 := maxf(ra.position.x, rb.position.x)
	var ox1 := minf(ra.end.x, rb.end.x)
	var oz0 := maxf(ra.position.y, rb.position.y)
	var oz1 := minf(ra.end.y, rb.end.y)
	var gap_x := maxf(rb.position.x - ra.end.x, ra.position.x - rb.end.x)
	var gap_z := maxf(rb.position.y - ra.end.y, ra.position.y - rb.end.y)
	var axis := ""
	if oz1 - oz0 >= 9.0 and gap_x > 0.5 and gap_x <= MAX_GAP:
		axis = "x"
	elif ox1 - ox0 >= 9.0 and gap_z > 0.5 and gap_z <= MAX_GAP:
		axis = "z"
	else:
		return 0
	var hi := a if ya >= yb else b
	var lo := b if ya >= yb else a
	var count := 1 if ((oz1 - oz0) if axis == "x" else (ox1 - ox0)) < 26.0 else 2
	var made := 0
	var lo0 := (oz0 if axis == "x" else ox0)
	var lo1 := (oz1 if axis == "x" else ox1)
	# candidate lateral positions across the shared overlap; keep the first clear ones
	var cands: Array = []
	for t in [0.5, 0.35, 0.65, 0.22, 0.78, 0.12, 0.88]:
		cands.append(lerpf(lo0, lo1, t))
	if count == 2:
		cands = [lerpf(lo0, lo1, 0.3), lerpf(lo0, lo1, 0.7), lerpf(lo0, lo1, 0.5), lerpf(lo0, lo1, 0.15), lerpf(lo0, lo1, 0.85)]
	var placed: Array = []
	for lat: float in cands:
		if made >= count:
			break
		var ok := true
		for pl: float in placed:
			if absf(pl - lat) < 8.0:
				ok = false
		if not ok or lat - WIDTH * 0.5 < lo0 + 1.0 or lat + WIDTH * 0.5 > lo1 - 1.0:
			continue
		var link := _route(k, hi, lo, axis, lat, walks, steel, paint, lightm)
		if not link.is_empty():
			placed.append(lat)
			links.append(link)
			made += 1
	return made


## Build one catwalk from `hi` down to `lo`. Returns {} when it would not fit.
static func _route(k: Kit, hi: Dictionary, lo: Dictionary, axis: String, lat: float, walks: Array, steel: Material, paint: Material, lightm: Material) -> Dictionary:
	var rh: Rect2 = hi.rect
	var rl: Rect2 = lo.rect
	var yh: float = hi.y
	var yl: float = lo.y
	var dy := maxf(yh - yl, 0.0)
	# direction of travel and the two facing edges
	var dir := 1.0
	var e_hi: float
	var e_lo: float
	var lo_len: float
	if axis == "x":
		dir = 1.0 if rh.end.x <= rl.position.x else -1.0
		e_hi = rh.end.x if dir > 0.0 else rh.position.x
		e_lo = rl.position.x if dir > 0.0 else rl.end.x
		lo_len = rl.size.x
	else:
		dir = 1.0 if rh.end.y <= rl.position.y else -1.0
		e_hi = rh.end.y if dir > 0.0 else rh.position.y
		e_lo = rl.position.y if dir > 0.0 else rl.end.y
		lo_len = rl.size.y
	var g := absf(e_lo - e_hi)
	var run := maxf(dy, 0.3) * RAMP_RATIO
	var lo_need := 1.2 + run + 1.5
	var hi_room := (rh.size.x if axis == "x" else rh.size.y)
	if lo_need > lo_len - 0.5 or EXT + 1.0 > hi_room:
		return {}
	# footprints (world XZ) must be clear of clutter and of tower footprints
	var foot_hi := _foot(axis, e_hi - dir * (EXT + 0.5), e_hi + dir * 0.3, lat)
	var foot_lo := _foot(axis, e_lo - dir * 0.3, e_lo + dir * (lo_need), lat)
	for r: Rect2 in hi.clutter:
		if r.intersects(foot_hi):
			return {}
	for r: Rect2 in lo.clutter:
		if r.intersects(foot_lo):
			return {}
	var av_h: Rect2 = hi.avoid
	var av_l: Rect2 = lo.avoid
	if av_h.size != Vector2.ZERO and av_h.intersects(foot_hi):
		return {}
	if av_l.size != Vector2.ZERO and av_l.intersects(foot_lo):
		return {}
	# a route must not run through a third building's roof
	var corridor := _foot(axis, minf(e_hi, e_lo), maxf(e_hi, e_lo), lat)
	for w: Dictionary in walks:
		if w != hi and w != lo and (w.rect as Rect2).intersects(corridor):
			return {}
	# fire escapes hang in the alleys: keep the deck clear of them
	for w: Dictionary in [hi, lo]:
		for e: Dictionary in w.get("escapes", []):
			if (e.rect as Rect2).intersects(corridor) and yh < float(e.top) + 1.5:
				return {}
	# local frame: +X runs from the hi roof edge toward the lo roof
	var origin := Vector3(e_hi, 0.0, lat) if axis == "x" else Vector3(lat, 0.0, e_hi)
	var yaw := 0.0
	if axis == "x":
		yaw = 0.0 if dir > 0.0 else 180.0
	else:
		yaw = -90.0 if dir > 0.0 else 90.0
	var c := k.sub("Route", origin, yaw)
	var deck_len := EXT + g + 1.2
	c.box(Vector3(-EXT + deck_len * 0.5, yh - 0.4, 0.0), Vector3(deck_len, 0.4, WIDTH), steel, true)
	for sgn: float in [-1.0, 1.0]:
		# rails only over the gap (roof edges stay open so you can hop on and off)
		c.box(Vector3(g * 0.5, yh, sgn * (WIDTH * 0.5 - 0.08)), Vector3(g + 0.6, 0.95, 0.16), steel, true)
		c.box(Vector3(-EXT + deck_len * 0.5, yh + 0.004, sgn * (WIDTH * 0.5 - 0.3)), Vector3(deck_len, 0.03, 0.2), paint, false, Vector3.ZERO, false)
	# underside truss + lights so the span reads as a structure
	c.box(Vector3(g * 0.5, yh - 1.5, 0.0), Vector3(g + 0.4, 1.1, 0.5), steel, false)
	c.box(Vector3(g * 0.5, yh - 0.55, 0.0), Vector3(maxf(g - 1.0, 0.5), 0.08, 1.4), lightm, false, Vector3.ZERO, false)
	# solid support where the deck meets the lower roof, then the ramp down onto it
	if yh - 0.4 - yl > 0.05:
		c.box(Vector3(g + 0.6, yl, 0.0), Vector3(1.2, yh - 0.4 - yl, WIDTH), steel, true)
	c.ramp(Vector3(g + 1.2, yh, 0.0), Vector3(g + 1.2 + run, yl, 0.0), WIDTH, dy + 0.5, steel)
	var world_a := c.root.to_global(Vector3(-1.0, yh + 0.5, 0.0))
	var world_b := c.root.to_global(Vector3(g + 1.2 + run + 0.7, yl + 0.5, 0.0))
	return {"a": world_a, "b": world_b, "dy": dy, "gap": g, "yh": yh, "yl": yl, "ids": [hi.id, lo.id]}


static func _foot(axis: String, u0: float, u1: float, lat: float) -> Rect2:
	var lo := minf(u0, u1)
	var len := absf(u1 - u0)
	if axis == "x":
		return Rect2(lo, lat - WIDTH * 0.5 - 0.3, len, WIDTH + 0.6)
	return Rect2(lat - WIDTH * 0.5 - 0.3, lo, WIDTH + 0.6, len)
