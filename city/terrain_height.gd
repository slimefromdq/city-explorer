# TerrainHeight - "how high is the ground at map point (x, y)?"
#
# One job: turn the layout data into a height number. It is a plain function of
# the JSON (no randomness, no nodes), so the mesh, and later roads, lots and
# buildings, can all ask the same question and always agree on where the ground is.
#
# The rule, in plain words:
#   1. Land sits a little above sea level, and hills add bumps on top.
#   2. Near the coast the land slopes down to sea level; past it the sea floor drops away.
#      Hills are NOT squeezed by the coast: squeezing a tall hill into a shore ramp makes
#      cliffs no road can climb. Instead the data keeps hills inland, so they have already
#      faded out at the shore (the validator checks this).
#   3. The river and the harbour basin are carved out below sea level, and so are the
#      ponds and creeks listed in the data (a small bowl, or a narrow trench, with a soft rim).
# Water itself is NOT modelled here: it is one flat plane at sea level, so
# "lower than sea level" simply means "wet".
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

# Where the shoreline touches the water: a hair above it so beaches are not underwater.
const SHORE_LIFT := 0.3

var sea_level: float
var _base: float
var _sea_depth: float
var _shelf_width: float
var _coast_width: float
var _river_depth: float
var _bank_width: float
var _land: PackedVector2Array
var _river: Array
var _basin: PackedVector2Array
var _hills: Array  # each: {center: Vector2, radius: float, height: float}
var _ponds: Array  # each: {center: Vector2, radius: float, depth: float}
var _creeks: Array  # each: {path: Array, depth: float, bank: float, box: Rect2 (where it can matter)}


func _init(city: Dictionary) -> void:
	var t: Dictionary = city["terrain"]
	sea_level = float(t["sea_level"])
	_base = float(t["base_height"])
	_sea_depth = float(t["sea_depth"])
	_shelf_width = float(t["shelf_width"])
	_coast_width = float(t["coast_slope_width"])
	_river_depth = float(t["river_depth"])
	_bank_width = float(t["river_bank_width"])
	_land = CityData.land_polygon(city)
	_river = city["river"]["path"]
	_basin = CityData.to_points(city["harbour"]["basin"])
	for creek in t.get("creeks", []):
		var box := Rect2(Vector2(creek["path"][0][0], creek["path"][0][1]), Vector2.ZERO)
		var reach := float(creek["bank_width"])
		for pt in creek["path"]:
			box = box.expand(Vector2(pt[0], pt[1]))
			reach = maxf(reach, float(creek["bank_width"]) + float(pt[2]))
		_creeks.append({"path": creek["path"], "depth": float(creek["depth"]), "bank": float(creek["bank_width"]), "box": box.grow(reach)})
	for pond in t.get("ponds", []):
		_ponds.append({"center": Vector2(pond["center"][0], pond["center"][1]), "radius": float(pond["radius"]), "depth": float(pond["depth"])})
	for h in t["hills"]:
		_hills.append({
			"center": Vector2(h["center"][0], h["center"][1]),
			"radius": float(h["radius"]),
			"height": float(h["height"]),
		})


# `small_water` = false ignores the park's creeks and ponds: that is the level the GROUND would be at
# without them, which is what a footpath or bridge deck follows so it stays level over a creek.
func height_at(p: Vector2, small_water: bool = true) -> float:
	var inland := -Geo2D.polygon_signed_distance(p, _land)  # metres inside the coast (negative = at sea)
	var ground: float
	if inland <= 0.0:
		ground = sea_level - _sea_depth * _smooth(0.0, _shelf_width, -inland)
	else:
		ground = lerpf(sea_level + SHORE_LIFT, sea_level + _base, _smooth(0.0, _coast_width, inland)) + _hills_at(p)
	# Carve water downward only (min), so the sea floor is never raised by the river rule.
	var clearance := Geo2D.water_clearance(p, _river, _basin)  # negative = inside the water
	var wet := 1.0 - _smooth(0.0, _bank_width, clearance)
	var carved := minf(ground, lerpf(ground, sea_level - _river_depth, wet))
	if not small_water:
		return carved
	for creek in _creeks:
		if creek["box"].has_point(p):
			var edge := Geo2D.river_clearance(p, creek["path"])  # negative = in the creek
			var creek_wet := 1.0 - _smooth(0.0, float(creek["bank"]), edge)
			carved = minf(carved, lerpf(carved, sea_level - float(creek["depth"]), creek_wet))
	for pond in _ponds:
		# a bowl: full depth in the middle 60%, easing up to ground level at the rim
		var closeness := 1.0 - _smooth(0.6, 1.0, p.distance_to(pond["center"]) / float(pond["radius"]))
		carved = minf(carved, lerpf(carved, sea_level - float(pond["depth"]), closeness))
	return carved


# Height the hills add at p (zero outside every hill's radius).
func _hills_at(p: Vector2) -> float:
	var h := 0.0
	for hill in _hills:
		var t := 1.0 - p.distance_to(hill["center"]) / float(hill["radius"])
		h += float(hill["height"]) * _smooth(0.0, 1.0, t)
	return h


# Slope (rise over run) around p, measured with a small step in 4 directions.
func slope_at(p: Vector2, step: float = 5.0) -> float:
	var h := height_at(p)
	var worst := 0.0
	for dir in [Vector2.RIGHT, Vector2.LEFT, Vector2.UP, Vector2.DOWN]:
		worst = maxf(worst, absf(height_at(p + dir * step) - h) / step)
	return worst


# Smoothstep: 0 below a, 1 above b, an S-curve between, so slopes have no sharp creases.
static func _smooth(a: float, b: float, x: float) -> float:
	var t := clampf((x - a) / (b - a), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)
