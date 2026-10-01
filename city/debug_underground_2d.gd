# DebugUnderground2D - draws the metro and the sewer society on top of the map.
#
# One job: show the two hidden layers. It is a CHILD of DebugMap2D so it shares
# the parent's scale/position (same screen spot as the surface) and its toggles.
# WHY separate: the surface map file stays short, and each layer is easy to find.
extends Node2D

const DebugDraw := preload("res://city/debug_draw.gd")
const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

const SEWER := Color("6b4f2a")
const SEWER_DARK := Color("2c1d0c")

@onready var map := get_parent()


func _draw() -> void:
	if map.city.is_empty():
		return
	if map.show_sewers:
		_draw_sewers()
	if map.show_metro:
		_draw_metro()


# Dashed = "you cannot see this from the street".
func _draw_sewers() -> void:
	var u: Dictionary = map.city["underground"]
	for t in u["tunnels"]:
		var pts := CityData.to_points(t["path"])
		for i in range(pts.size() - 1):
			draw_dashed_line(map.px(pts[i]), map.px(pts[i + 1]), SEWER, maxf(float(t["width"]) * map.map_scale, 2.5), 7.0)
	for c in u["chambers"]:
		var at: Vector2 = map.px(Vector2(c["center"][0], c["center"][1]))
		var r: float = float(c["radius"]) * map.map_scale
		draw_circle(at, r, Color(SEWER_DARK, 0.75))
		draw_arc(at, r, 0.0, TAU, 32, SEWER, 2.5, true)
		DebugDraw.label(self, at + Vector2(-r, r + 13), String(c["name"]), 12, Color("f0d9a8"), Color.BLACK)
	for e in u["entrances"]:  # where a surface person can climb down
		draw_circle(map.px(Vector2(e["at"][0], e["at"][1])), 4.5, Color("78e08f"))
		draw_arc(map.px(Vector2(e["at"][0], e["at"][1])), 4.5, 0.0, TAU, 12, Color.BLACK, 1.5)
	for o in u["outfalls"]:  # where the pipes empty into the water
		var q: Vector2 = map.px(Vector2(o["at"][0], o["at"][1]))
		draw_rect(Rect2(q - Vector2(4.5, 4.5), Vector2(9, 9)), Color("e8e0c0"))
		draw_rect(Rect2(q - Vector2(4.5, 4.5), Vector2(9, 9)), Color.BLACK, false, 1.5)


# Tunnel = dashed, sky rail = solid and fatter, ramp between them = dotted.
# The third number of each path point is the height (see city.json "metro.note").
func _draw_metro() -> void:
	for line in map.city["metro"]["lines"]:
		var color := Color(line["color"])
		var path: Array = line["path"]
		for i in range(path.size() - 1):
			var a: Vector2 = map.px(Vector2(path[i][0], path[i][1]))
			var b: Vector2 = map.px(Vector2(path[i + 1][0], path[i + 1][1]))
			var ha := float(path[i][2])
			var hb := float(path[i + 1][2])
			if ha > 0.0 and hb > 0.0:
				draw_line(a, b, Color.WHITE, 9.0, true)
				draw_line(a, b, color, 6.0, true)
			elif ha < 0.0 and hb < 0.0:
				draw_dashed_line(a, b, Color.WHITE, 6.0, 9.0)
				draw_dashed_line(a, b, color, 4.0, 9.0)
			else:
				draw_dashed_line(a, b, Color.WHITE, 6.0, 3.0)
				draw_dashed_line(a, b, color, 4.0, 3.0)
	var drawn := {}
	for line in map.city["metro"]["lines"]:
		for st in line["stations"]:
			var key := "%s@%s" % [st["name"], st["at"]]
			if drawn.has(key):
				continue
			drawn[key] = true
			var hub: bool = st.has("site")
			var at: Vector2 = map.px(Vector2(st["at"][0], st["at"][1]))
			var r := 9.0 if hub else 4.5
			var sky: bool = Geo2D.track_at(Vector2(st["at"][0], st["at"][1]), line["path"])["height"] > 0.0
			if sky and not hub:  # square = platform up on the sky rail
				draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), Color.WHITE)
				draw_rect(Rect2(at - Vector2(r, r), Vector2(r, r) * 2.0), Color.BLACK, false, 2.0)
			else:
				draw_circle(at, r, Color.WHITE)
				draw_arc(at, r, 0.0, TAU, 16, Color.BLACK, 2.0)
			if not hub:  # the hub is already labelled by its site
				DebugDraw.label(self, at + Vector2(7, -5), String(st["name"]), 10, Color.WHITE, Color.BLACK)
