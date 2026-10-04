extends Node
## Global signal bus. Gameplay code emits, UI/VFX/audio listen. Nothing in
## here holds state, so systems stay decoupled.

signal hit_resolved(attacker: Node3D, victim: Node3D, result: int, amount: float, pos: Vector3)
signal fighter_died(victim: Node3D, killer: Node3D)
signal popup(text: String, pos: Vector3, color: Color)
signal camera_shake(amount: float)
signal feed(text: String)
signal shard_collected(count: int, total: int)

# ---- Meridia Hero Sandbox (res://game) ----
## A hero emitted a movement event (see MoveEvent.Type). Heroes also emit this on
## their own `movement_event` signal; this global copy is for UI and debugging.
signal movement_event(hero: Node3D, type: int, data: Dictionary)
## A hero's movement/defense state machine switched state.
signal hero_state_changed(hero: Node3D, from: StringName, to: StringName)
