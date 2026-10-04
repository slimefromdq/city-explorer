extends MoveState
## Sigil leap, part 1: the committed windup.
##
## The moment you press dash, the direction is locked in (where the camera
## aims), a charge is spent, and a sigil starts drawing itself behind you,
## facing the way you'll leap. For `dash_startup` seconds you hang almost still:
## momentum bleeds away, gravity is weak, and nothing cancels this state. That
## vulnerability is the price of the leap. Then the sigil is formed and we hand
## over to DashLaunch.
##
## Events: OnDashStart on entry, OnSigilFormed at the end of the windup.

const SIGIL_SCENE := preload("res://game/vfx/sigil/sigil.tscn")

var _dir := Vector3.FORWARD
var _sigil: Sigil


func enter(_from: StringName, _data: Dictionary) -> void:
	motor.dash_pool.spend()
	motor.dash_buffer_left = 0.0
	motor.jump_buffer_left = 0.0
	motor.jumped = false
	_dir = motor.dash_direction()
	if Vector2(_dir.x, _dir.z).length() > 0.05:
		hero.face_yaw = atan2(-_dir.x, -_dir.z)   # turn to face the leap immediately
	_sigil = _spawn_sigil()
	hero.emit_movement_event(MoveEvent.Type.DASH_START, {"direction": _dir})


func exit() -> void:
	hero.model.set_charge(0.0)


func physics_update(dt: float) -> void:
	# Bleed off existing momentum: the windup reads as a pause, not a slide.
	var keep := exp(-tuning.dash_startup_brake * dt)
	motor.run_vel *= keep
	motor.impulse *= keep
	if motor.on_floor:
		motor.vy = -3.0
	else:
		# Rising or falling, vertical speed bleeds away too: the hero hangs.
		motor.vy *= exp(-tuning.dash_startup_hang_brake * dt)
		motor.apply_gravity(dt, tuning.dash_startup_gravity)
	motor.move(dt)
	var k := clampf(machine.time_in_state / tuning.dash_startup, 0.0, 1.0)
	hero.model.set_charge(k)
	if machine.time_in_state >= tuning.dash_startup - 0.0001:
		var clipped := _sigil != null and _sigil.clipped
		hero.emit_movement_event(MoveEvent.Type.SIGIL_FORMED, {"clipped": clipped})
		machine.change(&"DashLaunch", {"direction": _dir, "sigil": _sigil})


## Place the sigil `sigil_offset` behind the body centre, facing the leap.
## If something is in the way back there (a wall, a low ceiling, the floor),
## the sigil appears flat against that surface instead. The leap still happens.
func _spawn_sigil() -> Sigil:
	var center := hero.global_position + Vector3.UP * (tuning.crouch_height if motor.crouched else tuning.stand_height) * 0.5
	var pos := center - _dir * tuning.sigil_offset
	var facing := _dir
	var clipped := false
	var q := PhysicsRayQueryParameters3D.create(center, center - _dir * (tuning.sigil_offset + 0.05), Hero.LAYER_WORLD)
	q.exclude = [hero.get_rid()]
	var hit := hero.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		pos = hit.position + hit.normal * 0.03
		facing = hit.normal
		clipped = true
	var s := SIGIL_SCENE.instantiate() as Sigil
	var world := hero.get_parent()
	world.add_child(s)
	s.global_position = pos
	s.face(facing)
	s.play(tuning.dash_startup, clipped)
	return s
