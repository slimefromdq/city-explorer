extends Node
## Headless checks for M3a: the three heroes and their cards, GameState and
## the save file (round trip, broken file, unknown cards), the apartment
## (saved hero applied, cards locked, mirror hero select) and the hero
## passives' conditions.
##   godot --headless --fixed-fps 60 res://game/tests/m3a_heroes_save_test.tscn
## Uses its own save file (user://m3a_test_save.json), never your real save.
## The broken-save and unknown-card checks are SUPPOSED to print errors/warnings.

const APARTMENT := preload("res://game/levels/apartment/apartment.tscn")
const ARENA := preload("res://game/levels/test_arena/test_arena.tscn")
const TEST_SAVE := "user://m3a_test_save.json"

var passed := 0
var failed := 0
var hero: Hero
var level: Node3D


func _ready() -> void:
	SaveService.path = TEST_SAVE
	_delete(TEST_SAVE)
	_delete(TEST_SAVE + ".broken")
	GameState.reset_to_defaults()
	await _frames(2)
	_heroes()
	await _save_roundtrip()
	await _apartment()
	await _persistence()
	await _passives()
	await _hero_cards()
	_delete(TEST_SAVE)
	_delete(TEST_SAVE + ".broken")
	print("\n%d passed, %d failed" % [passed, failed])
	get_tree().quit(1 if failed > 0 else 0)


func _heroes() -> void:
	print("heroes")
	var defs := GameState.hero_definitions()
	var ids := []
	for d in defs:
		ids.append(String(d.id))
		_check(d.validate().is_empty(), "%s validates (incl. a movement-event card) %s" % [d.display_name, str(d.validate())])
	ids.sort()
	_check(ids == ["butcher", "engineer", "sky_runner"], "three heroes: %s" % str(ids))
	var bad := PackedStringArray()
	for c in CardLibrary.all_cards():
		for p in (c as AbilityCard).validate():
			bad.append("%s: %s" % [c.display_name, p])
	_check(bad.is_empty(), "all %d library cards validate %s" % [CardLibrary.all_cards().size(), str(bad)])


func _save_roundtrip() -> void:
	print("save / load")
	_check(GameState.hero_id == &"sky_runner", "a new save starts as Sky Runner")
	_check(GameState.owned_cards.size() == CardLibrary.all_cards().size(), "a new save owns every card (%d)" % GameState.owned_cards.size())
	_check(_names(GameState.loadout_cards(&"butcher")) == ["Cleaver", "Meat Hook", "Ball Kick", "Riposte"], "Butcher starts with his own loadout")

	GameState.set_hero(&"engineer")
	GameState.set_loadout_slot(&"engineer", 1, GameState.card_by_id("blink"))
	GameState.set_outfit_part("head", "cap")
	GameState.discover_entrance("sewer_01")
	await _frames(2)   # the save is written once, at the end of the frame
	_check(FileAccess.file_exists(TEST_SAVE), "changing something writes the save file")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_check(data is Dictionary and data.get("hero") == "engineer", "the file says hero = engineer")
	_check(data is Dictionary and str(data.get("loadouts", {}).get("engineer", [])) == str(["rivet_gun", "blink", "ember_bomb", "drop_charge"]),
			"the file has Engineer's edited loadout (Blink in slot R)")

	GameState.reset_to_defaults()
	_check(GameState.hero_id == &"sky_runner" and GameState.outfit.is_empty(), "(state wiped in memory)")
	_check(SaveService.load_game(), "load_game finds the file")
	_check(GameState.hero_id == &"engineer", "hero restored")
	_check(_names(GameState.loadout_cards(&"engineer")) == ["Rivet Gun", "Blink", "Ember Bomb", "Drop Charge"], "loadout restored")
	_check(GameState.outfit.get("head") == "cap", "outfit restored")
	_check(GameState.discovered_entrances.has("sewer_01"), "discovered entrance restored")
	_check(_names(GameState.loadout_cards(&"sky_runner")) == ["Pulse Pistol", "Blink", "Rocket Jump", "Sigil Barrage"], "other heroes' loadouts untouched")

	var d2 := GameState.to_dict()
	d2["loadouts"]["butcher"] = ["cleaver", "no_such_card", "ball_kick", "riposte"]
	d2["owned_cards"].append("no_such_card")
	GameState.from_dict(d2)
	_check(GameState.loadouts["butcher"][1] == "" and not GameState.owned_cards.has("no_such_card"), "an unknown card in a save is dropped, not a crash")

	var f := FileAccess.open(TEST_SAVE, FileAccess.WRITE)
	f.store_string("{ this is not json")
	f.close()
	_check(not SaveService.load_game(), "a broken save is rejected")
	_check(FileAccess.file_exists(TEST_SAVE + ".broken") and GameState.hero_id == &"sky_runner", "the broken file is kept as .broken and the game starts fresh")

	# Leave a known save behind for the apartment checks: Butcher, default cards.
	GameState.reset_to_defaults()
	GameState.set_hero(&"butcher")
	await _frames(2)


func _apartment() -> void:
	print("apartment")
	_load(APARTMENT)
	await _frames(3)
	_check(hero.definition != null and hero.definition.id == &"butcher", "you start as the saved hero (Butcher)")
	_check(_names(hero.runner.cards) == ["Cleaver", "Meat Hook", "Ball Kick", "Riposte"], "with that hero's saved loadout")
	_check(hero.runner.passive != null and hero.runner.passive.display_name == "Bloodlust", "and its passive")
	_check(hero.runner.locked and not hero.runner.try_cast(0), "cards are locked indoors")

	# Walk-up check: stand in front of the mirror and face it.
	hero.global_position = Vector3(3.6, 0.05, -1.0)
	hero.velocity = Vector3.ZERO
	hero.reset_physics_interpolation()
	hero.intent.aim_yaw = -PI * 0.5   # facing +x
	await _frames(3)
	_check(hero.interactor.current != null and hero.interactor.current.name == "Mirror", "facing the mirror shows its prompt (%s)" % str(hero.interactor.current))
	hero.intent.aim_yaw = PI * 0.5    # back turned
	await _frames(2)
	_check(hero.interactor.current == null, "no prompt with your back to it")

	hero.intent.aim_yaw = -PI * 0.5
	await _frames(2)
	hero.intent.interact_pressed = true
	await _frames(2)
	var menu := level.get_node("HeroSelectMenu") as HeroSelectMenu
	var figure := level.get_node("MirrorAlcove/MirrorFigure") as HeroModel
	_check(menu.is_open(), "pressing F at the mirror opens hero select")
	_check(get_viewport().get_camera_3d() == level.get_node("MirrorAlcove/MirrorCamera"), "the view switches to the mirror")
	_check(not (hero.get_node("PlayerInput") as HeroPlayerInput).enabled and not hero.model.visible, "the player is frozen and hidden while it's open")
	_check(menu.heroes[menu.index].id == &"butcher", "it opens on the current hero")

	menu.browse(1)
	var shown := menu.heroes[menu.index]
	_check(shown.id != &"butcher" and figure.body_color == shown.body_color, "browsing recolours the figure in the mirror (%s)" % shown.display_name)
	_check(GameState.hero_id == &"butcher", "browsing alone changes nothing")
	_send_action(&"ui_cancel")
	await _frames(2)
	_check(not menu.is_open(), "(Esc reached the menu)")
	if menu.is_open():
		menu.cancel()
	_check(not menu.is_open() and GameState.hero_id == &"butcher", "Esc closes it with nothing changed")
	_check(figure.body_color == hero.definition.body_color, "the figure goes back to your hero's colours")
	_check((hero.get_node("PlayerInput") as HeroPlayerInput).enabled and hero.model.visible, "you can move again")
	_check(get_viewport().get_camera_3d() != level.get_node("MirrorAlcove/MirrorCamera"), "the view returns to your camera")

	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false
	hero.intent.aim_yaw = -PI * 0.5   # the re-enabled input turned us toward the camera
	await _frames(2)
	hero.intent.interact_pressed = true
	await _frames(2)
	for k in 3:
		if menu.heroes[menu.index].id == &"sky_runner":
			break
		_send_action(&"ui_right")
		await _frames(1)
	_check(menu.heroes[menu.index].id == &"sky_runner", "arrow keys browse to Sky Runner")
	_send_action(&"ui_accept")
	await _frames(2)
	_check(not menu.is_open() and GameState.hero_id == &"sky_runner", "Enter picks Sky Runner")
	_check(hero.definition.id == &"sky_runner" and _names(hero.runner.cards) == ["Pulse Pistol", "Blink", "Rocket Jump", "Sigil Barrage"], "you become Sky Runner with his cards")
	_check(hero.runner.passive != null and hero.runner.passive.display_name == "Tailwind", "and his passive")
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(TEST_SAVE))
	_check(data is Dictionary and data.get("hero") == "sky_runner", "the pick is saved right away")


func _persistence() -> void:
	print("quit and reload")
	GameState.set_loadout_slot(&"sky_runner", 2, GameState.card_by_id("ember_bomb"))
	await _frames(2)
	_unload()
	GameState.reset_to_defaults()   # like quitting: memory is gone, only the file remains
	SaveService.load_game()
	_load(APARTMENT)
	await _frames(3)
	_check(hero.definition.id == &"sky_runner", "after a reload you're still Sky Runner")
	_check(_names(hero.runner.cards) == ["Pulse Pistol", "Blink", "Ember Bomb", "Sigil Barrage"], "and your edited loadout came back")


func _passives() -> void:
	print("passives (conditional modifiers)")
	var r := hero.runner
	_check(is_equal_approx(r.stat_mult(ModifierEffect.Stat.DAMAGE), 1.0), "Tailwind: no bonus on the ground")
	hero.global_position.y = 2.0
	hero.reset_physics_interpolation()
	await _frames(2)
	_check(not hero.motor.on_floor and is_equal_approx(r.stat_mult(ModifierEffect.Stat.DAMAGE), 1.3), "Tailwind: +30%% damage in the air (x%.2f)" % r.stat_mult(ModifierEffect.Stat.DAMAGE))
	await _wait_until(func() -> bool: return hero.motor.on_floor, 120)

	hero.apply_definition(GameState.hero_definition(&"butcher"), GameState.loadout_cards(&"butcher"))
	_check(is_equal_approx(r.stat_mult(ModifierEffect.Stat.DAMAGE), 1.0), "Bloodlust: no bonus at full health")
	hero.defense.health = hero.tuning.max_health * 0.4
	_check(is_equal_approx(r.stat_mult(ModifierEffect.Stat.DAMAGE), 1.35), "Bloodlust: +35% below half health")
	hero.defense.health = hero.tuning.max_health

	hero.apply_definition(GameState.hero_definition(&"engineer"), GameState.loadout_cards(&"engineer"))
	_check(is_equal_approx(r.stat_mult(ModifierEffect.Stat.COOLDOWN_SPEED), 1.2) and is_equal_approx(r.stat_add(ModifierEffect.Stat.EXTRA_BOUNCES), 1.0),
			"Tinkerer: cooldowns x1.2 and +1 bounce")
	_check(is_equal_approx(r.stat_mult(ModifierEffect.Stat.DAMAGE), 1.0), "(Bloodlust is gone after switching)")


func _hero_cards() -> void:
	print("the new hero cards, in the arena")
	_unload()
	GameState.reset_to_defaults()
	_load(ARENA)
	for d in level.get_node("TargetDummies").get_children():
		d.set(&"active", false)
	await _frames(3)
	var near := level.get_node("TargetDummies/Near") as TargetDummy
	var r := hero.runner

	# Butcher: Cleaver (slot 0), Meat Hook (slot 1)
	level.call(&"_equip_loadout", (level.get(&"loadouts") as Array).size())
	GameState.set_hero(&"butcher")
	level.call(&"_equip_loadout", (level.get(&"loadouts") as Array).size())
	_check(hero.definition.id == &"butcher" and r.passive.display_name == "Bloodlust", "Tab's last entry is your saved hero (Butcher)")
	await _stand(Vector3(30, 0.05, 43.6), near)
	near.reset()
	hero.intent.card_held[0] = true
	hero.intent.card_pressed[0] = true
	await _wait_until(func() -> bool: return near.hits_taken > 0, 20)
	hero.intent.card_held[0] = false
	_check(near.hits_taken == 1, "Cleaver hits the dummy in front of you (%.0f damage)" % near.total_damage)

	await _stand(Vector3(30, 0.05, 49.0), near)
	near.reset()
	var z0 := near.global_position.z
	hero.intent.card_pressed[1] = true
	await _wait_until(func() -> bool: return near.hits_taken > 0, 40)
	await _frames(15)
	_check(near.hits_taken >= 1, "Meat Hook hits at range (%.0f damage)" % near.total_damage)
	_check(near.global_position.z > z0 + 0.5, "and drags the dummy toward you (moved %.1f m)" % (near.global_position.z - z0))

	# Engineer: Rivet Gun (slot 0, hold), Drop Charge on roll
	GameState.set_hero(&"engineer")
	level.call(&"_equip_loadout", (level.get(&"loadouts") as Array).size())
	await _stand(Vector3(30, 0.05, 47.0), near)
	near.reset()
	hero.intent.card_held[0] = true
	hero.intent.card_pressed[0] = true
	await _wait_until(func() -> bool: return near.hits_taken > 0, 60)
	hero.intent.card_held[0] = false
	_check(near.hits_taken > 0, "Rivet Gun hits (%d rivets so far)" % near.hits_taken)
	var casts := [0]
	var count := func(card: AbilityCard, _s: int, _d: int) -> void:
		if card.display_name == "Drop Charge":
			casts[0] += 1
	r.card_cast.connect(count)
	await _frames(10)
	hero.intent.roll_pressed = true
	await _wait_until(func() -> bool: return casts[0] > 0, 20)
	_check(casts[0] == 1, "rolling drops a Drop Charge (OnRoll)")
	r.card_cast.disconnect(count)

	# Sky Runner: Sigil Barrage when the sigil forms
	GameState.set_hero(&"sky_runner")
	level.call(&"_equip_loadout", (level.get(&"loadouts") as Array).size())
	await _stand(Vector3(30, 0.05, 47.0), near)
	var barrage := [0]
	var count2 := func(card: AbilityCard, _s: int, _d: int) -> void:
		if card.display_name == "Sigil Barrage":
			barrage[0] += 1
	r.card_cast.connect(count2)
	hero.intent.dash_pressed = true
	await _wait_until(func() -> bool: return barrage[0] > 0, 60)
	_check(barrage[0] == 1, "a real sigil leap fires Sigil Barrage (OnSigilFormed)")
	r.card_cast.disconnect(count2)

	level.call(&"_equip_loadout", 0)
	_check(r.passive == null, "switching back to a test loadout drops the hero passive")


# ------------------------------------------------------------------ helpers

func _load(scene: PackedScene) -> void:
	level = scene.instantiate()
	add_child(level)
	hero = level.get_node("PlayerHero")
	(hero.get_node("PlayerInput") as HeroPlayerInput).enabled = false


func _unload() -> void:
	level.free()
	level = null
	hero = null


func _stand(pos: Vector3, look_at: Node3D) -> void:
	var i := hero.intent
	i.move = Vector2.ZERO
	for s in 4:
		i.card_held[s] = false
	hero.global_position = pos
	hero.velocity = Vector3.ZERO
	hero.motor.reset()
	hero.states.change(&"Air")
	hero.reset_physics_interpolation()
	await _wait_until(func() -> bool: return hero.states.current_name == &"Ground", 60)
	var target := look_at.global_position + Vector3.UP * 1.2
	var eye := hero.global_position + Vector3.UP * 1.55
	var d := (target - eye).normalized()
	i.aim_point = target
	i.aim_dir = d
	i.aim_yaw = atan2(-d.x, -d.z)
	await _frames(20)   # turn to face it


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


func _wait_until(cond: Callable, max_frames: int) -> void:
	for i in max_frames:
		if cond.call():
			return
		await get_tree().physics_frame


func _check(ok: bool, what: String) -> void:
	if ok:
		passed += 1
		print("  ok   ", what)
	else:
		failed += 1
		print("  FAIL ", what)
