class_name WorkbenchMenu
extends RoomMenu
## The card workbench: your cards on the left, your current hero's 4 slots on
## the right. Drag a card onto a slot (or click a card, then click a slot).
## Drag a slot's card back to the list, or right-click the slot, to empty it.
## A card can be in one slot at a time; putting it in another slot moves it.
## Every change goes through GameState.place_card, so it's saved at once and
## each hero keeps its own loadout. Esc closes.

var _list: GridContainer
var _slots: Array[CardTile] = []
var _list_tiles: Array[CardTile] = []
var _title: Label
var _details: RichTextLabel
var _count: Label
var _held: AbilityCard


func _on_open() -> bool:
	_held = null
	return true


## Put `card` in `slot` of the current hero (null empties it).
func place(slot: int, card: AbilityCard) -> void:
	GameState.place_card(GameState.hero_id, slot, card)
	if card != null:
		Events.feed.emit("%s -> %s" % [card.display_name, CardTile.SLOT_NAMES[slot]])
	_refresh()


func clear_slot(slot: int) -> void:
	place(slot, null)


func reset_to_default() -> void:
	GameState.reset_loadout(GameState.hero_id)
	_refresh()


func drop_on_slot(tile: CardTile, data: Dictionary) -> void:
	var card := data.get("card") as AbilityCard
	var from: int = data.get("from_slot", -1)
	if from >= 0 and from != tile.slot and tile.card != null:
		# Slot to slot onto a full slot: swap the two.
		var other := tile.card
		place(tile.slot, card)
		place(from, other)
	else:
		place(tile.slot, card)


func drop_on_list(_tile: CardTile, data: Dictionary) -> void:
	var from: int = data.get("from_slot", -1)
	if from >= 0:
		clear_slot(from)


func _click(tile: CardTile, button: int) -> void:
	if tile.slot >= 0:
		if button == MOUSE_BUTTON_RIGHT:
			clear_slot(tile.slot)
		elif button == MOUSE_BUTTON_LEFT and _held != null:
			place(tile.slot, _held)
			_held = null
			_refresh()
	elif button == MOUSE_BUTTON_LEFT:
		_held = null if _held == tile.card else tile.card
		_refresh()


func _hover(card: AbilityCard) -> void:
	if card == null:
		_details.text = ""
		return
	var cost := PackedStringArray()
	if card.cooldown > 0.0:
		cost.append("%.1f s cooldown" % card.cooldown)
	if card.charges > 1:
		cost.append("%d charges" % card.charges)
	if card.energy_cost > 0.0:
		cost.append("%d energy" % int(card.energy_cost))
	_details.text = "[b][color=#%s]%s[/color][/b]   [color=#999]%s%s[/color]\n%s" % [
		card.color.lightened(0.3).to_html(false), card.display_name, CardTile.trigger_text(card),
		("   " + ", ".join(cost)) if not cost.is_empty() else "", card.description]


func _input(event: InputEvent) -> void:
	if visible and event.is_pressed() and not event.is_echo() and event.is_action(&"ui_cancel"):
		close()
		get_viewport().set_input_as_handled()


func _refresh() -> void:
	var def := GameState.current_hero()
	var cards := GameState.loadout_cards(GameState.hero_id)
	_title.text = "%s's loadout" % (def.display_name if def != null else "?")
	for i in 4:
		_slots[i].setup(cards[i], i)
		_slots[i].set_selected(false)
	for t in _list_tiles:
		_list.remove_child(t)
		t.queue_free()
	_list_tiles.clear()
	var owned := GameState.slottable_cards()
	_count.text = "Your cards (%d)" % owned.size()
	for c in owned:
		var t := CardTile.new()
		t.setup(c, -1)
		t.on_click = _click
		t.on_hover = _hover
		t.on_drop = drop_on_list
		_list.add_child(t)
		t.set_dimmed(cards.has(c))
		t.set_selected(c == _held)
		_list_tiles.append(t)


func _build() -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	panel.offset_left = 40
	panel.offset_right = -40
	panel.offset_top = 40
	panel.offset_bottom = -70
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.06, 0.07, 0.1, 0.94)
	bg.set_corner_radius_all(8)
	bg.set_content_margin_all(22)
	panel.add_theme_stylebox_override(&"panel", bg)
	add_child(panel)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override(&"separation", 28)
	panel.add_child(cols)

	# Left: the cards you own. Dropping a slot's card here empties that slot.
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.size_flags_stretch_ratio = 1.8
	cols.add_child(left)
	left.add_child(_label("CARD WORKBENCH", 15, Color(0.7, 0.72, 0.78)))
	_count = _label("", 22)
	left.add_child(_count)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(scroll)
	_list = GridContainer.new()
	_list.columns = 3
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override(&"h_separation", 10)
	_list.add_theme_constant_override(&"v_separation", 10)
	scroll.add_child(_list)

	# Right: the 4 slots, card details, buttons.
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override(&"separation", 10)
	cols.add_child(right)
	right.add_child(_label("", 15))
	_title = _label("", 22)
	right.add_child(_title)
	for i in 4:
		var t := CardTile.new()
		t.setup(null, i)
		t.on_drop = drop_on_slot
		t.on_click = _click
		t.on_hover = _hover
		t.custom_minimum_size = Vector2(260, 64)
		right.add_child(t)
		_slots.append(t)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_details.add_theme_font_size_override(&"normal_font_size", 15)
	_details.add_theme_font_size_override(&"bold_font_size", 17)
	right.add_child(_details)
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 10)
	right.add_child(buttons)
	var reset := _button("Reset to hero default", reset_to_default)
	reset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(reset)
	var done := _button("Done (Esc)", close)
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buttons.add_child(done)
	right.add_child(_label("Drag a card onto a slot, or click a card then a slot.\nRight-click a slot (or drag it back) to empty it. Saved as you go.", 14, Color(0.6, 0.62, 0.68)))
