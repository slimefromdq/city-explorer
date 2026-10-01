class_name RouteData
extends RefCounted
## Loads data/routes.json: the one place that says which lines exist, where they stop and which way
## they run. Boards, route maps, tunnels, trains and destination stations all read from here.
##
##   stops: id -> {id, name, district, platform: Vector3, entrance: Vector3, style, stairs_dir, platform_side}
##   lines: Array of {id, name, short, color: Color, cruise_speed, path: PackedVector3Array (smoothed),
##                    raw: PackedVector3Array, stops: [{stop, s (train-centre arc length), pos: Vector3}], length}

const FILE := "res://data/routes.json"
const CORNER_RADIUS := 45.0   # how widely a path's corners are rounded (m)
const SAMPLE_STEP := 2.0      # spacing of the smoothed path's points (m)

var train_length := 24.0
var stops := {}
var lines: Array = []


static func load_default() -> RouteData:
	var rd := RouteData.new()
	var f := FileAccess.open(FILE, FileAccess.READ)
	if f == null:
		push_error("RouteData: cannot read %s" % FILE)
		return rd
	var parsed = JSON.parse_string(f.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("RouteData: %s is not valid JSON" % FILE)
		return rd
	rd.train_length = float(parsed.get("train_length", 24.0))
	for s in parsed["stops"]:
		var stop: Dictionary = s.duplicate(true)
		stop["platform"] = _v3(s["platform"])
		stop["entrance"] = _v3(s["entrance"])
		if s.has("stairs_dir"):
			stop["stairs_dir"] = Vector2(s["stairs_dir"][0], s["stairs_dir"][1])
		rd.stops[s["id"]] = stop
	for l in parsed["lines"]:
		var line: Dictionary = {"id": l["id"], "name": l["name"], "short": l["short"], "color": Color(l["color"]),
			"cruise_speed": float(l.get("cruise_speed", 25.0))}
		var raw := PackedVector3Array()
		for p in l["path"]:
			raw.append(_v3(p))
		line["raw"] = raw
		line["path"] = smooth(raw, CORNER_RADIUS)
		var stop_list: Array = []
		for st in l["stops"]:
			var pos := _v3(st["at"])
			stop_list.append({"stop": st["stop"], "pos": pos, "s": arc_of(line["path"], pos)})
		line["stops"] = stop_list
		line["length"] = path_length(line["path"])
		rd.lines.append(line)
	return rd


func line(id: String) -> Dictionary:
	for l in lines:
		if l["id"] == id:
			return l
	return {}


func stop(id: String) -> Dictionary:
	return stops.get(id, {})


## The destination stops of a line (everything but the hub).
func destinations() -> Array:
	var out: Array = []
	for id in stops:
		if id != "central":
			out.append(stops[id])
	return out


## The line that serves a stop (first match).
func line_of_stop(stop_id: String) -> Dictionary:
	for l in lines:
		for s in l["stops"]:
			if s["stop"] == stop_id and stop_id != "central":
				return l
	return {}


static func _v3(a) -> Vector3:
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


## Round the corners of a polyline: each interior vertex becomes a quadratic arc that starts and
## ends on the neighbouring straight pieces, so the direction (and the grade) change smoothly.
static func smooth(pts: PackedVector3Array, radius: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	if pts.size() < 3:
		return pts
	out.append(pts[0])
	for i in range(1, pts.size() - 1):
		var p := pts[i]
		var a := (p - pts[i - 1])
		var b := (pts[i + 1] - p)
		var la := a.length()
		var lb := b.length()
		var da := a / la
		var db := b / lb
		var turn := da.angle_to(db)
		var t: float = radius * tan(turn * 0.5)
		t = minf(t, 0.45 * minf(la, lb))
		if turn < 0.002 or t < 0.5:
			out.append(p)
			continue
		var p0 := p - da * t
		var p2 := p + db * t
		var n := maxi(6, ceili(t * 2.0 / SAMPLE_STEP))
		for k in range(n + 1):
			var u := float(k) / n
			out.append(p0 * ((1.0 - u) * (1.0 - u)) + p * (2.0 * (1.0 - u) * u) + p2 * (u * u))
	out.append(pts[pts.size() - 1])
	return out


static func path_length(p: PackedVector3Array) -> float:
	var s := 0.0
	for i in range(1, p.size()):
		s += p[i].distance_to(p[i - 1])
	return s


## Arc length of the point on the path closest to `pos`.
static func arc_of(path: PackedVector3Array, pos: Vector3) -> float:
	var best := INF
	var best_s := 0.0
	var s := 0.0
	for i in range(1, path.size()):
		var a := path[i - 1]
		var b := path[i]
		var ab := b - a
		var t := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := (a + ab * t).distance_to(pos)
		if d < best:
			best = d
			best_s = s + ab.length() * t
		s += ab.length()
	return best_s


## Point and forward direction at arc length s (clamped to the path).
static func sample(path: PackedVector3Array, s: float) -> Dictionary:
	var acc := 0.0
	for i in range(1, path.size()):
		var seg := path[i].distance_to(path[i - 1])
		if acc + seg >= s or i == path.size() - 1:
			var t := clampf((s - acc) / maxf(seg, 0.0001), 0.0, 1.0)
			return {"pos": path[i - 1].lerp(path[i], t), "dir": (path[i] - path[i - 1]).normalized()}
		acc += seg
	return {"pos": path[0], "dir": Vector3.RIGHT}
