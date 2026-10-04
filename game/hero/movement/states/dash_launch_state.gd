extends MoveState
## Sigil leap, part 2: the launch off the sigil.
##
## A fixed-speed burst along the locked direction for dash_distance metres.
## The motor sweeps the body along the path every tick, so even at full speed
## the leap stops at walls instead of passing through them. Hitting a wall with
## a ledge in reach turns into a mantle; landing or a head-on wall ends early.
## When it ends we keep some momentum and float briefly.
##
## Event: OnDashLaunch on entry.

var _dir := Vector3.FORWARD
var _duration := 0.3


func enter(_from: StringName, data: Dictionary) -> void:
	_dir = data["direction"]
	_duration = tuning.dash_distance / maxf(1.0, tuning.dash_speed)
	motor.run_vel = Vector3.ZERO
	motor.vy = 0.0
	motor.impulse = Vector3.ZERO
	var sigil: Sigil = data.get("sigil")
	if sigil != null and is_instance_valid(sigil):
		sigil.launch()
	hero.model.set_charge(1.0)
	hero.emit_movement_event(MoveEvent.Type.DASH_LAUNCH, {"direction": _dir, "speed": tuning.dash_speed})


func exit() -> void:
	hero.model.set_charge(0.0)


func physics_update(_dt: float) -> void:
	motor.move_direct(_dir * tuning.dash_speed)
	if motor.just_landed or hero.is_on_ceiling():
		_finish()
		return
	if hero.is_on_wall() and _dir.dot(motor.wall_normal) < -0.5:
		var ledge := motor.find_ledge()
		_finish()
		if not ledge.is_empty():
			machine.change(&"Mantle", ledge)
		return
	if machine.time_in_state >= _duration - 0.0001:
		_finish()


func _finish() -> void:
	motor.impulse = _dir * tuning.dash_speed * tuning.dash_end_carry
	motor.vy = 0.0
	motor.hang_left = tuning.dash_end_hang
	motor.dash_cd_left = tuning.dash_cooldown
	machine.change(&"Ground" if motor.on_floor else &"Air")
