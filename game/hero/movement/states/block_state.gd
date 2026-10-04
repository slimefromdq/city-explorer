extends MoveState
## Holding block: the guard faces where you aim, you move slowly, and hits from
## the front arc are reduced (see HeroDefense). The first perfect_block_window
## seconds are a PERFECT block. Roll and the sigil leap can cancel out of it;
## letting go or leaving the ground lowers it.
##
## Event: OnBlockStart on entry. (OnPerfectBlock comes from HeroDefense when a
## hit actually lands inside the window.)


func enter(_from: StringName, _data: Dictionary) -> void:
	hero.defense.raise_guard()
	hero.face_yaw = hero.intent.aim_yaw
	hero.emit_movement_event(MoveEvent.Type.BLOCK_START, {"perfect_window": hero.defense.perfect_window_left > 0.0})
	Sfx.play_at(hero, PlaceholderSfx.sweep("guard_up", 520.0, 640.0, 0.08, 0.25, 0.2))


func exit() -> void:
	hero.defense.lower_guard()


func physics_update(dt: float) -> void:
	if try_start_dash() or try_start_roll():
		return
	if not hero.intent.block:
		machine.change(&"Crouch" if hero.intent.crouch else &"Ground")
		return
	hero.face_yaw = hero.intent.aim_yaw
	motor.steer(tuning.walk_speed * tuning.block_move_scale, tuning.ground_accel, tuning.ground_brake, dt)
	motor.vy = -3.0
	motor.move(dt)
	if not motor.on_floor:
		machine.change(&"Air")
