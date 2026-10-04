class_name HeroModel
extends Node3D
## Placeholder body built from primitive meshes: a torso, a head, a visor that
## shows which way the hero faces, a belt, and a guard shield that appears
## while blocking. M3's outfit slots (head, top, bottom, tint) will replace
## these parts; nothing outside this script cares what the model looks like.
##
## Everything visual about the hero's state goes through here: crouch squash,
## dash charge glow, roll tumble, hit flash, stun tint, guard shield.

@export var body_color := Color(0.22, 0.32, 0.55)
@export var accent_color := Color(1.0, 0.62, 0.25)
@export var guard_color := Color(0.45, 0.75, 1.0)
@export var perfect_guard_color := Color(1.0, 0.85, 0.25)

const PIVOT_HEIGHT := 0.6

var _pivot := Node3D.new()     # rotation point for the roll tumble (body centre)
var _parts := Node3D.new()     # all body meshes, offset so the feet sit at y = 0
var _crouched := false
var _charge := 0.0
var _flash := 0.0
var _body_mat: StandardMaterial3D
var _accent_mat: StandardMaterial3D
var _shield: MeshInstance3D
var _shield_mat: StandardMaterial3D
var _stunned := false


func _ready() -> void:
	add_child(_pivot)
	_pivot.position.y = PIVOT_HEIGHT
	_pivot.add_child(_parts)
	_parts.position.y = -PIVOT_HEIGHT
	_body_mat = _mat(body_color)
	_body_mat.emission_enabled = true
	_body_mat.emission_energy_multiplier = 0.0
	_accent_mat = _mat(accent_color)
	_accent_mat.emission_enabled = true
	_accent_mat.emission = accent_color
	_accent_mat.emission_energy_multiplier = 0.0
	var cap := CapsuleMesh.new()
	cap.radius = 0.28
	cap.height = 1.25
	_add_part(cap, _body_mat, Vector3(0, 0.72, 0))
	var sphere := SphereMesh.new()
	sphere.radius = 0.2
	sphere.height = 0.4
	_add_part(sphere, _body_mat, Vector3(0, 1.55, 0))
	var visor := BoxMesh.new()      # on the -Z side: Godot's "forward"
	visor.size = Vector3(0.3, 0.1, 0.12)
	_add_part(visor, _accent_mat, Vector3(0, 1.58, -0.17))
	var belt := CylinderMesh.new()
	belt.top_radius = 0.3
	belt.bottom_radius = 0.3
	belt.height = 0.08
	_add_part(belt, _accent_mat, Vector3(0, 0.85, 0))
	# Guard shield: a translucent disc in front of the chest, shown while blocking.
	var disc := CylinderMesh.new()
	disc.top_radius = 0.7
	disc.bottom_radius = 0.7
	disc.height = 0.04
	_shield_mat = StandardMaterial3D.new()
	_shield_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shield_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shield_mat.albedo_color = Color(guard_color, 0.35)
	_shield_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shield = _add_part(disc, _shield_mat, Vector3(0, 1.05, -0.55))
	_shield.rotation.x = PI * 0.5
	_shield.visible = false


func _add_part(mesh: Mesh, mat: Material, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	_parts.add_child(mi)
	return mi


func _process(dt: float) -> void:
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 5.0)
		_body_mat.emission_energy_multiplier = _flash * 3.0


## Squash the body while crouched so the short capsule is visible.
func set_crouched(on: bool) -> void:
	if on == _crouched:
		return
	_crouched = on
	_apply_scale()


## 0..1 glow on the accent parts: the sigil leap windup tell (held at 1 during
## the launch).
func set_charge(k: float) -> void:
	if is_equal_approx(k, _charge):
		return
	_charge = k
	_accent_mat.emission_energy_multiplier = k * 6.0
	_apply_scale()


## 0..1 progress through a roll: one forward tumble.
func set_roll(k: float) -> void:
	_pivot.rotation.x = -k * TAU if k > 0.0 and k < 1.0 else 0.0


## Brief full-body flash in the colour of what just happened to us.
func flash(color: Color) -> void:
	_body_mat.emission = color
	_flash = 1.0
	_body_mat.emission_energy_multiplier = 3.0


func set_stunned(on: bool) -> void:
	_stunned = on
	_body_mat.albedo_color = body_color.darkened(0.45) if on else body_color
	_pivot.rotation.z = 0.25 if on else 0.0


func set_guard(up: bool, perfect: bool) -> void:
	_shield.visible = up
	if up:
		_shield_mat.albedo_color = Color(perfect_guard_color, 0.55) if perfect else Color(guard_color, 0.35)


func _apply_scale() -> void:
	var pulse := 1.0 + 0.08 * _charge
	_parts.scale = Vector3(pulse, (0.62 if _crouched else 1.0) * pulse, pulse)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.6
	return m
