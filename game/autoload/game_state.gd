extends Node
## Everything the game remembers between scenes and sessions, as plain data:
## which hero you are, each hero's loadout, which cards you own, your outfit,
## and the underground entrances you've found. Scenes READ this when they load
## and call the setters when you change something; they never keep their own
## copy. SaveService writes it to disk whenever `changed` fires.
##
## Cards and heroes are stored by id (their file name without .tres), never as
## resources, so the save file is plain JSON that can't carry scripts.

signal changed

const HERO_DIR := "res://game/heroes/"
const CARD_DIR := "res://game/cards/library/"
const DEFAULT_HERO := &"sky_runner"

var hero_id: StringName = DEFAULT_HERO
## hero id -> Array of 4 card ids ("" = empty slot)
var loadouts := {}
var owned_cards: PackedStringArray = []
## slot name -> part id, plus "tint" -> Color html string (filled in by M3b)
var outfit := {}
var discovered_entrances: PackedStringArray = []


func _ready() -> void:
	reset_to_defaults()


## A brand-new save: own every card in the library, default hero, each hero's
## starting loadout.
func reset_to_defaults() -> void:
	hero_id = DEFAULT_HERO
	owned_cards = PackedStringArray()
	for path in _list(CARD_DIR):
		owned_cards.append(path.get_file().get_basename())
	loadouts = {}
	for def in hero_definitions():
		loadouts[String(def.id)] = _ids_of(def.starting_cards)
	outfit = {}
	discovered_entrances = PackedStringArray()


# ------------------------------------------------------------------ lookups

func hero_definitions() -> Array[HeroDefinition]:
	var out: Array[HeroDefinition] = []
	for path in _list(HERO_DIR):
		var h := load(path) as HeroDefinition
		if h != null:
			out.append(h)
	return out


func hero_definition(id: StringName) -> HeroDefinition:
	for h in hero_definitions():
		if h.id == id:
			return h
	push_error("GameState: no hero with id '%s' in %s" % [id, HERO_DIR])
	return null


func current_hero() -> HeroDefinition:
	var h := hero_definition(hero_id)
	return h if h != null else hero_definition(DEFAULT_HERO)


func card_by_id(id: String) -> AbilityCard:
	if id == "":
		return null
	var path := CARD_DIR + id + ".tres"
	if not ResourceLoader.exists(path):
		push_error("GameState: card '%s' not found (%s)" % [id, path])
		return null
	return load(path) as AbilityCard


func card_id(card: AbilityCard) -> String:
	return card.resource_path.get_file().get_basename() if card != null else ""


## The cards the given hero has equipped (4 entries, null = empty).
func loadout_cards(id: StringName) -> Array[AbilityCard]:
	var ids: Array = loadouts.get(String(id), [])
	if ids.is_empty():
		var def := hero_definition(id)
		if def != null:
			ids = _ids_of(def.starting_cards)
	var out: Array[AbilityCard] = []
	for i in 4:
		out.append(card_by_id(ids[i]) if i < ids.size() else null)
	return out


# ------------------------------------------------------------------ setters

func set_hero(id: StringName) -> void:
	if hero_definition(id) == null:
		return
	hero_id = id
	changed.emit()


func set_loadout_slot(id: StringName, slot: int, card: AbilityCard) -> void:
	var ids: Array = loadouts.get(String(id), _ids_of(hero_definition(id).starting_cards)).duplicate()
	while ids.size() < 4:
		ids.append("")
	ids[slot] = card_id(card)
	loadouts[String(id)] = ids
	changed.emit()


## Put `card` in `slot` of hero `id`'s loadout. A card can only be in one
## slot, so if it's already in another slot it moves (that slot empties).
## `card` = null empties the slot.
func place_card(id: StringName, slot: int, card: AbilityCard) -> void:
	var ids: Array = loadouts.get(String(id), []).duplicate()
	if ids.is_empty():
		ids = _ids_of(hero_definition(id).starting_cards)
	while ids.size() < 4:
		ids.append("")
	var cid := card_id(card)
	for i in ids.size():
		if cid != "" and ids[i] == cid:
			ids[i] = ""
	ids[slot] = cid
	loadouts[String(id)] = ids
	changed.emit()


## Back to the hero's starting loadout.
func reset_loadout(id: StringName) -> void:
	var def := hero_definition(id)
	if def != null:
		loadouts[String(id)] = _ids_of(def.starting_cards)
		changed.emit()


## Cards that can go in a slot at the workbench: owned, not proc-only (those
## only fire from other cards), and not a hero's built-in passive.
func slottable_cards() -> Array[AbilityCard]:
	var passives := []
	for h in hero_definitions():
		if h.passive != null:
			passives.append(card_id(h.passive))
	var out: Array[AbilityCard] = []
	for id in owned_cards:
		var c := card_by_id(id)
		if c != null and c.trigger != AbilityCard.Trigger.PROC_ONLY and not passives.has(id):
			out.append(c)
	return out


## Make `hero` look and play like the saved state: hero, loadout, outfit.
func dress(hero: Hero) -> void:
	var def := current_hero()
	if def == null:
		push_error("GameState: no hero definitions in %s" % HERO_DIR)
		return
	hero.apply_definition(def, loadout_cards(def.id))
	hero.model.apply_outfit(outfit)


## slot is "head", "top", "bottom" (a part id, "" = nothing) or "tint" (an
## html colour, "" = the hero's own accent colour).
func set_outfit_part(slot: String, value: String) -> void:
	outfit[slot] = value
	changed.emit()


func discover_entrance(id: String) -> void:
	if not discovered_entrances.has(id):
		discovered_entrances.append(id)
		changed.emit()


# ------------------------------------------------------------------ save data

func to_dict() -> Dictionary:
	return {
		"version": 1,
		"hero": String(hero_id),
		"loadouts": loadouts.duplicate(true),
		"owned_cards": Array(owned_cards),
		"outfit": outfit.duplicate(),
		"discovered_entrances": Array(discovered_entrances),
	}


## Load from a save dictionary. Unknown heroes/cards are dropped with a
## warning instead of breaking the game (e.g. a card file was renamed).
func from_dict(d: Dictionary) -> void:
	reset_to_defaults()
	var h := StringName(str(d.get("hero", DEFAULT_HERO)))
	hero_id = h if _hero_exists(h) else DEFAULT_HERO
	var owned := PackedStringArray()
	for id in d.get("owned_cards", []):
		if ResourceLoader.exists(CARD_DIR + str(id) + ".tres"):
			owned.append(str(id))
		else:
			push_warning("Save: dropping unknown card '%s'" % id)
	if not owned.is_empty():
		owned_cards = owned
	var lo: Dictionary = d.get("loadouts", {})
	for hid in lo:
		var ids: Array = []
		for id in lo[hid]:
			ids.append(str(id) if str(id) == "" or ResourceLoader.exists(CARD_DIR + str(id) + ".tres") else "")
		loadouts[str(hid)] = ids
	outfit = {}
	var o: Dictionary = d.get("outfit", {})
	for key in o:
		var v := str(o[key])
		if key == "tint" or v == "" or ResourceLoader.exists(OutfitCatalog.PARTS_DIR + v + ".tres"):
			outfit[str(key)] = v
		else:
			push_warning("Save: dropping unknown outfit part '%s'" % v)
	discovered_entrances = PackedStringArray(d.get("discovered_entrances", []))


func _hero_exists(id: StringName) -> bool:
	for h in hero_definitions():
		if h.id == id:
			return true
	return false


func _ids_of(cards: Array) -> Array:
	var ids: Array = []
	for c in cards:
		ids.append(card_id(c))
	return ids


func _list(dir: String) -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(dir):
		if f.ends_with(".tres"):
			out.append(dir + f)
	out.sort()
	return out
