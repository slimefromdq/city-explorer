extends Node3D
## Real physics fixtures plus deterministic charge/combo/transition checks.
## godot --headless --fixed-fps 60 res://tests/action_controller_test.tscn
const S := ActionPlayerStateMachine.State
const A := ActionPlayerStateMachine.Action
var player: ActionPlayerController
var passes := 0
var failures := 0
var events: Array[String] = []


func check(description: String, condition: bool, detail := "") -> void:
	if condition:
		passes += 1
		print("  ok  ", description)
	else:
		failures += 1
		print("  FAIL  ", description, " ", detail)


func frames(count: int) -> void:
	for i in count:
		await get_tree().physics_frame


func box(at: Vector3, size: Vector3) -> StaticBody3D:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var geometry := BoxShape3D.new()
	geometry.size = size
	shape.shape = geometry
	body.position = at
	body.add_child(shape)
	add_child(body)
	return body


func fresh(at := Vector3(0.0, 0.1, 10.0)) -> void:
	player.move_input = Vector2.ZERO
	player.sprint_held = false
	player.crouch_held = false
	player.block_held = false
	player.jump_held = false
	player.camera_yaw = 0.0
	player.aim_direction = Vector3.FORWARD
	player.facing_direction = Vector3.FORWARD
	player.reset_at(at)


func _ready() -> void:
	_charges_and_combat()
	_transition_rules()
	box(Vector3(0, -0.5, 0), Vector3(240, 1, 240))
	box(Vector3(-20, 1.4, 10), Vector3(8, 0.4, 8))
	box(Vector3(20, 0.4, -3), Vector3(6, 0.8, 4))
	box(Vector3(30, 1.0, -3), Vector3(6, 2, 4))
	box(Vector3(40, 0.5, -3), Vector3(6, 1, 4))
	box(Vector3(40, 2.8, -3), Vector3(6, 1.2, 4))
	box(Vector3(50, 2.0, -3), Vector3(6, 4, 4))
	box(Vector3(60, 5, 0), Vector3(1, 10, 40))
	var ramp := box(Vector3(80, 5, 0), Vector3(6, 0.4, 20))
	ramp.rotation_degrees.x = 26.0
	player = ActionPlayerController.new()
	player.position = Vector3(0, 0.1, 10)
	add_child(player)
	player.landed.connect(func(_impact: float): events.append("land"))
	player.air_dash_launched.connect(func(_direction: Vector3): events.append("launch"))
	player.dodge_started.connect(func(_direction: Vector3, _duration: float): events.append("dodge"))
	player.dodge_ended.connect(func(): events.append("dodge_end"))
	await _locomotion()
	await _slide_and_dodge()
	await _dash_and_combat()
	await _mantles()
	await _walls()
	await _slopes_and_surface_identity()
	print("ACTION CONTROLLER: %d passed, %d failed" % [passes, failures])
	get_tree().quit(1 if failures > 0 else 0)


func _charges_and_combat() -> void:
	var pool := ActionDodgeChargeController.new()
	pool.cooldown = 2.0
	check("three initial dodge charges", pool.available() == 3)
	pool.spend()
	pool.tick(0.5)
	pool.spend()
	pool.tick(0.5)
	pool.spend()
	check("empty pool rejects dodge", not pool.spend())
	pool.tick(1.0)
	check("first charge regenerates on its own deadline", pool.available() == 1)
	pool.tick(0.5)
	check("second charge keeps independent deadline", pool.available() == 2)
	pool.tick(0.5)
	check("third charge keeps independent deadline", pool.available() == 3)
	var combat := ActionCombatController.new()
	combat.tuning = ActionControllerTuning.new()
	var windows: Array[String] = []
	combat.attack_active_started.connect(func(hit: int): windows.append("start%d" % hit))
	combat.attack_active_ended.connect(func(hit: int): windows.append("end%d" % hit))
	combat.press_attack()
	check("attack starts with startup", combat.phase == &"startup" and combat.hit == 0)
	check("early combo click rejected", not combat.press_attack())
	combat.tick(0.2)
	check("active window opens independently of animation", windows == ["start1"])
	check("valid combo click queues hit two", combat.press_attack())
	combat.tick(0.31)
	check("queued second attack starts", combat.hit == 1 and combat.phase == &"startup")
	combat.tick(0.22)
	combat.press_attack()
	combat.tick(0.4)
	check("queued third attack starts", combat.hit == 2)
	combat.tick(0.3)
	check("third hit cannot queue fourth", not combat.press_attack())
	combat.tick(0.6)
	check("three hit chain closes all active windows", windows == ["start1", "end1", "start2", "end2", "start3", "end3"])
	combat.press_attack()
	combat.tick(0.4)
	check("late click is rejected", not combat.press_attack())
	combat.tick(0.11)
	combat.press_attack()
	check("click after recovery resets combo", combat.hit == 0)
	combat.tick(0.15)
	combat.cancel()
	check("cancelling active attack closes hit detection hook", windows.back() == "end1" and combat.hit == -1)


func _transition_rules() -> void:
	var state := ActionPlayerStateMachine.new()
	var tuning := ActionControllerTuning.new()
	state.set_state(S.MANTLING)
	for action in [A.JUMP, A.DODGE, A.AIR_DASH, A.BLOCK, A.ATTACK]:
		check("mantle locks action %d" % action, not state.allows(action, false, tuning))
	state.set_state(S.WALL_RUNNING)
	check("wall jump overrides normal jump", state.allows(A.JUMP, false, tuning))
	check("wall run disallows air dash by default", not state.allows(A.AIR_DASH, false, tuning))
	tuning.allow_dash_from_wall_run = true
	check("wall dash can be explicitly enabled", state.allows(A.AIR_DASH, false, tuning))
	state.set_state(S.BLOCKING)
	check("blocking rejects melee", not state.allows(A.ATTACK, true, tuning))
	tuning.jump_cancels_block = false
	tuning.dodge_cancels_block = false
	check("block cancellation policy honored", not state.allows(A.JUMP, true, tuning) and not state.allows(A.DODGE, true, tuning))
	state.set_state(S.DODGING)
	check("dodge locks attacks and block", not state.allows(A.ATTACK, true, tuning) and not state.allows(A.BLOCK, true, tuning))


func _locomotion() -> void:
	await frames(12)
	check("capsule grounded on real floor", player.grounded)
	player.move_input = Vector2(0, 1)
	await frames(30)
	check("walk reaches configured speed", absf(player.horizontal_speed - player.tuning.move_speed) < 0.2)
	player.sprint_held = true
	await frames(25)
	check("sprint reaches configured speed", absf(player.horizontal_speed - player.tuning.sprint_speed) < 0.2)
	player.move_input = Vector2.ZERO
	await frames(30)
	check("smooth deceleration reaches rest", player.horizontal_speed < 0.1)
	fresh()
	await frames(12)
	player.camera_yaw = PI * 0.5
	player.move_input = Vector2(0, 1)
	await frames(20)
	check("forward input follows camera yaw", player.velocity.x < -6.0 and absf(player.velocity.z) < 0.1)
	fresh()
	await frames(12)
	player.jump_held = true
	player.request(A.JUMP)
	await frames(4)
	check("jump leaves floor into airborne state", not player.grounded and player.states.current == S.AIRBORNE and player.velocity.y > 0.0)
	check("jump timers exposed", player.time_since_last_jump < 0.15 and player.time_since_leaving_ground > 0.0)
	await frames(90)
	check("fall and landing emit hook", player.grounded and "land" in events)
	fresh(Vector3(0, 8, 10))
	player.velocity = Vector3(10, 0, 0)
	player.move_input = Vector2(0, 1)
	await frames(10)
	check("air control preserves more momentum", player.velocity.x > 7.0)
	fresh()
	await frames(12)
	player.crouch_held = true
	player.move_input = Vector2(0, 1)
	await frames(20)
	check("slow crouch uses crouching state", player.states.current == S.CROUCHING)
	check("crouch resizes real capsule", is_equal_approx(player._capsule.height, player.tuning.crouching_height))
	check("crouch speed configured", absf(player.horizontal_speed - player.tuning.crouch_speed) < 0.2)
	player.global_position = Vector3(-20, 0.02, 10)
	player.move_input = Vector2.ZERO
	player.crouch_held = false
	await frames(10)
	check("low ceiling prevents standing", player.states.current == S.CROUCHING and player._capsule.height < player.tuning.standing_height)
	player.global_position = Vector3(-26, 0.02, 10)
	await frames(10)
	check("standing resumes after clearing ceiling", player.states.current == S.GROUNDED and is_equal_approx(player._capsule.height, player.tuning.standing_height))


func slide_distance(speed: float) -> float:
	fresh()
	await frames(12)
	player.velocity = Vector3(0, 0, -speed)
	player.crouch_held = true
	var start := player.global_position
	await frames(2)
	check("fast crouch enters slide", player.states.current == S.SLIDING)
	check("slide preserves entry momentum", player.horizontal_speed > speed - 0.5)
	await frames(160)
	check("friction ends slide in crouch", player.states.current == S.CROUCHING)
	return start.distance_to(player.global_position)


func _slide_and_dodge() -> void:
	var slow := await slide_distance(8.5)
	var fast := await slide_distance(12.0)
	check("higher entry speed travels farther", fast > slow * 1.5, "%s / %s" % [fast, slow])
	fresh()
	await frames(12)
	player.velocity = Vector3(0, 0, -12)
	player.crouch_held = true
	await frames(3)
	player.crouch_held = false
	await frames(3)
	check("releasing crouch ends slide", player.states.current == S.GROUNDED)
	fresh()
	await frames(12)
	player.move_input = Vector2(1, 0)
	player.request(A.DODGE)
	player.request(A.ATTACK)
	await frames(2)
	check("dodge wins over simultaneous melee", player.states.current == S.DODGING and player.combat.hit == -1)
	check("dodge launches immediately", player.velocity.x > 20.0)
	check("dodge consumes one charge", player.dodge_charges.available() == 2)
	player.move_input = Vector2(-1, 0)
	await frames(5)
	check("dodge locks normal steering", player.velocity.x > 20.0)
	await frames(20)
	check("dodge ends and emits hook", player.states.current != S.DODGING and "dodge_end" in events)
	fresh()
	await frames(12)
	player.facing_direction = Vector3.RIGHT
	player.request(A.DODGE)
	await frames(2)
	check("dodge falls back to facing without input", player.velocity.x > 20.0)


func _dash_and_combat() -> void:
	fresh()
	await frames(12)
	player.request(A.AIR_DASH)
	await frames(2)
	check("ground air dash rejected", player.states.current == S.GROUNDED and not player.movement.dash_used)
	fresh(Vector3(0, 15, 10))
	player.request(A.AIR_DASH)
	await frames(2)
	check("dash begins in separate startup", player.states.current == S.AIR_DASH_STARTUP)
	check("startup stabilizes momentum", player.velocity.length() < 1.0)
	player.request(A.DODGE)
	player.request(A.ATTACK)
	await frames(3)
	check("startup rejects conflicting actions", player.states.current == S.AIR_DASH_STARTUP)
	await frames(15)
	check("startup launches at high speed", player.states.current == S.AIR_DASH_LAUNCH and player.horizontal_speed > 30.0 and "launch" in events)
	await frames(18)
	check("launch restores normal air state", player.states.current == S.AIRBORNE)
	await frames(35)
	player.request(A.AIR_DASH)
	await frames(2)
	check("second air dash denied even after cooldown", player.states.current == S.AIRBORNE and player.movement.dash_used)
	await frames(100)
	check("landing restores air dash budget", player.grounded and not player.movement.dash_used)
	fresh()
	await frames(12)
	player.block_held = true
	player.move_input = Vector2(1, 0)
	await frames(20)
	check("block query active with reduced speed", player.is_blocking and player.horizontal_speed < 3.0)
	player.request(A.ATTACK)
	await frames(2)
	check("attack disabled while blocking", player.combat.hit == -1)
	player.jump_held = true
	player.request(A.JUMP)
	await frames(3)
	check("jump cancels block", not player.is_blocking and player.states.current == S.AIRBORNE)
	fresh()
	await frames(12)
	player.request(A.ATTACK)
	player.block_held = true
	await frames(3)
	check("attack wins over simultaneous block", player.states.current == S.ATTACKING and not player.is_blocking)
	await frames(9)
	player.request(A.ATTACK)
	await frames(22)
	check("controller drives queued melee chain", player.combat.hit == 1)


func _mantles() -> void:
	for entry in [{"x": 20.0, "height": 0.8, "low": true}, {"x": 30.0, "height": 2.0, "low": false}]:
		fresh(Vector3(entry.x, 0.4, -0.35))
		player.move_input = Vector2(0, 1)
		await frames(2)
		check("valid %.1fm ledge starts mantle" % entry.height, player.states.current == S.MANTLING, "%s / %s / %s" % [player.states.state_name(), player.parkour.mantle_rejection, player.parkour.mantle])
		check("mantle distinguishes low and high", player.parkour.mantle_duration == (player.tuning.mantle_low_duration if entry.low else player.tuning.mantle_high_duration))
		player.move_input = Vector2.ZERO
		player.block_held = true
		player.request(A.ATTACK)
		await frames(3)
		check("mantle blocks combat inputs", not player.is_blocking and player.combat.hit == -1)
		await frames(45)
		check("mantle reaches valid standing top", player.grounded and absf(player.global_position.y - entry.height) < 0.1, str(player.global_position))
	fresh(Vector3(40, 0.4, -0.35))
	player.move_input = Vector2(0, 1)
	await frames(2)
	check("mantle rejects obstructed standing clearance", player.states.current != S.MANTLING)
	fresh(Vector3(50, 0.4, -0.35))
	player.move_input = Vector2(0, 1)
	await frames(2)
	check("mantle rejects excessive height", player.states.current != S.MANTLING)
	fresh(Vector3(30, 0.4, -0.35))
	player.move_input = Vector2(0, 1)
	await frames(2)
	var obstruction := box(Vector3(30, 3.0, -1.5), Vector3(2, 2, 2))
	await frames(40)
	check("new obstruction aborts mantle without tunnelling", player.states.current != S.MANTLING and player.global_position.z > -1.0)
	obstruction.queue_free()


func _walls() -> void:
	fresh(Vector3(59.05, 4.0, 8))
	player.velocity = Vector3(0, 0, -10)
	player.move_input = Vector2(0, 1)
	player.sprint_held = true
	await frames(3)
	check("side probe detects runnable vertical wall", player.against_runnable_wall)
	check("airborne sprint enters wall run", player.states.current == S.WALL_RUNNING)
	var vertical := player.velocity.y
	await frames(15)
	check("wall run gradually falls", player.velocity.y < vertical and player.velocity.y > -5.0)
	player.jump_held = true
	player.request(A.JUMP)
	await frames(2)
	check("wall jump launches away and up", player.velocity.x < -7.0 and player.velocity.y > 9.0 and player.states.current == S.AIRBORNE, str(player.velocity))
	player.global_position = Vector3(59.05, 5.0, 0)
	player.velocity = Vector3(0, 0, -10)
	await frames(3)
	check("same wall cannot reconnect immediately", player.states.current == S.AIRBORNE)
	fresh(Vector3(59.05, 8.0, 8))
	player.velocity = Vector3(0, 0, -10)
	player.move_input = Vector2(0, 1)
	player.sprint_held = true
	await frames(3)
	player.request(A.AIR_DASH)
	await frames(2)
	check("wall run rejects air dash by default", player.states.current == S.WALL_RUNNING and not player.movement.dash_used)
	await frames(90)
	check("wall run expires at maximum duration", player.states.current == S.AIRBORNE)
	check("timed out wall run enforces reattach delay", player.parkour.reattach_left > 0.0)


func downhill_speed(acceleration: float) -> float:
	fresh(Vector3(80, 10, -3))
	await frames(60)
	check("slope fixture is walkable", player.grounded and player.surface_normal.y < 0.95)
	player.tuning.slide_downhill_acceleration = acceleration
	player.velocity = Vector3(0, 0, 10)
	player.crouch_held = true
	await frames(20)
	return player.horizontal_speed


func _slopes_and_surface_identity() -> void:
	var friction_only := await downhill_speed(0.0)
	var downhill := await downhill_speed(16.0)
	check("sufficiently steep downhill slope adds slide speed", downhill > friction_only + 1.0, "%s / %s" % [downhill, friction_only])
	player.tuning.slide_downhill_acceleration = 16.0
	# The city batches several different wall shapes in one StaticBody3D.
	var multi_surface := box(Vector3(100, 8, 0), Vector3(1, 16, 20))
	var second_shape := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(1, 16, 20)
	second_shape.shape = shape
	second_shape.position.x = 5.0
	multi_surface.add_child(second_shape)
	fresh(Vector3(99.05, 8, 4))
	player.velocity = Vector3(0, 0, -10)
	player.move_input = Vector2(0, 1)
	player.sprint_held = true
	await frames(3)
	check("batched world wall can start run", player.states.current == S.WALL_RUNNING)
	player.jump_held = true
	player.request(A.JUMP)
	await frames(2)
	player.global_position = Vector3(104.05, 8, 4)
	player.velocity = Vector3(0, 0, -10)
	await frames(3)
	check("different shape on same body allows new wall run", player.states.current == S.WALL_RUNNING)
	player.move_input = Vector2(1, 0)
	await frames(3)
	check("steering toward wall keeps stable side probes", player.states.current == S.WALL_RUNNING)
