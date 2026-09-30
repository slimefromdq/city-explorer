class_name Rain
extends CPUParticles3D
## Light rain that follows the camera. Purely mood: it sells the wet streets.

var follow: Node3D


func _ready() -> void:
	amount = 1800
	lifetime = 1.1
	emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	emission_box_extents = Vector3(38, 0.5, 38)
	direction = Vector3(0.12, -1, 0.05)
	spread = 2.0
	initial_velocity_min = 42.0
	initial_velocity_max = 50.0
	gravity = Vector3.ZERO
	local_coords = false
	var bm := BoxMesh.new()
	bm.size = Vector3(0.012, 0.9, 0.012)
	mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.75, 0.85, 1.0, 0.35)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material_override = m
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	visibility_aabb = AABB(Vector3(-60, -40, -60), Vector3(120, 80, 120))


func _process(_dt: float) -> void:
	if follow != null:
		global_position = follow.global_position + Vector3(0, 22, 0)
