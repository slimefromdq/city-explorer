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
const Sightlines := preload("res://city/sightlines.gd")
const LandmarkBuilder := preload("res://city/landmark_builder.gd")
const GreeneryPlan := preload("res://city/greenery_plan.gd")
const SignPlan := preload("res://city/sign_plan.gd")
const DiscoveryWalkPlan := preload("res://city/discovery_walk_plan.gd")
const ArchitecturePlan := preload("res://city/architecture_plan.gd")
const HarbourPlan := preload("res://city/harbour_plan.gd")

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
	_check_sightlines(city)
	_check_precinct(city)
	_check_greenery(city)
	_check_park(city)
	_check_signs(city)
	_check_discovery_walk(city)
	_check_architecture(city)
	_finish()

func _check_architecture(city: Dictionary) -> void:
	var terrain := TerrainHeight.new(city)
	var roads := RoadNetwork.new(city)
	var lots := LotPlan.new(city, roads)
	var views := Sightlines.new(city, terrain)
	var buildings := BuildingPlan.new(city, lots, terrain, views, TransitSystem.reserve_rects(RouteData.load_default()))
	var planting := GreeneryPlan.new(city, roads, lots, buildings, views, terrain, TransitSystem.reserve_rects(RouteData.load_default()))
	var architecture := ArchitecturePlan.new(buildings, planting, city, terrain, views)
	_expect(architecture.validate().is_empty(), "architecture stays within building footprints and roof sightline allowance: %s" % [architecture.validate()])
	_expect(architecture.civic.size() == 3, "museum, library and concert hall have distinct civic exteriors")
	_expect(architecture.families.size() >= 5, "district architecture uses %d roof families" % architecture.families.size())
	var harbour := HarbourPlan.new(city, terrain)
	_expect(harbour.validate().is_empty(), "harbour architecture stays inside pier reservations: %s" % [harbour.validate()])
	var walk := DiscoveryWalkPlan.new(city, terrain)
	var park = preload("res://city/park_walk_plan.gd").new(city, planting, terrain, walk)
	var park_problems: Array = park.validate(buildings.buildings, city)
	_expect(park_problems.is_empty(), "park loop connects safely, with full-width bridge coverage: %s" % [park_problems])
	var library = preload("res://city/library_walk_plan.gd").new(city, terrain, park)
	var library_problems: Array = library.validate(buildings.buildings, city)
	_expect(library_problems.is_empty(), "library walk connects on dry land with clear footprints and grades: %s" % [library_problems])

func _check_discovery_walk(city: Dictionary) -> void:
	if not city.has("discovery_walk"):
		return
	var terrain := TerrainHeight.new(city)
	var network := RoadNetwork.new(city)
	var lots := LotPlan.new(city, network)
	var buildings := BuildingPlan.new(city, lots, terrain, Sightlines.new(city, terrain), TransitSystem.reserve_rects(RouteData.load_default()))
	var walk := DiscoveryWalkPlan.new(city, terrain)
	var problems := walk.validate(buildings.buildings, city)
	_expect(problems.is_empty(), "discovery walk stays on land/bridge and clear of buildings: %s" % [problems])
	var gentle := true
	for i in walk.samples.size() - 1:
		var a := walk.samples[i]
		var b := walk.samples[i + 1]
		gentle = gentle and absf(b.y - a.y) / Vector2(b.x - a.x, b.z - a.z).length() <= 0.20
	_expect(gentle, "discovery walk has no grade above 20%")


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


# The tower must be seen from across the city: every viewpoint has an unobstructed line of sight to
# its upper part, and the planner keeps it that way by lowering buildings in the way.
func _check_sightlines(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var lot_plan := LotPlan.new(city, network)
	var terrain := TerrainHeight.new(city)
	var sightlines := Sightlines.new(city, terrain)
	var cfg: Dictionary = city["sightlines"]
	var plan := BuildingPlan.new(city, lot_plan, terrain, sightlines)
	var viewpoints: Array = cfg["viewpoints"]
	_expect(viewpoints.size() >= 5, "at least 5 viewpoints look at the tower (%d)" % viewpoints.size())

	# Viewpoints must be real, dry places, far enough away to be "across the city", and spread around it.
	var tower := sightlines.target_position
	var quadrants := {}
	var places_ok := true
	var far_enough := true
	var land := CityData.land_polygon(city)
	for vp in viewpoints:
		var p := Vector2(vp["position"][0], vp["position"][1])
		places_ok = places_ok and terrain.height_at(p) > terrain.sea_level + 0.5 and Geometry2D.is_point_in_polygon(p, land)
		for b in plan.buildings:
			places_ok = places_ok and Geo2D.segment_rect_overlap(p, p + Vector2(0.01, 0.0), b["center"], b["u"], b["size"] * 0.5).x < 0.0
		far_enough = far_enough and p.distance_to(tower) >= 250.0
		quadrants["%d%d" % [int(p.x > tower.x), int(p.y > tower.y)]] = true
	_expect(places_ok, "every viewpoint is on dry land, not inside a building")
	_expect(far_enough, "every viewpoint is at least 250 m from the tower")
	_expect(quadrants.size() >= 3, "the viewpoints surround the tower (%d of 4 directions)" % quadrants.size())

	# The check itself: nothing blocks any line of sight.
	var blocked := sightlines.find_blockers(plan.buildings)
	var text := []
	for b in blocked:
		text.append("%s blocked by %s" % [b["id"], b["blocked_by"]])
	_expect(blocked.is_empty(), "the tower is visible from every viewpoint (top %d%% shows)%s" % [int((1.0 - float(cfg["visible_from_fraction"])) * 100.0), "" if blocked.is_empty() else ": " + "; ".join(text)])
	# ...and with a safety margin too (the planner keeps `clearance` metres below every line).
	var margin_blocked := sightlines.find_blockers(plan.buildings, float(cfg["clearance"]) * 0.5)
	_expect(margin_blocked.is_empty(), "every line of sight keeps a safety margin of %.1f m" % (float(cfg["clearance"]) * 0.5))

	# The rule must be doing real work: the same city WITHOUT it has blocked sightlines.
	var without := BuildingPlan.new(city, lot_plan)
	var would_block := sightlines.find_blockers(without.buildings)
	_expect(would_block.size() >= 1, "the corridor rule is needed (without it %d of %d sightlines would be blocked)" % [would_block.size(), viewpoints.size()])

	# The rule must not wreck the city: most lots keep their building.
	var affected := plan.lowered.size() + plan.cleared.size()
	_expect(float(affected) <= 0.08 * float(plan.buildings.size()), "the corridors touch few lots (%d lowered, %d cleared of %d buildings)" % [plan.lowered.size(), plan.cleared.size(), plan.buildings.size()])

	# The tower stays the tallest thing, including every other landmark.
	var main_height := sightlines.tower_height
	var others_ok := true
	for lm in city["landmarks"]:
		if lm["id"] != sightlines.target_id:
			others_ok = others_ok and float(lm["height"]) < main_height * 0.9
	_expect(others_ok, "the tower is clearly taller than the other landmarks")

	# Each landmark's structure fits the ground reserved for it (its lot, or the plaza).
	var reserved := {}
	for lot in lot_plan.lots:
		reserved[lot["id"]] = lot["polygon"]
	var misfit := []
	for lm in city["landmarks"]:
		var footprint := LandmarkBuilder.ground_footprint(lm)
		var centre := Vector2(lm["position"][0], lm["position"][1])
		var yaw := Vector2.from_angle(deg_to_rad(float(lm.get("yaw", 0.0))))
		var corners := BuildingPlan.rect_corners(centre, yaw, footprint["half"])
		var home := PackedVector2Array()
		for lot in lot_plan.lots:
			if Geometry2D.is_point_in_polygon(centre, lot["polygon"]):
				home = lot["polygon"]
		if home.is_empty() or Geo2D.overlap_area(corners, home) < Geo2D.polygon_area(corners) * 0.99:
			misfit.append(lm["id"])
	_expect(misfit.is_empty(), "every landmark's structure fits inside the lot or plaza reserved for it%s" % ("" if misfit.is_empty() else " (not: %s)" % ", ".join(misfit)))


# Meridian Square: a big open space round the tower, with gardens, a pool, a mall and shops that all
# fit inside it, clear of the tower and of each other, and low enough not to block the sightlines.
func _check_precinct(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var lot_plan := LotPlan.new(city, network)
	var terrain := TerrainHeight.new(city)
	var sightlines := Sightlines.new(city, terrain)
	var precinct: Dictionary = city["precinct"]
	var home := PackedVector2Array()
	for lot in lot_plan.lots:
		if lot["id"] == "site_%s" % precinct["site"]:
			home = lot["polygon"]
	_expect(not home.is_empty(), "the square (site '%s') exists as a reserved lot" % precinct["site"])
	if home.is_empty():
		return
	var area := Geo2D.polygon_area(home)
	_expect(area >= 40000.0, "the square is big (%d m2; at least 40000)" % int(area))

	var tower_lm := {}
	for lm in city["landmarks"]:
		if lm["id"] == sightlines.target_id:
			tower_lm = lm
	var tower_box := BuildingPlan.rect_corners(sightlines.target_position, Vector2.RIGHT, LandmarkBuilder.ground_footprint(tower_lm)["half"])
	var clearance := INF
	for corner in tower_box:
		clearance = minf(clearance, -Geo2D.polygon_signed_distance(corner, home))
	_expect(clearance >= 50.0, "there is at least 50 m of open ground between the tower's base and the edge of the square (%.0f m)" % clearance)

	var kinds := {}
	var shapes := []   # {"name", "kind", "poly"}
	for f in precinct["features"]:
		kinds[f["kind"]] = int(kinds.get(f["kind"], 0)) + 1
		var poly := PackedVector2Array()
		match f["kind"]:
			"garden":
				poly = CityData.to_points(f["polygon"])
			"pool":
				var centre := Vector2(f["center"][0], f["center"][1])
				for k in 16:
					poly.append(centre + Vector2.from_angle(TAU * k / 16.0) * float(f["radius"]))
			_:
				poly = BuildingPlan.rect_corners(Vector2(f["center"][0], f["center"][1]), Vector2.from_angle(deg_to_rad(float(f.get("yaw", 0.0)))), Vector2(f["size"][0], f["size"][1]) * 0.5)
		shapes.append({"name": f["name"], "kind": f["kind"], "poly": poly, "feature": f})
	_expect(int(kinds.get("garden", 0)) >= 2 and int(kinds.get("pool", 0)) >= 1 and int(kinds.get("podium", 0)) >= 1 and int(kinds.get("pavilion", 0)) >= 4,
		"the square has gardens, a pool, a mall and shops (%s)" % str(kinds))

	var outside := []
	var on_tower := []
	for sh in shapes:
		if Geo2D.overlap_area(sh["poly"], home) < Geo2D.polygon_area(sh["poly"]) * 0.999:
			outside.append(sh["name"])
		if Geo2D.overlap_area(sh["poly"], tower_box) > 0.5:
			on_tower.append(sh["name"])
	_expect(outside.is_empty(), "every feature lies inside the square%s" % ("" if outside.is_empty() else " (not: %s)" % ", ".join(outside)))
	_expect(on_tower.is_empty(), "nothing is built on the tower's base%s" % ("" if on_tower.is_empty() else " (%s)" % ", ".join(on_tower)))
	var clashes := []
	for i in shapes.size():
		for j in range(i + 1, shapes.size()):
			var pair := [shapes[i]["kind"], shapes[j]["kind"]]
			if "pool" in pair and "garden" in pair:
				continue  # a fountain pool may sit inside a garden
			if Geo2D.overlap_area(shapes[i]["poly"], shapes[j]["poly"]) > 0.5:
				clashes.append("%s / %s" % [shapes[i]["name"], shapes[j]["name"]])
	_expect(clashes.is_empty(), "features do not overlap each other%s" % ("" if clashes.is_empty() else " (%s)" % ", ".join(clashes)))

	var too_tall := []
	for sh in shapes:
		var f: Dictionary = sh["feature"]
		if f.has("height"):
			var rect := Geo2D.min_area_rect(sh["poly"])
			var ground := terrain.height_at(rect["center"])
			if ground + float(f["height"]) > sightlines.ceiling_over(rect["center"], rect["u"], rect["half"]):
				too_tall.append(sh["name"])
	_expect(too_tall.is_empty(), "no feature in the square blocks a line of sight to the tower%s" % ("" if too_tall.is_empty() else " (%s)" % ", ".join(too_tall)))


# Greenery: the park has a pond and paths that do not collide; every tree stands somewhere sensible;
# green roofs follow the data; the whole plan is reproducible.
func _check_greenery(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var lot_plan := LotPlan.new(city, network)
	var terrain := TerrainHeight.new(city)
	var sightlines := Sightlines.new(city, terrain)
	var building_plan := BuildingPlan.new(city, lot_plan, terrain, sightlines)
	var plan := GreeneryPlan.new(city, network, lot_plan, building_plan, sightlines, terrain)
	var g: Dictionary = city["greenery"]

	var park := PackedVector2Array()
	for d in city["districts"]:
		if d["type"] == "park":
			park = CityData.to_points(d["polygon"])
	var museum := PackedVector2Array()
	for site in city["sites"]:
		if site["kind"] == "museum":
			museum = CityData.to_points(site["polygon"])

	# ponds: in the park, really underwater
	var ponds_ok := true
	for pond in city["terrain"].get("ponds", []):
		var centre := Vector2(pond["center"][0], pond["center"][1])
		ponds_ok = ponds_ok and Geo2D.polygon_signed_distance(centre, park) < -(float(pond["radius"]) + 15.0) \
			and terrain.height_at(centre) < terrain.sea_level - 1.0 and terrain.height_at(centre + Vector2(float(pond["radius"]) * 1.3, 0.0)) > terrain.sea_level + 1.0
	_expect(ponds_ok and city["terrain"].get("ponds", []).size() >= 1, "the park has a pond that is underwater, with dry banks, well inside the park")

	# paths: inside the park, not through the pond or the museum
	var paths_ok := true
	for path in plan.paths:
		for p in path["points"]:
			paths_ok = paths_ok and Geometry2D.is_point_in_polygon(p, park) and not Geometry2D.is_point_in_polygon(p, museum)
			for pond in city["terrain"].get("ponds", []):
				paths_ok = paths_ok and p.distance_to(Vector2(pond["center"][0], pond["center"][1])) > float(pond["radius"]) + float(path["width"]) * 0.5
	_expect(paths_ok and plan.paths.size() >= 3, "%d footpaths stay inside the park, off the pond and the museum" % plan.paths.size())

	# trees
	var zones := {}
	for t in plan.trees:
		zones[t["zone"]] = int(zones.get(t["zone"], 0)) + 1
	_expect(plan.trees.size() >= 400 and zones.has("park") and zones.has("street") and zones.has("garden"), "trees grow in the park, along the streets and in the gardens (%s)" % str(zones))

	var roads: Array = network.ribbons(0.0)
	var land_ok := true
	var on_road := 0
	var in_lot := 0
	var in_water := 0
	var in_pond := 0
	var too_high := 0
	var blocks_view := 0
	var off_park := 0
	var lots_with_box := []
	for lot in lot_plan.lots:
		lots_with_box.append({"poly": lot["polygon"], "box": _box(lot["polygon"])})
	for t in plan.trees:
		var p: Vector2 = t["pos"]
		land_ok = land_ok and _inside_any(p, network.interior)
		if _inside_any(p, network.water_zone):
			in_water += 1
		for r in roads:
			if _box(r).has_point(p) and Geometry2D.is_point_in_polygon(p, r):
				on_road += 1
				break
		if t["zone"] != "garden":  # (the square's gardens are inside a reserved lot on purpose)
			for l in lots_with_box:
				if l["box"].has_point(p) and Geometry2D.is_point_in_polygon(p, l["poly"]):
					in_lot += 1
					break
		for pond in city["terrain"].get("ponds", []):
			if p.distance_to(Vector2(pond["center"][0], pond["center"][1])) < float(pond["radius"]):
				in_pond += 1
		var height: float = float(GreeneryPlan.TREE_HEIGHT[t["kind"]]) * float(t["scale"])
		if height > float(g["tree_max_height"]) + 0.01:
			too_high += 1
		if terrain.height_at(p) + height > sightlines.ceiling_over(p, Vector2.RIGHT, Vector2(1.5, 1.5)):
			blocks_view += 1
		if t["zone"] == "park" and not Geometry2D.is_point_in_polygon(p, park):
			off_park += 1
	_expect(land_ok, "every tree stands on land inside the coast road")
	_expect(on_road == 0 and in_lot == 0 and in_water == 0 and in_pond == 0,
		"no tree is on a road (%d), in a lot (%d), in the water (%d) or in a pond (%d)" % [on_road, in_lot, in_water, in_pond])
	_expect(off_park == 0, "park trees stay inside the park")
	_expect(too_high == 0, "no tree is taller than %d m" % int(g["tree_max_height"]))
	_expect(blocks_view == 0, "no tree rises into a line of sight to the tower")

	# green roofs and sky gardens follow the data
	var by_group := {}
	var roofed := {}
	for b in building_plan.buildings:
		by_group[b["group"]] = int(by_group.get(b["group"], 0)) + 1
	var by_id := {}
	for b in building_plan.buildings:
		by_id[b["id"]] = b
	var roofs_inside := true
	for roof in plan.roofs:
		var b: Dictionary = by_id[roof["building"]]
		roofed[b["group"]] = int(roofed.get(b["group"], 0)) + 1
		roofs_inside = roofs_inside and roof["size"].x <= b["size"].x and roof["size"].y <= b["size"].y
	var fraction_ok := true
	var text := []
	for group in g["green_roof_fraction"]:
		if int(by_group.get(group, 0)) >= 30:
			var share := float(roofed.get(group, 0)) / float(by_group[group])
			fraction_ok = fraction_ok and absf(share - float(g["green_roof_fraction"][group])) <= 0.15
			text.append("%s %d%%" % [group, int(share * 100.0)])
	_expect(fraction_ok, "the share of green roofs matches the data (%s)" % ", ".join(text))
	_expect(roofs_inside, "every roof garden lies within its building's footprint")
	var financial_roofs := float(roofed.get("financial", 0)) / maxf(float(by_group.get("financial", 1)), 1.0)
	_expect(financial_roofs > float(roofed.get("lowrise", 0)) / maxf(float(by_group.get("lowrise", 1)), 1.0), "the financial towers are the greenest (Singapore): %d%% roofs vs low-rise" % int(financial_roofs * 100.0))
	var band_ok := true
	for band in plan.sky_gardens:
		var b: Dictionary = by_id[band["building"]]
		band_ok = band_ok and int(b["floors"]) >= GreeneryPlan.SKY_GARDEN_MIN_FLOORS and float(band["level"]) < float(b["height"]) and float(band["level"]) > 0.0
	_expect(band_ok and plan.sky_gardens.size() > 0, "%d sky-garden bands sit on tall towers, below their roofs" % plan.sky_gardens.size())

	# same JSON -> same plants
	var again := GreeneryPlan.new(city, RoadNetwork.new(city), lot_plan, building_plan, sightlines, terrain)
	var same := again.trees.size() == plan.trees.size() and again.roofs.size() == plan.roofs.size()
	if same:
		for i in plan.trees.size():
			same = same and again.trees[i]["pos"].is_equal_approx(plan.trees[i]["pos"]) and is_equal_approx(float(again.trees[i]["scale"]), float(plan.trees[i]["scale"]))
	_expect(same, "the planting is reproducible (%d trees, %d roof gardens)" % [plan.trees.size(), plan.roofs.size()])


# The park: a creek that crosses it (spring to culvert), widening into the lake, footbridges wherever a
# path crosses it, and distinct zones (cherry garden, basketball courts, open field) that do not collide.
func _check_park(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var lot_plan := LotPlan.new(city, network)
	var terrain := TerrainHeight.new(city)
	var sightlines := Sightlines.new(city, terrain)
	var building_plan := BuildingPlan.new(city, lot_plan, terrain, sightlines)
	var plan := GreeneryPlan.new(city, network, lot_plan, building_plan, sightlines, terrain)
	var g: Dictionary = city["greenery"]
	var park := PackedVector2Array()
	for d in city["districts"]:
		if d["type"] == "park":
			park = CityData.to_points(d["polygon"])
	var museum := PackedVector2Array()
	for site in city["sites"]:
		if site["kind"] == "museum":
			museum = CityData.to_points(site["polygon"])
	var roads: Array = network.ribbons(0.0)
	var creeks: Array = city["terrain"].get("creeks", [])
	_expect(creeks.size() >= 1, "the park has a creek")

	for creek in creeks:
		var path: Array = creek["path"]
		var inside := true
		var wet := true
		var low_y := INF
		var high_y := -INF
		for pt in path:
			var p := Vector2(pt[0], pt[1])
			inside = inside and Geo2D.polygon_signed_distance(p, park) <= -8.0
			wet = wet and terrain.height_at(p) < terrain.sea_level - 1.0
			low_y = minf(low_y, p.y)
			high_y = maxf(high_y, p.y)
		_expect(inside, "creek '%s' stays inside the park (it never reaches a road or the coast)" % creek["name"])
		_expect(wet, "creek '%s' is underwater along its whole length" % creek["name"])
		var park_box := Rect2(park[0], Vector2.ZERO)
		for p in park:
			park_box = park_box.expand(p)
		_expect(high_y - low_y >= 0.7 * park_box.size.y, "creek '%s' runs right across the park (%d m of its %d m)" % [creek["name"], int(high_y - low_y), int(park_box.size.y)])
		# clear of roads, the museum, and through the lake
		var water := Geo2D.river_polygon(path)
		var near_road := INF
		for r in roads:
			if _box(r).grow(30.0).intersects(_box(water)):
				near_road = minf(near_road, _min_distance(water, r))
		_expect(near_road >= 8.0, "the creek keeps clear of every road (nearest %.0f m)" % near_road)
		_expect(Geo2D.polygon_signed_distance(Vector2(museum[0]), water) > 15.0 and Geo2D.overlap_area(water, museum) == 0.0, "the creek stays clear of the museum")
		var through_lake := false
		for pond in city["terrain"].get("ponds", []):
			through_lake = through_lake or Geo2D.river_clearance(Vector2(pond["center"][0], pond["center"][1]), path) < float(pond["radius"]) * 0.4
		_expect(through_lake, "the creek flows through the lake (the lake widens it)")

		# footbridges: every crossing has one, long enough, and no path dips into the creek without one
		var expected := 0
		var bank := float(creek["bank_width"])
		for fp in plan.paths:
			for banks in Geometry2D.offset_polygon(water, bank):
				expected += Geometry2D.intersect_polyline_with_polygon(fp["points"], banks).size()
		_expect(plan.footbridges.size() == expected and expected >= 1, "every path crossing the creek has a footbridge (%d crossings, %d bridges)" % [expected, plan.footbridges.size()])
		var uncovered := 0
		for fp in plan.paths:
			for p in fp["points"]:
				if Geo2D.river_clearance(p, path) < bank - 0.5:
					var covered := false
					for fb in plan.footbridges:
						covered = covered or Geo2D.polyline_distance(p, PackedVector2Array([fb["from"], fb["to"]])) <= float(fb["width"]) * 0.5 + 0.5
					if not covered:
						uncovered += 1
		_expect(uncovered == 0, "no footpath runs through the creek without a bridge (%d points)" % uncovered)

	# zones
	var zones: Array = g["park_zones"]
	var kinds := {}
	for z in zones:
		kinds[z["kind"]] = true
	_expect(kinds.has("cherry_garden") and kinds.has("basketball_court") and kinds.has("open_field"), "the park has a cherry blossom garden, basketball courts and an open field")
	var polys := []
	var bad := []
	for z in zones:
		var poly := CityData.to_points(z["polygon"])
		polys.append(poly)
		if Geo2D.polygon_signed_distance(poly[0], park) > -3.0:
			bad.append("%s (edge)" % z["id"])
		for p in poly:
			if Geo2D.polygon_signed_distance(p, park) > -3.0:
				bad.append("%s (outside the park)" % z["id"])
				break
		if Geo2D.overlap_area(poly, museum) > 0.0:
			bad.append("%s on the museum" % z["id"])
		for creek in creeks:
			var closest := INF
			for p in poly:
				closest = minf(closest, Geo2D.river_clearance(p, creek["path"]))
			if closest < float(creek["bank_width"]) + 3.0:
				bad.append("%s too close to the creek" % z["id"])
		for pond in city["terrain"].get("ponds", []):
			for p in poly:
				if p.distance_to(Vector2(pond["center"][0], pond["center"][1])) < float(pond["radius"]) + 4.0:
					bad.append("%s on the lake" % z["id"])
					break
	for i in polys.size():
		for j in range(i + 1, polys.size()):
			if Geo2D.overlap_area(polys[i], polys[j]) > 0.0:
				bad.append("%s overlaps %s" % [zones[i]["id"], zones[j]["id"]])
	_expect(bad.is_empty(), "the zones sit inside the park, clear of the creek, lake, museum and each other%s" % ("" if bad.is_empty() else " (%s)" % ", ".join(bad)))

	# courts: regulation size, inside their zone, not overlapping
	var court_total := 0
	var courts_ok := true
	var court_polys := []
	for z in zones:
		if z["kind"] != "basketball_court":
			continue
		var zone_poly := CityData.to_points(z["polygon"])
		for court in z["courts"]:
			court_total += 1
			var corners := BuildingPlan.rect_corners(Vector2(court["center"][0], court["center"][1]), Vector2.from_angle(deg_to_rad(float(court["yaw"]))), Vector2(14.0, 7.5))
			courts_ok = courts_ok and Geo2D.overlap_area(corners, zone_poly) >= Geo2D.polygon_area(corners) * 0.999 and Geo2D.polygon_signed_distance(corners[0], zone_poly) < -2.0
			for other in court_polys:
				courts_ok = courts_ok and Geo2D.overlap_area(corners, other) == 0.0
			court_polys.append(corners)
	_expect(court_total >= 2 and courts_ok, "%d basketball courts (28 x 15 m) fit inside their paved zone without touching" % court_total)

	# trees follow the zones
	var cherry_trees := 0
	var strays := 0
	var in_creek := 0
	for t in plan.trees:
		var p: Vector2 = t["pos"]
		for creek in creeks:
			if Geo2D.river_clearance(p, creek["path"]) < 0.0:
				in_creek += 1
		for i in zones.size():
			if Geometry2D.is_point_in_polygon(p, polys[i]):
				if t["zone"] == "cherry" and zones[i]["kind"] == "cherry_garden":
					cherry_trees += 1
				else:
					strays += 1
	_expect(cherry_trees >= 40, "the cherry blossom garden is densely planted (%d blossom trees)" % cherry_trees)
	_expect(strays == 0, "no ordinary tree stands in the court or the open field (%d stray)" % strays)
	_expect(in_creek == 0, "no tree stands in the creek")


# Smallest distance between two polygons' outlines (large if they are far apart).
func _min_distance(a: PackedVector2Array, b: PackedVector2Array) -> float:
	var best := INF
	for p in a:
		best = minf(best, absf(Geo2D.polygon_signed_distance(p, b)))
	for p in b:
		best = minf(best, absf(Geo2D.polygon_signed_distance(p, a)))
	if Geo2D.overlap_area(a, b) > 0.0:
		return 0.0
	return best


# Signs: mounted on the facade that faces a road, at shop height, inside the lot, in the count the data asks.
func _check_signs(city: Dictionary) -> void:
	var network := RoadNetwork.new(city)
	var lot_plan := LotPlan.new(city, network)
	var terrain := TerrainHeight.new(city)
	var sightlines := Sightlines.new(city, terrain)
	var building_plan := BuildingPlan.new(city, lot_plan, terrain, sightlines)
	var planting := GreeneryPlan.new(city, network, lot_plan, building_plan, sightlines, terrain)
	var architecture := ArchitecturePlan.new(building_plan, planting, city)
	var plan := SignPlan.new(city, network, architecture)
	var g: Dictionary = city["greenery"]
	var by_id := {}
	for b in architecture.buildings:
		by_id[b["id"]] = b
	var lots_by_id := {}
	for lot in lot_plan.lots:
		lots_by_id[lot["id"]] = lot["polygon"]

	_expect(plan.signs.size() >= 400, "the streets are signage-heavy (%d signs)" % plan.signs.size())
	var per_building := {}
	var off_wall := 0
	var wrong_height := 0
	var outside_lot := 0
	var too_many := 0
	var low := float(g["sign_min_height"])
	var high := float(g["sign_max_height"])
	for s in plan.signs:
		var b: Dictionary = by_id[s["building"]]
		per_building[s["building"]] = int(per_building.get(s["building"], 0)) + 1
		# on the wall: in the building's own frame the sign sits on one face
		var u: Vector2 = b["u"]
		var local := Vector2((s["pos"] - b["center"]).dot(u), (s["pos"] - b["center"]).dot(u.orthogonal()))
		var half: Vector2 = b["size"] * 0.5
		var on_x_face := absf(absf(local.x) - half.x) < 0.05 and absf(local.y) <= half.y + 0.05
		var on_y_face := absf(absf(local.y) - half.y) < 0.05 and absf(local.x) <= half.x + 0.05
		if not (on_x_face or on_y_face):
			off_wall += 1
		if float(s["above_base"]) < low - 0.01 or float(s["above_base"]) + float(s["size"].y) > float(b["render_height"]):
			wrong_height += 1
		# the sign must not poke out of the lot (so it cannot reach the road)
		var tip: Vector2 = s["pos"] + (s["normal"] as Vector2) * float(s["size"].z)
		if not Geometry2D.is_point_in_polygon(tip, lots_by_id[b["lot"]]):
			outside_lot += 1
		if float(s["above_base"]) > high + 0.01:
			wrong_height += 1
	for id in per_building:
		if per_building[id] > int(g["signs"].get(by_id[id]["group"], 0)):
			too_many += 1
	_expect(off_wall == 0, "every sign is mounted on a wall (%d floating)" % off_wall)
	_expect(wrong_height == 0, "every sign is at shop height, below its roof (%d wrong)" % wrong_height)
	_expect(outside_lot == 0, "no sign sticks out of its lot towards the road (%d do)" % outside_lot)
	_expect(too_many == 0, "no building has more signs than the data allows")
	var groups := {}
	for s in plan.signs:
		groups[by_id[s["building"]]["group"]] = true
	_expect(groups.has("midrise") and groups.has("core") and groups.has("harbour") and groups.has("lowrise"), "signs appear in every district type that should have them")
	var again := SignPlan.new(city, RoadNetwork.new(city), architecture)
	var same := again.signs.size() == plan.signs.size()
	if same:
		for i in plan.signs.size():
			same = same and again.signs[i]["pos"].is_equal_approx(plan.signs[i]["pos"]) and again.signs[i]["color"] == plan.signs[i]["color"]
	_expect(same, "the signs are reproducible (%d signs)" % plan.signs.size())


func _inside_any(p: Vector2, polygons: Array) -> bool:
	for poly in polygons:
		if Geometry2D.is_point_in_polygon(p, poly):
			return true
	return false


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
