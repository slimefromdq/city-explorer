# RoadNetwork - turns the raw road lines in city.json into the real, drivable pieces.
#
# One job: decide WHERE roads actually exist. The JSON stores avenues, streets
# and diagonals as long ideal lines; this cuts them down by the rules below and
# hands back clean polylines. Both the 2D debug map and the 3D builder use it,
# so the picture and the world can never disagree about where a road is.
#
# A road piece is cut off wherever the road would be:
#   - in the sea, or closer than COAST_MARGIN to the coast (beach, not asphalt)
#   - in water or on the river bank (nearer than terrain.river_bank_width)
#   - inside a district or site flagged "roads": false (park, station, plaza...)
#   - on a bridge's span: the bridge takes over there, and the road meets it at its ends
# No terrain heights are needed, so this is a pure 2D rule set.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

const STEP := 3.0               # how finely a line is checked (m); also how precisely cuts land
const COAST_MARGIN := 12.0      # roads stop this far inside the coast (m)
const ZONE_INSET := 4.0         # no-road zones are shrunk by this, so a road ON a zone's edge
                                # (e.g. the avenues along the park) is not cut away
const BRIDGE_SIDE_MARGIN := 1.0 # a bridge claims the road within this much beyond its edges (m)
const MIN_PIECE := 25.0         # shorter leftovers (a street chopped on both sides) are dropped, not built (m)
const SNAP_REACH := 6.0         # a road end this close to a bridge end is joined to it exactly (m)

# Each: {"id": String, "kind": "street"|"avenue"|"diagonal", "width": float, "points": PackedVector2Array}
var segments: Array = []
# Each: {"id", "name", "width", "from": Vector2, "to": Vector2}
var bridges: Array = []

var _land_ok: Array = []   # polygons: land minus the coast margin
var _zones: Array = []     # polygons where roads are not allowed
var _river: Array
var _basin: PackedVector2Array
var _bank: float


func _init(city: Dictionary) -> void:
	_river = city["river"]["path"]
	_basin = CityData.to_points(city["harbour"]["basin"])
	_bank = float(city["terrain"]["river_bank_width"])
	_land_ok = Geometry2D.offset_polygon(CityData.land_polygon(city), -COAST_MARGIN)
	for group in [city["districts"], city["sites"]]:
		for area in group:
			if area.get("roads", true) == false:
				_zones.append_array(Geometry2D.offset_polygon(CityData.to_points(area["polygon"]), -ZONE_INSET))
	for b in city["bridges"]:
		bridges.append({
			"id": b["id"], "name": b["name"], "width": float(b["width"]),
			"from": Vector2(b["from"][0], b["from"][1]), "to": Vector2(b["to"][0], b["to"][1]),
		})
	for line in _ideal_lines(city):
		var n := 0
		for run in _drivable_runs(line["points"]):
			segments.append({
				"id": "%s_%d" % [line["id"], n], "kind": line["kind"],
				"width": line["width"], "points": _snap_to_bridges(run),
			})
			n += 1


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


# Walk along the line in small steps; every unbroken stretch of "road allowed" is one piece.
func _drivable_runs(points: PackedVector2Array) -> Array:
	var runs: Array = []
	var current := PackedVector2Array()
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var steps := maxi(1, ceili(a.distance_to(b) / STEP))
		for s in steps + (1 if i == points.size() - 2 else 0):
			var p := a.lerp(b, float(s) / steps)
			if _road_allowed(p):
				current.append(p)
			else:
				_keep_if_long_enough(runs, current)
				current = PackedVector2Array()
	_keep_if_long_enough(runs, current)
	return runs


func _keep_if_long_enough(runs: Array, run: PackedVector2Array) -> void:
	var length := 0.0
	for i in range(run.size() - 1):
		length += run[i].distance_to(run[i + 1])
	if length >= MIN_PIECE:
		runs.append(run)


func _road_allowed(p: Vector2) -> bool:
	var on_land := false
	for poly in _land_ok:
		on_land = on_land or Geometry2D.is_point_in_polygon(p, poly)
	if not on_land:
		return false
	for zone in _zones:
		if Geometry2D.is_point_in_polygon(p, zone):
			return false
	if Geo2D.water_clearance(p, _river, _basin) < _bank:
		return false
	return not _on_a_bridge(p)


func _on_a_bridge(p: Vector2) -> bool:
	for b in bridges:
		var from: Vector2 = b["from"]
		var axis: Vector2 = (b["to"] as Vector2) - from
		var t: float = (p - from).dot(axis) / axis.length_squared()
		if t >= 0.0 and t <= 1.0:
			var lateral: float = absf((p - from).cross(axis)) / axis.length()
			if lateral <= float(b["width"]) * 0.5 + BRIDGE_SIDE_MARGIN:
				return true
	return false


# The cut leaves a gap of up to one STEP before a bridge; close it by moving the
# road's end onto the bridge end, but only if the road is heading the same way.
func _snap_to_bridges(run: PackedVector2Array) -> PackedVector2Array:
	var out := run.duplicate()
	for end in [0, run.size() - 1]:
		var inner := 1 if end == 0 else run.size() - 2
		var heading := (run[end] - run[inner]).normalized()
		for b in bridges:
			for tip in [b["from"], b["to"]]:
				var axis: Vector2 = (b["to"] - b["from"]).normalized()
				if run[end].distance_to(tip) <= SNAP_REACH and absf(heading.dot(axis)) > 0.9:
					out[end] = tip
	return out
