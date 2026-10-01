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

const DISTRICT_TYPES := ["core", "midrise", "lowrise", "harbour", "park", "financial"]
const LANDMARK_RIVER_MARGIN := 25.0  # landmark must stand at least this far from the water (m)
const MAX_OVERLAP_FRACTION := 0.02   # districts may share at most 2% of the smaller one's area
const BRIDGE_REACH := 40.0           # a road crossing the river needs a bridge this close (m)
const JOIN_REACH := 12.0             # tunnels/chambers closer than this count as connected (m)
const STATION_ON_LINE := 6.0         # a station must sit this close to its metro line (m)
const OUTFALL_REACH := 15.0          # an outfall must be this close to the waterline (m)
const SITE_KINDS := ["station", "library", "museum", "performance_hall"]
const LEVEL_TRACK_GRADE := 0.02      # a platform needs track flatter than this
const MIN_LAND_FRACTION := 0.98      # a district must lie on land (districts are drawn to the coast)

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
	_check_land(city)
	_check_river(city)
	_check_districts(city)
	_check_harbour(city)
	_check_sites(city)
	_check_core_and_landmark(city)
	_check_roads_and_bridges(city)
	_check_terrain(city)
	_check_metro(city)
	_check_underground(city)
	_check_everything_on_land(city)
	_finish()


func _check_meta(city: Dictionary) -> void:
	var meta: Dictionary = city.get("meta", {})
	_expect(meta.has("seed") and typeof(meta["seed"]) in [TYPE_INT, TYPE_FLOAT],
		"meta.seed present (needed for a reproducible city)")
	var size: Array = meta.get("map_size", [])
	_expect(size.size() == 2 and float(size[0]) > 0 and float(size[1]) > 0,
		"meta.map_size is [width, height] with positive numbers")


# The coastline must be a real, simple shape inside the map, with a natural
# (not rectangular) outline: it may not fill the whole map box.
func _check_land(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	var land := CityData.land_polygon(city)
	_expect(land.size() >= 8 and not Geometry2D.triangulate_polygon(land).is_empty(), "land outline is a simple polygon with >= 8 points")
	var inside := true
	for p in land:
		inside = inside and Rect2(Vector2.ZERO, size).has_point(p)
	_expect(inside, "land outline lies within the map")
	var fill := Geo2D.polygon_area(land) / (size.x * size.y)
	_expect(fill < 0.85, "land is not close to a rectangle (fills %d%% of the map box, limit 85%%)" % int(fill * 100.0))


func _check_river(city: Dictionary) -> void:
	var path: Array = city["river"]["path"]
	_expect(path.size() >= 2, "river has at least 2 path points")
	var land := CityData.land_polygon(city)
	var first := Vector2(path[0][0], path[0][1])
	_expect(absf(Geo2D.polygon_signed_distance(first, land)) <= 25.0,
		"river starts on the coast (it enters the city from outside)")
	var widths_ok := true
	for p in path:
		widths_ok = widths_ok and float(p[2]) > 0.0
	_expect(widths_ok, "every river point has a width > 0")


func _check_districts(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	var districts: Array = city["districts"]
	_expect(districts.size() >= 5, "at least 5 districts (found %d)" % districts.size())

	var ids := {}
	var polys := {}
	var types := {}
	for d in districts:
		var id: String = d["id"]
		_expect(not ids.has(id), "district id '%s' is unique" % id)
		ids[id] = true
		_expect(d["type"] in DISTRICT_TYPES, "district '%s' has a known type (%s)" % [id, d["type"]])
		types[d["type"]] = true
		_expect(typeof(d.get("roads", true)) == TYPE_BOOL, "district '%s' has a boolean 'roads' flag (or none)" % id)
		var poly := CityData.to_points(d["polygon"])
		polys[id] = poly
		_expect(poly.size() >= 3, "district '%s' polygon has >= 3 points" % id)
		var inside := true
		for p in poly:
			inside = inside and (Rect2(Vector2.ZERO, size).has_point(p) or _on_edge(p, size))
		_expect(inside, "district '%s' lies within the map" % id)
		_expect(not Geometry2D.triangulate_polygon(poly).is_empty(),
			"district '%s' polygon is simple (no self-crossing)" % id)
		var on_land := Geo2D.overlap_area(poly, CityData.land_polygon(city)) / Geo2D.polygon_area(poly)
		_expect(on_land >= MIN_LAND_FRACTION, "district '%s' lies on land, not in the sea (%d%% on land)" % [id, int(on_land * 100.0)])

	for need in ["core", "park", "midrise", "lowrise", "harbour", "financial"]:
		_expect(types.has(need), "there is a '%s' district" % need)

	var keys := polys.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var a: PackedVector2Array = polys[keys[i]]
			var b: PackedVector2Array = polys[keys[j]]
			var overlap := Geo2D.overlap_area(a, b)
			var limit := MAX_OVERLAP_FRACTION * minf(Geo2D.polygon_area(a), Geo2D.polygon_area(b))
			_expect(overlap <= limit, "districts '%s' and '%s' do not overlap badly (%.0f m2 shared)" % [keys[i], keys[j], overlap])

	var land := CityData.land_polygon(city)
	var covered := 0.0
	for id in polys:
		covered += Geo2D.overlap_area(polys[id], land)
	var coverage := covered / Geo2D.polygon_area(land)
	_expect(coverage >= 0.95, "districts cover the land (%d%%); no unzoned gaps" % int(coverage * 100.0))


func _check_core_and_landmark(city: Dictionary) -> void:
	var path: Array = city["river"]["path"]
	var core_pt := Vector2(city["core"]["center"][0], city["core"]["center"][1])
	_expect(_district_at(city, core_pt, "core"), "core.center lies inside a 'core' district")

	var lm: Dictionary = city["landmark"]
	var lm_pt := Vector2(lm["position"][0], lm["position"][1])
	var clearance := Geo2D.water_clearance(lm_pt, path, CityData.to_points(city["harbour"]["basin"]))
	_expect(clearance >= LANDMARK_RIVER_MARGIN,
		"landmark is not in the water and keeps %.0f m from the bank (found %.0f m)" % [LANDMARK_RIVER_MARGIN, clearance])
	_expect(_district_at(city, lm_pt, "core"), "landmark stands in the core (midtown) district")
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


# The harbour is where the river ends: the basin must touch the map edge, the
# river's last point must be in it, and each pier must run from land into water.
func _check_harbour(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	var river: Array = city["river"]["path"]
	var basin := CityData.to_points(city["harbour"]["basin"])
	_expect(basin.size() >= 3 and not Geometry2D.triangulate_polygon(basin).is_empty(), "harbour basin is a simple polygon")
	var land := CityData.land_polygon(city)
	var open_sea := false
	for p in basin:
		open_sea = open_sea or not Geometry2D.is_point_in_polygon(p, land)
	_expect(open_sea, "harbour basin reaches past the coastline (it opens to the sea)")
	var end := Vector2(river[-1][0], river[-1][1])
	_expect(Geometry2D.is_point_in_polygon(end, basin), "the river's far end flows into the harbour basin")
	for pier in city["harbour"]["piers"]:
		var from_c := Geo2D.polygon_signed_distance(Vector2(pier["from"][0], pier["from"][1]), basin)
		var to_c := Geo2D.polygon_signed_distance(Vector2(pier["to"][0], pier["to"][1]), basin)
		_expect(from_c >= -2.0 and to_c < -10.0, "pier '%s' starts on land and ends in the basin" % pier["id"])


# Sites sit on top of districts, so they may not touch water or each other.
func _check_sites(city: Dictionary) -> void:
	var river: Array = city["river"]["path"]
	var basin := CityData.to_points(city["harbour"]["basin"])
	var polys := {}
	for site in city["sites"]:
		var poly := CityData.to_points(site["polygon"])
		polys[site["id"]] = poly
		_expect(site["kind"] in SITE_KINDS, "site '%s' has a known kind (%s)" % [site["id"], site["kind"]])
		_expect(_district_at(city, Geo2D.polygon_centroid(poly), ""), "site '%s' stands inside a district" % site["id"])
		var dry := true
		for p in poly:
			dry = dry and Geo2D.water_clearance(p, river, basin) >= 10.0
		dry = dry and Geo2D.water_clearance(Geo2D.polygon_centroid(poly), river, basin) >= 10.0
		_expect(dry, "site '%s' is on dry land" % site["id"])
	var keys := polys.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			_expect(Geo2D.overlap_area(polys[keys[i]], polys[keys[j]]) == 0.0, "sites '%s' and '%s' do not overlap" % [keys[i], keys[j]])


# Metro: at least one line crosses the whole map, every station sits on its line,
# and EVERY line stops inside the hub site (Central Station).
func _check_metro(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	var metro: Dictionary = city["metro"]
	var hub_poly := PackedVector2Array()
	for site in city["sites"]:
		if site["id"] == metro["hub"]:
			hub_poly = CityData.to_points(site["polygon"])
	_expect(not hub_poly.is_empty(), "metro hub '%s' is a defined site" % metro["hub"])

	var land_box := Rect2(CityData.land_polygon(city)[0], Vector2.ZERO)
	for p in CityData.land_polygon(city):
		land_box = land_box.expand(p)
	var spans_map := false
	var has_elevated := false
	var has_tunnel := false
	for line in metro["lines"]:
		var raw: Array = line["path"]
		var path := CityData.to_points(raw)
		var ext := Rect2(path[0], Vector2.ZERO)
		for p in path:
			ext = ext.expand(p)
		if ext.size.x >= 0.85 * land_box.size.x or ext.size.y >= 0.85 * land_box.size.y:
			spans_map = true
		var worst_grade := 0.0
		for i in range(raw.size() - 1):
			var length := path[i].distance_to(path[i + 1])
			worst_grade = maxf(worst_grade, absf(float(raw[i + 1][2]) - float(raw[i][2])) / length)
			has_elevated = has_elevated or float(raw[i][2]) > 0.0
			has_tunnel = has_tunnel or float(raw[i][2]) < 0.0
		_expect(worst_grade <= float(metro["max_grade"]),
			"metro line %s ramps are gentle enough (steepest %.1f%%, limit %.1f%%)" % [line["id"], worst_grade * 100.0, float(metro["max_grade"]) * 100.0])
		var stations_ok := true
		var level_ok := true
		var hub_ok := false
		for st in line["stations"]:
			var at := Vector2(st["at"][0], st["at"][1])
			var track := Geo2D.track_at(at, raw)
			stations_ok = stations_ok and float(track["dist"]) <= STATION_ON_LINE
			level_ok = level_ok and float(track["grade"]) <= LEVEL_TRACK_GRADE
			if st.has("site") and st["site"] == metro["hub"]:
				hub_ok = hub_ok or Geometry2D.is_point_in_polygon(at, hub_poly)
		_expect(stations_ok, "metro line %s: every station lies on the line (within %d m)" % [line["id"], int(STATION_ON_LINE)])
		_expect(level_ok, "metro line %s: every station platform is on level track" % line["id"])
		_expect(hub_ok, "metro line %s stops inside the central station" % line["id"])
	_expect(spans_map, "at least one metro line crosses the whole city (>= 85% of its width or height)")
	_expect(has_elevated and has_tunnel, "the metro has both above-ground and underground sections")


# Sewers: everything must be one connected network (otherwise part of the
# Underguild is unreachable), entrances must be on tunnels, outfalls on the water.
func _check_underground(city: Dictionary) -> void:
	var size := CityData.map_size(city)
	var river: Array = city["river"]["path"]
	var basin := CityData.to_points(city["harbour"]["basin"])
	var u: Dictionary = city["underground"]
	var lines := {}
	for t in u["tunnels"]:
		lines[t["id"]] = CityData.to_points(t["path"])

	for e in u["entrances"]:
		var at := Vector2(e["at"][0], e["at"][1])
		_expect(lines.has(e["tunnel"]) and Geo2D.polyline_distance(at, lines[e["tunnel"]]) <= JOIN_REACH,
			"entrance '%s' sits on its tunnel '%s'" % [e["id"], e["tunnel"]])
	for o in u["outfalls"]:
		var at := Vector2(o["at"][0], o["at"][1])
		var gap := absf(Geo2D.water_clearance(at, river, basin))
		_expect(lines.has(o["tunnel"]) and Geo2D.polyline_distance(at, lines[o["tunnel"]]) <= JOIN_REACH and gap <= OUTFALL_REACH,
			"outfall '%s' joins tunnel '%s' and sits at the waterline (%.0f m off)" % [o["id"], o["tunnel"], gap])
	for c in u["chambers"]:
		var at := Vector2(c["center"][0], c["center"][1])
		_expect(Rect2(Vector2.ZERO, size).has_point(at), "chamber '%s' is on the map" % c["id"])

	# Connectivity: flood-fill from the first tunnel across tunnels that touch.
	var ids := lines.keys()
	var seen := {ids[0]: true}
	var queue := [ids[0]]
	while not queue.is_empty():
		var cur: String = queue.pop_back()
		for other in ids:
			if not seen.has(other) and _tunnels_touch(lines[cur], lines[other]):
				seen[other] = true
				queue.append(other)
	_expect(seen.size() == ids.size(), "all %d tunnels form one connected network (%d reachable)" % [ids.size(), seen.size()])
	for c in u["chambers"]:
		var at := Vector2(c["center"][0], c["center"][1])
		var linked := false
		for id in ids:
			linked = linked or Geo2D.polyline_distance(at, lines[id]) <= float(c["radius"])
		_expect(linked, "chamber '%s' is reached by a tunnel" % c["id"])


func _tunnels_touch(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	for p in a:
		if Geo2D.polyline_distance(p, b) <= JOIN_REACH:
			return true
	for p in b:
		if Geo2D.polyline_distance(p, a) <= JOIN_REACH:
			return true
	return false


# Anything standing on the map must be on land (the coast cuts the old rectangle).
func _check_everything_on_land(city: Dictionary) -> void:
	var land := CityData.land_polygon(city)
	var groups := {
		"landmark": [city["landmark"]["position"]],
		"core centre": [city["core"]["center"]],
		"hill centres": [],
		"bridge ends": [],
		"metro stations": [],
		"metro paths": [],
		"tunnels": [],
		"chambers": [],
		"entrances and outfalls": [],
		"site corners": [],
		"road diagonals": [],
		"piers (land end)": [],
	}
	for h in city["terrain"]["hills"]:
		groups["hill centres"].append(h["center"])
	for b in city["bridges"]:
		groups["bridge ends"].append_array([b["from"], b["to"]])
	for line in city["metro"]["lines"]:
		for st in line["stations"]:
			groups["metro stations"].append(st["at"])
		for p in line["path"]:
			groups["metro paths"].append(p)
	var u: Dictionary = city["underground"]
	for t in u["tunnels"]:
		for p in t["path"]:
			groups["tunnels"].append(p)
	for c in u["chambers"]:
		groups["chambers"].append(c["center"])
	for e in u["entrances"]:
		groups["entrances and outfalls"].append(e["at"])
	for o in u["outfalls"]:
		groups["entrances and outfalls"].append(o["at"])
	for site in city["sites"]:
		for p in site["polygon"]:
			groups["site corners"].append(p)
	for d in city["roads"]["diagonals"]:
		for p in d["path"]:
			groups["road diagonals"].append(p)
	for pier in city["harbour"]["piers"]:
		groups["piers (land end)"].append(pier["from"])
	for name in groups:
		var bad := 0
		for p in groups[name]:
			if not Geometry2D.is_point_in_polygon(Vector2(p[0], p[1]), land):
				bad += 1
		_expect(bad == 0, "%s: all on land%s" % [name, "" if bad == 0 else " (%d outside the coast)" % bad])


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
