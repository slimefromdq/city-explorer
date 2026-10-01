# validate_routes - checks data/routes.json against the terrain.
#
# Run:  godot --headless --path . --script res://tools/validate_routes.gd
# For every line: grade never above max_grade, track level for LEVEL_RUN before each stop, every
# stop's centre on the path, and the tunnel's roof buried at least MIN_COVER under the ground (or the
# river bed). Also prints each line's length and the ride time at cruise speed.
extends SceneTree

const MAX_GRADE := 0.08
const LEVEL_RUN := 25.0
const MIN_COVER := 0.8
const ROOF_ABOVE_FLOOR := 4.6   # floor to the top of the roof slab
const SKIP_COVER_WITHIN := 0.0
var fails := 0


func _init() -> void:
	var CityData = load("res://city/city_data.gd")
	var TerrainHeight = load("res://city/terrain_height.gd")
	var city: Dictionary = CityData.load_city()
	var terrain = TerrainHeight.new(city)
	var rd := RouteData.load_default()
	for line in rd.lines:
		var path: PackedVector3Array = line["path"]
		var lid: String = line["id"]
		var worst_cover := INF
		var worst_at := Vector3.ZERO
		var max_grade := 0.0
		var s := 0.0
		var samples: Array = []
		for i in range(1, path.size()):
			var seg := Vector2(path[i].x - path[i - 1].x, path[i].z - path[i - 1].z).length()
			if seg > 0.001:
				max_grade = maxf(max_grade, absf(path[i].y - path[i - 1].y) / seg)
		var length: float = line["length"]
		var step := 2.0
		var d := 0.0
		while d <= length:
			var smp := RouteData.sample(path, d)
			var p: Vector3 = smp["pos"]
			var ground: float = terrain.height_at(Vector2(p.x, p.z))
			# the roof is as wide as the tunnel: look at the worst ground over +-3 m sideways
			var dir: Vector3 = smp["dir"]
			var side := Vector3(-dir.z, 0, dir.x).normalized()
			var g := ground
			for off in [-3.0, 3.0]:
				var q: Vector3 = p + side * float(off)
				g = minf(g, terrain.height_at(Vector2(q.x, q.z)))
			var cover := g - (p.y + ROOF_ABOVE_FLOOR)
			if cover < worst_cover:
				worst_cover = cover
				worst_at = p
			d += step
		_expect(max_grade <= MAX_GRADE + 0.002, "line %s: steepest grade %.1f%% (max %.0f%%)" % [lid, max_grade * 100.0, MAX_GRADE * 100.0])
		_expect(worst_cover >= MIN_COVER, "line %s: thinnest cover %.2f m at (%d, %.1f, %d)" % [lid, worst_cover, worst_at.x, worst_at.y, worst_at.z])
		for st in line["stops"]:
			var sp: Vector3 = st["pos"]
			var s0: float = st["s"] - rd.train_length * 0.5 - LEVEL_RUN
			var s1: float = st["s"] + rd.train_length * 0.5 + LEVEL_RUN * 0.5
			var y0: float = RouteData.sample(path, clampf(st["s"], 0, length))["pos"].y
			var level := true
			var ds := maxf(s0, 0.0)
			while ds <= minf(s1, length):
				var yy: float = RouteData.sample(path, ds)["pos"].y
				if absf(yy - y0) > 0.02:
					level = false
				ds += 2.0
			var offset := (RouteData.sample(path, st["s"])["pos"] as Vector3).distance_to(sp)
			_expect(level, "line %s: stop %s is on level track (%.0f m before, %.0f m after)" % [lid, st["stop"], LEVEL_RUN + rd.train_length * 0.5, LEVEL_RUN * 0.5 + rd.train_length * 0.5])
			_expect(offset < 1.0, "line %s: stop %s centre lies on the path (off by %.2f m)" % [lid, st["stop"], offset])
			_expect(absf(sp.y - y0) < 0.05, "line %s: stop %s y matches the path" % [lid, st["stop"]])
		var s_a: float = line["stops"][0]["s"]
		var s_b: float = line["stops"][line["stops"].size() - 1]["s"]
		var dist: float = absf(s_b - s_a)
		print("  line %s: path %.0f m, stops %.0f m apart, ride at %.0f m/s cruise ~ %.1f s" % [lid, length, dist, line["cruise_speed"], dist / line["cruise_speed"] + 4.0])
	print("validate_routes: %s" % ("OK" if fails == 0 else "%d FAILED" % fails))
	quit(1 if fails > 0 else 0)


func _expect(ok: bool, msg: String) -> void:
	if ok:
		print("  ok   ", msg)
	else:
		fails += 1
		print("  FAIL ", msg)
