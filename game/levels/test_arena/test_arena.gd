extends Node3D
## The M1 movement test arena. All geometry lives in the scene as CSG boxes
## (move them around in the editor freely); this script only handles the
## fast-iteration tools: instant respawn and the falling-off-the-world reset.

## Falling below this height respawns you instantly.
@export var kill_height := -30.0

@onready var hero: Hero = $PlayerHero


func _ready() -> void:
	var spawn := $SpawnPoint as Marker3D
	hero.set_spawn(spawn.global_transform, spawn.global_rotation.y)
	_add_help()


func _physics_process(_dt: float) -> void:
	if hero.global_position.y < kill_height:
		hero.respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dbg_reset"):
		hero.respawn()


func _add_help() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "WASD move   Shift sprint   Space jump (hold = higher; on a wall in the air = wall kick)   C / Ctrl crouch   E sigil leap (aim with the camera)   Q roll   F / RMB block\nRun into a ledge in the air to mantle   F5 respawn   F3 debug overlay   Esc free mouse"
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_top = -56
	layer.add_child(label)
	add_child(layer)
