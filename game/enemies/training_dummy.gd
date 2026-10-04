class_name TrainingDummy
extends StaticBody3D
## A stationary training dummy that attacks the player hero, so roll and block
## have something to answer. Each dummy has ONE attack, chosen in the Inspector,
## and every attack is telegraphed by colour so you can read what to do:
##   SWING  (orange) - melee in front of it. Blockable; perfect-block it to stagger it.
##   SHOOT  (yellow) - fires a slow orb. Block it or roll through it.
##   SLAM   (purple) - ground slam around it, UNBLOCKABLE. Roll out or through it.
##   NONE           - a punching bag that never attacks.
## The danger zone of a swing/slam is drawn on the ground during the windup.

enum Attack { NONE, SWING, SHOOT, SLAM }

const SWING_COLOR := Color(1.0, 0.55, 0.15)
const SHOOT_COLOR := Color(1.0, 0.85, 0.25)
const SLAM_COLOR := Color(0.7, 0.3, 1.0)

@export var display_name := "Dummy"
@export var attack: Attack = Attack.SWING
## Only attacks while the player hero is within this distance.
@export var aggro_range := 6.0
## Seconds between attacks (after the previous one lands).
@export var interval := 2.2
## Telegraph length: how long the tell shows before the attack lands.
@export var windup := 0.6
@export var damage := 12.0
@export var guard_damage := 30.0
@export var knockback := 6.0
## How long a clean hit stuns the hero.
@export var flinch := 0.25
## Melee reach for SWING, radius for SLAM.
@export var reach := 3.2
@export var projectile_speed := 14.0
@export var turn_speed := 5.0
## After a perfect block, the dummy is stunned this long.
@export var stagger_time := 1.2
@export var active := true

enum Phase { IDLE, WINDUP, STAGGERED }
var phase := Phase.IDLE
var _cd := 1.0
var _t := 0.0
var _target: Hero
var _body_mat: StandardMaterial3D
var _tell_mat: StandardMaterial3D
var _arm: Node3D
var _zone: MeshInstance3D
var _zone_mat: StandardMaterial3D
var _label: Label3D


func _ready() -> void:
	collision_layer = Hero.LAYER_WORLD
	collision_mask = 0
	add_to_group(&"dummies")
	_build()


func _color() -> Color:
	match attack:
		Attack.SWING:
			return SWING_COLOR
		Attack.SHOOT:
			return SHOOT_COLOR
		Attack.SLAM:
			return SLAM_COLOR
	return Color(0.6, 0.6, 0.6)


func _physics_process(dt: float) -> void:
	_t += dt
	if not active or attack == Attack.NONE:
		return
	if _target == null or not is_instance_valid(_target):
		_target = get_tree().get_first_node_in_group(&"player_hero") as Hero
		if _target == null:
			return
	match phase:
		Phase.STAGGERED:
			_body_mat.albedo_color = Color(1.0, 0.85, 0.3).lerp(Color(0.55, 0.5, 0.45), clampf(_t / stagger_time, 0, 1))
			rotation.z = sin(_t * 20.0) * 0.08 * (1.0 - _t / stagger_time)
			if _t >= stagger_time:
				rotation.z = 0.0
				_to_idle()
		Phase.IDLE:
			_face_target(dt, 1.0)
			_cd -= dt
			if _cd <= 0.0 and _in_range() and not _target.defense.dead:
				_start_windup()
		Phase.WINDUP:
			# Track the target early in the windup, then lock in (so it can be dodged).
			if _t < windup * 0.6:
				_face_target(dt, 1.0)
			var k := clampf(_t / windup, 0.0, 1.0)
			_tell_mat.emission_energy_multiplier = 0.6 + k * 2.4
			_arm.rotation.x = lerpf(0.0, 1.3, k)
			if _zone != null:
				_zone.visible = true
				_zone_mat.albedo_color.a = 0.15 + 0.35 * k
			if _t >= windup:
				_strike()


func _in_range() -> bool:
	return global_position.distance_to(_target.global_position) <= aggro_range


func _face_target(dt: float, mult: float) -> void:
	var d := _target.global_position - global_position
	if Vector2(d.x, d.z).length() < 0.1:
		return
	var want := atan2(-d.x, -d.z)
	rotation.y = lerp_angle(rotation.y, want, minf(1.0, turn_speed * mult * dt))


func _start_windup() -> void:
	phase = Phase.WINDUP
	_t = 0.0
	_label.text = "!"
	_label.visible = true
	Sfx.play_at(self, PlaceholderSfx.sweep("windup_%d" % attack, 300.0, 600.0, windup * 0.9, 0.3, 0.15))


func _strike() -> void:
	var hit := HitData.new()
	hit.attacker = self
	hit.damage = damage
	hit.guard_damage = guard_damage
	hit.flinch = flinch
	var to_target := _target.global_position - global_position
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	hit.from_dir = -flat.normalized() if flat.length() > 0.01 else Vector3.FORWARD
	hit.knockback = flat.normalized() * knockback + Vector3.UP * knockback * 0.25
	hit.position = _target.global_position + Vector3.UP
	var result := -1
	match attack:
		Attack.SWING:
			var fwd := -global_basis.z
			if flat.length() <= reach and fwd.dot(flat.normalized()) > 0.3:
				result = _target.take_hit(hit)
			Sfx.play_at(self, PlaceholderSfx.sweep("swing", 500.0, 200.0, 0.15, 0.35, 0.8))
		Attack.SHOOT:
			var muzzle := global_position + Vector3.UP * 1.4 - global_basis.z * 0.6
			var aim := (_target.global_position + Vector3.UP * 1.0) - muzzle
			DummyProjectile.create(self, muzzle, aim, projectile_speed, hit)
			Sfx.play_at(self, PlaceholderSfx.sweep("shoot", 900.0, 400.0, 0.12, 0.3, 0.3))
		Attack.SLAM:
			hit.blockable = false
			hit.weight = HitData.Weight.HEAVY
			hit.knockback = flat.normalized() * knockback * 1.5 + Vector3.UP * knockback * 0.6
			if flat.length() <= reach and absf(to_target.y) < 2.5:
				result = _target.take_hit(hit)
			Sfx.play_at(self, PlaceholderSfx.sweep("slam", 160.0, 50.0, 0.4, 0.6, 0.7))
			Events.camera_shake.emit(0.3)
	if result == HitData.Result.PERFECT_BLOCK:
		stagger()
	else:
		_to_idle()


## Knocked off balance by a perfect block: can't attack for stagger_time.
func stagger() -> void:
	phase = Phase.STAGGERED
	_t = 0.0
	_reset_tell()
	_label.text = "STAGGERED"
	_label.visible = true
	FloatingText.spawn(self, "STAGGERED", global_position + Vector3.UP * 2.6, Color(1.0, 0.85, 0.2), 48)


func _to_idle() -> void:
	phase = Phase.IDLE
	_t = 0.0
	_cd = interval
	_reset_tell()
	_label.visible = false
	_body_mat.albedo_color = Color(0.55, 0.5, 0.45)


func _reset_tell() -> void:
	_tell_mat.emission_energy_multiplier = 0.6
	_arm.rotation.x = 0.0
	if _zone != null:
		_zone.visible = false


func _build() -> void:
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.45
	cap.height = 2.0
	shape.shape = cap
	shape.position.y = 1.0
	add_child(shape)
	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = Color(0.55, 0.5, 0.45)
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 0.45
	cm.height = 2.0
	body.mesh = cm
	body.material_override = _body_mat
	body.position.y = 1.0
	add_child(body)
	_tell_mat = StandardMaterial3D.new()
	_tell_mat.albedo_color = _color()
	_tell_mat.emission_enabled = true
	_tell_mat.emission = _color()
	_tell_mat.emission_energy_multiplier = 0.6
	# A coloured band and a face plate in the attack colour.
	var band := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.47
	bm.bottom_radius = 0.47
	bm.height = 0.18
	band.mesh = bm
	band.material_override = _tell_mat
	band.position.y = 1.5
	add_child(band)
	var face := MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(0.4, 0.15, 0.1)
	face.mesh = fm
	face.material_override = _tell_mat
	face.position = Vector3(0, 1.75, -0.42)
	add_child(face)
	# The "arm": rises during the windup.
	_arm = Node3D.new()
	_arm.position = Vector3(0.5, 1.3, 0)
	add_child(_arm)
	var arm_mesh := MeshInstance3D.new()
	var am := BoxMesh.new()
	am.size = Vector3(0.18, 0.18, 1.0)
	arm_mesh.mesh = am
	arm_mesh.material_override = _tell_mat
	arm_mesh.position = Vector3(0, 0, -0.5)
	_arm.add_child(arm_mesh)
	# Ground danger zone (a disc of radius `reach`) shown during the windup.
	if attack == Attack.SWING or attack == Attack.SLAM:
		_zone = MeshInstance3D.new()
		var zm := CylinderMesh.new()
		zm.top_radius = reach
		zm.bottom_radius = reach
		zm.height = 0.02
		_zone.mesh = zm
		_zone_mat = StandardMaterial3D.new()
		_zone_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_zone_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_zone_mat.albedo_color = Color(_color(), 0.2)
		_zone.material_override = _zone_mat
		_zone.position.y = 0.03
		_zone.visible = false
		add_child(_zone)
	_label = Label3D.new()
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.font_size = 96
	_label.outline_size = 16
	_label.pixel_size = 0.006
	_label.modulate = _color()
	_label.position.y = 2.6
	_label.visible = false
	add_child(_label)
	var name_label := Label3D.new()
	name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_label.text = display_name
	name_label.font_size = 40
	name_label.outline_size = 8
	name_label.pixel_size = 0.006
	name_label.position.y = 2.25
	add_child(name_label)
