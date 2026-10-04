class_name ActionPlaceholderView
extends Node3D
## Disposable presentation adapter. Geometry follows hooks and telemetry;
## it never writes velocity or advances gameplay timers.
var player: ActionPlayerController
var capsule := MeshInstance3D.new()
var facing := MeshInstance3D.new()
var shield := MeshInstance3D.new()
var circle := MeshInstance3D.new()
var strike := MeshInstance3D.new()
var _roll := 0.0


func material(color: Color, glow := false) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	if color.a < 1.0:
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	if glow:
		mat.emission_enabled = true
		mat.emission = Color(color.r, color.g, color.b)
	return mat


func _ready() -> void:
	player = get_parent() as ActionPlayerController
	call_deferred("_build")


func _build() -> void:
	var mesh := CapsuleMesh.new()
	mesh.radius = player.tuning.capsule_radius
	mesh.height = player.tuning.standing_height
	capsule.mesh = mesh
	capsule.material_override = material(Color(0.15, 0.65, 0.8))
	add_child(capsule)
	var marker := BoxMesh.new()
	marker.size = Vector3(0.12, 0.18, 0.22)
	facing.mesh = marker
	facing.material_override = material(Color(1.0, 0.75, 0.22), true)
	add_child(facing)
	var sphere := SphereMesh.new()
	sphere.radius = 0.65
	sphere.height = 1.3
	shield.mesh = sphere
	shield.material_override = material(Color(0.25, 0.6, 1.0, 0.3), true)
	add_child(shield)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.7
	ring.outer_radius = 0.77
	circle.mesh = ring
	circle.material_override = material(Color(0.75, 0.35, 1.0), true)
	circle.top_level = true
	add_child(circle)
	circle.visible = false
	# Inner ring and six radial marks make the anticipation circle readable.
	var inner := MeshInstance3D.new()
	var inner_mesh := TorusMesh.new()
	inner_mesh.inner_radius = 0.42
	inner_mesh.outer_radius = 0.45
	inner.mesh = inner_mesh
	inner.material_override = circle.material_override
	circle.add_child(inner)
	for i in 6:
		var rune := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.04, 0.04, 0.18)
		rune.mesh = bar
		rune.material_override = circle.material_override
		rune.position = Vector3(sin(i * TAU / 6.0), 0.0, cos(i * TAU / 6.0)) * 0.58
		rune.rotation.y = i * TAU / 6.0
		circle.add_child(rune)
	var slash := BoxMesh.new()
	slash.size = Vector3(1.0, 0.08, 0.08)
	strike.mesh = slash
	strike.material_override = material(Color(1.0, 0.7, 0.2), true)
	add_child(strike)
	strike.visible = false
	player.vfx_requested.connect(_vfx)
	player.air_dash_ended.connect(func(): circle.visible = false)
	player.air_dash_launched.connect(func(_dir: Vector3): circle.visible = false)
	player.dodge_started.connect(func(_direction: Vector3, _duration: float): _roll = 0.0)


func _vfx(effect: StringName, details: Dictionary) -> void:
	if effect != &"OccultCircle":
		return
	circle.visible = true
	circle.global_position = details.position
	var direction: Vector3 = details.direction
	var up := Vector3.FORWARD if absf(direction.dot(Vector3.UP)) > 0.95 else Vector3.UP
	circle.global_basis = Basis.looking_at(direction, up) * Basis(Vector3.RIGHT, PI * 0.5)


func _process(dt: float) -> void:
	if capsule.mesh == null:
		return
	var height := player._capsule.height
	capsule.scale.y = lerpf(capsule.scale.y, height / player.tuning.standing_height, minf(1.0, dt * 22.0))
	capsule.position.y = height * 0.5
	rotation.y = atan2(-player.facing_direction.x, -player.facing_direction.z)
	facing.position = Vector3(0.0, height * 0.75, -0.38)
	shield.visible = player.is_blocking
	shield.position = Vector3(0.0, 1.0, -0.55)
	if player.states.current == ActionPlayerStateMachine.State.DODGING:
		_roll += dt / player.tuning.dodge_duration * TAU
		capsule.rotation.x = -_roll
	else:
		capsule.rotation.x = 0.0
	_pose_attack()


func _pose_attack() -> void:
	var combat := player.combat
	strike.visible = combat.hit >= 0
	if not strike.visible:
		return
	var index := combat.hit
	var startup := player.tuning.attack_startup[index]
	var active := player.tuning.attack_active[index]
	var angle := -1.2
	if combat.phase == &"startup":
		angle = lerpf(-0.5, -1.2, clampf(combat.elapsed / startup, 0.0, 1.0))
	elif combat.phase == &"active":
		angle = lerpf(-1.2, 1.2, clampf((combat.elapsed - startup) / active, 0.0, 1.0))
	else:
		angle = lerpf(1.2, 0.0, clampf((combat.elapsed - startup - active) / player.tuning.attack_recovery[index], 0.0, 1.0))
	# Two opposing horizontal swings, then an overhead finisher.
	if index == 1:
		angle = -angle
	strike.rotation = Vector3.ZERO
	if index == 2:
		strike.position = Vector3(0.0, 1.1 + cos(angle) * 0.4, -0.65)
		strike.rotation.z = angle
	else:
		strike.position = Vector3(sin(angle) * 0.6, 1.0, -0.65 - cos(angle) * 0.25)
		strike.rotation.y = angle
	strike.scale = Vector3.ONE * (1.0 if combat.phase == &"active" else 0.6)
