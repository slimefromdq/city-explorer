extends MoveState
## Staggered: flinching from a hit, guard broken, or down. No input at all
## until the timer runs out. Gravity and momentum (knockback) still apply.

var _time := 0.3


func enter(_from: StringName, data: Dictionary) -> void:
	_time = data.get("time", 0.3)
	hero.model.set_stunned(true)


func exit() -> void:
	hero.model.set_stunned(false)


func physics_update(dt: float) -> void:
	motor.run_vel = motor.run_vel.move_toward(Vector3.ZERO, tuning.ground_brake * dt)
	if motor.on_floor:
		motor.vy = -3.0
	else:
		motor.apply_gravity(dt)
	motor.move(dt)
	if machine.time_in_state >= _time:
		machine.change(&"Ground" if motor.on_floor else &"Air")
