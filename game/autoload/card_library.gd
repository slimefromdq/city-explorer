extends Node
## Finds every card file in game/cards/library/ and reloads them on F4 while
## the game runs. That's the fast-iteration loop: edit a card .tres in the
## Inspector, save, press F4, and the change is live on every equipped card.
##
## How it works: Godot keeps loaded resources in a cache. Reloading with
## CACHE_MODE_REPLACE_DEEP refreshes those SAME objects from disk, so every
## runner that holds the card sees the new numbers without re-equipping.

signal reloaded(count: int)

const LIBRARY_DIR := "res://game/cards/library/"


func _ready() -> void:
	# Check every card once at startup so mistakes show up in the Output panel
	# even for cards nobody has equipped yet.
	for path in card_paths():
		var c := load(path) as AbilityCard
		if c == null:
			push_error("CardLibrary: %s is not an AbilityCard" % path)
			continue
		for p in c.validate():
			push_error("Card %s: %s" % [c.label(), p])


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed(&"card_reload"):
		reload_all()


## Every card .tres in the library folder (loadouts and other resources skipped).
func card_paths() -> PackedStringArray:
	var out := PackedStringArray()
	for f in ResourceLoader.list_directory(LIBRARY_DIR):
		if f.ends_with(".tres"):
			var path := LIBRARY_DIR + f
			if _is_card(path):
				out.append(path)
	out.sort()
	return out


func all_cards() -> Array[AbilityCard]:
	var out: Array[AbilityCard] = []
	for path in card_paths():
		var c := load(path) as AbilityCard
		if c != null:
			out.append(c)
	return out


## Re-read every card file (library + anything equipped from elsewhere) and
## tell the runners. Returns how many files were reloaded.
func reload_all() -> int:
	var paths := {}
	for p in card_paths():
		paths[p] = true
	for r in get_tree().get_nodes_in_group(&"ability_runners"):
		for c in (r as AbilityRunner).cards:
			if c != null and c.resource_path != "":
				paths[c.resource_path] = true
	for p in paths:
		var c := ResourceLoader.load(p, "", ResourceLoader.CACHE_MODE_REPLACE_DEEP) as AbilityCard
		if c == null:
			push_error("CardLibrary: could not reload %s" % p)
	for r in get_tree().get_nodes_in_group(&"ability_runners"):
		(r as AbilityRunner).refresh()
	print("CardLibrary: reloaded %d card files" % paths.size())
	Events.feed.emit("Reloaded %d cards" % paths.size())
	reloaded.emit(paths.size())
	return paths.size()


func _is_card(path: String) -> bool:
	return load(path) is AbilityCard
