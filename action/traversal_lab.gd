extends Node3D
## Run this scene for the compact traversal course; pass -- --city to use the
## same controller in the existing open-world CityBuilder map.
var player: ActionPlayerController
var input: ActionPlayerInput
var spawn_point := Vector3(0.0, 0.1, 8.0)


func _ready() -> void:
	SkyEnv.build(self)
	if "--city" in OS.get_cmdline_user_args():
		var city := CityBuilder.new()
		add_child(city)
		city.build()
		spawn_point = city.markers["player"]
	else:
		_course()
	player = preload("res://action/player.tscn").instantiate()
	player.position = spawn_point
	add_child(player)
	input = ActionPlayerInput.new()
	input.player = player
	add_child(input)
	var layer := CanvasLayer.new()
	var help := Label.new()
	help.position = Vector2(20, 18)
	help.text = "ACTION CONTROLLER / TRAVERSAL LAB\nWASD move · Shift sprint · Space jump / wall jump · Ctrl or C crouch / slide\nQ dodge · E air dash · RMB block · LMB melee combo · F3 debug · F5 reset · Esc free cursor"
	help.add_theme_color_override("font_outline_color", Color.BLACK)
	help.add_theme_constant_override("outline_size", 5)
	layer.add_child(help)
	add_child(layer)
	var debug := ActionControllerDebugView.new()
	debug.player = player
	add_child(debug)


func _course() -> void:
	var kit := Kit.new(self, "TraversalCourse")
	var ground := StandardMaterial3D.new()
	ground.albedo_color = Color(0.12, 0.18, 0.24)
	var ledge := StandardMaterial3D.new()
	ledge.albedo_color = Color(0.26, 0.42, 0.46)
	var wall := StandardMaterial3D.new()
	wall.albedo_color = Color(0.5, 0.3, 0.25)
	kit.box(Vector3(-5, -1, -10), Vector3(70, 1, 90), ground)
	kit.box(Vector3(-4, 0, -5), Vector3(5, 0.8, 4), ledge)
	kit.box(Vector3(4, 0, -8), Vector3(5, 2.0, 5), ledge)
	kit.box(Vector3(10, 0, -17), Vector3(1, 7, 24), wall)
	kit.box(Vector3(16, 0, -17), Vector3(1, 7, 24), wall)
	kit.box(Vector3(-13, 0, -14), Vector3(6, 0.4, 14), ledge, true, Vector3(16, 0, 0))
	kit.box(Vector3(-6, 1.2, 4), Vector3(6, 0.35, 4), wall)
	_sign(Vector3(-4, 1.3, -5), "LOW VAULT / 0.8m")
	_sign(Vector3(4, 2.6, -8), "HIGH MANTLE / 2m")
	_sign(Vector3(13, 7.5, -10), "WALL RUN / sprint + jump alongside")
	_sign(Vector3(-13, 2.7, -14), "DOWNHILL SLIDE")
	_sign(Vector3(-6, 2.0, 4), "CROUCH CLEARANCE")


func _sign(at: Vector3, text: String) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = at
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 36
	add_child(label)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dbg_reset"):
		player.reset_at(spawn_point)


func _physics_process(_dt: float) -> void:
	if player != null and player.global_position.y < -30.0:
		player.reset_at(spawn_point)
