# DebugMap2D - top-down 2D picture of city.json.
#
# One job: DRAW the data. It never changes it and never decides anything about
# the city. If the picture looks wrong, the data (or the generator later) is
# wrong, not this file. That is what makes it a trustworthy debugging tool.
extends Node2D

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

# Colours are presentation only (not layout), so they live here, not in the JSON.
const DISTRICT_COLORS := {
	"core": Color("c9a0dc"),
	"midrise": Color("f2c078"),
	"lowrise": Color("f5e6a8"),
	"harbour": Color("8ec3d6"),
	"park": Color("8fcf8a"),
}
const BG := Color("2b2f36")
const WATER := Color("3f7fc4")
const ROAD_STREET := Color("fdfdfd")
const ROAD_AVENUE := Color("d7d7d7")
const ROAD_DIAGONAL := Color("e8743b")
const BRIDGE := Color("7a4a24")
const LANDMARK := Color("d6212b")
const OUTLINE := Color(0, 0, 0, 0.55)
const LEGEND_WIDTH := 250.0
const MARGIN := 24.0

var _city: Dictionary
var _scale := 1.0
var _origin := Vector2.ZERO  # screen position of map (0, 0)


func _ready() -> void:
	_city = CityData.load_city()
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), BG)
	if _city.is_empty():
		_text(Vector2(MARGIN, MARGIN + 20), "Could not load res://data/city.json (see Output)", 18, LANDMARK)
		return
	_fit_map_to(view)
	var map_px := CityData.map_size(_city) * _scale
	draw_rect(Rect2(_origin, map_px), Color("1c1f24"))  # map bounds

	# Painter's order: later layers sit on top of earlier ones.
	_draw_districts(false)
	_draw_roads()
	_draw_districts(true)  # parks go over the roads: a park is meant to be road-free
	_draw_terrain()
	_draw_river()
	_draw_bridges()
	_draw_core_center()
	_draw_landmark()
	_draw_outside_mask()
	_draw_district_labels()  # last, so no road or river hides a name
	_draw_legend(view)


# Scale the map to fill the window, leaving a column on the right for the legend.
func _fit_map_to(view: Vector2) -> void:
	var avail := Vector2(view.x - LEGEND_WIDTH - MARGIN * 3.0, view.y - MARGIN * 2.0)
	var size := CityData.map_size(_city)
	_scale = minf(avail.x / size.x, avail.y / size.y)
	_origin = Vector2(MARGIN, MARGIN)


func _px(p: Vector2) -> Vector2:
	return _origin + p * _scale


# Two passes (parks=false, then parks=true) so parks can sit on top of the roads.
# The data still contains the roads under the park; Phase 3 decides how to clip them.
func _draw_districts(parks: bool) -> void:
	for d in _city["districts"]:
		if (d["type"] == "park") != parks:
			continue
		var screen := PackedVector2Array()
		for p in CityData.to_points(d["polygon"]):
			screen.append(_px(p))
		var color: Color = DISTRICT_COLORS.get(d["type"], Color.MAGENTA)
		draw_colored_polygon(screen, Color(color, 0.88) if parks else color)
		screen.append(screen[0])
		draw_polyline(screen, OUTLINE, 2.0)


# The river ends and hill rings can poke past the map edge; paint the margin over them.
func _draw_outside_mask() -> void:
	var view := get_viewport_rect().size
	var map_px := CityData.map_size(_city) * _scale
	var end := _origin + map_px
	draw_rect(Rect2(0, 0, _origin.x, view.y), BG)
	draw_rect(Rect2(end.x, 0, view.x - end.x, view.y), BG)
	draw_rect(Rect2(0, 0, view.x, _origin.y), BG)
	draw_rect(Rect2(0, end.y, view.x, view.y - end.y), BG)


func _draw_district_labels() -> void:
	for d in _city["districts"]:
		var is_park: bool = d["type"] == "park"
		var label: String = ("PARK: " if is_park else "") + String(d["name"])
		var at := _px(Geo2D.label_point(CityData.to_points(d["polygon"])))
		_text(at + Vector2(-label.length() * 4.0, 0), label, 15, Color.BLACK, Color(1, 1, 1, 0.85))


# Hills as faint dashed-looking rings: height is not visible top-down, so the
# label carries it.
func _draw_terrain() -> void:
	for h in _city["terrain"]["hills"]:
		var c := _px(Vector2(h["center"][0], h["center"][1]))
		var r: float = float(h["radius"]) * _scale
		draw_arc(c, r, 0.0, TAU, 64, Color(0.2, 0.15, 0.1, 0.5), 1.5, true)
		draw_arc(c, r * 0.55, 0.0, TAU, 48, Color(0.2, 0.15, 0.1, 0.5), 1.5, true)
		_text(c + Vector2(-r * 0.45, -r * 0.6), "%s +%dm" % [h["name"], int(h["height"])], 11, Color(0.25, 0.12, 0.02), Color(1, 1, 1, 0.8))


# Streets first (thin), avenues over them (wide), diagonals on top, so the
# hierarchy reads at a glance.
func _draw_roads() -> void:
	var size := CityData.map_size(_city)
	var roads: Dictionary = _city["roads"]
	var streets: Dictionary = roads["streets"]
	for y in streets["y"]:
		draw_line(_px(Vector2(0, y)), _px(Vector2(size.x, y)), ROAD_STREET, float(streets["width"]) * _scale, true)
	var avenues: Dictionary = roads["avenues"]
	for x in avenues["x"]:
		draw_line(_px(Vector2(x, 0)), _px(Vector2(x, size.y)), ROAD_AVENUE, float(avenues["width"]) * _scale, true)
	for diag in roads["diagonals"]:
		var screen := PackedVector2Array()
		for p in CityData.to_points(diag["path"]):
			screen.append(_px(p))
		draw_polyline(screen, ROAD_DIAGONAL, float(diag["width"]) * _scale, true)


# The river is a ribbon whose width changes along its length: one quad per
# segment plus a disc at each joint so bends have no gaps.
func _draw_river() -> void:
	var path: Array = _city["river"]["path"]
	for i in range(path.size() - 1):
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var n := (b - a).orthogonal().normalized()
		var ha: float = float(path[i][2]) * 0.5
		var hb: float = float(path[i + 1][2]) * 0.5
		draw_colored_polygon(PackedVector2Array([
			_px(a + n * ha), _px(b + n * hb), _px(b - n * hb), _px(a - n * ha)]), WATER)
	for i in range(1, path.size() - 1):  # end points sit on the map edge: no cap
		draw_circle(_px(Vector2(path[i][0], path[i][1])), float(path[i][2]) * 0.5 * _scale, WATER)
	var mid := Vector2(path[1][0], path[1][1])
	_text(_px(mid) + Vector2(-30, 5), "River " + String(_city["river"]["name"]), 13, Color.WHITE)


func _draw_bridges() -> void:
	for b in _city["bridges"]:
		var a := _px(Vector2(b["from"][0], b["from"][1]))
		var c := _px(Vector2(b["to"][0], b["to"][1]))
		# Slightly wider than the road it carries so it stands out over the water.
		draw_line(a, c, BRIDGE, float(b["width"]) * _scale + 3.0, true)
		draw_line(a, c, Color("d9b88f"), float(b["width"]) * _scale - 2.0, true)


func _draw_core_center() -> void:
	var c := _px(Vector2(_city["core"]["center"][0], _city["core"]["center"][1]))
	draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.BLACK, 2.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.BLACK, 2.0)
	_text(c + Vector2(10, 14), "core centre", 11, Color.BLACK)


# A big red triangle with a white rim: the one marker that must be findable instantly.
func _draw_landmark() -> void:
	var lm: Dictionary = _city["landmark"]
	var c := _px(Vector2(lm["position"][0], lm["position"][1]))
	var tri := PackedVector2Array([c + Vector2(0, -14), c + Vector2(12, 10), c + Vector2(-12, 10)])
	draw_colored_polygon(tri, LANDMARK)
	tri.append(tri[0])
	draw_polyline(tri, Color.WHITE, 2.0)
	_text(c + Vector2(16, 4), "%s (%dm)" % [lm["name"], int(lm["height"])], 14, Color.WHITE, Color.BLACK)


func _draw_legend(view: Vector2) -> void:
	var x := view.x - LEGEND_WIDTH - MARGIN * 0.5
	var y := MARGIN
	draw_rect(Rect2(x - 12, y - 8, LEGEND_WIDTH + 12, view.y - MARGIN * 2.0 + 16), Color(0, 0, 0, 0.35))
	_text(Vector2(x, y + 14), "%s  (seed %d)" % [_city["meta"]["name"], int(_city["meta"]["seed"])], 17, Color.WHITE)
	y += 40
	_text(Vector2(x, y), "Districts", 13, Color("aab")); y += 8
	for type in DISTRICT_COLORS:
		draw_rect(Rect2(x, y, 22, 14), DISTRICT_COLORS[type])
		_text(Vector2(x + 32, y + 12), String(type), 13, Color.WHITE)
		y += 22
	y += 12
	_text(Vector2(x, y), "Lines", 13, Color("aab")); y += 8
	y = _legend_line(x, y, ROAD_STREET, 3.0, "street (E-W)")
	y = _legend_line(x, y, ROAD_AVENUE, 7.0, "avenue (N-S)")
	y = _legend_line(x, y, ROAD_DIAGONAL, 6.0, "diagonal avenue")
	y = _legend_line(x, y, BRIDGE, 7.0, "bridge")
	y = _legend_line(x, y, WATER, 10.0, "river")
	y += 8
	var tri := PackedVector2Array([Vector2(x + 11, y), Vector2(x + 22, y + 22), Vector2(x, y + 22)])
	draw_colored_polygon(tri, LANDMARK)
	_text(Vector2(x + 32, y + 18), "landmark tower", 13, Color.WHITE)
	y += 32
	draw_arc(Vector2(x + 11, y + 10), 10.0, 0.0, TAU, 24, Color(0.9, 0.8, 0.6), 1.5, true)
	_text(Vector2(x + 32, y + 14), "hill (ring = foot)", 13, Color.WHITE)
	y += 32
	_text(Vector2(x, y + 8), "Scale: map %d x %d m" % [int(CityData.map_size(_city).x), int(CityData.map_size(_city).y)], 12, Color("aab"))


func _legend_line(x: float, y: float, color: Color, width: float, label: String) -> float:
	draw_line(Vector2(x, y + 11), Vector2(x + 22, y + 11), color, width)
	_text(Vector2(x + 32, y + 16), label, 13, Color.WHITE)
	return y + 22


# Thin wrapper so every label goes through one place (font, size, outline).
func _text(pos: Vector2, text: String, size: int, color: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	var font := ThemeDB.fallback_font
	if outline.a > 0.0:
		for off in [Vector2(1, 1), Vector2(-1, 1), Vector2(1, -1), Vector2(-1, -1)]:
			draw_string(font, pos + off, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, outline)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)
