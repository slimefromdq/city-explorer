class_name TargetDummy
extends CharacterBody3D
## A punching bag for testing cards. It never attacks. It shows a floating
## damage number for every hit, a health bar, gets knocked around by pushes,
## and falls over at 0 health, then stands back up after `revive_time`.
## F5 (dbg_reset) puts every dummy back where it started at full health.

@export var max_health := 300.0
@export var revive_time := 2.5
## Knockback slows down by this much per second on the ground.
@export var ground_friction := 18.0
@export var gravity := 22.0
@export var color := Color(0.75, 0.7, 0.6)

var health := 0.0
var dead := false
var total_damage := 0.0          # since the last reset, for checking numbers in tests
var hits_taken := 0
var statuses := StatusSet.new()

var _home := Transform3D.IDENTITY
var _revive_left := 0.0
var _flash := 0.0
var _mat: StandardMaterial3D
var _bar: Label3D
var _visual: Node3D


func _ready() -> void:
	collision_layer = CardEffect.LAYER_CHARACTER
	collision_mask = CardEffect.LAYER_WORLD
	add_to_group(&"target_dummies")
	_home = global_transform
	_build()
	reset()


func reset() -> void:
	global_transform = _home
	velocity = Vector3.ZERO
	health = max_health
	dead = false
	total_damage = 0.0
	hits_taken = 0
	statuses.clear()
	_visual.rotation = Vector3.ZERO
	reset_physics_interpolation()
	_update_bar()


func is_dead() -> bool:
	return dead


## Cards deal damage through this, the same entry point heroes use.
func take_hit(hit: HitData) -> int:
	if dead:
		return HitData.Result.NONE
	var amount := minf(hit.damage, health)
	health -= amount
	total_damage += amount
	hits_taken += 1
	_flash = 1.0
	var big := hit.damage >= 30.0
	FloatingText.spawn(self, "%d" % roundi(hit.damage), hit.position + Vector3(randf_range(-0.3, 0.3), 0.6, 0.0),
			Color(1.0, 0.85, 0.3) if big else Color(1, 1, 1), 72 if big else 52)
	if health <= 0.0:
		_die()
	_update_bar()
	Events.hit_resolved.emit(hit.attacker, self, HitData.Result.HIT, amount, hit.position)
	return HitData.Result.HIT


## Status effects from cards (slow, burn). Shown as a tint and a word over the bar.
func apply_status(kind: StatusSet.Kind, duration: float, magnitude: float, source: Node3D) -> void:
	if dead:
		return
	var fresh := not statuses.has(kind)
	statuses.apply(kind, duration, magnitude, source)
	if fresh:
		FloatingText.spawn(self, StatusSet.NAMES[kind], global_position + Vector3.UP * 2.9, StatusSet.COLORS[kind], 44)


## Knockback from cards. Slowed dummies get pushed less far.
func push(v: Vector3) -> void:
	velocity += v * statuses.speed_mult()


func _die() -> void:
	dead = true
	_revive_left = revive_time
	FloatingText.spawn(self, "KO", global_position + Vector3.UP * 2.6, Color(1, 0.4, 0.3), 80)


func _physics_process(dt: float) -> void:
	if dead:
		_visual.rotation.x = move_toward(_visual.rotation.x, -PI * 0.5, dt * 6.0)
		_revive_left -= dt
		if _revive_left <= 0.0:
			dead = false
			health = max_health
			_visual.rotation = Vector3.ZERO
			_update_bar()
	if not is_on_floor():
		velocity.y -= gravity * dt
	else:
		var h := Vector3(velocity.x, 0.0, velocity.z).move_toward(Vector3.ZERO, ground_friction * dt)
		velocity.x = h.x
		velocity.z = h.z
	move_and_slide()
	statuses.tick(self, dt)
	var tint := statuses.tint()
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 6.0)
		_mat.emission = Color(1, 1, 1)
		_mat.emission_energy_multiplier = _flash * 2.0
	elif tint.a > 0.0:
		_mat.emission = tint
		var flicker := 0.5 + 0.5 * sin(Time.get_ticks_msec() * 0.02) if statuses.has(StatusSet.Kind.BURN) else 1.0
		_mat.emission_energy_multiplier = 0.6 + 0.6 * flicker
	else:
		_mat.emission_energy_multiplier = 0.0
	_update_bar()


func _update_bar() -> void:
	if _bar == null:
		return
	var n := 10
	var filled := ceili(health / max_health * n)
	var status := statuses.label()
	_bar.text = "%s%s\n%d / %d" % [status + "\n" if status != "" else "", "|".repeat(filled) + ".".repeat(n - filled), roundi(health), roundi(max_health)]
	_bar.modulate = Color(0.4, 1.0, 0.5).lerp(Color(1.0, 0.3, 0.25), 1.0 - health / max_health)


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.9
	shape.shape = cap
	shape.position.y = 0.95
	add_child(shape)
	_visual = Node3D.new()
	add_child(_visual)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = Color(1, 1, 1)
	_mat.emission_energy_multiplier = 0.0
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.4
	cm.height = 1.9
	body.mesh = cm
	body.material_override = _mat
	body.position.y = 0.95
	_visual.add_child(body)
	# A bullseye on the chest so it reads as "target", not "enemy".
	for ring in [[0.3, Color(0.9, 0.2, 0.2)], [0.2, Color(1, 1, 1)], [0.1, Color(0.9, 0.2, 0.2)]]:
		var disc := MeshInstance3D.new()
		var dm := CylinderMesh.new()
		dm.top_radius = ring[0]
		dm.bottom_radius = ring[0]
		dm.height = 0.02
		disc.mesh = dm
		var m := StandardMaterial3D.new()
		m.albedo_color = ring[1]
		disc.material_override = m
		disc.rotation.x = PI * 0.5
		disc.position = Vector3(0, 1.25, -0.4 - (0.3 - ring[0]) * 0.05)
		_visual.add_child(disc)
	_bar = Label3D.new()
	_bar.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_bar.font_size = 40
	_bar.outline_size = 8
	_bar.pixel_size = 0.006
	_bar.position.y = 2.35
	add_child(_bar)
