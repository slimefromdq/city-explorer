class_name Pickup
extends Area3D
## Street-level health orb. Cheap "pull the fight down" bait: a reason to
## walk out of the sky. Respawns after a delay.

@export var heal := 30.0
@export var respawn_time := 18.0

var _mesh: MeshInstance3D
var _t := 0.0
var _active := true


func _ready() -> void:
	collision_layer = 0
	collision_mask = Fighter.LAYER_FIGHTER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.2
	cs.shape = s
	cs.position = Vector3(0, 1.0, 0)
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.32
	m.height = 0.64
	m.radial_segments = 10
	m.rings = 5
	_mesh.mesh = m
	_mesh.material_override = Mats.glow(Color(0.35, 1.0, 0.55), 4.0)
	_mesh.position = Vector3(0, 1.0, 0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	var beam := MeshInstance3D.new()
	var b := CylinderMesh.new()
	b.top_radius = 0.08
	b.bottom_radius = 0.08
	b.height = 6.0
	b.radial_segments = 6
	beam.mesh = b
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.albedo_color = Color(0.35, 1.0, 0.55, 0.25)
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beam.material_override = bm
	beam.position = Vector3(0, 3.0, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	body_entered.connect(_on_body)


func _process(dt: float) -> void:
	_t += dt
	if _active:
		_mesh.position.y = 1.0 + sin(_t * 2.5) * 0.12
		_mesh.rotation.y += dt * 1.5


func _on_body(b: Node3D) -> void:
	var f := b as Fighter
	if not _active or f == null or not f.alive or f.health >= f.max_health:
		return
	f.health = minf(f.max_health, f.health + heal)
	Events.popup.emit("+%d" % int(heal), f.global_position + Vector3.UP * 2.3, Color(0.4, 1.0, 0.55))
	_active = false
	_mesh.visible = false
	get_tree().create_timer(respawn_time).timeout.connect(func() -> void:
		_active = true
		_mesh.visible = true)
