class_name RoomMenu
extends CanvasLayer
## Shared behaviour for the apartment's menus (mirror, wardrobe, workbench):
## while one is open the player is frozen and hidden, the mouse is free, the
## card HUD and interact prompt are hidden, and the view can switch to a
## preview camera. Closing undoes all of that. Subclasses build their own UI
## in `_build()` and refresh it in `_refresh()`.

signal closed

var hero: Hero
var figure: HeroModel
var view_cam: Camera3D

var _prev_cam: Camera3D


func _ready() -> void:
	layer = 70
	visible = false
	_build()


func is_open() -> bool:
	return visible


## Open for `h`, previewing on `fig` through `cam` (both optional).
func open(h: Hero, fig: HeroModel = null, cam: Camera3D = null) -> void:
	hero = h
	figure = fig
	view_cam = cam
	if not _on_open():
		return
	_set_player_control(false)
	if view_cam != null:
		_prev_cam = get_viewport().get_camera_3d()
		view_cam.make_current()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_refresh()


func close() -> void:
	if not visible:
		return
	visible = false
	if view_cam != null and _prev_cam != null:
		_prev_cam.make_current()
	_set_player_control(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


# ------------------------------------------------------------------ for subclasses

## Return false to refuse to open (and log why).
func _on_open() -> bool:
	return true


func _build() -> void:
	pass


func _refresh() -> void:
	pass


## A dark rounded panel on the left of the screen, `width` pixels wide.
func _side_panel(width: float) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.anchor_top = 0.08
	panel.anchor_bottom = 0.92
	panel.offset_left = 40
	panel.offset_right = 40 + width
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.1, 0.9)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", bg)
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	panel.add_child(box)
	return box


func _label(text: String, size := 16, color := Color(0.92, 0.92, 0.95)) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # keys go to _input, not button focus
	b.add_theme_font_size_override(&"font_size", 18)
	b.pressed.connect(cb)
	return b


## Freeze the player while a menu is up: no input, no held keys left over,
## no interact prompt or card HUD, and the body hidden so it doesn't block
## the preview.
func _set_player_control(on: bool) -> void:
	if hero == null:
		return
	var input := hero.get_node_or_null("PlayerInput") as HeroPlayerInput
	if input != null:
		input.enabled = on
	if not on:
		var i := hero.intent
		i.move = Vector2.ZERO
		i.sprint = false
		i.crouch = false
		i.jump_held = false
		i.block = false
		for s in i.card_held.size():
			i.card_held[s] = false
		i.clear_presses()
	if hero.interactor != null:
		hero.interactor.set_active(on)
	hero.model.visible = on
	var hud := hero.get_node_or_null("CardHud") as CanvasLayer
	if hud != null:
		hud.visible = on
