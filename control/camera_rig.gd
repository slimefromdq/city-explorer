class_name CameraRig
extends Node3D
## Over-the-shoulder camera. Owns mouse-look, collision pull-in, FOV kick,
## snapshot zoom and hit shake, and answers "what am I aiming at?" for the
## player controller (aim_dir / aim_point).

const SENS := 0.0022
const PITCH_MIN := deg_to_rad(-80.0)
const PITCH_MAX := deg_to_rad(80.0)

var target: Fighter
var yaw := 0.0
var pitch := deg_to_rad(-8.0)
var camera := Camera3D.new()
var _arm := SpringArm3D.new()
var _pivot := Node3D.new()
var _shake := 0.0
var _fov := 75.0
var _height_smooth := 0.0


func _ready() -> void:
	top_level = true
	add_child(_pivot)
	_pivot.add_child(_arm)
	_arm.spring_length = 4.6
	_arm.collision_mask = Fighter.LAYER_WORLD
	_arm.margin = 0.3
	var shape := SphereShape3D.new()
	shape.radius = 0.25
	_arm.shape = shape
	_arm.add_child(camera)
	camera.fov = _fov
	camera.far = 4500.0
	camera.current = true
	Events.camera_shake.connect(func(a: float) -> void: _shake = maxf(_shake, a))


func look(rel: Vector2) -> void:
	yaw -= rel.x * SENS
	pitch = clampf(pitch - rel.y * SENS, PITCH_MIN, PITCH_MAX)


func snap_to_target() -> void:
	if target != null:
		global_position = target.global_position + Vector3.UP * 1.55
		_height_smooth = global_position.y


func _process(dt: float) -> void:
	if target == null:
		return
	var tp := target.get_global_transform_interpolated().origin
	_height_smooth = lerpf(_height_smooth, tp.y + 1.55, minf(1.0, dt * 12.0))
	var zoom := target.aim_zoom
	# shoulder offset shrinks when zoomed so the scope line matches the reticle
	var shoulder := lerpf(0.95, 0.55, zoom)
	global_position = Vector3(tp.x, _height_smooth, tp.z)
	rotation = Vector3(pitch, yaw, 0.0)
	_pivot.rotation = Vector3.ZERO
	_pivot.position = Vector3(shoulder, 0.0, 0.0)
	_arm.spring_length = lerpf(4.6, 3.0, zoom)
	# FOV: wider when dashing/sprinting, tight when charging the snapshot
	var speed_kick := clampf((Vector2(target.velocity.x, target.velocity.z).length() - 9.0) / 30.0, 0.0, 1.0)
	var want := 75.0 + speed_kick * 16.0
	if target.loco.drive == Locomotion.Drive.DASH:
		want += 8.0
	want = lerpf(want, 42.0, zoom)
	_fov = lerpf(_fov, want, minf(1.0, dt * 9.0))
	camera.fov = _fov
	_shake = maxf(0.0, _shake - dt * 2.2)
	if _shake > 0.0:
		camera.h_offset = randf_range(-1.0, 1.0) * _shake * 0.15
		camera.v_offset = randf_range(-1.0, 1.0) * _shake * 0.15
	else:
		camera.h_offset = 0.0
		camera.v_offset = 0.0


## Ray from the screen centre; returns the world point under the reticle.
func compute_aim(exclude: Array[RID]) -> Dictionary:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 300.0, Fighter.LAYER_WORLD | Fighter.LAYER_HURTBOX)
	q.collide_with_areas = true
	q.exclude = exclude
	var r := target.get_world_3d().direct_space_state.intersect_ray(q)
	var point: Vector3 = r.position if not r.is_empty() else origin + dir * 300.0
	return {"dir": dir, "point": point}
