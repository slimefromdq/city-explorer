extends Node3D
## The M1 movement test arena. All geometry lives in the scene as CSG boxes
## (move them around in the editor freely); this script only handles the
## fast-iteration tools: instant respawn and the falling-off-the-world reset.

## Falling below this height respawns you instantly.
@export var kill_height := -30.0
## Card loadouts to try; Tab cycles through them (the first one is equipped at
## start). After the last one comes "your hero": the hero and loadout you picked
## in the apartment, with its passive.
@export var loadouts: Array[CardLoadout] = []

var loadout_index := 0

@onready var hero: Hero = $PlayerHero


func _ready() -> void:
	var spawn := $SpawnPoint as Marker3D
	# Came through the apartment's front door: arrive at the door, as your hero.
	var arrival := SceneRouter.take_arrival()
	var from_door := arrival != "" and has_node(arrival)
	if from_door:
		spawn = get_node(arrival) as Marker3D
	hero.set_spawn(spawn.global_transform, spawn.global_rotation.y)
	hero.global_position = spawn.global_position
	hero.reset_physics_interpolation()
	hero.model.apply_outfit(GameState.outfit)   # cosmetic, so always worn
	if from_door:
		_equip_loadout(loadouts.size())
	elif not loadouts.is_empty() and hero.runner != null:
		_equip_loadout(0)
	var door := get_node_or_null("ApartmentDoor/Use") as Interactable
	if door != null:
		door.used.connect(func(_who: Hero) -> void: SceneRouter.go(SceneRouter.APARTMENT, "FrontDoorSpawn"))
	_add_help()


func _physics_process(_dt: float) -> void:
	if hero.global_position.y < kill_height:
		hero.respawn()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"dbg_reset"):
		hero.respawn()
		for d in get_tree().get_nodes_in_group(&"target_dummies"):
			(d as TargetDummy).reset()
	elif event.is_action_pressed(&"loadout_next") and not loadouts.is_empty():
		_equip_loadout((loadout_index + 1) % (loadouts.size() + 1))


func _equip_loadout(i: int) -> void:
	loadout_index = i
	if i == loadouts.size():
		var def := GameState.current_hero()
		if def != null:
			GameState.dress(hero)
			Events.feed.emit("Loadout: your hero, %s" % def.display_name)
		return
	hero.runner.set_passive(null)
	var lo := loadouts[i]
	if lo == null:
		push_error("Test arena: loadouts[%d] is empty" % i)
		return
	hero.runner.set_cards(lo.cards)
	Events.feed.emit("Loadout: %s" % lo.display_name)


func _add_help() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "WASD move   Shift sprint   Space jump (hold = higher; on a wall in the air = wall kick)   C / Ctrl crouch   E sigil leap (aim with the camera)   Q roll   RMB block   F use\nCrouch while running fast = slide   Run into a ledge in the air to mantle   Door left of the spawn (F) = back to your apartment\nCards: LMB primary   R / G / V abilities   Tab next loadout   F4 reload cards   F5 respawn + reset dummies   F3 debug overlay   Esc free mouse"
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_top = -76
	layer.add_child(label)
	add_child(layer)
