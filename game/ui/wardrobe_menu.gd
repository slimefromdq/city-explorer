class_name WardrobeMenu
extends RoomMenu
## The wardrobe: pick a head, top and bottom part and a colour tint. Outfits
## are cosmetic only and work on every hero. Each change shows on the figure
## in the mirror at once and is saved at once; there's nothing to confirm.
## Keys: W/S or up/down pick a row, A/D or left/right change it, Esc or F closes.

const ROWS := ["head", "top", "bottom", "tint"]
const ROW_NAMES := ["Head", "Top", "Bottom", "Tint"]

var row := 0

var _value_labels: Array[Label] = []
var _row_marks: Array[Label] = []


func _on_open() -> bool:
	row = 0
	return true


## Step the given row's choice by `step` (wrapping; "nothing" is one of the choices).
func cycle(row_index: int, step: int) -> void:
	var key: String = ROWS[row_index]
	var options := _options(key)
	var cur := str(GameState.outfit.get(key, ""))
	var i := maxi(options.find(cur), 0)
	GameState.set_outfit_part(key, options[wrapi(i + step, 0, options.size())])
	_apply()


func pick_tint(html: String) -> void:
	GameState.set_outfit_part("tint", html)
	_apply()


## "" + every part id for a slot, or "" + every tint colour.
func _options(key: String) -> Array:
	var out := [""]
	if key == "tint":
		out = OutfitCatalog.TINTS.duplicate()
	else:
		for p in OutfitCatalog.parts_for(OutfitCatalog.SLOT_KEYS.find(key) as OutfitPart.Slot):
			out.append(OutfitCatalog.id_of(p))
	return out


func _apply() -> void:
	if figure != null:
		figure.apply_outfit(GameState.outfit)
	if hero != null:
		hero.model.apply_outfit(GameState.outfit)
	_refresh()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action(&"move_forward") or event.is_action(&"ui_up"):
		row = wrapi(row - 1, 0, ROWS.size())
		_refresh()
	elif event.is_action(&"move_back") or event.is_action(&"ui_down"):
		row = wrapi(row + 1, 0, ROWS.size())
		_refresh()
	elif event.is_action(&"move_left") or event.is_action(&"ui_left"):
		cycle(row, -1)
	elif event.is_action(&"move_right") or event.is_action(&"ui_right"):
		cycle(row, 1)
	elif event.is_action(&"ui_cancel") or event.is_action(&"interact") or event.is_action(&"ui_accept"):
		close()
	else:
		return
	get_viewport().set_input_as_handled()


func _refresh() -> void:
	for r in ROWS.size():
		var key: String = ROWS[r]
		var v := str(GameState.outfit.get(key, ""))
		var text := ""
		if key == "tint":
			text = "hero colour" if v == "" else "#" + v
		else:
			var part := OutfitCatalog.part_by_id(v)
			text = part.display_name if part != null else "nothing"
		_value_labels[r].text = text
		_row_marks[r].text = ">" if r == row else ""


func _build() -> void:
	var box := _side_panel(440)
	box.add_child(_label("WARDROBE: outfit", 15, Color(0.7, 0.72, 0.78)))
	box.add_child(_label("Cosmetic only. Any outfit works on any hero.", 15, Color(0.75, 0.76, 0.8)))
	for r in ROWS.size():
		var line := HBoxContainer.new()
		line.add_theme_constant_override(&"separation", 8)
		box.add_child(line)
		var mark := _label("", 20, Color(1.0, 0.8, 0.4))
		mark.custom_minimum_size.x = 16
		line.add_child(mark)
		_row_marks.append(mark)
		var title := _label(ROW_NAMES[r], 20)
		title.custom_minimum_size.x = 90
		line.add_child(title)
		line.add_child(_button("<", cycle.bind(r, -1)))
		var value := _label("", 20)
		value.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		value.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		line.add_child(value)
		_value_labels.append(value)
		line.add_child(_button(">", cycle.bind(r, 1)))
	var swatches := GridContainer.new()
	swatches.columns = 5
	swatches.add_theme_constant_override(&"h_separation", 8)
	swatches.add_theme_constant_override(&"v_separation", 8)
	box.add_child(swatches)
	for t in OutfitCatalog.TINTS:
		var b := Button.new()
		b.focus_mode = Control.FOCUS_NONE
		b.custom_minimum_size = Vector2(64, 36)
		b.tooltip_text = "hero colour" if t == "" else "#" + t
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.3, 0.3, 0.34) if t == "" else Color.html(t)
		sb.set_corner_radius_all(6)
		b.add_theme_stylebox_override(&"normal", sb)
		b.add_theme_stylebox_override(&"hover", sb)
		b.add_theme_stylebox_override(&"pressed", sb)
		if t == "":
			b.text = "hero"
		b.pressed.connect(pick_tint.bind(t))
		swatches.add_child(b)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)
	var done := _button("Done (Esc / F)", close)
	box.add_child(done)
	box.add_child(_label("W / S pick a row, A / D change it. Saved as you go.", 15, Color(0.6, 0.62, 0.68)))
