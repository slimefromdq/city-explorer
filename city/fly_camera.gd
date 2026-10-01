# FlyCamera - a free-flying inspection camera.
#
# One job: let you look around the generated city. Hold right mouse to look,
# WASD to move, Q/E down/up, Shift = fast, mouse wheel = change speed.
# Keys are read directly (not via the project's input map) so it works anywhere.
extends Camera3D

var speed := 250.0
var _yaw := 0.0
var _pitch := 0.0


# Place the camera so the whole map is in view, looking at its centre.
func frame(center: Vector3, span: float) -> void:
	position = center + Vector3(0.0, span * 0.55, span * 0.75)
	look_at(center)
	_yaw = rotation.y
	_pitch = rotation.x
	near = 2.0   # a tiny near plane ruins depth precision far away (shorelines flicker)
	far = span * 4.0


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		_yaw -= event.relative.x * 0.003
		_pitch = clampf(_pitch - event.relative.y * 0.003, -1.55, 1.55)
		rotation = Vector3(_pitch, _yaw, 0.0)
	elif event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			speed *= 1.2
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			speed /= 1.2


func _process(delta: float) -> void:
	var move := Vector3.ZERO
	if Input.is_physical_key_pressed(KEY_W): move.z -= 1.0
	if Input.is_physical_key_pressed(KEY_S): move.z += 1.0
	if Input.is_physical_key_pressed(KEY_A): move.x -= 1.0
	if Input.is_physical_key_pressed(KEY_D): move.x += 1.0
	if Input.is_physical_key_pressed(KEY_E): move.y += 1.0
	if Input.is_physical_key_pressed(KEY_Q): move.y -= 1.0
	var fast := 4.0 if Input.is_physical_key_pressed(KEY_SHIFT) else 1.0
	position += (global_transform.basis * move) * speed * fast * delta
