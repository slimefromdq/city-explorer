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


## Shared by the "free" states (Ground, Air, Crouch): start a sigil leap if one
## was pressed and is allowed. Committed states (Mantle, the leap itself) don't
## call this, so a press during them waits in the buffer.
func try_start_dash() -> bool:
	if not motor.wants_dash():
		return false
	machine.change(&"DashStartup")
	return true


## Ground-only dodge roll. Called by Ground, Crouch and Block, so a roll can
## cancel out of those. A press in the air stays buffered until you land.
func try_start_roll() -> bool:
	if not motor.wants_roll():
		return false
	machine.change(&"Roll")
	return true


## Raise the guard if block is held (Ground and Crouch call this).
func try_start_block() -> bool:
	if not hero.intent.block or not motor.on_floor:
		return false
	machine.change(&"Block")
	return true
