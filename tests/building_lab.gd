extends Node3D
## Phase 1 lab: a flat ground, a light, a camera, and a row of generated
## buildings to compare side by side. The existing city is not involved.
##
##   godot res://tests/building_lab.tscn         (right-drag = orbit, wheel = zoom)
##
## Edit CASES to try other buildings. Row types:
##   free  - explicit width/depth/floors/floor height/seed
##   lot   - "match the city": a 29 x 29 m lot and a target height in metres

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
]

var _yaw := deg_to_rad(-28.0)
var _pitch := deg_to_rad(-26.0)
var _dist := 200.0
var _target := Vector3.ZERO
var _cam: Camera3D


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

	var x := 0.0
	var max_h := 0.0
	for c: Dictionary in CASES:
		var plan: BuildingPlan
		if c.has("lot"):
			plan = BuildingGenerator.plan_for_lot(c.lot, c.h, c.fh, c.seed)
		else:
			plan = BuildingGenerator.plan(c.w, c.d, c.floors, c.fh, c.seed)
		BuildingBuilder.build(self, plan, Vector3(x, 0.0, 0.0))
		var w := BuildingGrid.to_metres(plan.width_u)
		var d := BuildingGrid.to_metres(plan.depth_u)
		max_h = maxf(max_h, BuildingGrid.to_metres(plan.height_units()))
		var label := Label3D.new()
		label.text = "%s\n%.0f x %.0f m, %d floors, %.1f m tall" % [c.name, w, d, plan.floors, BuildingGrid.to_metres(plan.height_units())]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.pixel_size = 0.1
		label.position = Vector3(x + w * 0.5, 4.0, d + 3.0)
		label.no_depth_test = true
		add_child(label)
		x += w + GAP_M
	_target = Vector3(x * 0.5, max_h * 0.3, 10.0)
	_dist = maxf(90.0, x * 0.5)
	_update_camera()
	var shot := OS.get_environment("LAB_SHOT")   # debug hook: save a screenshot and quit
	if shot != "":
		for i in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.005
		_pitch = clampf(_pitch - event.relative.y * 0.005, deg_to_rad(-88.0), deg_to_rad(-2.0))
		_update_camera()
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_dist = maxf(10.0, _dist * 0.9)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_dist = minf(900.0, _dist * 1.1)
		_update_camera()


func _update_camera() -> void:
	var basis := Basis.from_euler(Vector3(_pitch, _yaw, 0.0))
	_cam.global_position = _target + basis * Vector3(0.0, 0.0, _dist)
	_cam.look_at(_target, Vector3.UP)
