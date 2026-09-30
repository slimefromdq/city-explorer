extends Node3D
## Building lab: a flat ground, a light, a camera, and generated buildings to
## compare side by side. The existing city is not involved.
##
##   godot res://tests/building_lab.tscn
##   right-drag = orbit   wheel = zoom   T = top-down view   F = footprint overlay
##
## Every building is validated when the scene starts; problems are printed to the
## console and the label turns red. The footprint overlay draws each building's
## ground rectangle on top of everything: green = fine, red = has a problem or
## overlaps another footprint. The two "overlap demo" buildings overlap on purpose,
## so you can see what a failure looks like.
##
## Edit CASES to try other buildings. Row types:
##   free  - explicit width/depth/floors/floor height/seed
##   lot   - "match the city": a lot rectangle (metres) and a target height
## Add "pos": Vector3(...) to place a case explicitly instead of in the row.

const GAP_M := 10.0

const CASES := [
	{"name": "thin tower", "w": 12.0, "d": 12.0, "floors": 30, "fh": 3.5, "seed": 7},
	{"name": "short + wide", "w": 40.0, "d": 24.0, "floors": 3, "fh": 3.5, "seed": 3},
	{"name": "lot 96 m, seed 1", "lot": Rect2(0, 0, 29, 29), "h": 96.0, "fh": 4.0, "seed": 1},
	{"name": "lot 96 m, seed 2", "lot": Rect2(0, 0, 29, 29), "h": 96.0, "fh": 4.0, "seed": 2},
	{"name": "lot 96 m, seed 3", "lot": Rect2(0, 0, 29, 29), "h": 96.0, "fh": 4.0, "seed": 3},
	{"name": "lot 22 m old town", "lot": Rect2(0, 0, 29, 29), "h": 22.0, "fh": 3.0, "seed": 11},
	{"name": "lot 14 m low", "lot": Rect2(0, 0, 29, 29), "h": 14.0, "fh": 3.5, "seed": 5},
	{"name": "long block", "w": 50.0, "d": 14.0, "floors": 6, "fh": 3.5, "seed": 9},
	# deliberately overlapping footprints, to show the overlay and the overlap check working
	{"name": "overlap demo A", "w": 20.0, "d": 20.0, "floors": 5, "fh": 3.5, "seed": 21, "pos": Vector3(0, 0, -60)},
	{"name": "overlap demo B", "w": 20.0, "d": 20.0, "floors": 8, "fh": 3.5, "seed": 22, "pos": Vector3(14, 0, -54)},
]

var _yaw := deg_to_rad(-28.0)
var _pitch := deg_to_rad(-26.0)
var _dist := 200.0
var _target := Vector3.ZERO
var _top_down := false
var _bounds := Rect2()
var _cam: Camera3D
var _overlay: Node3D
var _hud: Label


func _ready() -> void:
	_cam = $Camera
	$Sun.rotation_degrees = Vector3(-50.0, -35.0, 0.0)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.68, 0.85)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.72, 0.78)
	env.ambient_light_energy = 0.8
	_cam.environment = env
	_overlay = Node3D.new()
	_overlay.name = "FootprintOverlay"
	add_child(_overlay)
	_build_buildings()
	var layer := CanvasLayer.new()
	add_child(layer)
	_hud = Label.new()
	_hud.position = Vector2(12, 8)
	_hud.add_theme_color_override("font_outline_color", Color.BLACK)
	_hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(_hud)
	_overlay.visible = false
	if OS.get_environment("LAB_VIEW") == "top":
		_top_down = true
		_overlay.visible = true
	_update_camera()
	_update_hud()
	var shot := OS.get_environment("LAB_SHOT")   # debug hook: save a screenshot and quit
	if shot != "":
		for i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _build_buildings() -> void:
	var entries: Array = []
	var x := 0.0
	var row_h := 0.0
	var row_right := 0.0
	for c: Dictionary in CASES:
		var plan: BuildingPlan
		if c.has("lot"):
			plan = BuildingGenerator.plan_for_lot(c.lot, c.h, c.fh, c.seed)
		else:
			plan = BuildingGenerator.plan(c.w, c.d, c.floors, c.fh, c.seed)
		var w := BuildingGrid.to_metres(plan.width_u)
		var d := BuildingGrid.to_metres(plan.depth_u)
		var at := Vector3(x, 0.0, 0.0)
		if c.has("pos"):
			at = c.pos
		else:
			x += w + GAP_M
			row_h = maxf(row_h, BuildingGrid.to_metres(plan.height_units()))
			row_right = x
		BuildingBuilder.build(self, plan, at)
		var entry := {"name": c.name, "plan": plan, "at": at}
		if c.has("lot"):
			entry["lot"] = Rect2(at.x, at.z, c.lot.size.x, c.lot.size.y)   # the lot it was placed in
		entries.append(entry)
		_bounds = _bounds.merge(Rect2(at.x, at.z, w, d)) if _bounds.has_area() else Rect2(at.x, at.z, w, d)

	# validate each building, then all footprints together
	var problems := {}   # entry name -> issue count
	var report := PackedStringArray()
	for e: Dictionary in entries:
		var issues := BuildingValidator.validate(e.plan)
		if not issues.is_empty():
			problems[e.name] = issues.size()
			report.append(BuildingValidator.format("%s (seed %d)" % [e.name, e.plan.seed_value], issues))
	for issue in BuildingValidator.check_footprints(entries):
		report.append("[%s] %s" % [issue.code, issue.text])
		for e: Dictionary in entries:
			if issue.text.begins_with(e.name + " ") or (" and " + e.name + " ") in issue.text:
				problems[e.name] = int(problems.get(e.name, 0)) + 1
	print("\n=== building lab: %d buildings, %s ===" % [entries.size(), "all valid" if report.is_empty() else "problems found"])
	for line in report:
		print(line)

	for e: Dictionary in entries:
		var plan: BuildingPlan = e.plan
		var at: Vector3 = e.at
		var w := BuildingGrid.to_metres(plan.width_u)
		var d := BuildingGrid.to_metres(plan.depth_u)
		var bad := problems.has(e.name)
		_add_footprint(at, w, d, bad)
		var label := Label3D.new()
		label.text = "%s\n%.0f x %.0f m, %d floors, %.1f m tall\n%s" % [e.name, w, d, plan.floors, BuildingGrid.to_metres(plan.height_units()), "PROBLEMS" if bad else "valid"]
		label.modulate = Color(1.0, 0.45, 0.4) if bad else Color.WHITE
		label.outline_modulate = Color.BLACK
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.1
		label.no_depth_test = true
		label.position = Vector3(at.x + w * 0.5, 4.0, at.z + d + 3.0)
		add_child(label)
	_target = Vector3(row_right * 0.5, row_h * 0.3, -5.0)
	_dist = maxf(90.0, row_right * 0.5)


## The building's ground rectangle: a translucent fill plus a solid outline, drawn
## over everything (no depth test) so it is visible from above through the roofs.
func _add_footprint(at: Vector3, w: float, d: float, bad: bool) -> void:
	var col := Color(0.95, 0.2, 0.2) if bad else Color(0.2, 0.9, 0.4)
	var fill := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(w, 0.1, d)
	fill.mesh = bm
	fill.material_override = _overlay_material(Color(col.r, col.g, col.b, 0.3))
	fill.position = Vector3(at.x + w * 0.5, 0.08, at.z + d * 0.5)
	fill.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_overlay.add_child(fill)
	var line := _overlay_material(col)
	var t := 0.4
	for seg in [[Vector3(w, 0.12, t), Vector3(w * 0.5, 0.0, 0.0)], [Vector3(w, 0.12, t), Vector3(w * 0.5, 0.0, d)],
			[Vector3(t, 0.12, d), Vector3(0.0, 0.0, d * 0.5)], [Vector3(t, 0.12, d), Vector3(w, 0.0, d * 0.5)]]:
		var m := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = seg[0]
		m.mesh = b
		m.material_override = line
		m.position = at + seg[1] + Vector3(0.0, 0.09, 0.0)
		m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_overlay.add_child(m)


func _overlay_material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.no_depth_test = true
	m.render_priority = 10
	if c.a < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_T:
			_top_down = not _top_down
			_overlay.visible = _top_down or _overlay.visible
		elif event.keycode == KEY_F:
			_overlay.visible = not _overlay.visible
		_update_camera()
		_update_hud()
	elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and not _top_down:
		_yaw -= event.relative.x * 0.005
		_pitch = clampf(_pitch - event.relative.y * 0.005, deg_to_rad(-88.0), deg_to_rad(-2.0))
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(10.0, _dist * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(900.0, _dist * 1.1)
		_update_camera()


func _update_hud() -> void:
	_hud.text = "T: %s view    F: footprints %s    right-drag: orbit    wheel: zoom" % ["perspective" if _top_down else "top-down", "off" if _overlay.visible else "on"]


func _update_camera() -> void:
	$Sun.shadow_enabled = not _top_down   # long shadows hide the layout when seen from above
	if _top_down:
		# Straight down, north (-z) at the top of the screen, +x to the right. Orthographic, so
		# distances on screen are to scale and nothing leans.
		var centre := _bounds.get_center()
		_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
		var aspect := 16.0 / 9.0
		var vp := get_viewport().get_visible_rect().size
		if vp.y > 0.0:
			aspect = vp.x / vp.y
		_cam.size = maxf(_bounds.size.y, _bounds.size.x / aspect) * 1.25 * (_dist / maxf(90.0, _bounds.size.x * 0.5))
		_cam.global_position = Vector3(centre.x, 600.0, centre.y)
		_cam.look_at(Vector3(centre.x, 0.0, centre.y), Vector3(0.0, 0.0, -1.0))
	else:
		_cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
		_cam.global_position = _target + basis * Vector3(0.0, 0.0, _dist)
		_cam.look_at(_target, Vector3.UP)
