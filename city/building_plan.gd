# BuildingPlan - decides what gets built on every lot.
#
# One job: for each lot choose a footprint (a rectangle inside the lot) and a height
# (from HeightRule). It builds no 3D; it only produces the list that the building
# builder draws and the validator checks. Lots holding a landmark are skipped (the
# landmark itself is built later); special sites get fixed civic heights from the JSON.
#
# Each lot has its own seeded random generator (from meta.seed and the lot id), so the
# same JSON always gives the same city, and editing one district does not change another.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")
const HeightRule := preload("res://city/height_rule.gd")

const MIN_FOOTPRINT_WIDTH := 4.0  # a building narrower than this (m) is not worth building

# Each: {"id": String, "lot": String, "group": String (district type or "civic"),
#        "type": String, "site_kind": String, "center": Vector2, "u": Vector2 (long axis),
#        "size": Vector2 (length along u, width across), "height": float, "floors": int,
#        "distance": float (to the core centre)}
var buildings: Array = []
var unbuilt: Array = []  # lot ids that could not fit any footprint
var lowered: Array = []  # building ids cut down to keep a line of sight to the tower clear
var cleared: Array = []  # lot ids left empty because even a 2-floor building would block a line of sight


# `terrain` and `sightlines` are optional only so a plan can be built WITHOUT the sightline rule
# (the validator does that to prove the rule is doing real work).
func _init(city: Dictionary, lot_plan, terrain = null, sightlines = null) -> void:
	var rules: Dictionary = city["buildings"]
	var core := Vector2(city["core"]["center"][0], city["core"]["center"][1])
	var main_height := 0.0
	for lm in city["landmarks"]:
		if lm.get("main", false):
			main_height = float(lm["height"])
	var height_cap := main_height * float(rules["height_cap_fraction"])
	for lot in lot_plan.lots:
		if lot["landmark"] != "":
			continue  # reserved for the landmark
		var coverage := 0.85
		var height := 0.0
		var floors := 0
		var group: String = lot["type"]
		if lot["kind"] == "site":
			height = float(rules["sites"].get(lot["site_kind"], 0.0))
			if height <= 0.0:
				continue  # e.g. the plaza stays open
			floors = maxi(1, roundi(height / float(rules["floor_height"])))
			height = floors * float(rules["floor_height"])
			group = "civic"
			coverage = 0.9
		else:
			var rng := RandomNumberGenerator.new()
			rng.seed = hash("%d:%s" % [int(city["meta"]["seed"]), lot["id"]])
			var type_rules: Dictionary = rules["types"][lot["type"]]
			var result := HeightRule.compute(lot["center"].distance_to(core), type_rules, rules, rng.randf() * 2.0 - 1.0)
			height = result["height"]
			floors = result["floors"]
			if height > height_cap:  # nothing may rival the main landmark
				floors = int(floor(height_cap / float(rules["floor_height"])))
				height = floors * float(rules["floor_height"])
			coverage = float(type_rules["coverage"])
		var fit := _footprint(lot["polygon"], coverage, float(rules["setback"]))
		if fit.is_empty():
			unbuilt.append(lot["id"])
			continue
		var lowered_here := false
		if sightlines != null and terrain != null:
			# Keep the roof under the line of sight to the tower (measured from the lowest ground under it).
			var allowed: float = sightlines.ceiling_over(fit["center"], fit["u"], fit["size"] * 0.5) - base_elevation(fit["center"], fit["u"], fit["size"], terrain) - sightlines.roof_extra
			if allowed < height:
				var allowed_floors := int(floor(allowed / float(rules["floor_height"])))
				if allowed_floors < int(rules["min_floors"]):
					cleared.append(lot["id"])
					continue
				floors = allowed_floors
				height = floors * float(rules["floor_height"])
				lowered_here = true
		if lowered_here:
			lowered.append("building_%s" % lot["id"])
		buildings.append({
			"id": "building_%s" % lot["id"], "lot": lot["id"], "group": group, "type": lot["type"],
			"site_kind": lot["site_kind"], "center": fit["center"], "u": fit["u"], "size": fit["size"],
			"height": height, "floors": floors, "distance": lot["center"].distance_to(core),
		})


# A rectangle inside the lot (kept `setback` from its edge, filling about `coverage` of it).
# Most lots are plain rectangles. Odd ones (beside a curved road or the coast) get the largest
# rectangle that fits, found by trying a few orientations and centres and growing the rectangle
# until it just touches the edge.
func _footprint(poly: PackedVector2Array, coverage: float, setback: float) -> Dictionary:
	var inset := Geometry2D.offset_polygon(poly, -setback)
	if inset.is_empty():
		return {}
	var base: PackedVector2Array = inset[0]
	for piece in inset:
		if Geo2D.polygon_area(piece) > Geo2D.polygon_area(base):
			base = piece
	var rect := Geo2D.min_area_rect(base)
	if rect.is_empty():
		return {}
	var shape: Vector2 = rect["half"]  # long : short proportions of the best-fit rectangle
	var best := {}
	var best_scale := 0.0
	for u in [rect["u"], _longest_edge_direction(base)]:
		for c in [rect["center"], Geo2D.label_point(base, 2.0), Geo2D.polygon_centroid(base)]:
			var scale := _largest_fit(base, c, u, shape)
			if scale > best_scale:
				best_scale = scale
				best = {"center": c, "u": u}
	if best.is_empty():
		return {}
	var half := shape * best_scale * sqrt(coverage)
	if half.y * 2.0 < MIN_FOOTPRINT_WIDTH:
		return {}
	return {"center": best["center"], "u": best["u"], "size": half * 2.0}


# The biggest scale (0..1) at which the proportioned rectangle still lies inside the polygon.
func _largest_fit(poly: PackedVector2Array, center: Vector2, u: Vector2, shape: Vector2) -> float:
	if _fits(poly, center, u, shape):
		return 1.0
	var lo := 0.0
	var hi := 1.0
	for i in 12:
		var mid := (lo + hi) * 0.5
		if _fits(poly, center, u, shape * mid):
			lo = mid
		else:
			hi = mid
	return lo


func _fits(poly: PackedVector2Array, center: Vector2, u: Vector2, half: Vector2) -> bool:
	if not Geometry2D.is_point_in_polygon(center, poly):
		return false
	var corners := rect_corners(center, u, half)
	return Geo2D.overlap_area(corners, poly) >= Geo2D.polygon_area(corners) * 0.999


func _longest_edge_direction(poly: PackedVector2Array) -> Vector2:
	var best := Vector2.RIGHT
	var best_len := 0.0
	for i in poly.size():
		var edge := poly[(i + 1) % poly.size()] - poly[i]
		if edge.length() > best_len:
			best_len = edge.length()
			best = edge.normalized()
	return best


# The ground level a building stands on: the LOWEST point under its footprint (so on a slope it is
# flush downhill and partly buried uphill, never floating). The builder uses this too.
static func base_elevation(center: Vector2, u: Vector2, size: Vector2, terrain) -> float:
	var low: float = terrain.height_at(center)
	var v := u.orthogonal()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		low = minf(low, terrain.height_at(center + u * corner.x * size.x * 0.5 + v * corner.y * size.y * 0.5))
	return low


# The four corners of a rectangle given its centre, long axis and half-sizes.
static func rect_corners(center: Vector2, u: Vector2, half: Vector2) -> PackedVector2Array:
	var v := u.orthogonal()
	return PackedVector2Array([center - u * half.x - v * half.y, center + u * half.x - v * half.y,
		center + u * half.x + v * half.y, center - u * half.x + v * half.y])
