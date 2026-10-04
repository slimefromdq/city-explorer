extends MoveState
## Airborne: gravity, air steering, coyote jumps, wall kicks, ledge grabs, and
## landing (which emits OnLand).


func physics_update(dt: float) -> void:
	if try_start_dash():
		return
	var i := hero.intent
	if motor.jump_buffer_left > 0.0:
		if motor.coyote_left > 0.0 and not motor.crouched:
			# Walked off a ledge a moment ago: still allowed to jump ("coyote time").
			motor.jump()
			hero.emit_movement_event(MoveEvent.Type.JUMP)
		elif motor.can_wall_kick():
			motor.wall_kick()
			hero.emit_movement_event(MoveEvent.Type.WALL_KICK, {"kicks_used": motor.wall_kicks_used})
	motor.apply_jump_cut()
	var speed := tuning.sprint_speed if i.sprint else tuning.walk_speed
	motor.air_steer(speed, dt)
	motor.apply_gravity(dt)
	motor.move(dt)

	if motor.on_floor:
		hero.emit_movement_event(MoveEvent.Type.LAND, {"impact_speed": motor.land_speed})
		if i.crouch:
			# Landing with crouch held and speed to spare turns straight into a slide.
			machine.change(&"Slide" if motor.run_vel.length() >= tuning.slide_min_speed else &"Crouch")
		else:
			machine.change(&"Ground")
		return
	# Pushing into a wall with a ledge within reach? Pull up onto it.
	if motor.wall_left > 0.0 and _pushing_into_wall():
		var ledge := motor.find_ledge()
		if not ledge.is_empty():
			machine.change(&"Mantle", ledge)


func _pushing_into_wall() -> bool:
	var into := -motor.wall_normal
	return motor.wish_dir().dot(into) > 0.2 or motor.run_vel.dot(into) > 1.0
