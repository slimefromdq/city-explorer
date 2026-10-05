class_name MoveStateMachine
extends Node
## Holds the hero's movement/defense states (its child nodes) and runs the
## active one. States are found by their node name, so the scene tree in the
## editor shows exactly which states exist.

signal state_changed(from: StringName, to: StringName)

@export var initial_state: StringName = &"Air"

var current: MoveState
var current_name: StringName = &""
var time_in_state := 0.0
var _states := {}


func setup(hero: Hero, motor: HeroMotor) -> void:
	for child in get_children():
		var s := child as MoveState
		if s == null:
			continue
		s.machine = self
		s.hero = hero
		s.motor = motor
		s.tuning = hero.tuning
		_states[StringName(child.name)] = s
	change(initial_state)


func has_state(state_name: StringName) -> bool:
	return _states.has(state_name)


func change(to: StringName, data: Dictionary = {}) -> void:
	if not _states.has(to):
		push_error("MoveStateMachine: no state named '%s' (children: %s)" % [to, _states.keys()])
		return
	var from := current_name
	if current != null:
		current.exit()
	current = _states[to]
	current_name = to
	time_in_state = 0.0
	current.enter(from, data)
	state_changed.emit(from, to)


func physics_update(dt: float) -> void:
	time_in_state += dt
	if current != null:
		current.physics_update(dt)
