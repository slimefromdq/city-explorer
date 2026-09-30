class_name MeterRing
extends MeshInstance3D
## Ground ring on the character: outer arc = guard, middle pips = dodges,
## inner pips = air-dashes. Meters stay readable on the body in a crowd.

var fighter: Fighter
var _mat := ShaderMaterial.new()


func _ready() -> void:
	var q := QuadMesh.new()
	q.size = Vector2(2.7, 2.7)
	q.orientation = PlaneMesh.FACE_Y
	mesh = q
	_mat.shader = load("res://shaders/meter_ring.gdshader")
	_mat.render_priority = 2
	material_override = _mat
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0, 0.06, 0)


func _process(_dt: float) -> void:
	if fighter == null:
		return
	visible = fighter.alive
	_mat.set_shader_parameter("guard", fighter.guard.fraction())
	_mat.set_shader_parameter("dodge_charges", fighter.dodge.pool.charges)
	_mat.set_shader_parameter("dash_charges", fighter.loco.dash_pool.charges)
	_mat.set_shader_parameter("flash", fighter.guard.flash)
	_mat.set_shader_parameter("blocking", 1.0 if fighter.guard.blocking else 0.0)
	_mat.set_shader_parameter("stunned", 1.0 if fighter.stun_left > 0.0 else 0.0)
	_mat.set_shader_parameter("threat", fighter.bounty.threat())
