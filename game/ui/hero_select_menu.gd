class_name HeroSelectMenu
extends CanvasLayer
## The mirror's hero picker. While it's open the player can't move, the view
## switches to a camera looking at the figure in the mirror, and browsing
## recolours that figure so you see each hero before you pick it.
##
## It only changes things through GameState (set_hero) and Hero.apply_definition,
## so whatever the mirror picks is what the save file and every scene see.
## Keys: A/D or arrows browse, F/Enter choose, Esc cancel (nothing changes).

signal closed

var hero: Hero
var figure: HeroModel
var view_cam: Camera3D
var heroes: Array[HeroDefinition] = []
var index := 0

var _prev_cam: Camera3D
var _panel: PanelContainer
var _name: Label
var _desc: Label
var _cards: RichTextLabel
var _count: Label


func _ready() -> void:
	layer = 70
	visible = false
	_build()


func is_open() -> bool:
	return visible


## Open for `h`, previewing on `fig` through `cam` (both optional).
func open(h: Hero, fig: HeroModel, cam: Camera3D) -> void:
	hero = h
	figure = fig
	view_cam = cam
	heroes = GameState.hero_definitions()
	if heroes.is_empty():
		push_error("HeroSelectMenu: no heroes found in %s" % GameState.HERO_DIR)
		return
	index = 0
	for i in heroes.size():
		if heroes[i].id == GameState.hero_id:
			index = i
	_set_player_control(false)
	if view_cam != null:
		_prev_cam = get_viewport().get_camera_3d()
		view_cam.make_current()
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show()


## Pick the hero being shown: saved at once, applied to the player.
func confirm() -> void:
	var def := heroes[index]
	GameState.set_hero(def.id)
	hero.apply_definition(def, GameState.loadout_cards(def.id))
	Events.feed.emit("You are now %s" % def.display_name)
	_close()


## Leave without changing anything; the mirror goes back to the current hero.
func cancel() -> void:
	var cur := GameState.current_hero()
	if figure != null and cur != null:
		figure.set_colors(cur.body_color, cur.accent_color)
	_close()


func browse(step: int) -> void:
	index = wrapi(index + step, 0, heroes.size())
	_show()


func _close() -> void:
	visible = false
	if view_cam != null and _prev_cam != null:
		_prev_cam.make_current()
	_set_player_control(true)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	closed.emit()


func _input(event: InputEvent) -> void:
	if not visible or not event.is_pressed() or event.is_echo():
		return
	if event.is_action(&"move_left") or event.is_action(&"ui_left"):
		browse(-1)
	elif event.is_action(&"move_right") or event.is_action(&"ui_right"):
		browse(1)
	elif event.is_action(&"interact") or event.is_action(&"ui_accept"):
		confirm()
	elif event.is_action(&"ui_cancel"):
		cancel()
	else:
		return
	get_viewport().set_input_as_handled()


## Freeze the player while the menu is up: no input, no held keys left over,
## no interact prompt, and the body hidden so it doesn't block the mirror.
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


func _show() -> void:
	var def := heroes[index]
	if figure != null:
		figure.set_colors(def.body_color, def.accent_color)
	_name.text = def.display_name
	_name.add_theme_color_override(&"font_color", def.accent_color.lightened(0.2))
	_desc.text = def.description
	_count.text = "%d / %d%s" % [index + 1, heroes.size(), "   (current)" if def.id == GameState.hero_id else ""]
	var slot_names := ["LMB", "R", "G", "V"]
	var cards := GameState.loadout_cards(def.id)
	var t := "[b]Loadout[/b]\n"
	for s in 4:
		var c := cards[s]
		if c == null:
			t += "[color=#888]%s   (empty)[/color]\n" % slot_names[s]
		else:
			t += "[color=#%s]%s   %s[/color]   [color=#bbb]%s[/color]\n" % [
				c.color.lightened(0.3).to_html(false), slot_names[s], c.display_name, c.description]
	if def.passive != null:
		t += "\n[b]Passive[/b]\n[color=#%s]%s[/color]   [color=#bbb]%s[/color]" % [
			def.passive.color.lightened(0.3).to_html(false), def.passive.display_name, def.passive.description]
	_cards.text = t


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.anchor_top = 0.08
	_panel.anchor_bottom = 0.92
	_panel.offset_left = 40
	_panel.offset_right = 40 + 520
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.1, 0.88)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(22)
	_panel.add_theme_stylebox_override(&"panel", bg)
	add_child(_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 12)
	_panel.add_child(box)
	var title := Label.new()
	title.text = "MIRROR: choose your hero"
	title.add_theme_font_size_override(&"font_size", 15)
	title.add_theme_color_override(&"font_color", Color(0.7, 0.72, 0.78))
	box.add_child(title)
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	row.add_child(_button("<", browse.bind(-1)))
	_name = Label.new()
	_name.add_theme_font_size_override(&"font_size", 34)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_name)
	row.add_child(_button(">", browse.bind(1)))
	_count = Label.new()
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_count.add_theme_color_override(&"font_color", Color(0.6, 0.62, 0.68))
	box.add_child(_count)
	_desc = Label.new()
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_desc.add_theme_font_size_override(&"font_size", 17)
	box.add_child(_desc)
	_cards = RichTextLabel.new()
	_cards.bbcode_enabled = true
	_cards.fit_content = true
	_cards.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_cards.add_theme_font_size_override(&"normal_font_size", 15)
	_cards.add_theme_font_size_override(&"bold_font_size", 16)
	box.add_child(_cards)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	box.add_child(buttons)
	var pick := _button("Choose (F / Enter)", confirm)
	pick.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(pick)
	var back := _button("Cancel (Esc)", cancel)
	back.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(back)
	var hint := Label.new()
	hint.text = "A / D or arrows to browse"
	hint.add_theme_color_override(&"font_color", Color(0.6, 0.62, 0.68))
	box.add_child(hint)


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_NONE   # keys go to _input, not button focus
	b.add_theme_font_size_override(&"font_size", 18)
	b.pressed.connect(cb)
	return b
