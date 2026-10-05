class_name Interactable
extends Node3D
## Something the player can use by facing it and pressing F (the mirror, the
## workbench, doors). It only announces itself; whatever owns it connects to
## `used` and decides what happens. The player's Interactor finds the closest
## one in range and shows the prompt.

signal used(hero: Hero)

## Shown as "F  <prompt>".
@export var prompt := "Use"
## How close (metres, from this node's position) the hero must be.
@export var radius := 1.8
@export var enabled := true


func _ready() -> void:
	add_to_group(&"interactables")


func use(hero: Hero) -> void:
	if enabled:
		used.emit(hero)
