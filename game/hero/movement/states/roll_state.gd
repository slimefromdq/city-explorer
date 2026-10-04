extends MoveState
## Dodge roll: grounded, cheap, non-committal.
##
## Rolls in your movement direction (or backwards if you aren't pressing one),
## low to the ground (crouch-height capsule, so it fits under low gaps), fast
## then easing off. Invulnerable between roll_iframe_start and roll_iframe_end.
## Short cooldown, no charges. Can be started out of Ground, Crouch and Block
## (that's the "cancel out of most actions" part); M2 attacks will be added to
## that list. Rolling off a ledge hands straight over to Air with the speed.
##
## Event: OnRoll on entry.

var _dir := Vector3.FORWARD


func enter(_from: StringName, _data: Dictionary) -> void:
	motor.roll_buffer_left = 0.0
	motor.roll_pool.spend()
	var wish := motor.wish_dir()
	if wish.length() < 0.1:
		wish = -(Basis(Vector3.UP, hero.intent.aim_yaw) * Vector3.FORWARD)   # back-step roll
	_dir = Vector3(wish.x, 0.0, wish.z).normalized()
	hero.face_yaw = atan2(-_dir.x, -_dir.z)
	motor.hold_crouch = true
	motor.set_crouched(true)
	motor.impulse = Vector3.ZERO
	hero.emit_movement_event(MoveEvent.Type.ROLL, {"direction": _dir})
	Sfx.play_at(hero, PlaceholderSfx.sweep("roll", 240.0, 110.0, 0.28, 0.35, 0.75))


func exit() -> void:
	motor.hold_crouch = false
	hero.defense.iframes = false
	hero.model.set_roll(0.0)
	motor.roll_cd_left = tuning.roll_cooldown


func physics_update(dt: float) -> void:
	var t := machine.time_in_state
	var k := clampf(t / tuning.roll_time, 0.0, 1.0)
	var speed := tuning.roll_speed * lerpf(1.0, 0.55, k * k)
	motor.run_vel = _dir * speed
	if motor.on_floor:
		motor.vy = -3.0
	else:
		motor.apply_gravity(dt)
	hero.defense.iframes = t >= tuning.roll_iframe_start and t <= tuning.roll_iframe_end
	hero.model.set_roll(k)
	motor.move(dt)
	if not motor.on_floor:
		machine.change(&"Air")       # rolled off an edge: keep the speed, fall
	elif t >= tuning.roll_time:
		motor.run_vel = _dir * tuning.roll_speed * tuning.roll_end_carry
		machine.change(&"Crouch" if hero.intent.crouch else &"Ground")
