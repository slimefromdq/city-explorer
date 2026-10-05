class_name CardLoadout
extends Resource
## A named set of cards for the hero's slots: Primary (LMB), Ability 1 (R),
## Ability 2 (G), Ability 3 (V). In M3 a hero will be a loadout plus a passive.

@export var display_name := "Loadout"
@export var cards: Array[AbilityCard] = [null, null, null, null]
