extends Node
## Global signal bus. Gameplay code emits, UI/VFX/audio listen. Nothing in
## here holds state, so systems stay decoupled.

signal hit_resolved(attacker: Node3D, victim: Node3D, result: int, amount: float, pos: Vector3)
signal fighter_died(victim: Node3D, killer: Node3D)
signal popup(text: String, pos: Vector3, color: Color)
signal camera_shake(amount: float)
signal feed(text: String)
