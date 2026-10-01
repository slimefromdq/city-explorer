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
const TerrainHeight := preload("res://city/terrain_height.gd")
const RoadNetwork := preload("res://city/road_network.gd")
const LotPlan := preload("res://city/lot_plan.gd")
const BuildingPlan := preload("res://city/building_plan.gd")

const DISTRICT_TYPES := ["core", "midrise", "lowrise", "harbour", "park", "financial"]
const LANDMARK_RIVER_MARGIN := 25.0  # landmark must stand at least this far from the water (m)
const MAX_OVERLAP_FRACTION := 0.02   # districts may share at most 2% of the smaller one's area
const BRIDGE_REACH := 40.0           # a road crossing the river needs a bridge this close (m)
const JOIN_REACH := 12.0             # tunnels/chambers closer than this count as connected (m)
const STATION_ON_LINE := 6.0         # a station must sit this close to its metro line (m)
const OUTFALL_REACH := 15.0          # an outfall must be this close to the waterline (m)
const SITE_KINDS := ["station", "library", "museum", "performance_hall", "plaza"]
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
	_check_terrain_heights(city)
	_check_road_network(city)
	_check_lots(city)
	_check_buildings(city)
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
	_expect(Geo2D.polygon_signed_distance(first, land) <= -60.0,
		"the river springs inland (>= 60 m from the coast), so the land stays connected upstream")
	_expect(float(path[0][2]) <= 25.0, "the river starts narrow (a spring, width %d m)" % int(path[0][2]))
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

	# Landmarks: exactly one main tower in the core, near the core centre and the
	# tallest thing in the city; every landmark stands in the district it names.
	var basin := CityData.to_points(city["harbour"]["basin"])
	var seen := {}
	var mains := 0
	var tallest := 0.0
	var main_height := 0.0
	var covered_types := {}
	for lm in city["landmarks"]:
		var id: String = lm["id"]
		var pt := Vector2(lm["position"][0], lm["position"][1])
		_expect(not seen.has(id), "landmark id '%s' is unique" % id)
		seen[id] = true
		tallest = maxf(tallest, float(lm["height"]))
		_expect(float(lm["height"]) > 0.0, "landmark '%s' has a height > 0" % id)
		var clearance := Geo2D.water_clearance(pt, path, basin)
		_expect(clearance >= LANDMARK_RIVER_MARGIN,
			"landmark '%s' is not in the water and keeps %.0f m from the bank (found %.0f m)" % [id, LANDMARK_RIVER_MARGIN, clearance])
		var named_ok := false
		for d in city["districts"]:
			if d["id"] == lm["district"]:
				named_ok = Geometry2D.is_point_in_polygon(pt, CityData.to_points(d["polygon"]))
				covered_types[d["type"]] = true
		_expect(named_ok, "landmark '%s' stands inside its district '%s'" % [id, lm["district"]])
		var on_site := false
		for site in city["sites"]:
			if site["kind"] != "plaza" and Geometry2D.is_point_in_polygon(pt, CityData.to_points(site["polygon"])):
				on_site = true
		_expect(not on_site, "landmark '%s' does not stand inside another building site" % id)
		if lm.get("main", false):
			mains += 1
			main_height = float(lm["height"])
			_expect(_district_at(city, pt, "core"), "the main landmark stands in the core (midtown) district")
			_expect(pt.distance_to(core_pt) <= 60.0, "the main landmark is at the core centre (%.0f m away)" % pt.distance_to(core_pt))
	_expect(mains == 1, "exactly one main landmark (found %d)" % mains)
	_expect(main_height >= tallest, "the main landmark is the tallest landmark")
	for need in ["core", "harbour", "lowrise"]:
		_expect(covered_types.has(need), "the '%s' district has a landmark" % need)


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
		"landmarks": [],
		"core centre": [city["core"]["center"]],
		"hill centres": [],
		"bridge ends": [],
		"metro stations": [],
		"metro paths": [],
		"tunnels": [],
		"chambers": [],
		"entrances and outfalls": [],
		"site corners": [],
		"piers (land end)": [],
	}
	for lm in city["landmarks"]:
		groups["landmarks"].append(lm["position"])
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
	for pier in city["harbour"]["piers"]:
		groups["piers (land end)"].append(pier["from"])
	for name in groups:
		var bad := 0
		for p in groups[name]:
			if not Geometry2D.is_point_in_polygon(Vector2(p[0], p[1]), land):
				bad += 1
		_expect(bad == 0, "%s: all on land%s" % [name, "" if bad == 0 else " (%d outside the coast)" % bad])


# The height function must agree with the layout: water is low, everything built is dry.
func _check_terrain_heights(city: Dictionary) -> void:
	var t: Dictionary = city["terrain"]
	for key in ["sea_level", "base_height", "sea_depth", "shelf_width", "coast_slope_width", "river_depth", "river_bank_width", "mesh_cell_size"]:
		_expect(t.has(key) and typeof(t[key]) in [TYPE_INT, TYPE_FLOAT], "terrain.%s is a number" % key)
	var terrain := TerrainHeight.new(city)
	var wet := terrain.sea_level - 1.0   # lower than this = properly underwater
	var dry := terrain.sea_level + 1.0   # higher than this = properly dry

	var river_ok := true
	for p in city["river"]["path"]:
		river_ok = river_ok and terrain.height_at(Vector2(p[0], p[1])) < wet
	_expect(river_ok, "the river centreline is underwater everywhere")
	var basin := CityData.to_points(city["harbour"]["basin"])
	_expect(terrain.height_at(Geo2D.label_point(basin)) < wet, "the harbour basin is underwater")

	var bridges_ok := true
	for b in city["bridges"]:
		var a := Vector2(b["from"][0], b["from"][1])
		var c := Vector2(b["to"][0], b["to"][1])
		bridges_ok = bridges_ok and terrain.height_at(a) > dry and terrain.height_at(c) > dry and terrain.height_at((a + c) * 0.5) < wet
	_expect(bridges_ok, "every bridge starts and ends on dry ground and crosses water in the middle")

	var dry_ok := true
	for lm in city["landmarks"]:
		dry_ok = dry_ok and terrain.height_at(Vector2(lm["position"][0], lm["position"][1])) > dry
	for site in city["sites"]:
		for p in site["polygon"]:
			dry_ok = dry_ok and terrain.height_at(Vector2(p[0], p[1])) > dry
	_expect(dry_ok, "landmarks and building sites stand on dry ground")

	for lm in city["landmarks"]:
		if lm.get("main", false):
			var slope := terrain.slope_at(Vector2(lm["position"][0], lm["position"][1]))
			_expect(slope <= 0.1, "ground under the main landmark is flat enough (slope %.0f%%)" % (slope * 100.0))
	# Hills must have faded out by the shore (otherwise: sea cliffs and unclimbable roads).
	var land := CityData.land_polygon(city)
	for h in t["hills"]:
		var centre := Vector2(h["center"][0], h["center"][1])
		var coast_gap := -Geo2D.polygon_signed_distance(centre, land)  # metres from the hill centre to the coast
		var fade := 1.0 - coast_gap / float(h["radius"])
		var at_coast := 0.0 if fade <= 0.0 else float(h["height"]) * fade * fade * (3.0 - 2.0 * fade)
		_expect(at_coast <= 2.0, "hill '%s' has faded out by the coast (%.1f m of hill left at the shore)" % [h["name"], at_coast])
	for h in t["hills"]:
		var top := terrain.height_at(Vector2(h["center"][0], h["center"][1]))
		var want: float = float(t["sea_level"]) + float(t["base_height"]) + float(h["height"])
		_expect(top > float(t["sea_level"]) + float(t["base_height"]) + 0.5 * float(h["height"]),
			"hill '%s' really rises (top %.0f m, planned about %.0f m)" % [h["name"], top, want])


# The road network built from the data must be sane: roads exist, stay dry and out
# of no-road zones, climb hills at a drivable grade, and every bridge meets a road.
func _check_road_network(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var terrain := TerrainHeight.new(city)
	var roads: Dictionary = city["roads"]
	var kinds := {}
	for seg in network.segments:
		kinds[seg["id"].rsplit("_", true, 1)[0]] = true  # which ideal lines produced at least one piece
	var lost := []
	for y in roads["streets"]["y"]:
		if not kinds.has("street_y%d" % int(y)):
			lost.append("street y=%d" % int(y))
	for x in roads["avenues"]["x"]:
		if not kinds.has("avenue_x%d" % int(x)):
			lost.append("avenue x=%d" % int(x))
	for d in roads["diagonals"]:
		if not kinds.has("diagonal_%s" % d["id"]):
			lost.append("diagonal %s" % d["id"])
	_expect(lost.is_empty(), "every street, avenue and diagonal survives as drivable road%s" % ("" if lost.is_empty() else " (lost: %s)" % ", ".join(lost)))

	var wet := 0
	var worst := 0.0
	var worst_at := Vector2.ZERO
	for seg in network.segments:
		var pts: PackedVector2Array = seg["points"]
		for i in pts.size():
			if terrain.height_at(pts[i]) < terrain.sea_level + 0.5:
				wet += 1
			if i > 0:
				var grade := absf(terrain.height_at(pts[i]) - terrain.height_at(pts[i - 1])) / pts[i].distance_to(pts[i - 1])
				if grade > worst:
					worst = grade
					worst_at = pts[i]
	_expect(wet == 0, "no road point is under water (%d wet)" % wet)
	var shortest := INF
	for seg in network.segments:
		var length := 0.0
		for i in range(seg["points"].size() - 1):
			length += seg["points"][i].distance_to(seg["points"][i + 1])
		shortest = minf(shortest, length)
	_expect(shortest >= RoadNetwork.MIN_PIECE, "no tiny road stubs (shortest piece %.0f m)" % shortest)
	_expect(worst <= float(roads["max_grade"]),
		"roads are climbable (steepest %.0f%% at (%d, %d), limit %.0f%%)" % [worst * 100.0, worst_at.x, worst_at.y, float(roads["max_grade"]) * 100.0])

	var zones := []
	for group in [city["districts"], city["sites"]]:
		for area in group:
			if area.get("roads", true) == false:
				zones.append_array(Geometry2D.offset_polygon(CityData.to_points(area["polygon"]), -RoadNetwork.ZONE_INSET))
	var inside := 0
	for seg in network.segments:
		if seg["kind"] == "ring":
			continue  # the coast road may run along a park's shore
		for p in seg["points"]:
			for zone in zones:
				if Geo2D.polygon_signed_distance(p, zone) < -0.5:  # ends exactly on the edge are fine
					inside += 1
	_expect(inside == 0, "no road enters a 'roads: false' zone (park, station, plaza, library, museum, hall)")

	var unmet := []
	for b in network.bridges:
		for tip in [b["from"], b["to"]]:
			var met := false
			for seg in network.segments:
				var pts: PackedVector2Array = seg["points"]
				met = met or pts[0].distance_to(tip) < 2.0 or pts[pts.size() - 1].distance_to(tip) < 2.0
			if not met:
				unmet.append("%s" % b["id"])
	_expect(unmet.is_empty(), "every bridge end meets a road%s" % ("" if unmet.is_empty() else " (not met: %s)" % ", ".join(unmet)))
	_check_road_tidiness(city, network)
	_expect(float(roads["bridge_arch_height"]) >= 0.0 and float(roads["bridge_deck_thickness"]) > 0.0, "bridge style values are valid")


# The checks behind "roads should look planned, not random".
func _check_road_tidiness(city: Dictionary, network) -> void:
	var roads: Dictionary = city["roads"]
	var kinds := {}
	for seg in network.segments:
		kinds[seg["kind"]] = true
	_expect(kinds.has("ring") and kinds.has("quay"), "a coast road and a river embankment exist")

	# Diagonals: straight, start/end on a grid junction or run out to the coast, never at a shallow angle.
	var land := CityData.land_polygon(city)
	for d in roads["diagonals"]:
		_expect(d["path"].size() == 2, "diagonal '%s' is one straight line" % d["id"])
		var a := Vector2(d["path"][0][0], d["path"][0][1])
		var b := Vector2(d["path"][1][0], d["path"][1][1])
		var ends_ok := true
		for p in [a, b]:
			var node: bool = p.x in roads["avenues"]["x"].map(func(v): return float(v)) and p.y in roads["streets"]["y"].map(func(v): return float(v))
			var coast: bool = not Geometry2D.is_point_in_polygon(p, land)
			ends_ok = ends_ok and (node or coast)
		_expect(ends_ok, "diagonal '%s' starts and ends on a grid junction or at the coast" % d["id"])
		var angle := rad_to_deg(atan2(absf(b.y - a.y), absf(b.x - a.x)))
		var from_grid := minf(angle, 90.0 - angle)  # angle to the nearest street/avenue direction
		_expect(from_grid >= 25.0, "diagonal '%s' cuts the grid at a clear angle (%.0f degrees)" % [d["id"], from_grid])

	# Bridges: spaced out, so no two bridges crowd each other.
	var xs := []
	for b in network.bridges:
		xs.append(((b["from"] as Vector2) + (b["to"] as Vector2)).x * 0.5)
	xs.sort()
	var gap := INF
	for i in range(1, xs.size()):
		gap = minf(gap, xs[i] - xs[i - 1])
	_expect(gap >= 140.0, "bridges are at least 140 m apart (closest %.0f m)" % gap)

	# Buildings and landmarks keep clear of the roads.
	var crowded := []
	for site in city["sites"]:
		if site.get("roads", true) == false:
			continue
		var poly := CityData.to_points(site["polygon"])
		for seg in network.segments:
			for ribbon in Geometry2D.offset_polyline(seg["points"], float(seg["width"]) * 0.5, Geometry2D.JOIN_ROUND, Geometry2D.END_BUTT):
				if Geo2D.overlap_area(poly, ribbon) > 1.0:
					crowded.append("%s on %s" % [site["id"], seg["id"]])
	_expect(crowded.is_empty(), "building sites do not sit on any road%s" % ("" if crowded.is_empty() else " (%s)" % ", ".join(crowded)))
	var near := []
	for lm in city["landmarks"]:
		var p := Vector2(lm["position"][0], lm["position"][1])
		for seg in network.segments:
			if Geo2D.polyline_distance(p, seg["points"]) < float(seg["width"]) * 0.5 + 8.0:
				near.append("%s near %s" % [lm["id"], seg["id"]])
	_expect(near.is_empty(), "landmarks stand clear of roads%s" % ("" if near.is_empty() else " (%s)" % ", ".join(near)))

	# No random dead ends: every road piece ends on another road, or at a no-road zone
	# (park, plaza, station) it was deliberately stopped by.
	var zones := []
	for group in [city["districts"], city["sites"]]:
		for area in group:
			if area.get("roads", true) == false:
				zones.append(CityData.to_points(area["polygon"]))
	var dead := []
	for seg in network.segments:
		var pts: PackedVector2Array = seg["points"]
		for end in [pts[0], pts[pts.size() - 1]]:
			var met := false
			for other in network.segments:
				if other != seg and Geo2D.polyline_distance(end, other["points"]) <= 3.0:
					met = true
					break
			for zone in zones:
				met = met or absf(Geo2D.polygon_signed_distance(end, zone)) <= 8.0
			if not met:
				dead.append("%s (%d, %d)" % [seg["id"], end.x, end.y])
	_expect(dead.is_empty(), "no random dead ends: every road ends on another road or a park/plaza/station%s" % ("" if dead.is_empty() else " - found %d: %s" % [dead.size(), ", ".join(dead.slice(0, 6))]))


# Lots: they must sit on buildable land only (no road, water, park, sea, or another lot),
# be a sensible size, stand on gentle ground, and come out identical on every run.
func _check_lots(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var plan := LotPlan.new(city, network)
	var rules: Dictionary = city["lots"]
	var terrain := TerrainHeight.new(city)
	var lots: Array = plan.lots

	var per_type := {}
	for lot in lots:
		if lot["kind"] == "lot":
			per_type[lot["type"]] = int(per_type.get(lot["type"], 0)) + 1
	var summary := []
	for t in rules["types"]:
		summary.append("%s %d" % [t, int(per_type.get(t, 0))])
		_expect(int(per_type.get(t, 0)) > 0, "the '%s' district has building lots" % t)
	_report("PASS", "%d lots in total (%s)" % [lots.size(), ", ".join(summary)])

	var land := CityData.land_polygon(city)
	var water := Geo2D.water_polygon(city["river"]["path"], CityData.to_points(city["harbour"]["basin"]))
	var roads: Array = network.ribbons(0.0)
	var park_zones := []
	for d in city["districts"]:
		if d["type"] == "park":
			park_zones.append(CityData.to_points(d["polygon"]))
	var off_land := 0
	var on_road := []
	var in_water := 0
	var in_park := 0
	var too_small := 0
	var too_shallow := 0
	var too_steep := []
	for lot in lots:
		var poly: PackedVector2Array = lot["polygon"]
		if Geo2D.overlap_area(poly, land) < float(lot["area"]) - 0.5:
			off_land += 1
		for r in roads:
			if _boxes_touch(poly, r) and Geo2D.overlap_area(poly, r) > 0.5:
				on_road.append(lot["id"])
				break
		if Geo2D.overlap_area(poly, water) > 0.5:
			in_water += 1
		if lot["kind"] == "lot":
			for zone in park_zones:
				if Geo2D.overlap_area(poly, zone) > 0.5:
					in_park += 1
			var rect := Geo2D.min_area_rect(poly)
			if float(lot["area"]) < float(rules["min_lot_area"]) - 0.5:
				too_small += 1
			if float(rect["half"].y) * 2.0 < float(rules["min_depth"]) - 0.5:
				too_shallow += 1
		var slope := terrain.slope_at(lot["center"])
		if slope > float(rules["max_slope"]):
			too_steep.append("%s (%.0f%%)" % [lot["id"], slope * 100.0])
	_expect(off_land == 0, "every lot is on land (%d in the sea)" % off_land)
	_expect(on_road.is_empty(), "no lot overlaps a road%s" % ("" if on_road.is_empty() else " (%s)" % ", ".join(on_road.slice(0, 5))))
	_expect(in_water == 0, "no lot overlaps the river or harbour (%d do)" % in_water)
	_expect(in_park == 0, "no lot is inside the park")
	_expect(too_small == 0 and too_shallow == 0, "every lot is big and deep enough (%d too small, %d too shallow)" % [too_small, too_shallow])
	_expect(too_steep.is_empty(), "every lot stands on ground gentler than %d%%%s" % [int(float(rules["max_slope"]) * 100.0), "" if too_steep.is_empty() else " - steep: %s" % ", ".join(too_steep.slice(0, 5))])

	# Lots never overlap each other: bucket them in a coarse grid so only neighbours are compared.
	var buckets := {}
	for i in lots.size():
		for cell in _cells(lots[i]["polygon"]):
			if not buckets.has(cell):
				buckets[cell] = []
			buckets[cell].append(i)
	var overlaps := 0
	var done := {}
	for cell in buckets:
		var ids: Array = buckets[cell]
		for a in ids.size():
			for b in range(a + 1, ids.size()):
				var key := "%d_%d" % [ids[a], ids[b]]
				if done.has(key):
					continue
				done[key] = true
				var pa: PackedVector2Array = lots[ids[a]]["polygon"]
				var pb: PackedVector2Array = lots[ids[b]]["polygon"]
				if _boxes_touch(pa, pb) and Geo2D.overlap_area(pa, pb) > 0.5:
					overlaps += 1
	_expect(overlaps == 0, "no two lots overlap (%d overlapping pairs)" % overlaps)

	# Every landmark has a lot (or special site) to stand on, so the next phases can place it.
	var homeless := []
	for lm in city["landmarks"]:
		var p := Vector2(lm["position"][0], lm["position"][1])
		var found := false
		for lot in lots:
			found = found or Geometry2D.is_point_in_polygon(p, lot["polygon"])
		for site in city["sites"]:
			found = found or Geometry2D.is_point_in_polygon(p, CityData.to_points(site["polygon"]))
		if not found:
			homeless.append(lm["id"])
	_expect(homeless.is_empty(), "every landmark stands on a lot or a special site%s" % ("" if homeless.is_empty() else " (not: %s)" % ", ".join(homeless)))

	# Same JSON, same seed -> exactly the same lots.
	var again := LotPlan.new(city, RoadNetwork.new(city))
	var same := again.lots.size() == lots.size()
	if same:
		for i in lots.size():
			same = same and again.lots[i]["id"] == lots[i]["id"] and again.lots[i]["center"].is_equal_approx(lots[i]["center"]) \
				and is_equal_approx(float(again.lots[i]["area"]), float(lots[i]["area"]))
	_expect(same, "lots are reproducible: a second run gives exactly the same %d lots" % lots.size())


func _boxes_touch(a: PackedVector2Array, b: PackedVector2Array) -> bool:
	return _box(a).grow(0.01).intersects(_box(b))


func _box(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box


# The 100 m grid cells a polygon's bounding box touches.
func _cells(poly: PackedVector2Array) -> Array:
	var box := _box(poly)
	var cells := []
	for cx in range(int(floor(box.position.x / 100.0)), int(floor(box.end.x / 100.0)) + 1):
		for cy in range(int(floor(box.position.y / 100.0)), int(floor(box.end.y / 100.0)) + 1):
			cells.append("%d,%d" % [cx, cy])
	return cells


# Buildings: one per lot, inside its lot, and tall or short according to the RULE (district
# type + distance from the core), never random alone, never taller than the main landmark allows.
func _check_buildings(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var lot_plan := LotPlan.new(city, network)
	var plan := BuildingPlan.new(city, lot_plan)
	var rules: Dictionary = city["buildings"]
	var items: Array = plan.buildings

	# Every ordinary lot gets a building (a few tiny lots may be too small to build on).
	var buildable := 0
	for lot in lot_plan.lots:
		if lot["landmark"] == "" and not (lot["kind"] == "site" and float(rules["sites"].get(lot["site_kind"], 0.0)) <= 0.0):
			buildable += 1
	var built := items.size()
	_expect(float(built) >= 0.97 * buildable, "almost every lot has a building (%d of %d; %d too small)" % [built, buildable, plan.unbuilt.size()])
	var landmark_lots_empty := true
	for lot in lot_plan.lots:
		if lot["landmark"] != "":
			for b in items:
				landmark_lots_empty = landmark_lots_empty and b["lot"] != lot["id"]
	_expect(landmark_lots_empty, "lots reserved for landmarks stay empty")

	# Footprints stay inside their lots, so they cannot touch a road or the water either.
	var lots_by_id := {}
	for lot in lot_plan.lots:
		lots_by_id[lot["id"]] = lot
	var outside := 0
	var too_small := 0
	var clear_of_roads := true
	var road_boxes: Array = network.ribbons(0.0)
	for b in items:
		var corners := BuildingPlan.rect_corners(b["center"], b["u"], b["size"] * 0.5)
		var lot_poly: PackedVector2Array = lots_by_id[b["lot"]]["polygon"]
		if Geo2D.overlap_area(corners, lot_poly) < Geo2D.polygon_area(corners) * 0.995:
			outside += 1
		if minf(b["size"].x, b["size"].y) < 4.0:
			too_small += 1
	for b in items.slice(0, 80):  # spot-check against the real road polygons (the lot checks already cover the rest)
		var corners := BuildingPlan.rect_corners(b["center"], b["u"], b["size"] * 0.5)
		for r in road_boxes:
			if _boxes_touch(corners, r) and Geo2D.overlap_area(corners, r) > 0.1:
				clear_of_roads = false
	_expect(outside == 0, "every building stands inside its lot (%d poke out)" % outside)
	_expect(too_small == 0, "no building is narrower than 4 m (%d are)" % too_small)
	_expect(clear_of_roads, "no sampled building touches a road")

	# Heights follow the rule.
	var main_height := 0.0
	for lm in city["landmarks"]:
		if lm.get("main", false):
			main_height = float(lm["height"])
	var tallest := 0.0
	var by_group := {}
	for b in items:
		tallest = maxf(tallest, float(b["height"]))
		if not by_group.has(b["group"]):
			by_group[b["group"]] = []
		by_group[b["group"]].append(b)
	_expect(tallest <= main_height * float(rules["height_cap_fraction"]) + 0.01,
		"no building rivals the main landmark (tallest %.0f m, cap %.0f m, tower %.0f m)" % [tallest, main_height * float(rules["height_cap_fraction"]), main_height])
	_expect(float(rules["height_cap_fraction"]) <= 0.9 and tallest < main_height * 0.9,
		"the main landmark stays clearly the tallest thing in the city (tallest building %.0f m vs tower %.0f m)" % [tallest, main_height])
	var floor_height := float(rules["floor_height"])
	var snapped := true
	for b in items:
		snapped = snapped and absf(float(b["height"]) - float(b["floors"]) * floor_height) < 0.01 and int(b["floors"]) >= int(rules["min_floors"]) - 1
	_expect(snapped, "every height is a whole number of floors")

	var spread := 1.0 + float(rules["variation"])
	for group in rules["types"]:
		var rule: Dictionary = rules["types"][group]
		var list: Array = by_group.get(group, [])
		_expect(list.size() > 0, "district type '%s' has buildings" % group)
		var lo := INF
		var hi := 0.0
		for b in list:
			lo = minf(lo, b["height"])
			hi = maxf(hi, b["height"])
		var floor_slack := floor_height
		_expect(lo >= float(rule["min_height"]) * (1.0 - float(rules["variation"])) - floor_slack and hi <= float(rule["max_height"]) * spread + floor_slack,
			"'%s' heights stay within the rule (%.0f-%.0f m; rule %d-%d m +/- variation)" % [group, lo, hi, int(rule["min_height"]), int(rule["max_height"])])
		# Closer to the core must mean taller: compare the nearest third with the farthest third.
		if list.size() >= 9 and float(rule["max_height"]) > 1.5 * float(rule["min_height"]):
			var sorted := list.duplicate()
			sorted.sort_custom(func(a, c): return a["distance"] < c["distance"])
			var third := sorted.size() / 3
			var near := 0.0
			var far := 0.0
			for i in third:
				near += float(sorted[i]["height"])
				far += float(sorted[sorted.size() - 1 - i]["height"])
			_expect(near > far, "'%s': buildings near the core are taller than those far from it (%.0f m vs %.0f m)" % [group, near / third, far / third])

	# Variety: not every building in a group is identical.
	for group in by_group:
		if group == "civic" or by_group[group].size() < 20:
			continue
		var distinct := {}
		for b in by_group[group]:
			distinct[b["floors"]] = true
		_expect(distinct.size() >= 3, "'%s' has variety (%d different floor counts)" % [group, distinct.size()])

	# The outer low-rise districts keep one consistent, low style (the Paris part of the brief).
	var lowrise_tall := 0.0
	for b in by_group.get("lowrise", []):
		lowrise_tall = maxf(lowrise_tall, b["height"])
	_expect(lowrise_tall <= 30.0, "the low-rise districts stay low (tallest %.0f m)" % lowrise_tall)

	# Same JSON and seed -> exactly the same buildings.
	var again := BuildingPlan.new(city, LotPlan.new(city, RoadNetwork.new(city)))
	var same := again.buildings.size() == items.size()
	if same:
		for i in items.size():
			same = same and again.buildings[i]["id"] == items[i]["id"] and is_equal_approx(float(again.buildings[i]["height"]), float(items[i]["height"])) \
				and again.buildings[i]["center"].is_equal_approx(items[i]["center"])
	_expect(same, "buildings are reproducible: a second run gives the same %d buildings and heights" % items.size())


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
