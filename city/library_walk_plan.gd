extends RefCounted
## Park-to-library route. The endpoint joins CivicAccess's existing street apron.
const CityData := preload("res://city/city_data.gd")
const BuildingPlan := preload("res://city/building_plan.gd")
const LIFT := 0.56
var points := PackedVector2Array()
var samples := PackedVector3Array()
var signs: Array = []
var width := 4.0
var length := 0.0
var errors: Array[String] = []
var _terrain

func _init(city: Dictionary, terrain, park) -> void:
	_terrain = terrain
	var data: Dictionary = city.get("discovery_walk", {}).get("library_walk", {})
	points = CityData.to_points(data.get("points", []))
	signs = data.get("signs", [])
	if points.size() < 2:
		errors.append("Library walk needs at least two points")
		return
	if park.distance_to(points[0]) > 0.1 or absf(park.height_at(points[0]) - height_at(points[0])) > 0.05:
		errors.append("Library walk must connect level to the park loop")
	for i in points.size() - 1:
		var distance := points[i].distance_to(points[i + 1])
		if distance < 0.1:
			errors.append("Library walk has duplicate adjacent points")
			continue
		length += distance
		var steps := ceili(distance)
		for j in steps:
			var p := points[i].lerp(points[i + 1], float(j) / steps)
			samples.append(Vector3(p.x, height_at(p), p.y))
	var last := points[points.size() - 1]
	samples.append(Vector3(last.x, height_at(last), last.y))

func height_at(p: Vector2) -> float:
	var lift := minf(LIFT, lerpf(0.16, LIFT, clampf(p.distance_to(points[0]) / 30, 0, 1)))
	lift = minf(lift, lerpf(TerrainApron.ROAD_LIFT, LIFT, clampf(p.distance_to(points[points.size() - 1]) / 20, 0, 1)))
	return _terrain.height_at(p, false) + lift

func distance_to(p: Vector2) -> float:
	var nearest := INF
	for i in points.size() - 1:
		nearest = minf(nearest, p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])))
	return nearest

func validate(buildings: Array, city: Dictionary) -> Array[String]:
	var problems: Array[String] = errors.duplicate()
	var land := CityData.land_polygon(city)
	for i in samples.size():
		var s := samples[i]
		if i > 0:
			var prev := samples[i - 1]
			if absf(s.y - prev.y) / Vector2(s.x - prev.x, s.z - prev.z).length() > 0.20:
				problems.append("Library walk exceeds 20% grade at %s" % s)
		var next := samples[mini(i + 1, samples.size() - 1)]
		var prev := samples[maxi(i - 1, 0)]
		var across := Vector2(next.x - prev.x, next.z - prev.z).normalized().orthogonal()
		for side in [-1.0, 0.0, 1.0]:
			var p: Vector2 = Vector2(s.x, s.z) + across * side * (width * 0.5 + PlayerScale.RADIUS)
			if not Geometry2D.is_point_in_polygon(p, land) or _terrain.height_at(p) < _terrain.sea_level:
				problems.append("Library walk leaves dry land at %s" % p)
	for b in buildings:
		if b.get("site_kind", "") == "library" or distance_to(b["center"]) > b["size"].length() * 0.5 + 6:
			continue
		var footprint := BuildingPlan.rect_corners(b["center"], b["u"], b["size"] * 0.5)
		for polygon in Geometry2D.offset_polygon(footprint, width * 0.5 + PlayerScale.RADIUS):
			for s in samples:
				if Geometry2D.is_point_in_polygon(Vector2(s.x, s.z), polygon):
					problems.append("Library walk overlaps %s" % b["id"])
	return problems
