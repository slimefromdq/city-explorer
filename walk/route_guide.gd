extends CanvasLayer
## Read-only walking map. M toggles it without changing mouse capture or train UI.
const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")
var panel: GuideMap

func bind(city, walker: Walker) -> void:
	layer = 15
	panel = GuideMap.new()
	panel.setup(city, walker)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.hide()
	add_child(panel)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_M:
		panel.visible = not panel.visible
		get_viewport().set_input_as_handled()

class GuideMap extends Control:
	const PAPER := Color("eae7d8")
	const TEAL := Color("39c5b8")
	const GOLD := Color("efbe6d")
	const BASE := Vector2(1060, 660)
	const MAP := Rect2(28, 116, 640, 486)
	var walker: Walker
	var routes: Array = []
	var stops: Array = []
	var areas: Array = []
	var bounds: Rect2
	var map_scale := 1.0
	var map_origin := Vector2.ZERO
	var marker_position := Vector2.ZERO
	var marker_direction := Vector2.UP
	var marker_on_map := false

	func setup(city, player: Walker) -> void:
		walker = player
		var walk = city.discovery_walk
		routes.append({"points": walk.points, "color": TEAL})
		routes.append({"points": PackedVector2Array([walk.points[1], walk.approach]), "color": TEAL})
		for spur in walk.spurs:
			routes.append({"points": spur["points"], "color": GOLD})
		for path in city.park_walk.paths:
			routes.append({"points": path["points"], "color": TEAL})
		routes.append({"points": city.library_walk.points, "color": GOLD})
		bounds = Rect2(walk.points[0], Vector2.ZERO)
		for route in routes:
			for p in route["points"]:
				bounds = bounds.expand(p)
		bounds = bounds.grow(65)
		map_scale = minf(MAP.size.x / bounds.size.x, MAP.size.y / bounds.size.y)
		map_origin = MAP.position + (MAP.size - bounds.size * map_scale) * 0.5
		var crop := PackedVector2Array([bounds.position, Vector2(bounds.end.x, bounds.position.y), bounds.end, Vector2(bounds.position.x, bounds.end.y)])
		_add_area(CityData.land_polygon(city.city), crop, Color("364b49"))
		for district in city.city["districts"]:
			if district["type"] == "park":
				_add_area(CityData.to_points(district["polygon"]), crop, Color("456452"))
		_add_area(Geo2D.river_polygon(city.city["river"]["path"]), crop, Color("254e68"))
		for creek in city.city["terrain"]["creeks"]:
			_add_area(Geo2D.river_polygon(creek["path"]), crop, Color("254e68"))
		for pond in city.city["terrain"]["ponds"]:
			var circle := PackedVector2Array()
			var centre := Vector2(pond["center"][0], pond["center"][1])
			for i in 48:
				circle.append(centre + Vector2.from_angle(TAU * i / 48) * float(pond["radius"]))
			_add_area(circle, crop, Color("254e68"))
		for stop in walk.stops:
			stops.append({"name": stop["name"], "point": walk.points[int(stop["index"])], "detail": stop["caption"]})
		# The route stop marks the bridge approach; the map badge marks its deck.
		var bridge: Dictionary = walk.bridge
		stops[1]["point"] = (Vector2(bridge["from"][0], bridge["from"][1]) + Vector2(bridge["to"][0], bridge["to"][1])) * 0.5
		for pair in [["MuseumArrival", "Museum of Meridia", "Front terrace · east park branch"], ["LibraryArrival", "Meridian Library", "Front terrace · west lake branch"]]:
			var arrival: Node3D = city.get_node("CivicAccess/" + pair[0])
			var p: Vector3 = arrival.transform * arrival.get_meta("arrival_end")
			stops.append({"name": pair[1], "point": Vector2(p.x, p.z), "detail": pair[2]})

	func _add_area(polygon: PackedVector2Array, crop: PackedVector2Array, color: Color) -> void:
		for clipped in Geometry2D.intersect_polygons(polygon, crop):
			areas.append({"points": clipped, "color": color})

	func map_point(p: Vector2) -> Vector2:
		return map_origin + (p - bounds.position) * map_scale

	func _process(_delta: float) -> void:
		if walker == null or not visible:
			return
		var p := Vector2(walker.global_position.x, walker.global_position.z)
		marker_position = map_point(p)
		marker_on_map = bounds.has_point(p)
		# Global camera basis remains correct when a train reparents the walker.
		var forward := -walker.camera.global_basis.z
		marker_direction = Vector2(forward.x, forward.z).normalized()
		queue_redraw()

	func _text(p: Vector2, value: String, font_size: int, color := PAPER) -> void:
		draw_string(ThemeDB.fallback_font, p, value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)

	func _draw() -> void:
		var scale_factor := minf(1.0, minf((size.x - 24) / BASE.x, (size.y - 24) / BASE.y))
		draw_set_transform((size - BASE * scale_factor) * 0.5, 0, Vector2.ONE * scale_factor)
		draw_style_box(_background(), Rect2(Vector2.ZERO, BASE))
		_text(Vector2(28, 36), "MERIDIA  /  ON FOOT", 15, TEAL)
		_text(Vector2(28, 76), "Your city walk", 32)
		_text(Vector2(28, 101), "Follow the teal trail. Gold branches lead to civic terraces.", 16)
		_text(Vector2(895, 36), "M  CLOSE MAP", 15, TEAL)
		draw_rect(MAP, Color("20333a"))
		for area in areas:
			var polygon := PackedVector2Array()
			for p in area["points"]:
				polygon.append(map_point(p))
			draw_colored_polygon(polygon, area["color"])
		for route in routes:
			var line := PackedVector2Array()
			for p in route["points"]:
				line.append(map_point(p))
			draw_polyline(line, Color("142a2e"), 8, true)
			draw_polyline(line, route["color"], 4, true)
		for i in stops.size():
			var p := map_point(stops[i]["point"])
			var badge := p + Vector2(16, -16)
			draw_line(p, badge, PAPER, 1, true)
			draw_circle(p, 3, PAPER)
			draw_circle(badge, 11, PAPER)
			_text(badge + Vector2(-5, 5), str(i + 1), 15, Color("172d32"))
			var row := Vector2(700, 152 + i * 61)
			_text(row, "%d  %s" % [i + 1, stops[i]["name"]], 19)
			_text(row + Vector2(0, 23), stops[i]["detail"], 13, Color("b6c8c1"))
		_text(Vector2(MAP.end.x - 34, MAP.position.y + 28), "N ↑", 18)
		if marker_on_map:
			draw_circle(marker_position, 12, Color("142a2e"))
			draw_circle(marker_position, 7, Color("ffffff"))
			draw_line(marker_position, marker_position + marker_direction * 24, Color("ffffff"), 3, true)
		_text(Vector2(700, 554), "● YOU" if marker_on_map else "YOU ARE OUTSIDE THIS MAP", 15)
		_text(Vector2(700, 580), "North stays at the top", 14, Color("b6c8c1"))
		_text(Vector2(28, 635), "Stay on marked paths. Civic interiors are closed. Trains use their own destination panel.", 15)

	func _background() -> StyleBoxFlat:
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.055, 0.105, 0.12, 0.97)
		style.border_color = Color("52716c")
		style.set_border_width_all(1)
		style.set_corner_radius_all(12)
		return style
