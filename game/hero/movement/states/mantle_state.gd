extends MoveState
## Pulling up onto a ledge. A short scripted move: rise first, then forward, so
## the body clears the lip. Input is ignored until it finishes.

var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _t := 0.0
var _dur := 0.3


func enter(_prev: StringName, data: Dictionary) -> void:
	_from = hero.global_position
	_to = data["to"]
	_t = 0.0
	var height: float = data.get("height", 1.0)
	_dur = tuning.mantle_time + height * 0.04
	motor.run_vel = Vector3.ZERO
	motor.vy = 0.0
	motor.impulse = Vector3.ZERO
	hero.emit_movement_event(MoveEvent.Type.MANTLE, {"height": height})


func physics_update(dt: float) -> void:
	_t += dt
	var k := clampf(_t / _dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var p := _from.lerp(_to, e)
	p.y = lerpf(_from.y, _to.y, minf(1.0, e * 1.7))   # height leads, so we clear the edge
	hero.global_position = p
	hero.velocity = Vector3.ZERO
	if k >= 1.0:
		var fwd := (_to - _from) * Vector3(1, 0, 1)
		motor.run_vel = fwd.normalized() * 3.0 if fwd.length() > 0.01 else Vector3.ZERO
		motor.wall_kicks_used = 0
		motor.on_floor = true
		machine.change(&"Ground")
