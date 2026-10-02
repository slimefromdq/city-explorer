extends RefCounted
## Pure route geometry and elevations shared by rendering, validation and walking.
const CityData := preload("res://city/city_data.gd")
const BuildingPlan := preload("res://city/building_plan.gd")
const RoadBuilder := preload("res://city/road_builder.gd")
const LandmarkBuilder := preload("res://city/landmark_builder.gd")
const LIFT := 0.56  # above the highest road surface, with a shallow ramp at the station
const SAMPLE_STEP := 2.0

var points := PackedVector2Array()
var samples := PackedVector3Array()
var approach := Vector2.ZERO
var approach_samples := PackedVector3Array()
var width := 4.0
var bridge: Dictionary = {}
var stops: Array = []
var signs: Array = []
var rest_points: Array = []
var spurs: Array = []
var length := 0.0
var errors: Array[String] = []
var _terrain
var _arch := 0.0

func _init(city: Dictionary, terrain) -> void:
	_terrain = terrain
	var data: Dictionary = city.get("discovery_walk", {})
	if data.is_empty():
		return
	points = CityData.to_points(data.get("points", []))
	var entry: Array = data.get("approach", [])
	if entry.size() != 2:
		errors.append("Walk requires a street crossing approach")
		return
	approach = Vector2(entry[0], entry[1])
	width = float(data.get("width", 4.0))
	stops = data.get("stops", [])
	signs = data.get("signs", [])
	rest_points = data.get("rest_points", [])
	_arch = float(city["roads"]["bridge_arch_height"])
	for b in city["bridges"]:
		if b["id"] == data.get("bridge", ""):
			bridge = b
	if points.size() < 2 or width < 2.0 or bridge.is_empty():
		errors.append("Walk requires at least two points, width >= 2 m and an existing bridge")
		return
	if approach.distance_to(points[1]) < 0.1:
		errors.append("Crossing approach must differ from the first turn")
		return
	for i in points.size() - 1:
		if points[i].distance_to(points[i + 1]) < 0.1:
			errors.append("Walk has duplicate adjacent points")
			return
	for i in points.size() - 1:
		var distance := points[i].distance_to(points[i + 1])
		length += distance
		var steps := ceili(distance / SAMPLE_STEP)
		for j in steps:
			var p := points[i].lerp(points[i + 1], float(j) / steps)
			samples.append(Vector3(p.x, height_at(p), p.y))
	var last := points[points.size() - 1]
	samples.append(Vector3(last.x, height_at(last), last.y))
	var approach_steps := ceili(approach.distance_to(points[1]) / SAMPLE_STEP)
	for j in approach_steps + 1:
		var p := approach.lerp(points[1], float(j) / approach_steps)
		approach_samples.append(Vector3(p.x, height_at(p), p.y))
	for stop in stops:
		if int(stop.get("index", -1)) < 0 or int(stop.get("index", -1)) >= points.size():
			errors.append("Walk stop has an invalid point index")
	for entry_data in data.get("spurs", []):
		var branch := CityData.to_points(entry_data.get("points", []))
		if branch.size() < 2 or branch[0].distance_to(closest_point(branch[0])) > 0.1:
			errors.append("Walk spur must connect to the main promenade")
			continue
		var branch_samples := PackedVector3Array()
		var valid := true
		for i in branch.size() - 1:
			var steps := ceili(branch[i].distance_to(branch[i + 1]) / SAMPLE_STEP)
			if steps < 1:
				errors.append("Walk spur has duplicate adjacent points")
				valid = false
				break
			for j in steps:
				var p := branch[i].lerp(branch[i + 1], float(j) / steps)
				branch_samples.append(Vector3(p.x, _terrain.height_at(p, false) + 0.16, p.y))
		if valid:
			var p := branch[branch.size() - 1]
			branch_samples.append(Vector3(p.x, _terrain.height_at(p, false) + 0.16, p.y))
			if absf(height_at(branch[0]) - branch_samples[0].y) > 0.05:
				errors.append("Walk spur requires a level junction")
			spurs.append({"id": entry_data["id"], "name": entry_data["name"], "points": branch, "samples": branch_samples, "sign": entry_data.get("sign", {})})

func bridge_contains(p: Vector2) -> bool:
	if bridge.is_empty():
		return false
	var a := Vector2(bridge["from"][0], bridge["from"][1])
	var b := Vector2(bridge["to"][0], bridge["to"][1])
	var t := (p - a).dot(b - a) / a.distance_squared_to(b)
	return t >= 0.0 and t <= 1.0 and p.distance_to(a.lerp(b, t)) <= float(bridge["width"]) * 0.5

func height_at(p: Vector2) -> float:
	if bridge_contains(p):
		# Match the rendered bridge's sampled arch, not the riverbed underneath.
		var a := Vector2(bridge["from"][0], bridge["from"][1])
		var b := Vector2(bridge["to"][0], bridge["to"][1])
		var t := clampf((p - a).dot(b - a) / a.distance_squared_to(b), 0.0, 1.0)
		var steps := maxi(2, ceili(a.distance_to(b) / RoadBuilder.BRIDGE_STEP))
		var low := floorf(t * steps) / steps
		var high := minf(low + 1.0 / steps, 1.0)
		var arch := lerpf(sin(PI * low), sin(PI * high), (t - low) * steps) * _arch
		return lerpf(_terrain.height_at(a), _terrain.height_at(b), t) + arch + LIFT
	var lift := LIFT
	if points.size() >= 2:
		var first := Geometry2D.get_closest_point_to_segment(p, points[0], points[1])
		if p.distance_to(first) <= width:
			lift = lerpf(TerrainApron.ROAD_LIFT, LIFT, points[0].distance_to(first) / points[0].distance_to(points[1]))
		var crossing := Geometry2D.get_closest_point_to_segment(p, points[1], approach)
		if p.distance_to(crossing) <= width:
			lift = lerpf(LIFT, TerrainApron.ROAD_LIFT, points[1].distance_to(crossing) / points[1].distance_to(approach))
		var last := points.size() - 1
		var arrival := Geometry2D.get_closest_point_to_segment(p, points[last - 1], points[last])
		if p.distance_to(arrival) <= width:
			lift = lerpf(LIFT, 0.16, points[last - 1].distance_to(arrival) / points[last - 1].distance_to(points[last]))
	return _terrain.height_at(p, false) + lift

func distance_to(p: Vector2) -> float:
	var distance := p.distance_to(closest_point(p))
	for spur in spurs:
		var branch: PackedVector2Array = spur["points"]
		for i in branch.size() - 1:
			distance = minf(distance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, branch[i], branch[i + 1])))
	return distance

func closest_point(p: Vector2) -> Vector2:
	var nearest := INF
	var closest := Vector2.INF
	for i in points.size() - 1:
		var q := Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])
		if p.distance_to(q) < nearest:
			nearest = p.distance_to(q)
			closest = q
	return closest

func validate(buildings: Array, city: Dictionary) -> Array[String]:
	var problems: Array[String] = errors.duplicate()
	if not errors.is_empty() or samples.is_empty():
		return problems
	var land := CityData.land_polygon(city)
	var checked_samples := samples.duplicate()
	checked_samples.append_array(approach_samples)
	for spur in spurs:
		checked_samples.append_array(spur["samples"])
	for sample in checked_samples:
		var p := Vector2(sample.x, sample.z)
		if not Geometry2D.is_point_in_polygon(p, land):
			problems.append("Walk leaves the land at %s" % p)
			break
		if _terrain.height_at(p) < _terrain.sea_level and not bridge_contains(p):
			problems.append("Walk crosses water without a bridge at %s" % p)
			break
	for b in solid_obstacles(buildings, city):
		var poly := BuildingPlan.rect_corners(b["center"], b["u"], b["size"] * 0.5)
		for sample in checked_samples:
			var p := Vector2(sample.x, sample.z)
			var inside := Geometry2D.is_point_in_polygon(p, poly)
			var clearance := INF
			for edge in poly.size():
				clearance = minf(clearance, p.distance_to(Geometry2D.get_closest_point_to_segment(p, poly[edge], poly[(edge + 1) % poly.size()])))
			if inside or clearance < width * 0.5 + PlayerScale.RADIUS:
				problems.append("Walk overlaps building %s near %s" % [b["id"], p])
				break
	return problems

# Include the square's existing solid features, not just ordinary lot buildings.
static func solid_obstacles(buildings: Array, city: Dictionary) -> Array:
	var all := buildings.duplicate()
	for feature in city["precinct"]["features"]:
		if feature["kind"] in ["podium", "pavilion"]:
			all.append({"id": feature["name"], "center": Vector2(feature["center"][0], feature["center"][1]), "u": Vector2.from_angle(deg_to_rad(float(feature.get("yaw", 0)))), "size": Vector2(feature["size"][0], feature["size"][1]), "height": float(feature["height"])})
	for landmark in city["landmarks"]:
		if landmark["kind"] == "tower":
			all.append({"id": landmark["name"], "center": Vector2(landmark["position"][0], landmark["position"][1]), "u": Vector2.from_angle(deg_to_rad(float(landmark.get("yaw", 0)))), "size": LandmarkBuilder.ground_footprint(landmark)["half"] * 2.0, "height": float(landmark["height"])})
	return all
