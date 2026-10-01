# Geo2D - small 2D geometry helpers.
#
# One job: answer geometric questions about the layout data.
# WHY a shared file: "is this point in that polygon / in the river?" comes up in
# every phase (validator now, lots and sightlines later). One copy, one behaviour.
# Godot already ships the hard parts (Geometry2D); this file only adds the few
# city-specific questions on top.
extends RefCounted


# Shoelace formula: area of a simple polygon (always positive).
static func polygon_area(poly: PackedVector2Array) -> float:
	var sum := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		sum += a.x * b.y - b.x * a.y
	return absf(sum) * 0.5


# Area shared by two polygons. Exact (uses polygon clipping), so shared edges
# between neighbouring districts correctly count as zero overlap.
static func overlap_area(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var total := 0.0
	for piece in Geometry2D.intersect_polygons(a, b):
		total += polygon_area(piece)
	return total


static func polygon_centroid(poly: PackedVector2Array) -> Vector2:
	var cx := 0.0
	var cy := 0.0
	var area2 := 0.0
	for i in poly.size():
		var a := poly[i]
		var b := poly[(i + 1) % poly.size()]
		var cross := a.x * b.y - b.x * a.y
		area2 += cross
		cx += (a.x + b.x) * cross
		cy += (a.y + b.y) * cross
	if is_zero_approx(area2):
		return poly[0]
	return Vector2(cx, cy) / (3.0 * area2)


# A good spot for a district's name. The centroid of a concave (L-shaped)
# polygon can fall outside it, so instead test a grid of points and take the
# one deepest inside (farthest from every edge).
static func label_point(poly: PackedVector2Array, step: float = 20.0) -> Vector2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	var best := polygon_centroid(poly)
	var best_depth := -1.0
	var y := box.position.y
	while y <= box.end.y:
		var x := box.position.x
		while x <= box.end.x:
			var p := Vector2(x, y)
			if Geometry2D.is_point_in_polygon(p, poly):
				var depth := INF
				for i in poly.size():
					var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
					depth = minf(depth, p.distance_to(q))
				if depth > best_depth:
					best_depth = depth
					best = p
			x += step
		y += step
	return best


# Distance from point p to the river BANK. River path points are [x, y, width];
# the width is interpolated along each segment, so a widening river is handled.
# Negative result = p is inside the water.
static func river_clearance(p: Vector2, path: Array) -> float:
	var best := INF
	for i in range(path.size() - 1):
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var t := 0.0 if a == b else a.distance_to(q) / a.distance_to(b)
		var half := lerpf(float(path[i][2]), float(path[i + 1][2]), t) * 0.5
		best = minf(best, p.distance_to(q) - half)
	return best


# All points where the segment a-b crosses a polyline (e.g. a road crossing the river).
static func crossings(a: Vector2, b: Vector2, polyline: PackedVector2Array) -> Array[Vector2]:
	var found: Array[Vector2] = []
	for i in range(polyline.size() - 1):
		var hit = Geometry2D.segment_intersects_segment(a, b, polyline[i], polyline[i + 1])
		if hit != null:
			found.append(hit)
	return found


# Signed distance from p to a polygon's outline: negative inside, positive outside.
static func polygon_signed_distance(p: Vector2, poly: PackedVector2Array) -> float:
	var best := INF
	for i in poly.size():
		var q := Geometry2D.get_closest_point_to_segment(p, poly[i], poly[(i + 1) % poly.size()])
		best = minf(best, p.distance_to(q))
	return -best if Geometry2D.is_point_in_polygon(p, poly) else best


# Distance from p to the nearest point on a polyline (tunnel, metro line...).
static func polyline_distance(p: Vector2, line: PackedVector2Array) -> float:
	var best := INF
	for i in range(line.size() - 1):
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, line[i], line[i + 1])))
	return best


# Clearance to ANY water: the river or the harbour basin (negative = in the water).
static func water_clearance(p: Vector2, river_path: Array, basin: PackedVector2Array) -> float:
	return minf(river_clearance(p, river_path), polygon_signed_distance(p, basin))


# Height and steepness of a metro path [[x, y, h], ...] at the point nearest to p.
# If p touches two segments (a vertex), the flatter one wins: a platform sits on
# level track, so that is the sensible reading.
static func track_at(p: Vector2, path: Array) -> Dictionary:
	var best := {"dist": INF, "height": 0.0, "grade": INF}
	for i in range(path.size() - 1):
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var q := Geometry2D.get_closest_point_to_segment(p, a, b)
		var d := p.distance_to(q)
		var length := a.distance_to(b)
		var t := 0.0 if length == 0.0 else a.distance_to(q) / length
		var grade := absf(float(path[i + 1][2]) - float(path[i][2])) / maxf(length, 0.001)
		var closer: bool = d < float(best["dist"]) - 0.5
		var tie_flatter: bool = absf(d - float(best["dist"])) <= 0.5 and grade < float(best["grade"])
		if closer or tie_flatter:
			best = {"dist": d, "height": lerpf(float(path[i][2]), float(path[i + 1][2]), t), "grade": grade}
	return best


# The river as a filled polygon (variable width): one quad per segment plus a disc at each
# joint, merged into one shape. Matches river_clearance() to within a metre or two.
static func river_polygon(path: Array) -> PackedVector2Array:
	var shapes: Array = []
	for i in range(path.size() - 1):
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var n := (b - a).orthogonal().normalized()
		var ha := float(path[i][2]) * 0.5
		var hb := float(path[i + 1][2]) * 0.5
		shapes.append(PackedVector2Array([a + n * ha, b + n * hb, b - n * hb, a - n * ha]))
	for p in path:
		var disc := PackedVector2Array()
		for k in 24:
			disc.append(Vector2(p[0], p[1]) + Vector2.from_angle(TAU * k / 24.0) * float(p[2]) * 0.5)
		shapes.append(disc)
	return _union_all(shapes)


# River + harbour basin as one shape (they overlap where the river flows into the harbour).
static func water_polygon(river_path: Array, basin: PackedVector2Array) -> PackedVector2Array:
	return _union_all([river_polygon(river_path), basin])


# Merge overlapping polygons into one (the largest piece if there is any leftover hole).
static func _union_all(shapes: Array) -> PackedVector2Array:
	var acc: PackedVector2Array = shapes[0]
	for i in range(1, shapes.size()):
		var best := PackedVector2Array()
		var best_area := -1.0
		for piece in Geometry2D.merge_polygons(acc, shapes[i]):
			var area := polygon_area(piece)
			if area > best_area:
				best_area = area
				best = piece
		acc = best
	return acc


# Smallest rectangle (any rotation) that contains the polygon. Returns
# {"center": Vector2, "u": Vector2 (unit vector along the LONG side), "half": Vector2(half long, half short)}.
# Used to decide which way to cut a block into lots: always across its long side.
static func min_area_rect(poly: PackedVector2Array) -> Dictionary:
	var best := {}
	var best_area := INF
	for i in poly.size():
		var d := (poly[(i + 1) % poly.size()] - poly[i]).normalized()
		if d == Vector2.ZERO:
			continue
		var n := d.orthogonal()
		var lo_d := INF
		var hi_d := -INF
		var lo_n := INF
		var hi_n := -INF
		for p in poly:
			lo_d = minf(lo_d, p.dot(d))
			hi_d = maxf(hi_d, p.dot(d))
			lo_n = minf(lo_n, p.dot(n))
			hi_n = maxf(hi_n, p.dot(n))
		var area := (hi_d - lo_d) * (hi_n - lo_n)
		if area < best_area:
			best_area = area
			var center := d * (lo_d + hi_d) * 0.5 + n * (lo_n + hi_n) * 0.5
			var half_d := (hi_d - lo_d) * 0.5
			var half_n := (hi_n - lo_n) * 0.5
			best = {"center": center, "u": d, "half": Vector2(half_d, half_n)} if half_d >= half_n \
				else {"center": center, "u": n, "half": Vector2(half_n, half_d)}
	return best


# Where does the 2D segment a->b pass through a rotated rectangle? The rectangle is given by its
# centre, long axis u and half-sizes. Returns Vector2(t_in, t_out) (0 = at a, 1 = at b), or
# Vector2(-1, -1) if the segment misses it. Used by the line-of-sight checks.
static func segment_rect_overlap(a: Vector2, b: Vector2, center: Vector2, u: Vector2, half: Vector2) -> Vector2:
	var v := u.orthogonal()
	var pa := Vector2((a - center).dot(u), (a - center).dot(v))
	var pb := Vector2((b - center).dot(u), (b - center).dot(v))
	var d := pb - pa
	var t0 := 0.0
	var t1 := 1.0
	for axis in 2:
		if absf(d[axis]) < 0.000001:
			if absf(pa[axis]) > half[axis]:
				return Vector2(-1.0, -1.0)
		else:
			var ta := (-half[axis] - pa[axis]) / d[axis]
			var tb := (half[axis] - pa[axis]) / d[axis]
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
			if t0 > t1:
				return Vector2(-1.0, -1.0)
	return Vector2(t0, t1)
