class_name VFX
extends RefCounted
## Tiny stateless effect spawners. Everything is one-shot and frees itself.

static var _spark_mesh: SphereMesh
static var _glow_mat: StandardMaterial3D


static func _glow(color: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	return m


static func spark(tree: SceneTree, pos: Vector3, normal: Vector3, color: Color, amount := 10, speed := 6.0) -> void:
	if _spark_mesh == null:
		_spark_mesh = SphereMesh.new()
		_spark_mesh.radius = 0.04
		_spark_mesh.height = 0.08
		_spark_mesh.radial_segments = 6
		_spark_mesh.rings = 3
	var p := CPUParticles3D.new()
	p.mesh = _spark_mesh
	p.material_override = _glow(color)
	p.one_shot = true
	p.emitting = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = 0.35
	p.direction = normal
	p.spread = 55.0
	p.initial_velocity_min = speed * 0.4
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -12, 0)
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(p)
	p.global_position = pos
	tree.create_timer(0.8).timeout.connect(p.queue_free)


## Flat expanding ring, used for guard-break and dodge feedback.
static func ring_pulse(tree: SceneTree, pos: Vector3, color: Color, radius := 2.0, time := 0.35) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.42
	t.outer_radius = 0.5
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	mi.material_override = _glow(color)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.3
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, time).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, time)
	(mi.material_override as StandardMaterial3D).transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	tw.chain().tween_callback(mi.queue_free)


## Translucent ghost of the character silhouette (speed afterimage).
static func ghost(tree: SceneTree, xf: Transform3D, color: Color, life: float) -> void:
	var mi := MeshInstance3D.new()
	var c := CapsuleMesh.new()
	c.radius = 0.32
	c.height = 1.75
	c.radial_segments = 10
	c.rings = 3
	mi.mesh = c
	var m := _glow(color)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	tree.current_scene.add_child(mi)
	mi.global_transform = xf
	var tw := mi.create_tween().set_parallel(true)
	tw.tween_property(m, "albedo_color:a", 0.0, life)
	tw.tween_property(mi, "scale", Vector3(0.6, 1.0, 0.6), life)
	tw.chain().tween_callback(mi.queue_free)
