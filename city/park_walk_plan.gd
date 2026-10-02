extends RefCounted
## Selected existing park paths become playable. Their visual paving remains
## owned by GreeneryBuilder; this plan supplies matching physics and wayfinding.
const BuildingPlan := preload("res://city/building_plan.gd")
const CityData := preload("res://city/city_data.gd")
const LIFT := 0.16
var paths: Array = []
var signs: Array = []
var bridges: Array = []
var errors: Array[String] = []
var length := 0.0
var _terrain

func _init(city: Dictionary, greenery, terrain, discovery) -> void:
	_terrain = terrain
	signs = city.get("discovery_walk", {}).get("park_signs", [])
	var selected: Array = city.get("discovery_walk", {}).get("park_paths", [])
	for bridge in greenery.footbridges:
		if selected.has(bridge["path"]):
			var copy: Dictionary = bridge.duplicate()
			var points := PackedVector3Array()
			for p in bridge["points"]:
				points.append(Vector3(p.x, 0, p.y))
			var arrays := preload("res://city/ribbon_mesh.gd").build(points, bridge["width"])
			var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
			var polygon := PackedVector2Array()
			for i in points.size():
				polygon.append(Vector2(vertices[i * 2].x, vertices[i * 2].z))
			for i in range(points.size() - 1, -1, -1):
				polygon.append(Vector2(vertices[i * 2 + 1].x, vertices[i * 2 + 1].z))
			copy["polygon"] = polygon
			bridges.append(copy)
	for name in selected:
		var found := false
		for source in greenery.paths:
			if source["name"] != name:
				continue
			found = true
			var points: PackedVector2Array = source["points"]
			if points.size() < 3 or points[0].distance_to(points[points.size() - 1]) > 0.01:
				errors.append("Playable park loop must be closed: %s" % name)
				continue
			if discovery.distance_to(points[0]) > 0.1 or absf(discovery.height_at(points[0]) - height_at(points[0])) > 0.05:
				errors.append("Park loop must join the promenade at the same height")
			var samples := PackedVector3Array()
			for i in points.size():
				var p := points[i]
				samples.append(Vector3(p.x, height_at(p), p.y))
				if i > 0:
					length += p.distance_to(points[i - 1])
			var waypoints := points
			for raw in city["greenery"]["paths"]:
				if raw["name"] == name:
					waypoints = CityData.to_points(raw["points"])
			paths.append({"name": name, "width": source["width"], "points": points, "waypoints": waypoints, "samples": samples})
		if not found:
			errors.append("Unknown playable park path: %s" % name)

func bridge_at(p: Vector2) -> Dictionary:
	for bridge in bridges:
		if Geometry2D.is_point_in_polygon(p, bridge["polygon"]):
			return bridge
	return {}

func height_at(p: Vector2) -> float:
	var bridge := bridge_at(p)
	if not bridge.is_empty():
		return _terrain.height_at((bridge["from"] + bridge["to"]) * 0.5, false) + 0.18
	return _terrain.height_at(p, false) + 0.16

func distance_to(p: Vector2) -> float:
	var nearest := INF
	for path in paths:
		var points: PackedVector2Array = path["points"]
		for i in points.size() - 1:
			nearest = minf(nearest, p.distance_to(Geometry2D.get_closest_point_to_segment(p, points[i], points[i + 1])))
	return nearest

func validate(buildings: Array, city: Dictionary) -> Array[String]:
	var problems: Array[String] = errors.duplicate()
	var land := CityData.land_polygon(city)
	for path in paths:
		var points: PackedVector2Array = path["points"]
		for i in points.size() - 1:
			var tangent := (points[i + 1] - points[i]).normalized()
			var across := tangent.orthogonal()
			var steps := maxi(1, ceili(points[i].distance_to(points[i + 1])))
			for j in steps + 1:
				var p := points[i].lerp(points[i + 1], float(j) / steps)
				for side in [-1.0, 0.0, 1.0]:
					var edge: Vector2 = p + across * side * (float(path["width"]) * 0.5 + PlayerScale.RADIUS)
					if not Geometry2D.is_point_in_polygon(edge, land):
						problems.append("Park loop leaves land")
					if _terrain.height_at(edge) < _terrain.sea_level and bridge_at(edge).is_empty():
						problems.append("Park loop crosses water outside a footbridge at %s" % edge)
	for b in buildings:
		if distance_to(b["center"]) > b["size"].length() * 0.5 + 6:
			continue
		var footprint := BuildingPlan.rect_corners(b["center"], b["u"], b["size"] * 0.5)
		for path in paths:
			for p in path["points"]:
				for polygon in Geometry2D.offset_polygon(footprint, float(path["width"]) * 0.5 + PlayerScale.RADIUS):
					if Geometry2D.is_point_in_polygon(p, polygon):
						problems.append("Park loop overlaps %s" % b["id"])
	return problems
