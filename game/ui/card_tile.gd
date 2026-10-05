class_name CardTile
extends PanelContainer
## One card on the workbench: in the "your cards" list (slot = -1) or in one
## of the 4 loadout slots. Drag it somewhere, or click it (the workbench turns
## clicks into "pick up / put down"). The tile itself changes no game state:
## it hands drops and clicks to the workbench through the callables below.

const SLOT_NAMES := ["LMB", "R", "G", "V"]

var card: AbilityCard
## -1 = a tile in the card list; 0-3 = a loadout slot.
var slot := -1
## (tile, data) -> void. Set on tiles (and areas) that accept drops.
var on_drop: Callable
## (tile, button_index) -> void
var on_click: Callable
## (card or null) -> void, when the mouse moves over the tile
var on_hover: Callable

var _style := StyleBoxFlat.new()
var _title: Label
var _sub: Label
var _selected := false
var _dimmed := false


func setup(c: AbilityCard, slot_index: int) -> void:
	card = c
	slot = slot_index
	if _title != null:
		_refresh()


func set_selected(on: bool) -> void:
	_selected = on
	_refresh()


## Dim a list card that is already in one of the slots.
func set_dimmed(on: bool) -> void:
	_dimmed = on
	_refresh()


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(200, 58)
	_style.set_corner_radius_all(6)
	_style.set_content_margin_all(8)
	_style.border_width_left = 6
	add_theme_stylebox_override(&"panel", _style)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 0)
	add_child(box)
	_title = Label.new()
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_title.add_theme_font_size_override(&"font_size", 17)
	box.add_child(_title)
	_sub = Label.new()
	_sub.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sub.add_theme_font_size_override(&"font_size", 13)
	_sub.add_theme_color_override(&"font_color", Color(0.7, 0.72, 0.78))
	box.add_child(_sub)
	mouse_entered.connect(func() -> void:
		if on_hover.is_valid():
			on_hover.call(card))
	_refresh()


func _refresh() -> void:
	var col := card.color if card != null else Color(0.35, 0.36, 0.4)
	_style.bg_color = Color(0.13, 0.14, 0.18, 0.55 if _dimmed else 0.95)
	_style.border_color = col
	_style.border_width_top = 2 if _selected else 0
	_style.border_width_right = 2 if _selected else 0
	_style.border_width_bottom = 2 if _selected else 0
	if _selected:
		_style.border_color = Color(1.0, 0.85, 0.4)
	var prefix := "%s   " % SLOT_NAMES[slot] if slot >= 0 else ""
	if card == null:
		_title.text = prefix + "(empty)"
		_title.add_theme_color_override(&"font_color", Color(0.55, 0.56, 0.6))
		_sub.text = "drag a card here"
	else:
		_title.text = prefix + card.display_name
		_title.add_theme_color_override(&"font_color", col.lightened(0.35) if not _dimmed else Color(0.55, 0.56, 0.6))
		_sub.text = trigger_text(card) + ("   (equipped)" if _dimmed else "")


## "press", "hold", "auto: OnRoll", "passive"...: how the card fires, in a few words.
static func trigger_text(c: AbilityCard) -> String:
	match c.trigger:
		AbilityCard.Trigger.HOLD: return "hold to fire"
		AbilityCard.Trigger.RELEASE: return "hold, release to throw"
		AbilityCard.Trigger.MOVEMENT_EVENT: return "auto: " + MoveEvent.name_of(c.movement_event)
		AbilityCard.Trigger.PASSIVE: return "passive (always on)"
		AbilityCard.Trigger.PROC_ONLY: return "only cast by other cards"
	return "press"


func _gui_input(event: InputEvent) -> void:
	var mb := event as InputEventMouseButton
	if mb != null and mb.pressed and on_click.is_valid():
		on_click.call(self, mb.button_index)


func _get_drag_data(_pos: Vector2) -> Variant:
	if card == null:
		return null
	var preview := Label.new()
	preview.text = card.display_name
	preview.add_theme_font_size_override(&"font_size", 18)
	preview.add_theme_color_override(&"font_color", card.color.lightened(0.3))
	preview.add_theme_constant_override(&"outline_size", 5)
	preview.add_theme_color_override(&"font_outline_color", Color.BLACK)
	set_drag_preview(preview)
	return {"card": card, "from_slot": slot}


func _can_drop_data(_pos: Vector2, data: Variant) -> bool:
	return on_drop.is_valid() and data is Dictionary and (data as Dictionary).has("card")


func _drop_data(_pos: Vector2, data: Variant) -> void:
	on_drop.call(self, data)
