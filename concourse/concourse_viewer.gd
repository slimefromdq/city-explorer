extends Node3D
## Fly-around viewer for the concourse hall. Run ConcourseHallViewer.tscn (F6).
## ConcourseHall.tscn on its own has no camera, so running it shows only the empty background.
##
## Controls: hold right mouse to look, W/A/S/D move, Q/E down/up, Shift = fast,
## mouse wheel = speed, keys 1-6 jump to preset viewpoints, R = rebuild the hall.
## Env VIEWER_SHOT=/path.png saves one frame from preset 1 and quits (used to check the scene renders).

const GROUND_SIZE := 600.0
const GROUND_DROP := 0.6        # ground sits this far below the hall floor (m)
const EYE_HEIGHT := 1.7
const BASE_SPEED := 8.0         # m/s
const FAST_MULTIPLIER := 4.0
const SPEED_STEP := 1.2         # wheel changes speed by this factor
const MOUSE_SENSITIVITY := 0.003
const FOV := 75.0

@onready var hall: ConcourseHall = $ConcourseHall

var cam: Camera3D
var _speed := BASE_SPEED
var _yaw := 0.0
var _pitch := 0.0
var _presets: Array = []


func _ready() -> void:
	var ground := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(GROUND_SIZE, 0.2, GROUND_SIZE)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.27, 0.22)
	box.material = mat
	ground.mesh = box
	ground.position.y = -GROUND_DROP
	add_child(ground)

	cam = Camera3D.new()
	cam.fov = FOV
	cam.far = 800.0
	add_child(cam)
	cam.current = true

	_build_presets()
	_go(0)
	_add_help()

	var shot := OS.get_environment("VIEWER_SHOT")
	if shot != "":
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(shot)
		get_tree().quit()


func _build_presets() -> void:
	var bay: ConcourseBay = hall.get_node("Generated/WallNegZ/Bay0")
	var half: float = hall.hall_bays * bay.bay_width * 0.5
	var half_w: float = hall.hall_width * 0.5
	var deck: float = hall.mezzanine_height
	var clock_y: float = hall.landmark_height - 3.0
	_presets = [
		[Vector3(-half + 2.0, EYE_HEIGHT, 0), Vector3(half, bay.wall_height * 0.4, 0)],            # 1 entrance, down the hall
		[Vector3(-4.0, deck + EYE_HEIGHT, -half_w + 0.8), Vector3(0, clock_y, 0)],                  # 2 balcony, across to the clock
		[Vector3(5.0, deck + EYE_HEIGHT, half_w - 0.8), Vector3(0, 0, -2.0)],                       # 3 balcony, down at the booth
		[Vector3(-6.0, EYE_HEIGHT, -7.0), Vector3(half, hall.rose_height - 4.0, 0)],                # 4 floor, up at the far window
		[Vector3(half - 2.0, EYE_HEIGHT, 0), Vector3(-half, bay.wall_height * 0.4, 0)],             # 5 far end, looking back
		[Vector3(0, bay.wall_height + 3.0, 0), Vector3(0, 0, 0)],                                   # 6 straight down from under the vault
	]


func _go(i: int) -> void:
	var p: Array = _presets[i]
	cam.position = p[0]
	var up := Vector3.UP if i != 5 else Vector3(0, 0, -1)
	cam.look_at(p[1], up)
	_yaw = cam.rotation.y
	_pitch = cam.rotation.x


func _add_help() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "Hold right mouse to look  |  WASD move, Q/E down/up, Shift fast, wheel = speed  |  1-6 viewpoints, R rebuild"
	label.position = Vector2(12, 10)
	layer.add_child(label)
	add_child(layer)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * MOUSE_SENSITIVITY
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENSITIVITY, -1.55, 1.55)
		cam.rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_speed *= SPEED_STEP
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_speed /= SPEED_STEP
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode >= KEY_1 and event.physical_keycode < KEY_1 + _presets.size():
			_go(event.physical_keycode - KEY_1)
		elif event.physical_keycode == KEY_R:
			hall.rebuild()


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_E): move.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): move.y -= 1.0
	var fast := FAST_MULTIPLIER if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	cam.position += (cam.global_transform.basis * move) * _speed * fast * delta
