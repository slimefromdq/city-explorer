class_name Interactor
extends Node
## Lives on the player hero. Each tick it picks the nearest Interactable that
## is in range and roughly in front of the camera, shows "F  <prompt>", and
## uses it when the intent says interact was pressed. Bots don't need one.

## How far off to the side (dot product with the view direction) still counts.
@export_range(-1.0, 1.0) var min_facing := 0.2

var hero: Hero
var current: Interactable
var _label: Label


func _ready() -> void:
	hero = get_parent() as Hero
	process_physics_priority = 5   # after the hero has read this tick's intent
	var layer := CanvasLayer.new()
	layer.layer = 60
	add_child(layer)
	_label = Label.new()
	_label.set_anchors_preset(Control.PRESET_CENTER)
	_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_label.position.y = 40
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.add_theme_font_size_override(&"font_size", 22)
	_label.add_theme_constant_override(&"outline_size", 6)
	_label.add_theme_color_override(&"font_outline_color", Color.BLACK)
	layer.add_child(_label)


## Menus switch this off while they're open, so the prompt disappears and
## F does nothing in the world.
func set_active(on: bool) -> void:
	set_physics_process(on)
	if not on:
		current = null
		_label.text = ""


func _physics_process(_dt: float) -> void:
	if hero == null:
		return
	current = _find()
	_label.text = "F   %s" % current.prompt if current != null else ""


## Called by the hero during its tick, while the press is still set.
func handle_press() -> void:
	if not is_physics_processing():
		return
	var target := _find()
	if target != null:
		target.use(hero)


func _find() -> Interactable:
	var best: Interactable = null
	var best_d := INF
	var fwd := Basis(Vector3.UP, hero.intent.aim_yaw) * Vector3.FORWARD
	for n in hero.get_tree().get_nodes_in_group(&"interactables"):
		var it := n as Interactable
		if it == null or not it.enabled or not it.is_visible_in_tree():
			continue
		var to := it.global_position - hero.global_position
		to.y = 0.0
		var d := to.length()
		if d > it.radius or d >= best_d:
			continue
		if d > 0.4 and fwd.dot(to / d) < min_facing:
			continue
		best = it
		best_d = d
	return best
