class_name RouteMap
extends RefCounted
## A route-map panel: the shuttle network drawn on a board (river, the four lines in their colours, the
## stops with names, a legend) with a "YOU ARE HERE" marker at the stop it hangs in. The picture is
## painted into an Image from RouteData (no hand-made art); the text on top is Label3D.

const L := preload("res://station/station_layout.gd")
const PPM := 150.0                         # pixels per metre of panel
const WORLD_MIN := Vector2(120.0, 390.0)   # the map shows this part of the city (world x, z)
const WORLD_MAX := Vector2(1330.0, 930.0)
const BG := Color(0.07, 0.10, 0.14)
const LAND := Color(0.11, 0.17, 0.22)
const RIVER := Color(0.13, 0.30, 0.50)


## Build a panel. `pos` = centre, `yaw` turns it (a panel faces +z at yaw 0), `size` in metres.
static func build(parent: Node3D, panel_name: String, routes: RouteData, pos: Vector3, yaw: float, size: Vector2, here_stop: String, here_line: String, river: Array = []) -> Node3D:
	var root := Node3D.new()
	root.name = panel_name
	root.position = pos
	root.rotation.y = yaw
	parent.add_child(root)
	var px := Vector2i(int(size.x * PPM), int(size.y * PPM))
	var img := Image.create(px.x, px.y, false, Image.FORMAT_RGBA8)
	img.fill(BG)
	# map area: keep the world aspect, leave a margin and a legend strip at the bottom
	var margin := 0.07 * size.y
	var legend_h := 0.18 * size.y
	var area := Rect2(Vector2(margin, margin * 1.7), Vector2(size.x - margin * 2.0, size.y - margin * 2.7 - legend_h))
	var world := WORLD_MAX - WORLD_MIN
	var scale := Vector2(area.size.x / world.x, area.size.y / world.y)   # a diagram, not a survey: stretched to fill
	var origin := area.position
	var to_panel := func(w: Vector2) -> Vector2:
		return origin + (w - WORLD_MIN) * scale
	var to_px := func(p: Vector2) -> Vector2i:
		return Vector2i(int(p.x * PPM), int(p.y * PPM))
	# land
	var land_rect := Rect2i(to_px.call(origin), to_px.call(world * scale))
	img.fill_rect(land_rect, LAND)
	# river
	for i in range(river.size() - 1):
		var a: Array = river[i]
		var b: Array = river[i + 1]
		var w := maxf(float(a[2]), float(b[2])) * scale.y
		_stamp_line(img, to_px.call(to_panel.call(Vector2(a[0], a[1]))), to_px.call(to_panel.call(Vector2(b[0], b[1]))), int(w * PPM * 0.5), RIVER, land_rect)
	# lines
	var line_w := int(0.05 * PPM)
	for line in routes.lines:
		var pts: PackedVector3Array = line["path"]
		var col: Color = line["color"]
		var prev := Vector2i.ZERO
		var first := true
		var s := 0.0
		var length: float = line["length"]
		# only the part between the first and last stop
		var s_a: float = line["stops"][0]["s"]
		var s_b: float = line["stops"][line["stops"].size() - 1]["s"]
		s = s_a
		while s <= s_b:
			var p: Vector3 = RouteData.sample(pts, s)["pos"]
			var q: Vector2i = to_px.call(to_panel.call(Vector2(p.x, p.z)))
			if not first:
				_stamp_line(img, prev, q, line_w, col, land_rect)
			prev = q
			first = false
			s += 12.0
		var last: Vector3 = RouteData.sample(pts, s_b)["pos"]
		_stamp_line(img, prev, to_px.call(to_panel.call(Vector2(last.x, last.z))), line_w, col, land_rect)
		length = length
	# stops
	var labels: Array = []
	var seen := {}
	for line in routes.lines:
		for st in line["stops"]:
			var sid: String = st["stop"]
			if seen.has(sid):
				continue
			seen[sid] = true
			var stop := routes.stop(sid)
			var wp := Vector2(stop["platform"].x, stop["platform"].z)
			var pp: Vector2 = to_panel.call(wp)
			var radius := int((0.13 if sid == "central" else 0.085) * PPM)
			_disc(img, to_px.call(pp), radius, Color.WHITE)
			_disc(img, to_px.call(pp), int(radius * 0.62), BG if sid != "central" else Color(0.9, 0.2, 0.2))
			labels.append({"text": stop["name"], "pos": pp, "hub": sid == "central", "line": line["color"] if sid != "central" else Color.WHITE})
	var here_stop_data := routes.stop(here_stop)
	if not here_stop_data.is_empty():
		var hpp: Vector2 = to_panel.call(Vector2(here_stop_data["platform"].x, here_stop_data["platform"].z))
		_disc(img, to_px.call(hpp), int(0.2 * PPM), Color(1.0, 0.2, 0.2))
		_disc(img, to_px.call(hpp), int(0.16 * PPM), LAND)
		_disc(img, to_px.call(hpp), int(0.12 * PPM), Color.WHITE)
		_disc(img, to_px.call(hpp), int(0.075 * PPM), Color(0.9, 0.2, 0.2))
	# legend: four chips with line names along the bottom
	var lx := margin
	var ly := size.y - legend_h * 0.5
	var legend: Array = []
	for line in routes.lines:
		var chip := Rect2i(to_px.call(Vector2(lx, ly - 0.05 * size.y)), Vector2i(int(0.14 * PPM), int(0.1 * size.y * PPM)))
		img.fill_rect(chip, line["color"])
		legend.append({"text": String(line["name"]), "pos": Vector2(lx + 0.2 * size.y * 0.5, ly)})
		lx += (size.x - margin * 2.0) * 0.25
	# the panel: frame, picture
	var frame := Greybox.mat(Color(0.18, 0.19, 0.22))
	Greybox.box(root, Vector3(size.x + 0.3, size.y + 0.3, 0.12), Vector3(0, 0, -0.07), frame)
	var tex := ImageTexture.create_from_image(img)
	var quad := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = size
	quad.mesh = qm
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	quad.material_override = mat
	root.add_child(quad)
	# text
	var text_h := 0.062 * size.y
	Greybox.label(root, "SHUTTLE NETWORK", Vector3(-size.x * 0.5 + margin, size.y * 0.5 - margin * 0.9, 0.01), 0.0, text_h * 1.5, Color(0.95, 0.95, 0.95)).horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	for l in labels:
		var p: Vector2 = l["pos"]
		var dy: float = -0.085 * size.y if l["hub"] else 0.085 * size.y
		var local := Vector3(p.x - size.x * 0.5, size.y * 0.5 - p.y + dy, 0.012)
		var lab := Greybox.label(root, String(l["text"]), local, 0.0, text_h * (1.2 if l["hub"] else 0.95), Color(1, 1, 1))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	for l in legend:
		var p: Vector2 = l["pos"]
		var lab := Greybox.label(root, String(l["text"]), Vector3(p.x - size.x * 0.5, size.y * 0.5 - p.y, 0.012), 0.0, text_h * 0.8, Color(0.9, 0.9, 0.9))
		lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	# you are here: a red ring round the stop and the words under its name
	var here := routes.stop(here_stop)
	if not here.is_empty():
		var hp: Vector2 = to_panel.call(Vector2(here["platform"].x, here["platform"].z))
		var ring := Image.create(2, 2, false, Image.FORMAT_RGBA8)
		ring = ring
		var you := Greybox.label(root, "YOU ARE HERE", Vector3(hp.x - size.x * 0.5, size.y * 0.5 - hp.y - 0.17 * size.y, 0.02), 0.0, text_h * 1.15, Color(1.0, 0.35, 0.3))
		you.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return root


static func _stamp_line(img: Image, a: Vector2i, b: Vector2i, half: int, color: Color, clip: Rect2i) -> void:
	var d := Vector2(b - a)
	var steps := maxi(1, int(d.length() / maxf(half * 0.7, 1.0)))
	var size := Vector2i(half * 2 + 1, half * 2 + 1)
	for i in range(steps + 1):
		var p := Vector2i(Vector2(a) + d * (float(i) / steps)) - Vector2i(half, half)
		var r := Rect2i(p, size).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 0 and r.size.y > 0:
			img.fill_rect(r, color)


static func _disc(img: Image, c: Vector2i, radius: int, color: Color) -> void:
	for dy in range(-radius, radius + 1):
		var w := int(sqrt(float(radius * radius - dy * dy)))
		var r := Rect2i(c.x - w, c.y + dy, w * 2 + 1, 1).intersection(Rect2i(Vector2i.ZERO, img.get_size()))
		if r.size.x > 0 and r.size.y > 0:
			img.fill_rect(r, color)
