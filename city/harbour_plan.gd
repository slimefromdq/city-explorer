extends RefCounted
## Presentation on the two pier reservations already in city.json. A clear
## central strip divides container stacks / ferry shelters. No new land lots.
var parts: Array = []
var civic: Array = []
var piers: Array = []
var approaches: Array = []
const RoadNetwork := preload("res://city/road_network.gd")
const RoadBuilder := preload("res://city/road_builder.gd")
const CONCRETE := Color(0.57, 0.59, 0.56)
const STEEL := Color(0.26, 0.33, 0.35)
const YELLOW := Color(0.84, 0.65, 0.24)
const WHITE := Color(0.85, 0.86, 0.79)
const CONTAINERS := [Color(0.33, 0.49, 0.56), Color(0.63, 0.33, 0.24), Color(0.35, 0.49, 0.35)]

func _init(city: Dictionary, terrain) -> void:
	var roads := RoadNetwork.new(city)
	for pier in city["harbour"]["piers"]:
		var a := Vector2(pier["from"][0], pier["from"][1])
		var end := Vector2(pier["to"][0], pier["to"][1])
		var length := a.distance_to(end)
		var width := float(pier["width"])
		var deck := maxf(terrain.height_at(a) + 0.15, terrain.sea_level + 2.8)
		var b := {"id": pier["id"], "center": (a + end) * 0.5, "u": (end - a).normalized(), "size": Vector2(length, width), "height": 12.0, "base_y": deck, "group": "harbour"}
		piers.append(b)
		_approach(a, deck, width, roads, terrain)
		_add(b, Vector3(0, -0.5, 0), Vector3(length, 1, width), CONCRETE)
		# Piles reach below sea level; the deck remains a single flat datum.
		for i in maxi(2, ceili(length / 24.0)):
			var x := -length * 0.5 + 8 + i * (length - 16) / maxi(1, ceili(length / 24.0) - 1)
			for sign in [-1.0, 1.0]:
				_add(b, Vector3(x, -deck * 0.5 - 2, sign * width * 0.40), Vector3(0.7, deck + 4, 0.7), STEEL)
		for sign in [-1.0, 1.0]:
			_add(b, Vector3(0, 0.02, sign * width * 0.46), Vector3(length, 0.04, 0.30), YELLOW)
		if pier.get("use", "ferry") == "cargo":
			var count := maxi(1, floori((length - 32) / 22.0))
			for i in count:
				var x := -length * 0.5 + 24 + i * 22.0
				for side in [-1.0, 1.0]:
					var z: float = side * width * 0.32
					var layers := 2 if i % 3 == 0 else 1
					for layer in layers:
						var y := 1.3 + layer * 2.6
						_add(b, Vector3(x, y, z), Vector3(12, 2.6, 2.5), CONTAINERS[(i + layer) % CONTAINERS.size()])
						# Vertical ribs read as shipping containers at pedestrian scales.
						for rib in 9:
							for face in [-1.0, 1.0]:
								_add(b, Vector3(x - 5.4 + rib * 1.35, y, z + face * 1.28), Vector3(0.08, 2.45, 0.08), STEEL)
			var crane_x := length * 0.36
			for side in [-1.0, 1.0]:
				_add(b, Vector3(crane_x, 5.5, side * width * 0.40), Vector3(0.8, 11, 0.8), YELLOW)
			_add(b, Vector3(crane_x, 11.5, 0), Vector3(1.4, 1, width * 0.86), YELLOW)
			_add(b, Vector3(crane_x, 8.2, 0), Vector3(0.12, 5.6, 0.12), STEEL)
		else:
			for i in 3:
				var x := -length * 0.5 + 26 + i * 30
				for side in [-1.0, 1.0]:
					var z: float = side * width * 0.31
					_add(b, Vector3(x, 4.1, z), Vector3(14, 0.30, width * 0.25), WHITE)
					for dx in [-5.5, 5.5]:
						_add(b, Vector3(x + dx, 2, z), Vector3(0.18, 4, 0.18), STEEL)
					_add(b, Vector3(x, 0.55, z), Vector3(8, 0.20, 0.8), STEEL)
					for dx in [-3, 3]:
						_add(b, Vector3(x + dx, 0.23, z), Vector3(0.15, 0.46, 0.7), STEEL)

func _add(b: Dictionary, center: Vector3, size: Vector3, color: Color) -> void:
	parts.append({"building": b, "kind": "box", "center": center, "size": size, "color": color})

func _approach(pier_start: Vector2, deck: float, width: float, roads, terrain) -> void:
	var nearest := Vector2.INF
	var distance := INF
	var lift := 0.45
	for road in roads.segments:
		if road["kind"] not in ["ring", "quay"]:
			continue
		for i in road["points"].size() - 1:
			var p := Geometry2D.get_closest_point_to_segment(pier_start, road["points"][i], road["points"][i + 1])
			if p.distance_to(pier_start) < distance:
				distance = p.distance_to(pier_start)
				nearest = p
				lift = RoadBuilder.LIFT[road["kind"]]
	if nearest == Vector2.INF or distance < 0.1:
		return
	var start_y: float = terrain.height_at(nearest) + lift + 0.03
	var points := PackedVector3Array()
	var steps := maxi(2, ceili(distance / 2.0))
	for i in steps + 1:
		var t := float(i) / steps
		var p := nearest.lerp(pier_start, t)
		var y := maxf(lerpf(start_y, deck + 0.02, t), terrain.height_at(p) + 0.15)
		points.append(Vector3(p.x, y, p.y))
	approaches.append({"points": points, "width": minf(6, width * 0.5)})

func validate() -> Array[String]:
	var errors: Array[String] = []
	for part in parts:
		var b: Dictionary = part["building"]
		var c: Vector3 = part["center"]
		var half: Vector3 = part["size"] * 0.5
		if absf(c.x) + half.x > b["size"].x * 0.5 + 0.001 or absf(c.z) + half.z > b["size"].y * 0.5 + 0.001 or c.y + half.y > b["height"] + 0.001:
			errors.append("Harbour part leaves pier reservation: %s" % b["id"])
	if approaches.size() != piers.size():
		errors.append("A harbour pier has no connection to the coastal road")
	return errors
