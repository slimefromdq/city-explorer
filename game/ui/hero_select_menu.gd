class_name HeroSelectMenu
extends RoomMenu
## The mirror's hero picker. The view switches to the figure in the mirror,
## and browsing recolours that figure so you see each hero before you pick it.
##
## It only changes things through GameState (set_hero), so whatever the mirror
## picks is what the save file and every scene see.
## Keys: A/D or arrows browse, F/Enter choose, Esc cancel (nothing changes).

var heroes: Array[HeroDefinition] = []
var index := 0

var _name: Label
var _desc: Label
var _cards: RichTextLabel
var _count: Label


func _on_open() -> bool:
	heroes = GameState.hero_definitions()
	if heroes.is_empty():
		push_error("HeroSelectMenu: no heroes found in %s" % GameState.HERO_DIR)
		return false
	index = 0
	for i in heroes.size():
		if heroes[i].id == GameState.hero_id:
			index = i
	return true


## Pick the hero being shown: saved at once, applied to the player.
func confirm() -> void:
	var def := heroes[index]
	GameState.set_hero(def.id)
	GameState.dress(hero)
	Events.feed.emit("You are now %s" % def.display_name)
	close()


## Leave without changing anything; the mirror goes back to the current hero.
func cancel() -> void:
	var cur := GameState.current_hero()
	if figure != null and cur != null:
		figure.set_colors(cur.body_color, cur.accent_color)
	close()


func browse(step: int) -> void:
	index = wrapi(index + step, 0, heroes.size())
	_refresh()


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


func _refresh() -> void:
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
	var box := _side_panel(520)
	box.add_child(_label("MIRROR: choose your hero", 15, Color(0.7, 0.72, 0.78)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override(&"separation", 10)
	box.add_child(row)
	row.add_child(_button("<", browse.bind(-1)))
	_name = _label("", 34)
	_name.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	row.add_child(_name)
	row.add_child(_button(">", browse.bind(1)))
	_count = _label("", 16, Color(0.6, 0.62, 0.68))
	_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_count)
	_desc = _label("", 17)
	_desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
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
	box.add_child(_label("A / D or arrows to browse", 16, Color(0.6, 0.62, 0.68)))
