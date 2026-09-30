class_name Nameplate
extends Node3D
## Small health bar + name + bounty above the head. Deliberately small and
## placed just over the hat so street-level combat stays readable.

var fighter: Fighter
var _bar: MeshInstance3D
var _mat := ShaderMaterial.new()
var _name: Label3D
var _bounty: Label3D


func _ready() -> void:
	position = Vector3(0, 2.35, 0)
	_bar = MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 0.1)
	_bar.mesh = q
	_mat.shader = load("res://shaders/nameplate.gdshader")
	_bar.material_override = _mat
	_bar.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_bar)
	_name = _label(0.2, 18)
	_bounty = _label(0.4, 14)
	_bounty.modulate = Color(1.0, 0.85, 0.35)


func _label(y: float, size: int) -> Label3D:
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.fixed_size = true
	l.pixel_size = 0.0009
	l.font_size = size * 2
	l.outline_size = 8
	l.no_depth_test = false
	l.position = Vector3(0, y, 0)
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(l)
	return l


func set_name_text(t: String) -> void:
	if _name != null:
		_name.text = t


func _process(_dt: float) -> void:
	if fighter == null:
		return
	visible = fighter.alive and not fighter.is_in_group(&"local_player")
	var h := clampf(fighter.health / fighter.max_health, 0.0, 1.0)
	_mat.set_shader_parameter("health", h)
	_mat.set_shader_parameter("fill", Color(1.0, 0.35, 0.3).lerp(Color(0.4, 1.0, 0.5), h))
	_bounty.text = "x%d   $%d" % [fighter.bounty.streak, fighter.bounty.value()] if fighter.bounty.streak > 0 else ""
