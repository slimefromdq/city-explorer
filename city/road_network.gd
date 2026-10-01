# RoadNetwork - turns the raw road lines in city.json into the real, drivable pieces.
#
# One job: decide WHERE roads actually exist. The JSON stores avenues, streets
# and diagonals as long ideal lines; this trims them with a few simple rules and
# hands back clean polylines. Both the 2D debug map and the 3D builder use it,
# so the picture and the world can never disagree about where a road is.
#
# The rules that keep the network tidy:
#   1. COAST ROAD: a ring road runs just inside the coast. Roads are cut off at it,
#      so every street ends in a proper T-junction instead of at a ragged shore.
#   2. EMBANKMENT: a road runs along both river banks and around the harbour basin.
#      Roads are cut off at it too, and bridges run from embankment to embankment.
#   3. NO-ROAD ZONES: districts and sites flagged "roads": false (park, plaza, station)
#      swallow the roads that cross them.
#   4. Tiny leftover fragments are thrown away.
# Cuts are exact (polygon clipping), not sampled, so ends land precisely on the road
# they meet. No terrain heights are needed: this is a pure 2D rule set.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

const ZONE_INSET := 4.0   # no-road zones are shrunk by this, so a road ON a zone's edge
                          # (e.g. the avenues along the park) is not cut away
const SNAP_REACH := 6.0   # a road end this close to a bridge end is joined to it exactly (m)
const MIN_PIECE := 60.0   # shorter road pieces are dropped (m)
const POINT_SPACING := 4.0  # road pieces get a point at least this often (m), so a road can follow the ground

# Each: {"id": String, "kind": "street"|"avenue"|"diagonal"|"ring"|"quay", "width": float,
#        "points": PackedVector2Array}
var segments: Array = []
# Each: {"id", "name", "width", "from": Vector2, "to": Vector2}
var bridges: Array = []

var interior: Array = []    # polygons: the land inside the coast road
var water_zone: Array = []  # polygons: river + harbour + the embankment margin
var _no_road: Array = []     # polygons where roads are not allowed


func _init(city: Dictionary) -> void:
	var roads: Dictionary = city["roads"]
	var water := Geo2D.water_polygon(city["river"]["path"], CityData.to_points(city["harbour"]["basin"]))
	interior = Geometry2D.offset_polygon(CityData.land_polygon(city), -float(roads["ring"]["inset"]), Geometry2D.JOIN_ROUND)
	water_zone = Geometry2D.offset_polygon(water, float(roads["quay"]["inset"]), Geometry2D.JOIN_ROUND)
	for group in [city["districts"], city["sites"]]:
		for area in group:
			if area.get("roads", true) == false:
				_no_road.append_array(Geometry2D.offset_polygon(CityData.to_points(area["polygon"]), -ZONE_INSET))
	for b in city["bridges"]:
		bridges.append({
			"id": b["id"], "name": b["name"], "width": float(b["width"]),
			"from": Vector2(b["from"][0], b["from"][1]), "to": Vector2(b["to"][0], b["to"][1]),
		})

	for line in _ideal_lines(city):
		var n := 0
		for piece in _trim([line["points"]]):
			if _length(piece) >= MIN_PIECE:
				segments.append(_segment("%s_%d" % [line["id"], n], line["kind"], line["width"], _snap_to_bridges(piece)))
				n += 1
	_add_ring(float(roads["ring"]["width"]))
	_add_quay(float(roads["quay"]["width"]))


# The uncut lines straight from the JSON.
func _ideal_lines(city: Dictionary) -> Array:
	var size := CityData.map_size(city)
	var roads: Dictionary = city["roads"]
	var lines: Array = []
	for y in roads["streets"]["y"]:
		lines.append({"id": "street_y%d" % int(y), "kind": "street", "width": float(roads["streets"]["width"]),
			"points": PackedVector2Array([Vector2(0, y), Vector2(size.x, y)])})
	for x in roads["avenues"]["x"]:
		lines.append({"id": "avenue_x%d" % int(x), "kind": "avenue", "width": float(roads["avenues"]["width"]),
			"points": PackedVector2Array([Vector2(x, 0), Vector2(x, size.y)])})
	for d in roads["diagonals"]:
		lines.append({"id": "diagonal_%s" % d["id"], "kind": "diagonal", "width": float(d["width"]),
			"points": CityData.to_points(d["path"])})
	return lines


# Trim grid roads: keep what is inside the coast road, then remove the water zone
# and the no-road zones. Works on a list of polylines so every step can split them.
func _trim(pieces: Array) -> Array:
	var inside: Array = []
	for piece in pieces:
		for poly in interior:
			inside.append_array(Geometry2D.intersect_polyline_with_polygon(piece, poly))
	return _subtract(_subtract(inside, water_zone), _no_road)


# Remove the parts of every polyline that lie inside any of the polygons.
func _subtract(pieces: Array, polygons: Array) -> Array:
	var current := pieces
	for poly in polygons:
		var next: Array = []
		for piece in current:
			next.append_array(Geometry2D.clip_polyline_with_polygon(piece, poly))
		current = next
	return current


# The coast road follows the inner coast line; it stops where the water zone (the
# river mouth) interrupts it.
func _add_ring(width: float) -> void:
	var n := 0
	for poly in interior:
		for piece in _subtract([_closed(poly)], water_zone):
			if _length(piece) >= MIN_PIECE:
				segments.append(_segment("ring_%d" % n, "ring", width, piece))
				n += 1


# The embankment follows the water zone's outline, but only the part on land.
func _add_quay(width: float) -> void:
	var n := 0
	for poly in water_zone:
		var on_land: Array = []
		for inner in interior:
			on_land.append_array(Geometry2D.intersect_polyline_with_polygon(_closed(poly), inner))
		for piece in _subtract(on_land, _no_road):
			if _length(piece) >= MIN_PIECE:
				segments.append(_segment("quay_%d" % n, "quay", width, piece))
				n += 1


# Every road as a filled polygon (its width plus `margin` each side). Used to keep
# lots, trees and the like off the roads.
# The ORDER matters to anyone cutting these out of land: coast road and embankment first,
# then avenues, diagonals, streets. Each road then touches one that was cut before it, so a
# cut always splits or notches the land and never leaves a floating hole.
func ribbons(margin: float = 0.0) -> Array:
	var out: Array = []
	for kind in ["ring", "quay", "avenue", "diagonal", "street"]:
		for seg in segments:
			if seg["kind"] == kind:
				out.append_array(Geometry2D.offset_polyline(seg["points"], float(seg["width"]) * 0.5 + margin, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT))
	return out


func _segment(id: String, kind: String, width: float, points: PackedVector2Array) -> Dictionary:
	return {"id": id, "kind": kind, "width": width, "points": _densify(points)}


# Exact clipping leaves long straight pieces with only two points. A road needs a point every
# few metres to rise and fall with the terrain (and so slope checks look at real steps).
func _densify(points: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array([points[0]])
	for i in range(points.size() - 1):
		var steps := maxi(1, ceili(points[i].distance_to(points[i + 1]) / POINT_SPACING))
		for s in range(1, steps + 1):
			out.append(points[i].lerp(points[i + 1], float(s) / steps))
	return out


func _closed(poly: PackedVector2Array) -> PackedVector2Array:
	var line := poly.duplicate()
	line.append(poly[0])
	return line


func _length(points: PackedVector2Array) -> float:
	var total := 0.0
	for i in range(points.size() - 1):
		total += points[i].distance_to(points[i + 1])
	return total


# A road that ends within a hair of a bridge end is moved exactly onto it, but only if
# it is heading the same way as the bridge.
func _snap_to_bridges(run: PackedVector2Array) -> PackedVector2Array:
	var out := run.duplicate()
	for end in [0, run.size() - 1]:
		var inner := 1 if end == 0 else run.size() - 2
		var heading := (run[end] - run[inner]).normalized()
		for b in bridges:
			var axis: Vector2 = ((b["to"] as Vector2) - (b["from"] as Vector2)).normalized()
			for tip in [b["from"], b["to"]]:
				if run[end].distance_to(tip) <= SNAP_REACH and absf(heading.dot(axis)) > 0.9:
					out[end] = tip
	return out
