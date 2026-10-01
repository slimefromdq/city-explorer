class_name Walker
extends CharacterBody3D
## First-person walker for the station and the city: a capsule of the reference player's size
## (PlayerScale), WASD + mouse look + Space to jump, Shift to run. The city has collision only where the
## station needs it, so this is meant for the station, its plazas, the platforms, the trains and the
## destination entrances.
##
## On a train: when the train leaves with the player aboard the walker is reparented to the carriage and
## walks inside it without physics (clamped to the aisle); on arrival it goes back to normal.
## Tests can drive it with `scripted` + `wish` (a world-space direction) and `want_jump`.

const WALK_SPEED := 4.5
const RUN_SPEED := 7.5
const GRAVITY := 9.8
const EYE_HEIGHT := 1.62
const AISLE_X := 11.2
const AISLE_Z := 1.15

var camera: Camera3D
var riding: Train = null
var _world_parent: Node
var scripted := false
var wish := Vector3.ZERO            # world-space move direction (scripted mode)
var want_jump := false
var yaw := 0.0
var pitch := 0.0
var _jump_speed := sqrt(2.0 * GRAVITY * PlayerScale.JUMP_HEIGHT)
var mouse_sensitivity := 0.0025


func _ready() -> void:
	add_to_group("player")
	collision_layer = 1
	collision_mask = 1
	floor_max_angle = deg_to_rad(46.0)
	floor_snap_length = 0.55
	floor_stop_on_slope = true
	max_slides = 6
	var cs := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = PlayerScale.RADIUS
	capsule.height = PlayerScale.HEIGHT
	cs.shape = capsule
	cs.position.y = PlayerScale.HEIGHT * 0.5
	add_child(cs)
	camera = Camera3D.new()
	camera.name = "Eye"
	camera.position.y = EYE_HEIGHT
	camera.near = 0.05
	camera.far = 4000.0
	camera.fov = 75.0
	add_child(camera)
	camera.current = true


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.5, 1.5)
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and not RideUI.blocking:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func look_at_point(p: Vector3) -> void:
	var d := p - global_position
	yaw = atan2(-d.x, -d.z)
	pitch = clampf(atan2(d.y - EYE_HEIGHT, Vector2(d.x, d.z).length()), -1.5, 1.5)


func _physics_process(delta: float) -> void:
	rotation.y = yaw
	camera.rotation.x = pitch
	var input := _input_vector()
	if riding != null:
		_ride_move(input, delta)
		return
	var dir := Vector3.ZERO
	if scripted:
		dir = wish
	else:
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, -input.y))
	var speed := RUN_SPEED if (Input.is_physical_key_pressed(KEY_SHIFT) and not scripted) else WALK_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if is_on_floor():
		velocity.y = 0.0
		if want_jump or (not scripted and Input.is_physical_key_pressed(KEY_SPACE)):
			velocity.y = _jump_speed
			want_jump = false
	else:
		velocity.y -= GRAVITY * delta
	move_and_slide()


func _input_vector() -> Vector2:
	if scripted:
		return Vector2.ZERO
	var v := Vector2.ZERO
	if Input.is_physical_key_pressed(KEY_W): v.y += 1.0
	if Input.is_physical_key_pressed(KEY_S): v.y -= 1.0
	if Input.is_physical_key_pressed(KEY_D): v.x += 1.0
	if Input.is_physical_key_pressed(KEY_A): v.x -= 1.0
	return v.normalized()


## Walking on the train floor without physics: local movement clamped to the aisle.
func _ride_move(input: Vector2, delta: float) -> void:
	var local_dir := Vector3.ZERO
	if scripted:
		local_dir = riding.global_transform.basis.inverse() * wish
	else:
		local_dir = Basis(Vector3.UP, yaw) * Vector3(input.x, 0, -input.y)
	position += Vector3(local_dir.x, 0, local_dir.z) * 2.2 * delta
	position.x = clampf(position.x, -AISLE_X, AISLE_X)
	position.z = clampf(position.z, -AISLE_Z, AISLE_Z)
	position.y = 0.0
	velocity = Vector3.ZERO


## Called when the train leaves with the player aboard.
func begin_ride(train: Train) -> void:
	if riding != null:
		return
	var xf := global_transform
	var yaw_world := yaw
	_world_parent = get_parent()
	get_parent().remove_child(self)
	train.add_child(self)
	global_transform = xf
	riding = train
	collision_layer = 0
	collision_mask = 0
	# keep looking the same way relative to the world, expressed in the train's frame
	yaw = yaw_world - train.global_rotation.y
	position.y = 0.0
	velocity = Vector3.ZERO


## Called on arrival: back to the world, with physics.
func end_ride(world_parent: Node = null) -> void:
	if riding == null:
		return
	if world_parent == null:
		world_parent = _world_parent
	var xf := global_transform
	var yaw_world := yaw + riding.global_rotation.y
	riding.remove_child(self)
	world_parent.add_child(self)
	global_transform = xf
	riding = null
	collision_layer = 1
	collision_mask = 1
	rotation = Vector3.ZERO
	yaw = yaw_world
	velocity = Vector3.ZERO
