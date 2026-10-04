class_name CardHud
extends CanvasLayer
## Minimal on-screen card info for M2: a crosshair, the four card slots with
## their key, charges and cooldown, the energy bar, and short messages
## ("Reloaded 5 cards", "Loadout: ..."). It only reads the runner; nothing in
## the game depends on it. (The full HUD comes in M6.)

var runner: AbilityRunner
var _slots: Array[Dictionary] = []
var _energy: ProgressBar
var _toast: Label
var _toast_t := 0.0


func _ready() -> void:
	layer = 50
	_build()
	Events.feed.connect(show_message)


func show_message(text: String) -> void:
	_toast.text = text
	_toast_t = 2.0


func _process(dt: float) -> void:
	_toast_t -= dt
	_toast.modulate.a = clampf(_toast_t, 0.0, 1.0)
	if runner == null and get_parent() is Hero:
		runner = (get_parent() as Hero).runner   # the hero sets it up after we're ready
	if runner == null or runner.cards.is_empty():
		return
	for i in AbilityRunner.SLOT_COUNT:
		var ui := _slots[i]
		var card := runner.cards[i]
		var name_label: Label = ui.name
		var bar: ProgressBar = ui.bar
		var panel: PanelContainer = ui.panel
		if card == null:
			name_label.text = "%s  (empty)" % AbilityRunner.SLOT_KEYS[i]
			bar.value = 0.0
			panel.modulate = Color(1, 1, 1, 0.4)
			continue
		var ch := runner.slot_charges(i)
		var ready_count: int = ch[0]
		var max_count: int = ch[1]
		var progress: float = ch[2]
		var count_text := "  x%d" % ready_count if max_count > 1 else ""
		name_label.text = "%s  %s%s" % [AbilityRunner.SLOT_KEYS[i], card.display_name, count_text]
		bar.value = 1.0 if ready_count >= max_count else progress
		var usable := ready_count > 0 and runner.energy >= card.energy_cost
		panel.modulate = Color(1, 1, 1, 1.0 if usable else 0.5)
		(ui.style as StyleBoxFlat).border_color = card.color
	_energy.value = runner.energy / runner.max_energy


func _build() -> void:
	# Crosshair: a small dot with four ticks.
	var center := Control.new()
	center.set_anchors_preset(Control.PRESET_CENTER)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	# Drawn twice: a dark outline underneath so it reads on light and dark backgrounds.
	for pass_i in 2:
		var grow := 1.0 if pass_i == 0 else 0.0
		for r in [Rect2(-2, -2, 4, 4), Rect2(-1, -13, 2, 7), Rect2(-1, 6, 2, 7), Rect2(-13, -1, 7, 2), Rect2(6, -1, 7, 2)]:
			var c := ColorRect.new()
			c.color = Color(0, 0, 0, 0.8) if pass_i == 0 else Color(1, 1, 1, 0.95)
			c.position = r.position - Vector2(grow, grow)
			c.size = r.size + Vector2(grow, grow) * 2.0
			c.mouse_filter = Control.MOUSE_FILTER_IGNORE
			center.add_child(c)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_bottom = -96
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(box)
	_toast = Label.new()
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_font_size_override(&"font_size", 18)
	_toast.add_theme_constant_override(&"outline_size", 5)
	_toast.add_theme_color_override(&"font_outline_color", Color.BLACK)
	box.add_child(_toast)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 8)
	box.add_child(row)
	for i in AbilityRunner.SLOT_COUNT:
		var panel := PanelContainer.new()
		var style := StyleBoxFlat.new()
		style.bg_color = Color(0.03, 0.04, 0.08, 0.75)
		style.set_border_width_all(0)
		style.border_width_bottom = 3
		style.set_content_margin_all(6)
		style.set_corner_radius_all(4)
		panel.add_theme_stylebox_override(&"panel", style)
		panel.custom_minimum_size = Vector2(170, 0)
		var v := VBoxContainer.new()
		panel.add_child(v)
		var name_label := Label.new()
		name_label.add_theme_font_size_override(&"font_size", 14)
		v.add_child(name_label)
		var bar := ProgressBar.new()
		bar.max_value = 1.0
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 5)
		v.add_child(bar)
		row.add_child(panel)
		_slots.append({"panel": panel, "name": name_label, "bar": bar, "style": style})
	_energy = ProgressBar.new()
	_energy.max_value = 1.0
	_energy.show_percentage = false
	_energy.custom_minimum_size = Vector2(0, 6)
	var es := StyleBoxFlat.new()
	es.bg_color = Color(0.3, 0.7, 1.0)
	_energy.add_theme_stylebox_override(&"fill", es)
	box.add_child(_energy)
