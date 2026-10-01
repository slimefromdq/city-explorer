# DebugMap2D - top-down 2D picture of city.json.
#
# One job: DRAW the data. It never changes it and never decides anything about
# the city. If the picture looks wrong, the data (or the generator later) is
# wrong, not this file. That is what makes it a trustworthy debugging tool.
extends Node2D

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")
const DebugDraw := preload("res://city/debug_draw.gd")

# Colours are presentation only (not layout), so they live here, not in the JSON.
const DISTRICT_COLORS := {
	"core": Color("c9a0dc"),
	"midrise": Color("f2c078"),
	"lowrise": Color("f5e6a8"),
	"harbour": Color("8ec3d6"),
	"park": Color("8fcf8a"),
	"financial": Color("e58fb0"),
}
const BG := Color("2b2f36")
const SEA := Color("27537f")
const LAND := Color("d8cfae")
const WATER := Color("3f7fc4")
const ROAD_STREET := Color("fdfdfd")
const ROAD_AVENUE := Color("d7d7d7")
const ROAD_DIAGONAL := Color("e8743b")
const BRIDGE := Color("7a4a24")
const PIER := Color("5d4a3a")
const SITE_COLORS := {
	"station": Color(0.18, 0.18, 0.22, 0.88),
	"library": Color(0.45, 0.28, 0.14, 0.92),
	"museum": Color(0.12, 0.45, 0.45, 0.92),
	"performance_hall": Color(0.62, 0.15, 0.45, 0.92),
	"plaza": Color(0.85, 0.85, 0.8, 0.8),
}
const LANDMARK := Color("d6212b")
const LANDMARK_MINOR := Color("f2a900")
const OUTLINE := Color(0, 0, 0, 0.55)
const LEGEND_WIDTH := 250.0
const MARGIN := 24.0

var city: Dictionary
var land := PackedVector2Array()  # coastline polygon, cached in _ready
var map_scale := 1.0
var _origin := Vector2.ZERO  # screen position of map (0, 0)
# Which layers are visible. The underground layers overlap the surface, so each
# can be switched off (keys S / M / U) to read the others clearly.
var show_surface := true
var show_metro := true
var show_sewers := true


func _ready() -> void:
	city = CityData.load_city()
	if not city.is_empty():
		land = CityData.land_polygon(city)
	get_viewport().size_changed.connect(queue_redraw)
	queue_redraw()


func _unhandled_key_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_S: show_surface = not show_surface
		KEY_M: show_metro = not show_metro
		KEY_U: show_sewers = not show_sewers
		_: return
	queue_redraw()
	for child in get_children():
		child.queue_redraw()


func _draw() -> void:
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), BG)
	if city.is_empty():
		_text(Vector2(MARGIN, MARGIN + 20), "Could not load res://data/city.json (see Output)", 18, LANDMARK)
		return
	_fit_map_to(view)
	var map_px := CityData.map_size(city) * map_scale
	draw_rect(Rect2(_origin, map_px), SEA)  # everything outside the coast is sea
	if show_surface:
		draw_colored_polygon(_to_screen(land), LAND)

	# Painter's order: later layers sit on top of earlier ones.
	if show_surface:
		_draw_districts(false)
		_draw_roads()
		_draw_districts(true)  # districts with "roads": false cover the roads under them
		_draw_sites()
		_draw_terrain()
		_draw_river()
		_draw_harbour()
		_draw_bridges()
		_draw_core_center()
		_draw_landmarks()
	if show_surface:
		_draw_coastline()
		_draw_district_labels()  # last, so no road or river hides a name
	_draw_legend(view)


# Scale the map to fill the window, leaving a column on the right for the legend.
func _fit_map_to(view: Vector2) -> void:
	var avail := Vector2(view.x - LEGEND_WIDTH - MARGIN * 3.0, view.y - MARGIN * 2.0)
	var size := CityData.map_size(city)
	map_scale = minf(avail.x / size.x, avail.y / size.y)
	_origin = Vector2(MARGIN, MARGIN)


func px(p: Vector2) -> Vector2:
	return _origin + p * map_scale


func _to_screen(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(px(p))
	return out


# Layout polygons are drawn as zones; the part that falls in the sea is cut off here.
func _clip_to_land(poly: PackedVector2Array) -> Array:
	return Geometry2D.intersect_polygons(poly, land)


# Districts are land-only polygons that tile the coast, so they are drawn as
# stored (no clipping): if one pokes into the sea, the validator fails.
# Two passes: normal districts first, then districts flagged "roads": false
# (the park) on top of the roads. The roads still exist in the data under them;
# the flag is the rule, Phase 3 will use it to clip them.
func _draw_districts(over_roads: bool) -> void:
	for d in city["districts"]:
		if (d.get("roads", true) == false) != over_roads:
			continue
		var color: Color = DISTRICT_COLORS.get(d["type"], Color.MAGENTA)
		var screen := _to_screen(CityData.to_points(d["polygon"]))  # drawn exactly as stored
		draw_colored_polygon(screen, Color(color, 0.88) if over_roads else color)
		screen.append(screen[0])
		draw_polyline(screen, OUTLINE, 2.0)


# Sites (stations, library, museum, hall...) sit on top of the districts and
# roads, like a plaza that roads stop at. Colour says what kind of building.
func _draw_sites() -> void:
	for site in city["sites"]:
		var poly := CityData.to_points(site["polygon"])
		var screen := _to_screen(poly)
		draw_colored_polygon(screen, SITE_COLORS.get(site["kind"], Color.MAGENTA))
		screen.append(screen[0])
		draw_polyline(screen, Color.WHITE, 2.0)
		var at := px(Geo2D.label_point(poly))
		var label := String(site["name"])
		_text(at + Vector2(-label.length() * 3.2, 4), label, 12, Color.WHITE, Color.BLACK)


# The harbour basin is open water the river flows into, plus piers sticking into it.
func _draw_harbour() -> void:
	var h: Dictionary = city["harbour"]
	var basin := PackedVector2Array()
	for p in CityData.to_points(h["basin"]):
		basin.append(px(p))
	draw_colored_polygon(basin, WATER)
	for pier in h["piers"]:
		var a := px(Vector2(pier["from"][0], pier["from"][1]))
		var b := px(Vector2(pier["to"][0], pier["to"][1]))
		draw_line(a, b, PIER, float(pier["width"]) * map_scale, true)
	_text(px(Geo2D.label_point(CityData.to_points(h["basin"]))) + Vector2(-70, -40), String(h["name"]), 13, Color.WHITE, Color(0, 0, 0, 0.6))


# A dark outline so the natural shape of the city reads clearly.
func _draw_coastline() -> void:
	var outline := _to_screen(land)
	outline.append(outline[0])
	draw_polyline(outline, Color(0.1, 0.18, 0.3), 2.5, true)


func _draw_district_labels() -> void:
	for d in city["districts"]:
		var is_park: bool = d["type"] == "park"
		var label: String = ("PARK: " if is_park else "") + String(d["name"])
		var at := px(Geo2D.label_point(CityData.to_points(d["polygon"])))
		_text(at + Vector2(-label.length() * 4.0, 0), label, 15, Color.BLACK, Color(1, 1, 1, 0.85))


# Hills as faint brown rings (foot and half-height), clipped to the coast.
# Height is not visible top-down, so the label carries it.
func _draw_terrain() -> void:
	for h in city["terrain"]["hills"]:
		var centre := Vector2(h["center"][0], h["center"][1])
		for fraction in [1.0, 0.55]:
			var ring := PackedVector2Array()
			for i in 48:
				ring.append(centre + Vector2.from_angle(TAU * i / 48.0) * float(h["radius"]) * fraction)
			for piece in _clip_to_land(ring):
				var screen := _to_screen(piece)
				draw_colored_polygon(screen, Color(0.35, 0.22, 0.1, 0.08))
				screen.append(screen[0])
				draw_polyline(screen, Color(0.2, 0.15, 0.1, 0.5), 1.5, true)
		var c := px(centre)
		var r: float = float(h["radius"]) * map_scale
		_text(c + Vector2(-r * 0.45, -r * 0.6), "%s +%dm" % [h["name"], int(h["height"])], 11, Color(0.25, 0.12, 0.02), Color(1, 1, 1, 0.8))


# Streets first (thin), avenues over them (wide), diagonals on top, so the
# hierarchy reads at a glance.
func _draw_roads() -> void:
	var size := CityData.map_size(city)
	var roads: Dictionary = city["roads"]
	var streets: Dictionary = roads["streets"]
	for y in streets["y"]:
		_draw_road([Vector2(0, y), Vector2(size.x, y)], ROAD_STREET, float(streets["width"]))
	var avenues: Dictionary = roads["avenues"]
	for x in avenues["x"]:
		_draw_road([Vector2(x, 0), Vector2(x, size.y)], ROAD_AVENUE, float(avenues["width"]))
	for diag in roads["diagonals"]:
		_draw_road(CityData.to_points(diag["path"]), ROAD_DIAGONAL, float(diag["width"]))


# Roads are stored as long lines; the sea part is cut off so none runs into the water.
func _draw_road(line, color: Color, width: float) -> void:
	for piece in Geometry2D.intersect_polyline_with_polygon(PackedVector2Array(line), land):
		draw_polyline(_to_screen(piece), color, width * map_scale, true)


# The river is a ribbon whose width changes along its length: one quad per
# segment plus a disc at each joint so bends have no gaps.
func _draw_river() -> void:
	var path: Array = city["river"]["path"]
	for i in range(path.size() - 1):
		var a := Vector2(path[i][0], path[i][1])
		var b := Vector2(path[i + 1][0], path[i + 1][1])
		var n := (b - a).orthogonal().normalized()
		var ha: float = float(path[i][2]) * 0.5
		var hb: float = float(path[i + 1][2]) * 0.5
		draw_colored_polygon(PackedVector2Array([
			px(a + n * ha), px(b + n * hb), px(b - n * hb), px(a - n * ha)]), WATER)
	for i in range(0, path.size() - 1):  # a disc at the spring and each bend; the far end opens into the harbour
		draw_circle(px(Vector2(path[i][0], path[i][1])), float(path[i][2]) * 0.5 * map_scale, WATER)
	var mid := Vector2(path[1][0], path[1][1])
	_text(px(mid) + Vector2(-30, 5), "River " + String(city["river"]["name"]), 13, Color.WHITE)


func _draw_bridges() -> void:
	for b in city["bridges"]:
		var a := px(Vector2(b["from"][0], b["from"][1]))
		var c := px(Vector2(b["to"][0], b["to"][1]))
		# Slightly wider than the road it carries so it stands out over the water.
		draw_line(a, c, BRIDGE, float(b["width"]) * map_scale + 3.0, true)
		draw_line(a, c, Color("d9b88f"), float(b["width"]) * map_scale - 2.0, true)


func _draw_core_center() -> void:
	var c := px(Vector2(city["core"]["center"][0], city["core"]["center"][1]))
	draw_line(c + Vector2(-8, 0), c + Vector2(8, 0), Color.BLACK, 2.0)
	draw_line(c + Vector2(0, -8), c + Vector2(0, 8), Color.BLACK, 2.0)
	_text(c + Vector2(10, 14), "core centre", 11, Color.BLACK)


# Triangles with a white rim: red and large for the main tower (it must be
# findable instantly), gold and smaller for each district's own landmark.
func _draw_landmarks() -> void:
	for lm in city["landmarks"]:
		var main: bool = lm.get("main", false)
		var k := 1.0 if main else 0.75
		var c := px(Vector2(lm["position"][0], lm["position"][1]))
		var tri := PackedVector2Array([c + Vector2(0, -14) * k, c + Vector2(12, 10) * k, c + Vector2(-12, 10) * k])
		draw_colored_polygon(tri, LANDMARK if main else LANDMARK_MINOR)
		tri.append(tri[0])
		draw_polyline(tri, Color.WHITE, 2.0)
		_text(c + Vector2(16, 4), "%s (%dm)" % [lm["name"], int(lm["height"])], 14 if main else 12, Color.WHITE, Color.BLACK)


func _draw_legend(view: Vector2) -> void:
	var x := view.x - LEGEND_WIDTH - MARGIN * 0.5
	var y := MARGIN
	draw_rect(Rect2(x - 12, y - 8, LEGEND_WIDTH + 12, view.y - MARGIN * 2.0 + 16), Color(0, 0, 0, 0.35))
	_text(Vector2(x, y + 14), "%s  (seed %d)" % [city["meta"]["name"], int(city["meta"]["seed"])], 17, Color.WHITE)
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
	_text(Vector2(x + 32, y + 18), "main landmark", 13, Color.WHITE)
	y += 26
	draw_colored_polygon(PackedVector2Array([Vector2(x + 11, y + 4), Vector2(x + 19, y + 20), Vector2(x + 3, y + 20)]), LANDMARK_MINOR)
	_text(Vector2(x + 32, y + 18), "district landmark", 13, Color.WHITE)
	y += 28
	draw_arc(Vector2(x + 11, y + 10), 10.0, 0.0, TAU, 24, Color(0.9, 0.8, 0.6), 1.5, true)
	_text(Vector2(x + 32, y + 14), "hill (ring = foot)", 13, Color.WHITE)
	y += 32
	_text(Vector2(x, y), "Buildings", 13, Color("aab")); y += 8
	for kind in SITE_COLORS:
		draw_rect(Rect2(x, y, 22, 14), SITE_COLORS[kind])
		_text(Vector2(x + 32, y + 12), String(kind).replace("_", " "), 13, Color.WHITE)
		y += 20
	y += 8
	_text(Vector2(x, y), "Underground / rail (keys)", 13, Color("aab")); y += 8
	_text(Vector2(x, y + 14), "metro [M]: dashed = underground,", 12, Color.WHITE)
	_text(Vector2(x, y + 29), "solid = above ground, dotted = ramp", 12, Color.WHITE)
	y += 40
	y = _legend_line(x, y, Color("6b4f2a"), 4.0, "sewer tunnel / chamber [U]")
	_text(Vector2(x, y + 14), "[S] surface on/off", 12, Color("aab"))
	y += 30
	_text(Vector2(x, y + 8), "Scale: map %d x %d m" % [int(CityData.map_size(city).x), int(CityData.map_size(city).y)], 12, Color("aab"))


func _legend_line(x: float, y: float, color: Color, width: float, label: String) -> float:
	draw_line(Vector2(x, y + 11), Vector2(x + 22, y + 11), color, width)
	_text(Vector2(x + 32, y + 16), label, 13, Color.WHITE)
	return y + 22


# Thin wrapper so every label goes through one place (font, size, outline).
func _text(pos: Vector2, text: String, size: int, color: Color, outline: Color = Color(0, 0, 0, 0)) -> void:
	DebugDraw.label(self, pos, text, size, color, outline)
