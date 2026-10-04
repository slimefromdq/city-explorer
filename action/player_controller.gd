class_name ActionPlayerController
extends CharacterBody3D
## Composition root and deterministic intent consumer. Components own solvers,
## probes, charges and combat timing; the state machine owns action eligibility.
## Replace ActionPlayerInput with AI/network intents without changing physics.

signal animation_requested(state: StringName, details: Dictionary)
signal vfx_requested(effect: StringName, details: Dictionary)
signal landed(impact_speed: float)
signal mantle_started(low: bool, target: Vector3)
signal mantle_ended(completed: bool)
signal wall_run_started(normal: Vector3)
signal wall_jump_started(velocity: Vector3)
signal dodge_started(direction: Vector3, duration: float)
signal dodge_ended
signal air_dash_started(direction: Vector3)
signal air_dash_launched(direction: Vector3)
signal air_dash_ended

const S := ActionPlayerStateMachine.State
const A := ActionPlayerStateMachine.Action
@export var tuning: ActionControllerTuning
@export var debug_enabled := true

var states := ActionPlayerStateMachine.new()
var movement := ActionMovementController.new()
var parkour := ActionParkourController.new()
var combat := ActionCombatController.new()
var dodge_charges := ActionDodgeChargeController.new()

# Controllers write these held intents and call request for edges.
var move_input := Vector2.ZERO
var camera_yaw := 0.0
var aim_direction := Vector3.FORWARD
var facing_direction := Vector3.FORWARD
var sprint_held := false
var crouch_held := false
var block_held := false
var jump_held := false
var grounded := false
var surface_normal := Vector3.UP
var horizontal_speed := 0.0
var time_since_leaving_ground := 0.0
var time_since_last_jump := 1000.0
var against_runnable_wall := false
var mantle_target_available := false
var current_velocity: Vector3:
	get:
		return velocity
var current_movement_state: int:
	get:
		return states.current
var is_blocking: bool:
	get:
		return combat.is_blocking
var air_dash_available: bool:
	get:
		return not grounded and not movement.dash_used and movement.dash_cooldown_left <= 0.0

var _requests: Dictionary = {}
var _jump_buffer_left := 0.0
var _coyote_left := 0.0
var _jump_cut_available := false
var _shape := CollisionShape3D.new()
var _capsule := CapsuleShape3D.new()
var _height := 1.8


func _ready() -> void:
	if tuning == null:
		tuning = ActionControllerTuning.new()
	movement.tuning = tuning
	parkour.tuning = tuning
	combat.tuning = tuning
	dodge_charges.cooldown = tuning.dodge_charge_cooldown
	collision_layer = 2
	collision_mask = tuning.world_mask
	floor_max_angle = deg_to_rad(48.0)
	floor_snap_length = 0.25
	safe_margin = 0.01
	_capsule.radius = tuning.capsule_radius
	_capsule.height = tuning.standing_height
	_shape.shape = _capsule
	_shape.position.y = tuning.standing_height * 0.5
	_height = tuning.standing_height
	add_child(_shape)
	states.state_changed.connect(_state_changed)
	combat.attack_started.connect(func(hit: int): animation_requested.emit(&"Attack", {"hit": hit}))
	combat.attack_phase_changed.connect(func(hit: int, phase: StringName): animation_requested.emit(&"AttackPhase", {"hit": hit, "phase": phase}))
	states.set_state(S.AIRBORNE)


func request(action: ActionPlayerStateMachine.Action) -> void:
	_requests[action] = true


func world_move_direction() -> Vector3:
	return (Basis(Vector3.UP, camera_yaw) * Vector3(move_input.x, 0.0, -move_input.y)).limit_length(1.0)


func _state_changed(previous: int, current: int) -> void:
	if previous == S.DODGING:
		dodge_ended.emit()
	if previous == S.WALL_RUNNING:
		parkour.blocked_wall = movement.wall_rid
		parkour.blocked_wall_shape = movement.wall_shape
		parkour.reattach_left = tuning.wall_reattach_delay
	if previous in [S.AIR_DASH_STARTUP, S.AIR_DASH_LAUNCH] and current not in [S.AIR_DASH_STARTUP, S.AIR_DASH_LAUNCH]:
		air_dash_ended.emit()
	animation_requested.emit(StringName(states.state_name()), {})


func _rest_state() -> ActionPlayerStateMachine.State:
	if not is_on_floor():
		return S.AIRBORNE
	return S.CROUCHING if crouch_held or not can_stand() else S.GROUNDED


func can_stand() -> bool:
	return parkour.fits(self, global_position, tuning.standing_height)


func _stance(low: bool) -> void:
	var height := tuning.crouching_height if low else tuning.standing_height
	if is_equal_approx(height, _height):
		return
	if not low and not can_stand():
		return
	_height = height
	_capsule.height = height
	_shape.position.y = height * 0.5


func _physics_process(dt: float) -> void:
	grounded = is_on_floor()
	states.elapsed += dt
	dodge_charges.tick(dt)
	movement.dash_cooldown_left = maxf(0.0, movement.dash_cooldown_left - dt)
	time_since_last_jump += dt
	if grounded:
		_coyote_left = tuning.coyote_time
	else:
		_coyote_left = maxf(0.0, _coyote_left - dt)
	_jump_buffer_left = maxf(0.0, _jump_buffer_left - dt)
	if _requests.has(A.JUMP):
		_jump_buffer_left = tuning.jump_buffer
	var wish := world_move_direction()
	var forward := wish.normalized() if wish.length_squared() > 0.01 else facing_direction
	if states.current == S.WALL_RUNNING:
		forward = movement.wall_direction
	parkour.scan(self, forward, dt)
	against_runnable_wall = not parkour.wall.is_empty()
	mantle_target_available = not parkour.mantle.is_empty()
	# Fixed input priority: mantle > wall jump/jump > dodge > dash > attack > block > crouch.
	# Mantle assistance requires forward intent; a jump can explicitly request it too.
	var mantle_wanted := wish.length_squared() > 0.01 or _requests.has(A.MANTLE) or _jump_buffer_left > 0.0
	if mantle_target_available and mantle_wanted and states.allows(A.MANTLE, grounded, tuning) and can_stand():
		combat.set_block(false)
		parkour.begin_mantle(self)
		states.set_state(S.MANTLING)
		_jump_buffer_left = 0.0
		mantle_started.emit(parkour.mantle.low, parkour.mantle.target)
	_handle_actions(wish)
	_requests.clear()
	combat.tick(dt)
	if states.current == S.ATTACKING and combat.hit < 0:
		states.set_state(_rest_state())
	if states.current == S.BLOCKING and (not block_held or not grounded):
		combat.set_block(false)
		states.set_state(_rest_state())
	if states.current in [S.GROUNDED, S.CROUCHING, S.AIRBORNE]:
		states.set_state(_rest_state())
	_stance(states.current in [S.CROUCHING, S.SLIDING, S.DODGING, S.AIR_DASH_STARTUP])
	_update_facing(wish, dt)
	_solve(wish, dt)
	horizontal_speed = movement.horizontal(velocity).length()


func _handle_actions(wish: Vector3) -> void:
	if _jump_buffer_left > 0.0 and states.allows(A.JUMP, grounded, tuning) and can_stand():
		if states.current == S.WALL_RUNNING:
			movement.wall_jump(self)
			wall_jump_started.emit(velocity)
			_finish_jump()
		elif grounded or _coyote_left > 0.0:
			combat.set_block(false)
			velocity.y = tuning.jump_velocity
			_finish_jump()
			# Grounded is an intent context, so don't consume a ground dodge on this tick.
			grounded = false
	if _requests.has(A.DODGE) and states.allows(A.DODGE, grounded, tuning) and dodge_charges.spend():
		combat.set_block(false)
		movement.dodge_direction = wish.normalized() if wish.length_squared() > 0.01 else facing_direction
		states.set_state(S.DODGING)
		dodge_started.emit(movement.dodge_direction, tuning.dodge_duration)
	if _requests.has(A.AIR_DASH) and air_dash_available and states.allows(A.AIR_DASH, grounded, tuning) and can_stand():
		movement.begin_dash(self, aim_direction)
		states.set_state(S.AIR_DASH_STARTUP)
		air_dash_started.emit(movement.dash_direction)
		vfx_requested.emit(&"OccultCircle", {"position": global_position + Vector3.UP - movement.dash_direction * 0.8, "direction": movement.dash_direction, "duration": tuning.air_dash_startup})
	if _requests.has(A.ATTACK) and states.allows(A.ATTACK, grounded, tuning):
		if combat.press_attack():
			states.set_state(S.ATTACKING)
	if block_held and states.allows(A.BLOCK, grounded, tuning):
		states.set_state(S.BLOCKING)
		combat.set_block(true)
	if crouch_held and states.current == S.GROUNDED and states.allows(A.CROUCH, grounded, tuning):
		states.set_state(S.SLIDING if movement.horizontal(velocity).length() >= tuning.slide_min_speed else S.CROUCHING)
	if states.allows(A.WALL_RUN, grounded, tuning) and sprint_held and parkour.wall_available():
		if movement.begin_wall_run(self, parkour.wall):
			states.set_state(S.WALL_RUNNING)
			wall_run_started.emit(movement.wall_normal)


func _finish_jump() -> void:
	states.set_state(S.AIRBORNE)
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	_jump_cut_available = true
	time_since_last_jump = 0.0
	_stance(false)
	animation_requested.emit(&"Jump", {"velocity": velocity})


func _solve(wish: Vector3, dt: float) -> void:
	match states.current:
		S.MANTLING:
			time_since_leaving_ground += dt
			var result := parkour.step_mantle(self, dt)
			if result != 0:
				states.set_state(S.AIRBORNE)
				mantle_ended.emit(result == 1)
			return
		S.SLIDING:
			movement.slide_step(self, wish, dt)
			if not crouch_held or not grounded or movement.horizontal(velocity).length() < tuning.slide_end_speed:
				states.set_state(_rest_state())
		S.DODGING:
			movement.dodge_step(self, dt)
			if states.elapsed >= tuning.dodge_duration:
				velocity = movement.horizontal(velocity).limit_length(tuning.sprint_speed) + Vector3.UP * velocity.y
				states.set_state(_rest_state())
		S.WALL_RUNNING:
			if grounded or not sprint_held or states.elapsed >= tuning.wall_run_duration or parkour.wall.is_empty() or parkour.wall.rid != movement.wall_rid or parkour.wall.shape != movement.wall_shape:
				states.set_state(_rest_state())
				movement.free_step(self, wish, tuning.move_speed, dt)
			else:
				movement.wall_normal = parkour.wall.normal
				movement.wall_step(self, wish, dt)
		S.AIR_DASH_STARTUP:
			velocity = velocity.move_toward(Vector3.ZERO, tuning.gravity * dt)
			if states.elapsed >= tuning.air_dash_startup:
				_stance(false)
				if _height < tuning.standing_height:
					states.set_state(S.AIRBORNE)
				else:
					states.set_state(S.AIR_DASH_LAUNCH)
					movement.dash_step(self, wish, dt)
					air_dash_launched.emit(movement.dash_direction)
					vfx_requested.emit(&"AirDashBurst", {"direction": movement.dash_direction})
		S.AIR_DASH_LAUNCH:
			movement.dash_step(self, wish, dt)
			if states.elapsed >= tuning.air_dash_duration:
				velocity = velocity.limit_length(tuning.air_dash_exit_speed)
				states.set_state(S.AIRBORNE)
		_:
			var speed := tuning.sprint_speed if sprint_held else tuning.move_speed
			if states.current == S.CROUCHING or _height < tuning.standing_height:
				speed = tuning.crouch_speed
			if states.current == S.BLOCKING:
				speed = tuning.move_speed * tuning.block_move_scale
			elif states.current == S.ATTACKING:
				speed = tuning.move_speed * tuning.attack_move_scale
			movement.free_step(self, wish, speed, dt)
	if _jump_cut_available and velocity.y > 0.0 and not jump_held:
		velocity.y *= 0.5
		_jump_cut_available = false
	var impact := maxf(0.0, -velocity.y)
	var was_grounded := grounded
	move_and_slide()
	grounded = is_on_floor()
	surface_normal = get_floor_normal() if grounded else Vector3.UP
	if grounded:
		time_since_leaving_ground = 0.0
		movement.dash_used = false
		if not was_grounded:
			_jump_cut_available = false
			landed.emit(impact)
			animation_requested.emit(&"Land", {"impact_speed": impact})
			if states.current in [S.AIRBORNE, S.WALL_RUNNING, S.AIR_DASH_STARTUP, S.AIR_DASH_LAUNCH]:
				states.set_state(_rest_state())
	else:
		time_since_leaving_ground += dt
	if is_on_ceiling():
		velocity.y = minf(velocity.y, 0.0)
	if states.current == S.AIR_DASH_LAUNCH and is_on_wall():
		states.set_state(S.AIRBORNE)


func _update_facing(wish: Vector3, dt: float) -> void:
	var target := wish
	if states.current in [S.BLOCKING, S.ATTACKING]:
		target = movement.horizontal(aim_direction)
	elif states.current == S.DODGING:
		target = movement.dodge_direction
	elif states.current in [S.AIR_DASH_STARTUP, S.AIR_DASH_LAUNCH]:
		target = movement.horizontal(movement.dash_direction)
	if target.length_squared() > 0.01:
		facing_direction = movement.steer(facing_direction, target, 18.0, dt)


func reset_at(feet: Vector3) -> void:
	combat.cancel()
	states.set_state(S.AIRBORNE)
	global_position = feet
	velocity = Vector3.ZERO
	# CharacterBody floor contacts survive a teleport until its next slide solve.
	# Refresh them here so a reset cannot grant a ground action while in midair.
	move_and_slide()
	movement.dash_used = false
	movement.dash_cooldown_left = 0.0
	parkour.blocked_wall = RID()
	parkour.blocked_wall_shape = -1
	parkour.reattach_left = 0.0
	dodge_charges.reset()
	_requests.clear()
	_jump_buffer_left = 0.0
	_coyote_left = 0.0
	_jump_cut_available = false
	grounded = false
	time_since_leaving_ground = 0.0
	time_since_last_jump = 1000.0
	horizontal_speed = 0.0
	_stance(false)
	reset_physics_interpolation()
