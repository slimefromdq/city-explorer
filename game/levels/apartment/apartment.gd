extends Node3D
## Your apartment: the safe room between runs. The room itself is CSG in the
## scene (move furniture around in the editor freely); this script only wires
## the things you can use to what they do:
##   Mirror     -> hero select (HeroSelectMenu), previewed on the MirrorFigure
##   Wardrobe   -> outfits (WardrobeMenu), previewed on the same figure
##   Workbench  -> your current hero's card loadout (WorkbenchMenu)
##   FrontDoor  -> out (the test arena until the M4 city exists)
##
## On load it dresses the player from GameState: hero, that hero's saved
## loadout, outfit. Cards are locked here; movement still works.

## Where the front door leads. Becomes the city in M4.
@export_file("*.tscn") var front_door_target := "res://game/levels/test_arena/test_arena.tscn"
## The spawn point in that scene (a Marker3D name).
@export var front_door_target_spawn := "FromApartment"
## Falling below this height (out of the room somehow) puts you back at the spawn.
@export var kill_height := -10.0
## How fast the figure in the mirror turns, in radians per second.
@export var figure_turn_speed := 0.6

@onready var hero: Hero = $PlayerHero
@onready var figure: HeroModel = $MirrorAlcove/MirrorFigure
@onready var mirror_cam: Camera3D = $MirrorAlcove/MirrorCamera
@onready var menu: HeroSelectMenu = $HeroSelectMenu
@onready var wardrobe: WardrobeMenu = $WardrobeMenu
@onready var workbench: WorkbenchMenu = $WorkbenchMenu

var _figure_yaw := 0.0


func _ready() -> void:
	var spawn := $SpawnPoint as Marker3D
	var arrival := SceneRouter.take_arrival()
	if arrival != "" and has_node(arrival):
		spawn = get_node(arrival) as Marker3D
	hero.set_spawn(spawn.global_transform, spawn.global_rotation.y)
	hero.global_position = spawn.global_position
	hero.reset_physics_interpolation()
	_figure_yaw = figure.rotation.y
	_dress()
	GameState.changed.connect(_dress)
	($Interactables/Mirror as Interactable).used.connect(_open.bind(menu, true))
	($Interactables/Wardrobe as Interactable).used.connect(_open.bind(wardrobe, true))
	($Interactables/Workbench as Interactable).used.connect(_open.bind(workbench, false))
	($Interactables/FrontDoor as Interactable).used.connect(_go_out)
	_add_help()


func _physics_process(_dt: float) -> void:
	if hero.global_position.y < kill_height:
		hero.respawn()


func _process(dt: float) -> void:
	if figure != null and not _any_menu_open():
		figure.rotation.y += figure_turn_speed * dt


## Become whoever the save says you are: hero, that hero's loadout, outfit.
## Runs again whenever GameState changes (a pick, a slot edit, an outfit
## change, or wiping the save).
func _dress() -> void:
	GameState.dress(hero)
	if hero.runner != null:
		hero.runner.locked = true   # safe room: no casting indoors
	var def := GameState.current_hero()
	if def != null and not menu.is_open():
		figure.set_colors(def.body_color, def.accent_color)
	figure.apply_outfit(GameState.outfit)


func _open(_who: Hero, which: RoomMenu, use_mirror: bool) -> void:
	if _any_menu_open():
		return
	if use_mirror:
		figure.rotation.y = _figure_yaw   # face the room while you browse
		which.open(hero, figure, mirror_cam)
	else:
		which.open(hero)


func _any_menu_open() -> bool:
	return menu.is_open() or wardrobe.is_open() or workbench.is_open()


func _go_out(_who: Hero) -> void:
	SceneRouter.go(front_door_target, front_door_target_spawn)


func _add_help() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "WASD move   Shift sprint   Space jump   C crouch   Q roll   E sigil leap   RMB block\nF use: mirror = hero, wardrobe = outfit, workbench = cards, front door = go out   F10 twice = wipe save   Esc free mouse"
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_top = -56
	layer.add_child(label)
	add_child(layer)
