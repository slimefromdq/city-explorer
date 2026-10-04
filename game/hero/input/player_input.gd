class_name HeroPlayerInput
extends Node
## Turns keyboard + mouse into the hero's intent. Contains zero gameplay rules:
## it only reports what you are pressing and where you are aiming. Replace this
## node with a bot (or a network client) and the hero can't tell the difference.
##
## Lives as a child of the hero; finds the ShoulderCamera sibling for aiming.

## Tests switch this off and write the intent themselves.
@export var enabled := true

var hero: Hero
var cam: ShoulderCamera


func _ready() -> void:
	# Run before the hero's own physics tick so the intent is fresh.
	process_physics_priority = -20
	hero = get_parent() as Hero
	cam = hero.get_node_or_null("ShoulderCamera") as ShoulderCamera
	hero.add_to_group(&"player_hero")
	if enabled:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and cam != null:
		cam.look((event as InputEventMouseMotion).relative)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and (event as InputEventKey).keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _physics_process(_dt: float) -> void:
	if not enabled or hero == null:
		return
	var i := hero.intent
	if cam != null:
		i.aim_yaw = cam.yaw
		var aim := cam.compute_aim([hero.get_rid()])
		i.aim_dir = aim.dir
		i.aim_point = aim.point
	i.move = Input.get_vector(&"move_left", &"move_right", &"move_back", &"move_forward")
	i.sprint = Input.is_action_pressed(&"sprint")
	i.crouch = Input.is_action_pressed(&"crouch")
	i.jump_held = Input.is_action_pressed(&"jump")
	if Input.is_action_just_pressed(&"jump"):
		i.jump_pressed = true
	if Input.is_action_just_pressed(&"dash"):
		i.dash_pressed = true
