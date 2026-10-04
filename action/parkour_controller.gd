class_name ActionParkourController
extends RefCounted
## Physics probes and collision-safe mantle trajectory, independent of input.
var tuning: ActionControllerTuning
var wall: Dictionary = {}
var mantle: Dictionary = {}
var mantle_rejection := ""
var probes: Array[Dictionary] = []
var blocked_wall: RID
var blocked_wall_shape := -1
var reattach_left := 0.0
var mantle_from := Vector3.ZERO
var mantle_to := Vector3.ZERO
var mantle_duration := 0.0
var mantle_elapsed := 0.0


func ray(body: CharacterBody3D, from: Vector3, to: Vector3) -> Dictionary:
	probes.append({"from": from, "to": to})
	var query := PhysicsRayQueryParameters3D.create(from, to, tuning.world_mask, [body.get_rid()])
	return body.get_world_3d().direct_space_state.intersect_ray(query)


func fits(body: CharacterBody3D, feet: Vector3, height: float) -> bool:
	var capsule := CapsuleShape3D.new()
	capsule.radius = tuning.capsule_radius
	capsule.height = height
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = capsule
	query.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (height * 0.5 + 0.025))
	query.collision_mask = tuning.world_mask
	query.exclude = [body.get_rid()]
	query.margin = 0.005
	return body.get_world_3d().direct_space_state.intersect_shape(query, 1).is_empty()


func scan(body: CharacterBody3D, forward: Vector3, dt: float) -> void:
	probes.clear()
	wall = {}
	mantle = {}
	mantle_rejection = "No front obstacle"
	reattach_left = maxf(0.0, reattach_left - dt)
	if body.is_on_floor():
		blocked_wall = RID()
		blocked_wall_shape = -1
		reattach_left = 0.0
	var side := forward.cross(Vector3.UP).normalized()
	var chest := body.global_position + Vector3.UP * 0.9
	for direction in [side, -side]:
		var result := ray(body, chest, chest + direction * tuning.wall_reach)
		if not result.is_empty() and absf(result.normal.y) <= tuning.wall_max_normal_y:
			if wall.is_empty() or chest.distance_squared_to(result.position) < chest.distance_squared_to(wall.position):
				wall = result
	# A front obstruction, overhead clearance and downward top probe are all required.
	var base := body.global_position
	var obstacle := ray(body, base + Vector3.UP * tuning.mantle_min_height,
		base + Vector3.UP * tuning.mantle_min_height + forward * tuning.mantle_reach)
	if obstacle.is_empty() or absf(obstacle.normal.y) > tuning.wall_max_normal_y:
		return
	mantle_rejection = "Overhead obstruction"
	var top_origin := base + Vector3.UP * (tuning.mantle_max_height + 0.1)
	if not ray(body, top_origin, top_origin + forward * (tuning.mantle_reach + tuning.capsule_radius)).is_empty():
		return
	var inward: Vector3 = -obstacle.normal
	inward.y = 0.0
	inward = inward.normalized()
	var over: Vector3 = obstacle.position + inward * (tuning.capsule_radius + 0.12)
	over.y = top_origin.y
	var top := ray(body, over, Vector3(over.x, base.y + tuning.mantle_min_height, over.z))
	mantle_rejection = "No walkable ledge top"
	if top.is_empty() or top.normal.y < cos(body.floor_max_angle):
		return
	var height: float = top.position.y - base.y
	mantle_rejection = "Height outside limits"
	if height < tuning.mantle_min_height or height > tuning.mantle_max_height:
		return
	var target: Vector3 = top.position + Vector3.UP * 0.03
	mantle_rejection = "Standing capsule blocked at target"
	if not fits(body, target, tuning.standing_height):
		return
	# Check both segments of the lift-then-forward path with the full standing capsule.
	var lift := Vector3(base.x, target.y, base.z)
	mantle_rejection = "Mantle path obstructed"
	if not path_clear(body, base, lift) or not path_clear(body, lift, target):
		return
	mantle = {"target": target, "height": height, "low": height <= tuning.mantle_low_height}
	mantle_rejection = ""


func path_clear(body: CharacterBody3D, from: Vector3, to: Vector3) -> bool:
	var collision := KinematicCollision3D.new()
	return not body.test_move(Transform3D(body.global_basis, from), to - from, collision, 0.005)


func wall_available() -> bool:
	return not wall.is_empty() and (wall.rid != blocked_wall or wall.shape != blocked_wall_shape or reattach_left <= 0.0)


func detach_wall() -> void:
	if not wall.is_empty():
		blocked_wall = wall.rid
		blocked_wall_shape = wall.shape
	reattach_left = tuning.wall_reattach_delay


func begin_mantle(body: CharacterBody3D) -> void:
	mantle_from = body.global_position
	mantle_to = mantle.target
	mantle_duration = tuning.mantle_low_duration if mantle.low else tuning.mantle_high_duration
	mantle_elapsed = 0.0


## Returns 0 while moving, 1 on completion, -1 if newly blocked.
func step_mantle(body: CharacterBody3D, dt: float) -> int:
	mantle_elapsed += dt
	var t := clampf(mantle_elapsed / maxf(mantle_duration, 0.01), 0.0, 1.0)
	var lift := Vector3(mantle_from.x, mantle_to.y, mantle_from.z)
	var point: Vector3
	if t < 0.55:
		point = mantle_from.lerp(lift, smoothstep(0.0, 0.55, t))
	else:
		point = lift.lerp(mantle_to, smoothstep(0.55, 1.0, t))
	var collision := body.move_and_collide(point - body.global_position)
	body.velocity = Vector3.ZERO
	if collision != null:
		return -1
	return 1 if t >= 1.0 else 0
