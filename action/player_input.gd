class_name ActionPlayerInput
extends Node3D
## Camera/input adapter only. Headless tests and bots can omit this entirely.
var player: ActionPlayerController
var enabled := true
var yaw := 0.0
var pitch := -0.15
var camera := Camera3D.new()
var arm := SpringArm3D.new()
const ACTIONS := {
	&"jump": ActionPlayerStateMachine.Action.JUMP,
	&"dash": ActionPlayerStateMachine.Action.AIR_DASH,
	&"dodge": ActionPlayerStateMachine.Action.DODGE,
	&"m1": ActionPlayerStateMachine.Action.ATTACK,
}


func _ready() -> void:
	process_physics_priority = -20
	add_child(arm)
	arm.add_child(camera)
	arm.spring_length = 5.0
	arm.collision_mask = player.tuning.world_mask
	arm.add_excluded_object(player.get_rid())
	var sphere := SphereShape3D.new()
	sphere.radius = 0.2
	arm.shape = sphere
	camera.current = true
	camera.fov = 76.0
	camera.far = 4500.0
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * 0.0022
		pitch = clampf(pitch - event.relative.y * 0.0022, -1.2, 1.2)
	elif event.is_action_pressed(&"ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
		get_viewport().set_input_as_handled()


func _physics_process(_dt: float) -> void:
	if not enabled:
		return
	var captured := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	player.move_input = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward") if captured else Vector2.ZERO
	player.sprint_held = captured and Input.is_action_pressed(&"sprint")
	player.crouch_held = captured and Input.is_action_pressed(&"crouch")
	player.block_held = captured and Input.is_action_pressed(&"block")
	player.jump_held = captured and Input.is_action_pressed(&"jump")
	player.camera_yaw = yaw
	player.aim_direction = -Basis.from_euler(Vector3(pitch, yaw, 0.0)).z
	if not captured:
		return
	for binding in ACTIONS:
		if Input.is_action_just_pressed(binding):
			player.request(ACTIONS[binding])


func _process(dt: float) -> void:
	global_position = player.get_global_transform_interpolated().origin + Vector3.UP * 1.5
	rotation = Vector3(pitch, yaw, 0.0)
	camera.fov = lerpf(camera.fov, 76.0 + clampf(player.horizontal_speed - 10.0, 0.0, 12.0), minf(1.0, dt * 8.0))
