class_name ActionMovementController
extends RefCounted
## Velocity solvers; state priority and transitions live in the player coordinator.
var tuning: ActionControllerTuning
var dash_direction := Vector3.FORWARD
var dash_carry := Vector3.ZERO
var dodge_direction := Vector3.FORWARD
var wall_normal := Vector3.ZERO
var wall_direction := Vector3.FORWARD
var wall_speed := 0.0
var wall_rid: RID
var wall_shape := -1
var dash_used := false
var dash_cooldown_left := 0.0


func horizontal(velocity: Vector3) -> Vector3:
	return Vector3(velocity.x, 0.0, velocity.z)


func gravity(body: CharacterBody3D, dt: float, scale: float = 1.0) -> void:
	if body.is_on_floor() and body.velocity.y <= 0.0:
		body.velocity.y = -2.0
	else:
		body.velocity.y = maxf(-tuning.max_fall_speed, body.velocity.y - tuning.gravity * scale * dt)


func free_step(body: CharacterBody3D, wish: Vector3, speed: float, dt: float) -> void:
	var acceleration := tuning.air_acceleration
	if body.is_on_floor():
		acceleration = tuning.ground_acceleration if wish.length_squared() > 0.0 else tuning.ground_deceleration
	var h := horizontal(body.velocity).move_toward(wish * speed, acceleration * dt)
	gravity(body, dt)
	body.velocity.x = h.x
	body.velocity.z = h.z


func slide_step(body: CharacterBody3D, wish: Vector3, dt: float) -> void:
	var h := horizontal(body.velocity)
	var speed := maxf(0.0, h.length() - tuning.slide_friction * dt)
	var direction := steer(h.normalized(), wish, tuning.slide_steering, dt)
	h = direction * speed
	if body.is_on_floor():
		var normal := body.get_floor_normal()
		if normal.y < cos(deg_to_rad(tuning.slide_downhill_min_angle)):
			h += horizontal(Vector3.DOWN.slide(normal)) * tuning.slide_downhill_acceleration * dt
	h = h.limit_length(tuning.slide_max_speed)
	gravity(body, dt)
	body.velocity.x = h.x
	body.velocity.z = h.z


func dodge_step(body: CharacterBody3D, dt: float) -> void:
	gravity(body, dt)
	body.velocity.x = dodge_direction.x * tuning.dodge_speed
	body.velocity.z = dodge_direction.z * tuning.dodge_speed


func steer(direction: Vector3, wish: Vector3, rate: float, dt: float) -> Vector3:
	if wish.length_squared() < 0.01:
		return direction
	return direction.slerp(wish.normalized(), minf(1.0, rate * dt)).normalized()


func begin_wall_run(body: CharacterBody3D, wall: Dictionary) -> bool:
	var tangent: Vector3 = wall.normal.cross(Vector3.UP).normalized()
	var along := horizontal(body.velocity).dot(tangent)
	if absf(along) < tuning.wall_run_min_speed:
		return false
	wall_direction = tangent * signf(along)
	wall_speed = absf(along)
	wall_normal = wall.normal
	wall_rid = wall.rid
	wall_shape = wall.shape
	body.velocity.y = minf(body.velocity.y, 1.0)
	return true


func wall_step(body: CharacterBody3D, wish: Vector3, dt: float) -> void:
	var desired := horizontal(wish.slide(wall_normal))
	var target_speed := maxf(tuning.wall_run_min_speed, desired.dot(wall_direction) * tuning.sprint_speed)
	wall_speed = move_toward(wall_speed, target_speed, tuning.wall_run_steering * dt)
	gravity(body, dt, tuning.wall_run_gravity_scale)
	var h := wall_direction * wall_speed - wall_normal * 2.0
	body.velocity.x = h.x
	body.velocity.z = h.z


func wall_jump(body: CharacterBody3D) -> void:
	body.velocity = wall_normal * tuning.wall_jump_force + wall_direction * tuning.wall_jump_forward + Vector3.UP * tuning.wall_jump_up


func begin_dash(body: CharacterBody3D, direction: Vector3) -> void:
	dash_used = true
	dash_cooldown_left = tuning.air_dash_cooldown
	dash_direction = direction.normalized()
	dash_carry = body.velocity * tuning.air_dash_momentum_retained
	body.velocity *= 0.15


func dash_step(body: CharacterBody3D, wish: Vector3, dt: float) -> void:
	var desired := Vector3(wish.x, dash_direction.y, wish.z).normalized()
	if wish.length_squared() > 0.01:
		dash_direction = steer(dash_direction, desired, tuning.air_dash_steering, dt)
	body.velocity = dash_direction * tuning.air_dash_speed + dash_carry
