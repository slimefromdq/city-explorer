extends MoveState
## On the floor: walk, sprint, jump, and step into Crouch.
## If the capsule is still crouched (crouch released under a low ceiling), we
## move at crouch speed and can't jump until there's room to stand.


func physics_update(dt: float) -> void:
	if try_start_dash() or try_start_roll() or try_start_block():
		return
	var i := hero.intent
	if i.crouch:
		machine.change(&"Crouch")
		return
	var jumped := false
	if motor.jump_buffer_left > 0.0 and not motor.crouched:
		motor.jump()
		hero.emit_movement_event(MoveEvent.Type.JUMP)
		jumped = true
	var speed := tuning.walk_speed
	if motor.crouched:
		speed = tuning.crouch_speed
	elif i.sprint:
		speed = tuning.sprint_speed
	motor.steer(speed, tuning.ground_accel, tuning.ground_brake, dt)
	if not jumped:
		motor.vy = -3.0   # a small push down keeps us glued to slopes and step edges
	motor.move(dt)
	if jumped or not motor.on_floor:
		machine.change(&"Air")
