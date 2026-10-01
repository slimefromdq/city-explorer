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
