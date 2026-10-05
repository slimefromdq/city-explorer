extends Node3D
## Your apartment: the safe room between runs. The room itself is CSG in the
## scene (move furniture around in the editor freely); this script only wires
## the things you can use to what they do:
##   Mirror     -> hero select (HeroSelectMenu), previewed on the MirrorFigure
##   Workbench  -> card loadout editor (M3b)
##   Wardrobe   -> outfits (M3b)
##   FrontDoor  -> out to the city (M3b; the test arena until M4 exists)
##
## On load it turns the player into the hero saved in GameState, with that
## hero's saved loadout. Cards are locked here; movement still works.

## Falling below this height (out of the room somehow) puts you back at the spawn.
@export var kill_height := -10.0
## How fast the figure in the mirror turns, in radians per second.
@export var figure_turn_speed := 0.6

@onready var hero: Hero = $PlayerHero
@onready var figure: HeroModel = $MirrorAlcove/MirrorFigure
@onready var mirror_cam: Camera3D = $MirrorAlcove/MirrorCamera
@onready var menu: HeroSelectMenu = $HeroSelectMenu

var _figure_yaw := 0.0


func _ready() -> void:
	var spawn := $SpawnPoint as Marker3D
	hero.set_spawn(spawn.global_transform, spawn.global_rotation.y)
	_figure_yaw = figure.rotation.y
	_become_saved_hero()
	GameState.changed.connect(_on_state_changed)
	if hero.runner != null:
		hero.runner.locked = true   # safe room: no casting indoors
	($Interactables/Mirror as Interactable).used.connect(_on_mirror)
	($Interactables/Workbench as Interactable).used.connect(_coming_soon.bind("The card workbench"))
	($Interactables/Wardrobe as Interactable).used.connect(_coming_soon.bind("The wardrobe"))
	($Interactables/FrontDoor as Interactable).used.connect(_coming_soon.bind("The front door"))
	_add_help()


func _physics_process(_dt: float) -> void:
	if hero.global_position.y < kill_height:
		hero.respawn()


func _process(dt: float) -> void:
	if figure != null and not menu.is_open():
		figure.rotation.y += figure_turn_speed * dt


## Become whoever the save says you are, with that hero's own loadout.
func _become_saved_hero() -> void:
	var def := GameState.current_hero()
	if def == null:
		push_error("Apartment: GameState has no hero definitions; check %s" % GameState.HERO_DIR)
		return
	hero.apply_definition(def, GameState.loadout_cards(def.id))
	if figure != null:
		figure.set_colors(def.body_color, def.accent_color)


## Picking a hero or wiping the save (F10 twice) can change who you are or your cards.
func _on_state_changed() -> void:
	_become_saved_hero()


func _on_mirror(_who: Hero) -> void:
	if not menu.is_open():
		figure.rotation.y = _figure_yaw   # face the room while you browse
		menu.open(hero, figure, mirror_cam)


func _coming_soon(_who: Hero, what: String) -> void:
	Events.feed.emit("%s arrives in M3b" % what)


func _add_help() -> void:
	var layer := CanvasLayer.new()
	var label := Label.new()
	label.text = "WASD move   Shift sprint   Space jump   C crouch   Q roll   E sigil leap   RMB block\nF use (mirror = choose your hero)   F10 twice = wipe save   Esc free mouse   (cards are locked indoors)"
	label.add_theme_font_size_override(&"font_size", 15)
	label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	label.add_theme_constant_override(&"outline_size", 5)
	label.anchor_top = 1.0
	label.anchor_bottom = 1.0
	label.offset_left = 12
	label.offset_top = -56
	layer.add_child(label)
	add_child(layer)
