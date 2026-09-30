class_name PlayerController
extends Node
## Turns keyboard/mouse into Fighter intents. Contains zero gameplay rules:
## swap this for a BotBrain (or a network client) and the Fighter can't tell.

var fighter: Fighter
var rig: CameraRig
var enabled := true


func _ready() -> void:
	process_physics_priority = -20
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rig.look((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_dt: float) -> void:
	if not enabled or fighter == null:
		return
	var f := fighter
	f.aim_yaw = rig.yaw
	var aim := rig.compute_aim([f.hurtbox.get_rid()])
	f.aim_dir = aim.dir
	f.aim_point = aim.point
	if not f.alive:
		f.move_input = Vector2.ZERO
		return
	f.move_input = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	f.wants_sprint = Input.is_action_pressed(&"sprint")
	f.wants_block = Input.is_action_pressed(&"block")
	f.jump_held = Input.is_action_pressed(&"jump")
	if Input.is_action_just_pressed(&"jump"):
		f.loco.request_jump()
	if Input.is_action_just_pressed(&"dash"):
		f.loco.request_dash()
	if Input.is_action_just_pressed(&"dodge"):
		f.dodge.try_dodge()
	if Input.is_action_just_pressed(&"reload") and f.gun != null and f.can_act():
		f.gun.start_reload()
	f.hold_ability(0, Input.is_action_pressed(&"m1"))
	if Input.is_action_just_pressed(&"m1"):
		f.press_ability(0)
	for i in range(1, 5):
		var act := StringName("ability_%d" % i)
		if Input.is_action_just_pressed(act):
			f.press_ability(i)
		if Input.is_action_just_released(act):
			f.release_ability(i)
