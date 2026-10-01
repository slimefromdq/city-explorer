# Sightlines - "can you see the tower from here?"
#
# One job: the line-of-sight rules for the main landmark. The JSON lists viewpoints
# (places across the city where people stand); from each one, the tower must show at
# least its upper part. This file gives two things:
#   ceiling_over(...)  used while PLANNING: how high may a building be before it blocks
#                      a line of sight? (the planner keeps buildings under it)
#   find_blockers(...) used to CHECK: walk every line of sight and report what, if
#                      anything, gets in the way (a building, a hill, another landmark).
# Heights are absolute (metres above sea level), so hills count too.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

const TERRAIN_STEP := 8.0   # how often the ground is tested along a line of sight (m)
const LANDMARK_BOX := 36.0  # other landmarks are treated as a box this wide when checking (m)

var clearance: float
var half_width: float
var roof_extra: float  # roof gardens and parapets: every roof is treated as this much taller
var target_id: String
var target_position: Vector2
var tower_height: float
# Each ray: {"id", "name", "from": Vector2, "to": Vector2, "eye_y": float, "target_y": float}
var rays: Array = []

var _city: Dictionary
var _terrain


func _init(city: Dictionary, terrain) -> void:
	_city = city
	_terrain = terrain
	var cfg: Dictionary = city["sightlines"]
	clearance = float(cfg["clearance"])
	half_width = float(cfg["corridor_half_width"])
	roof_extra = float(city["greenery"]["roof_garden_height"])
	target_id = cfg["target"]
	for lm in city["landmarks"]:
		if lm["id"] == target_id:
			target_position = Vector2(lm["position"][0], lm["position"][1])
			tower_height = float(lm["height"])
	# The line of sight aims at the LOWEST part of the tower that must be visible. Any line to a
	# higher part lies above it, so keeping this one clear keeps all of them clear.
	var target_y: float = terrain.height_at(target_position) + tower_height * float(cfg["visible_from_fraction"])
	for vp in cfg["viewpoints"]:
		var from := Vector2(vp["position"][0], vp["position"][1])
		rays.append({"id": vp["id"], "name": vp["name"], "from": from, "to": target_position,
			"eye_y": terrain.height_at(from) + float(cfg["eye_height"]), "target_y": target_y})


# Height of a line of sight above sea level at fraction t of the way to the tower.
func ray_y(ray: Dictionary, t: float) -> float:
	return lerpf(float(ray["eye_y"]), float(ray["target_y"]), t)


# The highest a structure over this rectangle may reach (above sea level) without blocking any
# line of sight; INF if no sightline passes near it. The corridor is widened by half_width so
# the view is a ribbon, not a hair.
func ceiling_over(center: Vector2, u: Vector2, half: Vector2) -> float:
	var ceiling := INF
	var widened := half + Vector2(half_width, half_width)
	for ray in rays:
		var span := Geo2D.segment_rect_overlap(ray["from"], ray["to"], center, u, widened)
		if span.x >= 0.0:
			ceiling = minf(ceiling, ray_y(ray, span.x) - clearance)
	return ceiling


# Lines of sight that are blocked, with what blocks them: [{"id", "name", "blocked_by"}].
# `buildings` is BuildingPlan.buildings; `extra` is the safety margin to demand (0 = exact).
func find_blockers(buildings: Array, extra: float = 0.0) -> Array:
	var blocked: Array = []
	for ray in rays:
		var what := _first_blocker(ray, buildings, extra)
		if what != "":
			blocked.append({"id": ray["id"], "name": ray["name"], "blocked_by": what})
	return blocked


func _first_blocker(ray: Dictionary, buildings: Array, extra: float) -> String:
	var from: Vector2 = ray["from"]
	var to: Vector2 = ray["to"]
	var length := from.distance_to(to)
	# the ground (hills)
	var steps := ceili(length / TERRAIN_STEP)
	for i in range(1, steps):
		var t := float(i) / steps
		var p := from.lerp(to, t)
		if _terrain.height_at(p) + extra > ray_y(ray, t):
			return "terrain at (%d, %d)" % [p.x, p.y]
	# the buildings: where the line enters a building's footprint it must still be above its roof
	for b in buildings:
		var span := Geo2D.segment_rect_overlap(from, to, b["center"], b["u"], b["size"] * 0.5)
		if span.x < 0.0 or span.x > 0.999:
			continue
		var roof := _roof_y(b)
		if roof + extra > ray_y(ray, span.x):
			return "%s (%.0f m roof)" % [b["id"], roof - _terrain.height_at(b["center"])]
	# the other landmarks (treated as boxes)
	for lm in _city["landmarks"]:
		if lm["id"] == target_id:
			continue
		var c := Vector2(lm["position"][0], lm["position"][1])
		var span := Geo2D.segment_rect_overlap(from, to, c, Vector2.RIGHT, Vector2(LANDMARK_BOX, LANDMARK_BOX) * 0.5)
		if span.x >= 0.0 and _terrain.height_at(c) + float(lm["height"]) + extra > ray_y(ray, span.x):
			return "landmark %s" % lm["id"]
	return ""


# The roof of a planned building, above sea level (it stands on the lowest point under it).
func _roof_y(b: Dictionary) -> float:
	var low: float = _terrain.height_at(b["center"])
	var v: Vector2 = (b["u"] as Vector2).orthogonal()
	for corner in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		low = minf(low, _terrain.height_at(b["center"] + b["u"] * corner.x * b["size"].x * 0.5 + v * corner.y * b["size"].y * 0.5))
	return low + float(b["height"]) + roof_extra
