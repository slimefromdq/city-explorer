class_name ShoulderCamera
extends Node3D
## Over-the-shoulder third-person camera.
##
## It owns mouse-look (yaw/pitch), keeps itself out of walls with a spring arm,
## widens the FOV with speed, and answers "what is under the crosshair?" for the
## input script (aim_dir / aim_point). It never moves the hero.
##
## It is `top_level`, so although it sits under the hero in the scene tree it
## follows by code rather than inheriting the hero's transform.

@export var mouse_sensitivity := 0.0022
@export var distance := 4.2
## Sideways offset: positive puts the hero on the left of the screen.
@export var shoulder_offset := 0.85
@export var pivot_height := 1.55
@export var crouch_pivot_height := 1.0
@export_range(-89.0, 0.0) var min_pitch_deg := -80.0
@export_range(0.0, 89.0) var max_pitch_deg := 80.0
@export var base_fov := 75.0
## Extra FOV at full sprint speed and above, for a sense of speed.
@export var speed_fov_kick := 12.0
## FOV change while winding up a sigil leap (negative = a slight zoom-in tell).
@export var dash_startup_fov := -5.0
## Extra FOV during the leap itself.
@export var dash_launch_fov := 14.0
## How quickly the camera catches up vertically (stairs, landings).
@export var height_smoothing := 12.0

var target: Hero
var yaw := 0.0
var pitch := deg_to_rad(-10.0)
var camera := Camera3D.new()
var _pivot := Node3D.new()
var _arm := SpringArm3D.new()
var _height := 0.0
var _fov := 75.0


func _ready() -> void:
	top_level = true
	if target == null:
		target = get_parent() as Hero
	add_child(_pivot)
	_pivot.add_child(_arm)
	_arm.collision_mask = Hero.LAYER_WORLD
	_arm.margin = 0.25
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	_arm.shape = probe
	_arm.add_child(camera)
	camera.fov = base_fov
	camera.far = 4500.0
	camera.current = true
	_fov = base_fov
	if target != null:
		if not target.is_node_ready():
			await target.ready
		yaw = target.face_yaw
		snap()


func look(relative: Vector2) -> void:
	yaw -= relative.x * mouse_sensitivity
	pitch = clampf(pitch - relative.y * mouse_sensitivity, deg_to_rad(min_pitch_deg), deg_to_rad(max_pitch_deg))


func snap() -> void:
	if target != null:
		_height = target.global_position.y + pivot_height
		_process(0.0)


func _process(dt: float) -> void:
	if target == null:
		return
	var tp := target.get_global_transform_interpolated().origin
	var want_h := tp.y + (crouch_pivot_height if target.motor.crouched else pivot_height)
	_height = want_h if dt == 0.0 else lerpf(_height, want_h, minf(1.0, dt * height_smoothing))
	global_position = Vector3(tp.x, _height, tp.z)
	rotation = Vector3(pitch, yaw, 0.0)
	_pivot.position = Vector3(shoulder_offset, 0.0, 0.0)
	_arm.spring_length = distance
	var t := target.tuning
	var over_walk := clampf((target.horizontal_speed() - t.walk_speed) / maxf(0.1, t.sprint_speed - t.walk_speed), 0.0, 1.0)
	var want := base_fov + over_walk * speed_fov_kick
	match target.states.current_name:
		&"DashStartup":
			want += dash_startup_fov
		&"DashLaunch":
			want += dash_launch_fov
	_fov = lerpf(_fov, want, minf(1.0, dt * 8.0))
	camera.fov = _fov


## Ray from the screen centre. Returns {dir, point}: the aim direction and the
## first world/hurtbox point under the crosshair (or a far point if nothing).
func compute_aim(exclude: Array[RID]) -> Dictionary:
	var origin := camera.global_position
	var dir := -camera.global_transform.basis.z
	var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * 300.0, Hero.LAYER_WORLD | 4)
	q.collide_with_areas = true
	q.exclude = exclude
	var r := camera.get_world_3d().direct_space_state.intersect_ray(q)
	var point: Vector3 = r.position if not r.is_empty() else origin + dir * 300.0
	return {"dir": dir, "point": point}
