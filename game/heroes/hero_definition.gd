class_name HeroDefinition
extends Resource
## A hero is ONLY this: a name, colours, a starting loadout of 4 cards and a
## passive. Every hero shares the same body, movement and defense; who you
## are comes from your cards. Heroes live in game/heroes/*.tres.

## Stable id used in save files. Don't change it once players have saves.
@export var id: StringName = &"hero"
@export var display_name := "Hero"
@export_multiline var description := ""
@export var body_color := Color(0.22, 0.32, 0.55)
@export var accent_color := Color(1.0, 0.62, 0.25)
## Primary, Ability 1, Ability 2, Ability 3. This is the loadout a new save
## starts with; after that the workbench edits the player's own copy.
@export var starting_cards: Array[AbilityCard] = [null, null, null, null]
## A PASSIVE card (Modifier blocks), always on for this hero.
@export var passive: AbilityCard


func validate() -> PackedStringArray:
	var p := PackedStringArray()
	if id == &"" or id == &"hero":
		p.append("needs a unique id")
	if starting_cards.size() != 4:
		p.append("starting_cards should have exactly 4 entries (got %d)" % starting_cards.size())
	if passive != null and passive.trigger != AbilityCard.Trigger.PASSIVE:
		p.append("passive '%s' doesn't have the PASSIVE trigger" % passive.display_name)
	var has_event := false
	for c in starting_cards:
		if c != null and c.trigger == AbilityCard.Trigger.MOVEMENT_EVENT:
			has_event = true
	if not has_event:
		p.append("has no card that listens to a movement event")
	return p
