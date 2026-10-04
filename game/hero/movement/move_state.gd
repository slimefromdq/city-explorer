class_name MoveState
extends Node
## Base class for one movement/defense state (Ground, Air, Crouch, Mantle...).
##
## Exactly one state is active at a time. Each state handles only its own rules
## and says which state comes next by calling `machine.change(...)`. Because only
## one state is ever in charge, a rule like "you can't cancel the dash startup"
## lives in exactly one file.

var machine: MoveStateMachine
var hero: Hero
var motor: HeroMotor
var tuning: MovementTuning


## Called when this state becomes active. `from` is the previous state's name.
func enter(_from: StringName, _data: Dictionary) -> void:
	pass


## Called when this state stops being active.
func exit() -> void:
	pass


## Called every physics tick while active.
func physics_update(_dt: float) -> void:
	pass
