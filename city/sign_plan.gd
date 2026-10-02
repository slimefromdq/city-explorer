# SignPlan - where the neon signs go.
#
# One job: put signs on the facades. The signage-heavy streets of Seoul are the model: most
# buildings carry a few signs, mounted low (shop height) on the wall that faces the nearest
# road. A sign is either a flat panel on the wall or a narrow "blade" sign sticking out
# from it. Counts and heights come from the JSON; each building has its own seeded
# generator so the same JSON always gives the same signs. No 3D is built here.
extends RefCounted

const CityData := preload("res://city/city_data.gd")

const CELL := 40.0           # size of a cell in the road-point lookup grid (m)
const NEON_COLORS := 7       # how many colours the builder has (the plan only picks an index)
const FLAT_WIDTH := Vector2(3.0, 8.0)
const FLAT_HEIGHT := Vector2(1.2, 3.0)
const FLAT_DEPTH := 0.3
const BLADE_WIDTH := 0.6
const BLADE_HEIGHT := Vector2(3.0, 6.0)
const BLADE_REACH := 1.2     # how far a blade sign sticks out from the wall (m); less than the lot setback

# Each sign: {"building": String, "pos": Vector2 (on the wall), "normal": Vector2 (out of the wall),
#             "above_base": float (m above the building's base), "size": Vector3 (along the wall, tall, out of the wall),
#             "blade": bool, "color": int}
var signs: Array = []

var _grid := {}  # Vector2i cell -> Array of road points


func _init(city: Dictionary, network, building_plan) -> void:
	var g: Dictionary = city["greenery"]
	var counts: Dictionary = g["signs"]
	var low := float(g["sign_min_height"])
	var high := float(g["sign_max_height"])
	for seg in network.segments:
		for p in seg["points"]:
			var cell := Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))
			if not _grid.has(cell):
				_grid[cell] = []
			_grid[cell].append(p)
	for b in building_plan.buildings:
		var count := int(counts.get(b["group"], 0))
		if b["group"] == "civic" or count == 0 or float(b.get("render_height", b["height"])) < low + 3.0:
			continue
		var road := _nearest_road_point(b["center"])
		if road == Vector2.INF:
			continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:signs:%s" % [int(city["meta"]["seed"]), b["id"]])
		_sign_the_building(b, road, count, low, minf(high, float(b.get("render_height", b["height"])) - 3.0), rng)


func _sign_the_building(b: Dictionary, road: Vector2, count: int, low: float, high: float, rng: RandomNumberGenerator) -> void:
	var u: Vector2 = b["u"]
	var v := u.orthogonal()
	var center: Vector2 = b["center"]
	var toward := (road - center).normalized()
	# the wall that faces the road: of the four outward directions, the one pointing most towards it
	var normal := u
	for candidate in [u, -u, v, -v]:
		if candidate.dot(toward) > normal.dot(toward):
			normal = candidate
	var half_out: float = (b["size"].x if absf(normal.dot(u)) > 0.5 else b["size"].y) * 0.5
	var wall_width: float = b["size"].y if absf(normal.dot(u)) > 0.5 else b["size"].x
	var tangent := Vector2(normal.y, -normal.x)
	var band := (high - low) / count  # each sign gets its own height band, so signs never overlap
	for k in count:
		var blade := rng.randf() < 0.45
		var width := BLADE_WIDTH if blade else minf(lerpf(FLAT_WIDTH.x, FLAT_WIDTH.y, rng.randf()), wall_width * 0.8)
		var tall := lerpf(BLADE_HEIGHT.x if blade else FLAT_HEIGHT.x, BLADE_HEIGHT.y if blade else FLAT_HEIGHT.y, rng.randf())
		var slack := maxf(wall_width * 0.5 - width * 0.5 - 0.5, 0.0)
		var along := (rng.randf() * 2.0 - 1.0) * slack
		var y := low + band * k + rng.randf() * maxf(band - tall, 0.0)
		y = minf(y, float(b.get("render_height", b["height"])) - 0.5 - tall)  # keep signs on walls below pitched roofs/crowns
		if y < low:
			continue  # no room for a sign of this size at shop height on this building
		signs.append({
			"building": b["id"], "pos": center + normal * half_out + tangent * along, "normal": normal,
			"above_base": y, "size": Vector3(width, tall, BLADE_REACH if blade else FLAT_DEPTH),
			"blade": blade, "color": rng.randi() % NEON_COLORS,
		})


# The closest road point to p (searching outwards a few cells), or Vector2.INF if none is near.
func _nearest_road_point(p: Vector2) -> Vector2:
	var cx := int(floor(p.x / CELL))
	var cy := int(floor(p.y / CELL))
	for radius in [1, 2, 4]:
		var best := Vector2.INF
		var best_d := INF
		for dx in range(-radius, radius + 1):
			for dy in range(-radius, radius + 1):
				for q in _grid.get(Vector2i(cx + dx, cy + dy), []):
					var d := p.distance_squared_to(q)
					if d < best_d:
						best_d = d
						best = q
		if best != Vector2.INF:
			return best
	return Vector2.INF
