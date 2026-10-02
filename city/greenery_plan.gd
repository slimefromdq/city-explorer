# GreeneryPlan - where the plants go, and which buildings get green roofs.
#
# One job: choose positions. It places trees (in the park, along the roads, in the
# square's gardens), decides which buildings carry a roof garden or planted "sky garden"
# bands, and lists the park's footpaths. It builds no 3D; the greenery builder draws it.
#
# Rules every tree follows: stay out of the road, off the lots and the water, away from
# ponds, paths and buildings, and never rise into a line of sight to the tower. Every
# random choice uses a generator seeded from meta.seed and the object's own id, so the
# same JSON always plants the same trees.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

# Height of a full-size tree of each kind (m); a tree's scale multiplies this.
const TREE_HEIGHT := {"round": 9.5, "cone": 10.0}
const SCALE_RANGE := Vector2(0.75, 1.1)
const SIDEWALK_OFFSET := 2.0      # street trees stand this far beyond a road's edge (in the sidewalk gap)
const POINT_SPACING := 4.0        # footpaths get a point at least this often (m)
const GARDEN_TREE_SPACING := 12.0
const SKY_GARDEN_MIN_FLOORS := 12
const SKY_GARDEN_GROW := 1.6      # a sky-garden band sticks out this much beyond the building (m)

# Each tree: {"pos": Vector2, "kind": "round"|"cone", "scale": float, "tint": float, "zone": "park"|"street"|"garden"}
var trees: Array = []
# Each roof garden: {"building": String, "center": Vector2, "u": Vector2, "size": Vector2}
var roofs: Array = []
# Each band: {"building": String, "center": Vector2, "u": Vector2, "size": Vector2, "level": float (m above the building's base)}
var sky_gardens: Array = []
# Each path: {"name": String, "width": float, "points": PackedVector2Array}
var paths: Array = []
# Each footbridge: {"from", "to", "points", "width", "path"}: planned automatically
# wherever a footpath crosses a creek (the creek plus its banks), so the path stays level over the water.
var footbridges: Array = []

var _city: Dictionary
var _sightlines
var _terrain
var _ribbons: Array = []   # {"box": Rect2, "poly": PackedVector2Array}: every road, widened a little
var _network
var _keep_clear: Array = []  # polygons trees must avoid (sites, ponds are checked separately)
var _max_tree_height: float
var _zones: Array = []   # {"id", "kind", "polygon"}: the named parts of the park
var _creeks: Array = []  # {"path": Array, "polygon": PackedVector2Array (water), "bank": float}
var _walk_points := PackedVector2Array()
var _walk_paths: Array = []
var _walk_clearance := 0.0


func _init(city: Dictionary, network, lot_plan, building_plan, sightlines, terrain, reserved: Array = []) -> void:
	_city = city
	var walk: Dictionary = city.get("discovery_walk", {})
	_walk_points = CityData.to_points(walk.get("points", []))
	_walk_paths.append(_walk_points)
	_walk_paths.append(CityData.to_points(walk.get("library_walk", {}).get("points", [])))
	for spur in walk.get("spurs", []):
		var points := CityData.to_points(spur.get("points", []))
		_walk_paths.append(points)
	_walk_clearance = float(walk.get("width", 4.0)) * 0.5 + 3.5
	_network = network
	_sightlines = sightlines
	_terrain = terrain
	var g: Dictionary = city["greenery"]
	_max_tree_height = float(g["tree_max_height"])
	for poly in network.ribbons(0.8):
		_ribbons.append({"box": _bounds(poly), "poly": poly})
	for site in city["sites"]:
		if site["kind"] != "plaza":
			_keep_clear.append_array(Geometry2D.offset_polygon(CityData.to_points(site["polygon"]), 3.0))
	for r in reserved:   # station entrances: no trees
		_keep_clear.append(PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]))
	for zone in g["park_zones"]:
		_zones.append({"id": zone["id"], "kind": zone["kind"], "polygon": CityData.to_points(zone["polygon"])})
	for creek in city["terrain"].get("creeks", []):
		_creeks.append({"path": creek["path"], "polygon": Geo2D.river_polygon(creek["path"]), "bank": float(creek["bank_width"])})

	_plan_paths(g)
	_plan_footbridges()
	_plan_park_trees(lot_plan, g)
	_plan_cherry_trees(g)
	_plan_garden_trees()
	_plan_street_trees(network, g)
	_plan_roofs(building_plan, g)


# ---- paths -----------------------------------------------------------------------

func _plan_paths(g: Dictionary) -> void:
	for path in g["paths"]:
		var raw := CityData.to_points(path["points"])
		var dense := PackedVector2Array([raw[0]])
		for i in range(raw.size() - 1):
			var steps := maxi(1, ceili(raw[i].distance_to(raw[i + 1]) / POINT_SPACING))
			for s in range(1, steps + 1):
				dense.append(raw[i].lerp(raw[i + 1], float(s) / steps))
		paths.append({"name": path["name"], "width": float(path["width"]), "points": dense})


# Follow the path across each creek, extending beyond the banks far enough to
# support the full path width and player capsule on firm ground.
func _plan_footbridges() -> void:
	for path in paths:
		for creek in _creeks:
			for banks in Geometry2D.offset_polygon(creek["polygon"], float(creek["bank"])):
				for piece in Geometry2D.intersect_polyline_with_polygon(path["points"], banks):
					if piece.size() < 2:
						continue
					var a := piece[0]
					var b := piece[piece.size() - 1]
					# An oblique bank can meet the edge of a wide path before its
					# centreline. Cover that edge plus the capsule, with a dry landing.
					var landing := float(path["width"]) * 0.5 + PlayerScale.RADIUS + 1.5
					var bridge_points: PackedVector2Array = piece.duplicate()
					bridge_points.insert(0, a - (piece[1] - a).normalized() * landing)
					bridge_points.append(b + (b - piece[piece.size() - 2]).normalized() * landing)
					footbridges.append({"from": bridge_points[0], "to": bridge_points[bridge_points.size() - 1], "points": bridge_points, "width": float(path["width"]) + 1.5, "path": path["name"]})


# ---- trees -----------------------------------------------------------------------

func _plan_park_trees(lot_plan, g: Dictionary) -> void:
	var spacing := float(g["park_tree_spacing"])
	for block in lot_plan.block_map.blocks:
		if block["type"] != "park":
			continue
		var rng := _rng("park:%s" % block["id"])
		var poly: PackedVector2Array = block["polygon"]
		var inner: Array = Geometry2D.offset_polygon(poly, -4.0)
		var box := _bounds(poly)
		var y := box.position.y
		while y < box.end.y:
			var x := box.position.x
			while x < box.end.x:
				var p := Vector2(x, y) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * spacing * 0.7
				if _inside_any(p, inner) and _clear_of_features(p) and _tree_allowed(p):
					_add_tree(p, "park", rng, 0.65)
				x += spacing
			y += spacing


func _plan_garden_trees() -> void:
	var rng := _rng("gardens")
	for feature in _city["precinct"]["features"]:
		if feature["kind"] != "garden":
			continue
		var poly := CityData.to_points(feature["polygon"])
		var inner: Array = Geometry2D.offset_polygon(poly, -3.0)
		var box := _bounds(poly)
		var y := box.position.y + GARDEN_TREE_SPACING * 0.5
		while y < box.end.y:
			var x := box.position.x + GARDEN_TREE_SPACING * 0.5
			while x < box.end.x:
				var p := Vector2(x, y) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * 3.0
				if _inside_any(p, inner) and _clear_of_pool(p) and _tree_allowed(p):
					_add_tree(p, "garden", rng, 0.9)
				x += GARDEN_TREE_SPACING
			y += GARDEN_TREE_SPACING


func _plan_street_trees(network, g: Dictionary) -> void:
	var spacing := float(g["street_tree_spacing"])
	var kinds: Array = g["street_tree_roads"]
	for seg in network.segments:
		if not (seg["kind"] in kinds):
			continue
		var rng := _rng("street:%s" % seg["id"])
		var offset := float(seg["width"]) * 0.5 + SIDEWALK_OFFSET
		for stop in _stops_along(seg["points"], spacing, rng):
			var normal := (stop["tangent"] as Vector2).orthogonal()
			for side in [-1.0, 1.0]:  # both sides; a side facing the sea, the water or another road is rejected below
				var p: Vector2 = stop["pos"] + normal * side * offset
				if _street_spot_ok(p) and _tree_allowed(p):
					_add_tree(p, "street", rng, 0.9)


# Points along a polyline every `spacing` metres (first one half a gap in), with the direction there.
func _stops_along(points: PackedVector2Array, spacing: float, rng: RandomNumberGenerator) -> Array:
	var out: Array = []
	var carry := spacing * 0.5
	for i in range(points.size() - 1):
		var a := points[i]
		var b := points[i + 1]
		var length := a.distance_to(b)
		if length == 0.0:
			continue
		var d := (b - a) / length
		var t := carry
		while t <= length:
			out.append({"pos": a + d * (t + (rng.randf() - 0.5) * spacing * 0.2), "tangent": d})
			t += spacing
		carry = t - length
	return out


func _street_spot_ok(p: Vector2) -> bool:
	if not _inside_any(p, _network.interior):
		return false  # in the sea side of the coast road
	if _inside_any(p, _network.water_zone):
		return false  # on the water side of the embankment
	for r in _ribbons:
		if r["box"].has_point(p) and Geometry2D.is_point_in_polygon(p, r["poly"]):
			return false  # on a road (e.g. at a junction)
	for zone in _keep_clear:
		if Geometry2D.is_point_in_polygon(p, zone):
			return false
	return true


# The cherry blossom garden: a dense, even planting of pink blossom trees (the other zones are
# kept bare of ordinary trees: the court is paved, the field is open lawn).
func _plan_cherry_trees(g: Dictionary) -> void:
	var spacing := float(g["cherry_tree_spacing"])
	for zone in _zones:
		if zone["kind"] != "cherry_garden":
			continue
		var rng := _rng("cherry:%s" % zone["id"])
		var inner: Array = Geometry2D.offset_polygon(zone["polygon"], -3.0)
		var box := _bounds(zone["polygon"])
		var y := box.position.y + spacing * 0.5
		while y < box.end.y:
			var x := box.position.x + spacing * 0.5
			while x < box.end.x:
				var p := Vector2(x, y) + Vector2(rng.randf() - 0.5, rng.randf() - 0.5) * spacing * 0.5
				var on_path := false
				for path in paths:
					on_path = on_path or Geo2D.polyline_distance(p, path["points"]) < float(path["width"]) * 0.5 + 2.0
				if _inside_any(p, inner) and not on_path and _tree_allowed(p):
					_add_tree(p, "cherry", rng, 1.0)
				x += spacing
			y += spacing


# Park and garden trees keep away from ponds, creeks, paths, pools, buildings and the park's zones.
func _clear_of_features(p: Vector2) -> bool:
	for creek in _creeks:
		if Geo2D.river_clearance(p, creek["path"]) < float(creek["bank"]) + 3.0:
			return false
	for zone in _zones:
		if Geometry2D.is_point_in_polygon(p, zone["polygon"]):
			return false
	for pond in _city["terrain"].get("ponds", []):
		if p.distance_to(Vector2(pond["center"][0], pond["center"][1])) < float(pond["radius"]) + 5.0:
			return false
	for path in paths:
		if Geo2D.polyline_distance(p, path["points"]) < float(path["width"]) * 0.5 + 2.5:
			return false
	for zone in _keep_clear:
		if Geometry2D.is_point_in_polygon(p, zone):
			return false
	return true


func _clear_of_pool(p: Vector2) -> bool:
	for feature in _city["precinct"]["features"]:
		if feature["kind"] == "pool" and p.distance_to(Vector2(feature["center"][0], feature["center"][1])) < float(feature["radius"]) + 4.0:
			return false
	return true


# A tree may not rise into a line of sight to the tower (the corridor is a ribbon around it).
func _tree_allowed(p: Vector2) -> bool:
	for path in _walk_paths:
		for i in path.size() - 1:
			if p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])) < _walk_clearance:
				return false
	var top: float = _terrain.height_at(p) + _max_tree_height
	return top <= _sightlines.ceiling_over(p, Vector2.RIGHT, Vector2(1.5, 1.5))


func _add_tree(p: Vector2, zone: String, rng: RandomNumberGenerator, round_share: float) -> void:
	var kind := "round" if rng.randf() < round_share else "cone"
	trees.append({"pos": p, "kind": kind, "scale": lerpf(SCALE_RANGE.x, SCALE_RANGE.y, rng.randf()), "tint": rng.randf(), "zone": zone})


# ---- roofs and sky gardens -------------------------------------------------------

func _plan_roofs(building_plan, g: Dictionary) -> void:
	var fractions: Dictionary = g["green_roof_fraction"]
	var bands: Dictionary = g["sky_gardens"]
	var floor_height := float(_city["buildings"]["floor_height"])
	for b in building_plan.buildings:
		if b["group"] == "civic":
			continue
		var rng := _rng("roof:%s" % b["id"])
		if rng.randf() < float(fractions.get(b["group"], 0.0)):
			roofs.append({"building": b["id"], "center": b["center"], "u": b["u"], "size": b["size"] * 0.86})
		var count := int(bands.get(b["group"], 0))
		if count > 0 and int(b["floors"]) >= SKY_GARDEN_MIN_FLOORS:
			for k in count:
				var floors_up := roundi(float(b["floors"]) * float(k + 1) / float(count + 1))
				sky_gardens.append({"building": b["id"], "center": b["center"], "u": b["u"],
					"size": b["size"] + Vector2.ONE * SKY_GARDEN_GROW, "level": floors_up * floor_height})


# ---- helpers ---------------------------------------------------------------------

func _rng(label: String) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%d:%s" % [int(_city["meta"]["seed"]), label])
	return rng


func _inside_any(p: Vector2, polygons: Array) -> bool:
	for poly in polygons:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


func _bounds(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box
