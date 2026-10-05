extends MoveState
## Holding crouch on the ground: short capsule, slow movement. Letting go hands
## back to Ground; the motor stands us up as soon as there is headroom.


func enter(_from: StringName, _data: Dictionary) -> void:
	motor.hold_crouch = true
	motor.set_crouched(true)


func exit() -> void:
	motor.hold_crouch = false


func physics_update(dt: float) -> void:
	if try_start_dash() or try_start_roll() or try_start_block():
		return
	if not hero.intent.crouch:
		machine.change(&"Ground")
		return
	var jumped := false
	if motor.jump_buffer_left > 0.0 and motor.has_room_to_stand():
		# Jumping out of a crouch stands you up first.
		motor.set_crouched(false)
		motor.jump()
		hero.emit_movement_event(MoveEvent.Type.JUMP)
		jumped = true
	motor.steer(tuning.crouch_speed * hero.speed_mult(), tuning.ground_accel, tuning.ground_brake, dt)
	if not jumped:
		motor.vy = -3.0
	motor.move(dt)
	if jumped or not motor.on_floor:
		machine.change(&"Air")
