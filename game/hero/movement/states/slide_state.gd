extends MoveState
## Crouch while moving fast on the ground: a low slide that keeps your speed.
## Instead of braking to crouch speed, momentum only bleeds off slowly
## (slide_friction), downhill slopes speed you up, and you can only bend the
## slide a little (slide_turn_rate). Jumping out keeps the speed (slide-hop),
## so sprint -> slide -> jump, or leap -> land -> slide, chain together.
## Ends when you let go of crouch (stand up, keep momentum) or slow down to
## slide_end_speed (drops into a normal crouch if still held).
##
## Event: OnSlide on entry (data: speed).

var _sound_cd := 0.0


func enter(_from: StringName, _data: Dictionary) -> void:
	motor.hold_crouch = true
	motor.set_crouched(true)
	# Fold any leftover horizontal shove into run_vel so the slide owns it.
	motor.run_vel += Vector3(motor.impulse.x, 0.0, motor.impulse.z)
	motor.impulse = Vector3(0.0, motor.impulse.y, 0.0)
	hero.emit_movement_event(MoveEvent.Type.SLIDE, {"speed": motor.run_vel.length()})
	Sfx.play_at(hero, PlaceholderSfx.sweep("slide", 180.0, 90.0, 0.45, 0.3, 0.9))


func exit() -> void:
	motor.hold_crouch = false


func physics_update(dt: float) -> void:
	if try_start_dash() or try_start_roll() or try_start_block():
		return
	var i := hero.intent
	if motor.jump_buffer_left > 0.0 and motor.has_room_to_stand():
		# Slide-hop: stand, jump, and keep every bit of the slide speed.
		motor.set_crouched(false)
		motor.jump()
		hero.emit_movement_event(MoveEvent.Type.JUMP)
		motor.move(dt)
		machine.change(&"Air")
		return

	var v := motor.run_vel
	var speed := v.length()
	var dir := v / speed if speed > 0.01 else hero.global_basis * Vector3.FORWARD
	# Bend the slide toward the stick, a little; no speed gained from steering.
	var wish := motor.wish_dir()
	if wish.length() > 0.1:
		var turn := clampf(dir.signed_angle_to(wish, Vector3.UP), -tuning.slide_turn_rate * dt, tuning.slide_turn_rate * dt)
		dir = dir.rotated(Vector3.UP, turn)
	# Slopes: going downhill adds speed, uphill takes it away (like a sled).
	var n := hero.get_floor_normal() if motor.on_floor else Vector3.UP
	var downhill := Vector3(n.x, 0.0, n.z)
	var slope_accel := downhill.dot(dir) * tuning.gravity * tuning.slide_slope_mult
	speed = clampf(speed + (slope_accel - tuning.slide_friction) * dt, 0.0, tuning.slide_max_speed)
	motor.run_vel = dir * speed
	motor.vy = -3.0
	motor.move(dt)

	if not motor.on_floor:
		machine.change(&"Air")       # slid off an edge: fly on with the speed
	elif not i.crouch:
		machine.change(&"Ground")    # stand up; Ground's overspeed rule bleeds the extra off slowly
	elif motor.run_vel.length() < tuning.slide_end_speed:
		machine.change(&"Crouch")
