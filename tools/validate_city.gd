# validate_city - sanity checks for res://data/city.json.
#
# Run:  godot --headless --path . --script res://tools/validate_city.gd
# Optional: validate another file with  ... --script res://tools/validate_city.gd -- res://path.json
# Exit code 0 = no FAIL, 1 = at least one FAIL (WARN never fails the run).
#
# One job: catch layout mistakes in the DATA before any 3D is built from it.
# WHY: a bad polygon or a bridge to nowhere is cheap to fix here and confusing
# to debug later as "floating buildings" in 3D.
extends SceneTree

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

const DISTRICT_TYPES := ["core", "midrise", "lowrise", "harbour", "park"]
const LANDMARK_RIVER_MARGIN := 25.0  # landmark must stand at least this far from the water (m)
const MAX_OVERLAP_FRACTION := 0.02   # districts may share at most 2% of the smaller one's area
const BRIDGE_REACH := 40.0           # a road crossing the river needs a bridge this close (m)

var _fails := 0
var _warns := 0


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var city := CityData.load_city(args[0] if args.size() > 0 else CityData.DEFAULT_PATH)
	if city.is_empty():
		_report("FAIL", "city.json loads and is a JSON object")
		_finish()
		return
	_check_meta(city)
	_check_river(city)
	_check_districts(city)
	_check_core_and_landmark(city)
	_check_roads_and_bridges(city)
	_check_terrain(city)
	_finish()


func _check_meta(city: Dictionary) -> void:
	var meta: Dictionary = city.get("meta", {})
	_expect(meta.has("seed") and typeof(meta["seed"]) in [TYPE_INT, TYPE_FLOAT],
		"meta.seed present (needed for a reproducible city)")
	var size: Array = meta.get("map_size", [])
	_expect(size.size() == 2 and float(size[0]) > 0 and float(size[1]) > 0,
		"meta.map_size is [width, height] with positive numbers")


func _check_river(city: Dictionary) -> void:
	var path: Array = city["river"]["path"]
	_expect(path.size() >= 2, "river has at least 2 path points")
	var size := CityData.map_size(city)
	var first := Vector2(path[0][0], path[0][1])
	var last := Vector2(path[-1][0], path[-1][1])
	_expect(_on_edge(first, size) and _on_edge(last, size) and not _on_same_edge(first, last, size),
		"river enters and leaves the map on different edges (it really splits the city)")
	var widths_ok := true
	for p in path:
		widths_ok = widths_ok and float(p[2]) > 0.0
	_expect(widths_ok, "every river point has a width > 0")


func _check_districts(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	var districts: Array = city["districts"]
	_expect(districts.size() >= 4 and districts.size() <= 5, "4-5 districts (found %d)" % districts.size())

	var ids := {}
	var polys := {}
	var types := {}
	for d in districts:
		var id: String = d["id"]
		_expect(not ids.has(id), "district id '%s' is unique" % id)
		ids[id] = true
		_expect(d["type"] in DISTRICT_TYPES, "district '%s' has a known type (%s)" % [id, d["type"]])
		types[d["type"]] = true
		var poly := CityData.to_points(d["polygon"])
		polys[id] = poly
		_expect(poly.size() >= 3, "district '%s' polygon has >= 3 points" % id)
		var inside := true
		for p in poly:
			inside = inside and (Rect2(Vector2.ZERO, size).has_point(p) or _on_edge(p, size))
		_expect(inside, "district '%s' lies within the map" % id)
		_expect(not Geometry2D.triangulate_polygon(poly).is_empty(),
			"district '%s' polygon is simple (no self-crossing)" % id)

	for need in ["core", "park", "midrise", "lowrise", "harbour"]:
		_expect(types.has(need), "there is a '%s' district" % need)

	var keys := polys.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: PackedVector2Array = polys[keys[i]]
			var b: PackedVector2Array = polys[keys[j]]
			var overlap := Geo2D.overlap_area(a, b)
			var limit := MAX_OVERLAP_FRACTION * minf(Geo2D.polygon_area(a), Geo2D.polygon_area(b))
			_expect(overlap <= limit, "districts '%s' and '%s' do not overlap badly (%.0f m2 shared)" % [keys[i], keys[j], overlap])

	var total := 0.0
	for id in polys:
		total += Geo2D.polygon_area(polys[id])
	var coverage := total / (size.x * size.y)
	if coverage < 0.95:
		_report("WARN", "districts cover only %d%% of the map; the rest will stay empty" % int(coverage * 100.0))


func _check_core_and_landmark(city: Dictionary) -> void:
	var path: Array = city["river"]["path"]
	var core_pt := Vector2(city["core"]["center"][0], city["core"]["center"][1])
	_expect(_district_at(city, core_pt, "core"), "core.center lies inside a 'core' district")

	var lm: Dictionary = city["landmark"]
	var lm_pt := Vector2(lm["position"][0], lm["position"][1])
	var clearance := Geo2D.river_clearance(lm_pt, path)
	_expect(clearance >= LANDMARK_RIVER_MARGIN,
		"landmark is not in the river and keeps %.0f m from the bank (found %.0f m)" % [LANDMARK_RIVER_MARGIN, clearance])
	_expect(_district_at(city, lm_pt, ""), "landmark lies inside some district")
	_expect(not _district_at(city, lm_pt, "park"), "landmark is not inside the park")
	_expect(float(lm["height"]) > 0.0, "landmark has a height > 0")


# Every avenue/diagonal that crosses the river must have a bridge nearby; every
# bridge must really span the water. Streets are skipped on purpose: they run
# roughly parallel to the river, so the road phase will simply stop them at the bank.
func _check_roads_and_bridges(city: Dictionary) -> void:
	var river_path: Array = city["river"]["path"]
	var river_line := PackedVector2Array()
	for p in river_path:
		river_line.append(Vector2(p[0], p[1]))
	var size := CityData.map_size(city)
	var bridges: Array = city["bridges"]

	for b in bridges:
		var a := Vector2(b["from"][0], b["from"][1])
		var c := Vector2(b["to"][0], b["to"][1])
		var spans := not Geo2D.crossings(a, c, river_line).is_empty()
		var ends_dry := Geo2D.river_clearance(a, river_path) >= 0.0 and Geo2D.river_clearance(c, river_path) >= 0.0
		_expect(spans and ends_dry, "bridge '%s' crosses the river and both ends are on land" % b["id"])

	var lines := []  # [label, a, b]
	for x in city["roads"]["avenues"]["x"]:
		lines.append(["avenue x=%d" % int(x), Vector2(x, 0), Vector2(x, size.y)])
	for diag in city["roads"]["diagonals"]:
		var pts := CityData.to_points(diag["path"])
		for i in range(pts.size() - 1):
			lines.append(["diagonal '%s'" % diag["id"], pts[i], pts[i + 1]])
	for line in lines:
		for hit in Geo2D.crossings(line[1], line[2], river_line):
			var near := false
			for b in bridges:
				var mid := (Vector2(b["from"][0], b["from"][1]) + Vector2(b["to"][0], b["to"][1])) * 0.5
				near = near or mid.distance_to(hit) <= BRIDGE_REACH
			_expect(near, "%s has a bridge within %d m of where it crosses the river" % [line[0], int(BRIDGE_REACH)])

	var diag_count: int = city["roads"]["diagonals"].size()
	if diag_count < 3 or diag_count > 4:
		_report("WARN", "brief asked for 3-4 diagonal avenues, found %d" % diag_count)
	else:
		_report("PASS", "3-4 diagonal avenues (found %d)" % diag_count)


func _check_terrain(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	for h in city["terrain"]["hills"]:
		var c := Vector2(h["center"][0], h["center"][1])
		_expect(Rect2(Vector2.ZERO, size).has_point(c) and float(h["radius"]) > 0.0 and float(h["height"]) > 0.0,
			"hill '%s' centre is on the map with radius and height > 0" % h["name"])


# ---- helpers ---------------------------------------------------------------

# Is p inside any district (of the given type, or any type if type == "")?
func _district_at(city: Dictionary, p: Vector2, type: String) -> bool:
	for d in city["districts"]:
		if type != "" and d["type"] != type:
			continue
		if Geometry2D.is_point_in_polygon(p, CityData.to_points(d["polygon"])):
			return true
	return false


func _on_edge(p: Vector2, size: Vector2) -> bool:
	return is_zero_approx(p.x) or is_zero_approx(p.y) or is_equal_approx(p.x, size.x) or is_equal_approx(p.y, size.y)


func _on_same_edge(a: Vector2, b: Vector2, size: Vector2) -> bool:
	return (is_zero_approx(a.x) and is_zero_approx(b.x)) or (is_zero_approx(a.y) and is_zero_approx(b.y)) \
		or (is_equal_approx(a.x, size.x) and is_equal_approx(b.x, size.x)) \
		or (is_equal_approx(a.y, size.y) and is_equal_approx(b.y, size.y))


func _expect(ok: bool, message: String) -> void:
	_report("PASS" if ok else "FAIL", message)


func _report(level: String, message: String) -> void:
	if level == "FAIL":
		_fails += 1
	elif level == "WARN":
		_warns += 1
	print("[%s] %s" % [level, message])


func _finish() -> void:
	print("")
	print("%s: %d failure(s), %d warning(s)" % ["VALIDATION FAILED" if _fails > 0 else "VALIDATION PASSED", _fails, _warns])
	quit(1 if _fails > 0 else 0)
