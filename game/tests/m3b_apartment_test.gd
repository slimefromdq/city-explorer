extends Node
## Headless checks for M3b: the card workbench (drag and drop, click to place,
## moving and swapping, emptying, reset, per-hero loadouts), the wardrobe
## (outfit parts and tint on the player and the mirror figure), the front
## door to the arena and back, and the full "save, quit, reload, everything
## is remembered" check from the M3 spec.
##   godot --headless --fixed-fps 60 res://game/tests/m3b_apartment_test.tscn
## Uses its own save file (user://m3b_test_save.json), never your real save.

const APARTMENT := "res://game/levels/apartment/apartment.tscn"
const TEST_SAVE := "user://m3b_test_save.json"

var passed := 0
var failed := 0
var hero: Hero
var level: Node3D


func _ready() -> void:
	SaveService.path = TEST_SAVE
	_delete(TEST_SAVE)
	GameState.reset_to_defaults()
	SceneRouter.changer = _change_scene
	await _frames(2)
	_load(APARTMENT)
	await _frames(3)
	await _workbench()
	await _wardrobe()
	await _front_door()
	await _quit_and_reload()
	SceneRouter.changer = Callable()
	_delete(TEST_SAVE)
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _workbench() -> void:
	print("card workbench")
	var wb := level.get_node("WorkbenchMenu") as WorkbenchMenu
	await _use_from(Vector3(-2.8, 0.05, 1.4), PI * 0.5)
	_check(wb.is_open(), "F at the workbench opens it")
	_check(not (hero.get_node("PlayerInput") as HeroPlayerInput).enabled, "the player is frozen while it's open")
	var names := []
	for t in wb._list_tiles:
		names.append(t.card.display_name)
	_check(names.size() == GameState.slottable_cards().size() and names.size() >= 15, "your cards are listed (%d)" % names.size())
	_check(not names.has("Shrapnel") and not names.has("Tailwind"), "proc-only cards and hero passives aren't offered")
	_check(_names(wb._slots.map(func(t: CardTile) -> AbilityCard: return t.card)) == ["Pulse Pistol", "Blink", "Rocket Jump", "Sigil Barrage"], "the slots show Sky Runner's loadout")

	var ember := GameState.card_by_id("ember_bomb")
	var slot_g := wb._slots[2]
	var drag := {"card": ember, "from_slot": -1}
	_check(slot_g._can_drop_data(Vector2.ZERO, drag), "a slot accepts a dragged card")
	slot_g._drop_data(Vector2.ZERO, drag)
	await _frames(1)
	_check(_ids(&"sky_runner")[2] == "ember_bomb", "dropping Ember Bomb on G puts it there (saved state)")
	_check(hero.runner.cards[2] != null and hero.runner.cards[2].display_name == "Ember Bomb", "and the hero has it equipped right away")
	_check(wb._list_tiles.filter(func(t: CardTile) -> bool: return t.card == ember)[0]._dimmed, "the list marks it as equipped")

	# Same card into another slot moves it (one copy per loadout).
	wb._slots[3]._drop_data(Vector2.ZERO, {"card": ember, "from_slot": -1})
	_check(_ids(&"sky_runner")[2] == "" and _ids(&"sky_runner")[3] == "ember_bomb", "putting it in V moves it out of G")
	# Slot onto a full slot swaps.
	wb._slots[3]._drop_data(Vector2.ZERO, {"card": GameState.card_by_id("blink"), "from_slot": 1})
	_check(_ids(&"sky_runner")[1] == "ember_bomb" and _ids(&"sky_runner")[3] == "blink", "dragging R onto V swaps them")
	# Slot back onto the list empties it.
	wb._list_tiles[0]._drop_data(Vector2.ZERO, {"card": GameState.card_by_id("blink"), "from_slot": 3})
	_check(_ids(&"sky_runner")[3] == "", "dragging a slot's card back to the list empties the slot")
	# Click a card, then click a slot.
	var kick_tile: CardTile = wb._list_tiles.filter(func(t: CardTile) -> bool: return t.card.display_name == "Ball Kick")[0]
	wb._click(kick_tile, MOUSE_BUTTON_LEFT)
	wb._click(wb._slots[3], MOUSE_BUTTON_LEFT)
	_check(_ids(&"sky_runner")[3] == "ball_kick", "click a card, then a slot, also places it")
	wb._click(wb._slots[3], MOUSE_BUTTON_RIGHT)
	_check(_ids(&"sky_runner")[3] == "", "right-clicking a slot empties it")
	wb.reset_to_default()
	_check(_ids(&"sky_runner") == ["pulse_pistol", "blink", "rocket_jump", "sigil_barrage"], "reset puts the hero's starting cards back")

	# The loadout we'll check survives a reload: Ember Bomb in G, V empty.
	wb.place(2, ember)
	wb.place(3, null)
	_send_action(&"ui_cancel")
	await _frames(2)
	_check(not wb.is_open() and (hero.get_node("PlayerInput") as HeroPlayerInput).enabled, "Esc closes the workbench")
	_check(_ids(&"butcher") == ["cleaver", "meat_hook", "ball_kick", "riposte"], "other heroes' loadouts are untouched")
	_check(hero.runner.locked, "cards are still locked indoors after editing")


func _wardrobe() -> void:
	print("wardrobe")
	var wr := level.get_node("WardrobeMenu") as WardrobeMenu
	var figure := level.get_node("MirrorAlcove/MirrorFigure") as HeroModel
	await _use_from(Vector3(2.9, 0.05, 1.1), -PI * 0.5)
	_check(wr.is_open(), "F at the wardrobe opens it")
	_check(get_viewport().get_camera_3d() == level.get_node("MirrorAlcove/MirrorCamera"), "the view switches to the mirror")
	_check(_outfit_meshes(hero.model) == 0, "a new save wears nothing extra")
	wr.cycle(0, 1)
	var head := str(GameState.outfit.get("head", ""))
	_check(head != "" and OutfitCatalog.part_by_id(head) != null, "the head row picks a part (%s)" % head)
	await _frames(1)
	_check(_outfit_meshes(figure) > 0 and _outfit_meshes(hero.model) == _outfit_meshes(figure), "the figure in the mirror and your own model both wear it")
	wr.cycle(0, -1)
	_check(str(GameState.outfit.get("head", "x")) == "", "stepping back gets to 'nothing'")
	GameState.set_outfit_part("head", "head_helmet")
	wr._apply()
	_check(not figure._visor.visible, "the visor helmet hides the default visor")
	wr.cycle(1, 1)
	wr.cycle(2, 2)
	wr.pick_tint("d9483b")
	await _frames(1)
	_check(GameState.outfit.get("tint") == "d9483b", "picking a swatch sets the tint")
	var tinted := false
	for m in figure.find_child("Outfit", true, false).get_children():
		var mat := (m as MeshInstance3D).material_override as StandardMaterial3D
		tinted = tinted or mat.albedo_color.is_equal_approx(Color.html("d9483b"))
	_check(tinted, "the outfit takes the tint colour")
	_send_action(&"ui_cancel")
	await _frames(2)
	_check(not wr.is_open() and hero.model.visible, "Esc closes the wardrobe")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_check(data is Dictionary and (data["outfit"] as Dictionary).get("head") == "head_helmet", "the outfit is in the save file")
	GameState.discover_entrance("test_entrance")   # M4 fills these in; checked after the reload


func _front_door() -> void:
	print("front door")
	var outfit := GameState.outfit.duplicate()
	await _use_from(Vector3(1.6, 0.05, 2.4), PI)
	await _frames(3)
	_check(level.name == "TestArena", "the front door takes you to the test arena")
	_check(hero.global_position.distance_to(level.get_node("FromApartment").global_position) < 0.5, "you arrive at the door in the arena")
	_check(hero.definition != null and hero.definition.id == &"sky_runner", "as your hero")
	_check(_names(hero.runner.cards) == ["Pulse Pistol", "Blink", "Ember Bomb", ""], "with your edited loadout")
	_check(hero.runner.passive != null and hero.runner.passive.display_name == "Tailwind", "and its passive")
	_check(not hero.runner.locked, "cards work out here")
	_check(_outfit_meshes(hero.model) > 0 and GameState.outfit == outfit, "still wearing your outfit")
	await _use_from(Vector3(-2.4, 0.05, 6.0), PI * 0.5)
	await _frames(3)
	_check(level.name == "Apartment", "the arena's door brings you back")
	_check(hero.global_position.distance_to(level.get_node("FrontDoorSpawn").global_position) < 0.5, "arriving just inside the front door")


func _quit_and_reload() -> void:
	print("save, quit, reload")
	GameState.set_hero(&"engineer")
	GameState.place_card(&"engineer", 0, GameState.card_by_id("pulse_pistol"))
	await _frames(2)
	var before := GameState.to_dict()
	_unload()
	GameState.reset_to_defaults()   # quitting: memory is gone, only the file is left
	_check(GameState.hero_id == &"sky_runner" and GameState.outfit.is_empty(), "(memory wiped)")
	_check(SaveService.load_game(), "the save file loads")
	_check(JSON.stringify(GameState.to_dict()) == JSON.stringify(before), "everything in it matches what was saved")
	_load(APARTMENT)
	await _frames(3)
	_check(hero.definition.id == &"engineer", "hero remembered (Engineer)")
	_check(_names(hero.runner.cards) == ["Pulse Pistol", "Bug Grenade", "Ember Bomb", "Drop Charge"], "Engineer's loadout remembered")
	_check(_names(GameState.loadout_cards(&"sky_runner")) == ["Pulse Pistol", "Blink", "Ember Bomb", ""], "Sky Runner's loadout remembered too")
	_check(GameState.outfit.get("head") == "head_helmet" and GameState.outfit.get("tint") == "d9483b" and _outfit_meshes(hero.model) > 0, "outfit remembered and worn")
	_check(GameState.owned_cards.size() == CardLibrary.all_cards().size(), "owned cards remembered")
	_check(GameState.discovered_entrances.has("test_entrance"), "discovered entrances remembered")


# ------------------------------------------------------------------ helpers

## Stand at `pos` facing `yaw` and press F.
func _use_from(pos: Vector3, yaw: float) -> void:
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	hero.intent.aim_yaw = yaw
	await _frames(4)
	hero.intent.interact_pressed = true
	await _frames(3)


func _change_scene(path: String) -> void:
	_unload.call_deferred()
	_load.call_deferred(path)


func _load(path: String) -> void:
	level = (load(path) as PackedScene).instantiate()
	add_child(level)
	hero = level.get_node("PlayerHero")
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false


func _unload() -> void:
	if level != null:
		level.free()
	level = null
	hero = null


func _ids(id: StringName) -> Array:
	return GameState.loadouts.get(String(id), [])


func _outfit_meshes(m: HeroModel) -> int:
	var root := m.find_child("Outfit", true, false)
	return root.get_child_count() if root != null else -1


func _send_action(action: StringName) -> void:
	var e := InputEventAction.new()
	e.action = action
	e.pressed = true
	Input.parse_input_event(e)
	Input.flush_buffered_events()


func _names(cards: Array) -> Array:
	var out := []
	for c in cards:
		out.append((c as AbilityCard).display_name if c != null else "")
	return out


func _delete(p: String) -> void:
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("  ok   ", what)
	else:
		failed += 1
		print("  FAIL ", what)
