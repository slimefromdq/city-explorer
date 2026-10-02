extends Node
## Standalone entry point for the connected exploration milestone.
var layer: CanvasLayer
var menu: Control
var progress: ProgressBar
var status: Label
var start_button: Button
var exploring := false
var can_return := false

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	layer = CanvasLayer.new()
	layer.layer = 40
	add_child(layer)
	menu = ColorRect.new()
	menu.color = Color("10282d")
	menu.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(menu)
	var cover := TextureRect.new()
	cover.texture = load("res://walk/meridia_cover.png")
	cover.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	cover.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(cover)
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.07, 0.09, 0.68)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(veil)
	var centre := CenterContainer.new()
	centre.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	menu.add_child(centre)
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.035, 0.085, 0.10, 0.92)
	style.border_color = Color("52716c")
	style.set_border_width_all(1)
	style.set_corner_radius_all(16)
	style.content_margin_left = 36
	style.content_margin_right = 36
	style.content_margin_top = 32
	style.content_margin_bottom = 32
	panel.add_theme_stylebox_override("panel", style)
	centre.add_child(panel)
	var box := VBoxContainer.new()
	box.custom_minimum_size = Vector2(660, 0)
	box.add_theme_constant_override("separation", 22)
	panel.add_child(box)
	_label(box, "MERIDIA CITY  /  EXPLORATION MILESTONE", 18, Color("39c5b8"))
	_label(box, "Meridia City", 48)
	_label(box, "Central Station · Meridian Tower · the lake · civic terraces", 20)
	_label(box, "Follow the teal trail, or take a train.\nWASD move   Mouse look   Shift run   Space jump\nM walking map   Esc release mouse   F1 return to this screen", 18)
	start_button = Button.new()
	start_button.text = "Explore Meridia"
	start_button.custom_minimum_size.y = 58
	start_button.add_theme_font_size_override("font_size", 22)
	start_button.pressed.connect(start_exploring)
	box.add_child(start_button)
	start_button.grab_focus()
	progress = ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 12
	progress.hide()
	box.add_child(progress)
	status = _label(box, "Connected paths and trains are playable. Civic interiors are closed.", 16, Color("b6c8c1"))
	var quit_button := Button.new()
	quit_button.text = "Quit"
	quit_button.pressed.connect(func(): get_tree().quit())
	box.add_child(quit_button)

func _label(box: VBoxContainer, text: String, font_size: int, color := Color("eae7d8")) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	box.add_child(label)
	return label

func start_exploring() -> void:
	if exploring:
		return
	exploring = true
	start_button.disabled = true
	start_button.text = "Preparing your city…"
	progress.show()
	status.text = "Preparing Meridia"
	await get_tree().process_frame
	await get_tree().process_frame
	var walk := StationWalk.new()
	walk.staged_loading = true
	walk.loading_progress.connect(func(value: float, description: String):
		progress.value = value * 100
		status.text = description)
	add_child(walk)
	if not walk.ready_to_explore:
		await walk.exploration_ready
	menu.hide()
	can_return = true

func _unhandled_input(event: InputEvent) -> void:
	if can_return and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F1:
		RideUI.blocking = false
		get_viewport().set_input_as_handled()
		get_tree().reload_current_scene()
