class_name Shard
extends Area3D
## Sky Shard: an exploration collectible placed on hard-to-reach spots (roof
## tops, tower ledges, tree crowns, girders). Collecting refills the dash pool
## and pays score, so hunting them feeds the parkour loop.

static var collected := 0
static var total := 0

var _mesh: MeshInstance3D
var _t := 0.0
var _taken := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = Fighter.LAYER_FIGHTER
	var cs := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 1.7
	cs.shape = s
	add_child(cs)
	_mesh = MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.55
	m.height = 1.5
	m.radial_segments = 4
	m.rings = 2
	_mesh.mesh = m
	_mesh.material_override = Mats.glow(Color(0.35, 0.9, 1.0), 5.0)
	_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mesh)
	body_entered.connect(_on_body)
	_t = randf() * TAU


func _process(dt: float) -> void:
	_t += dt
	_mesh.position.y = sin(_t * 2.0) * 0.18
	_mesh.rotation.y += dt * 1.8


func _on_body(b: Node3D) -> void:
	var f := b as Fighter
	if _taken or f == null or not f.alive or not f.is_in_group(&"local_player"):
		return
	_taken = true
	collected += 1
	f.loco.dash_pool.fill()
	f.bounty.score += 50
	f.bounty.changed.emit()
	Events.popup.emit("SKY SHARD  %d / %d" % [collected, total], global_position + Vector3.UP * 1.5, Color(0.5, 0.95, 1.0))
	Events.shard_collected.emit(collected, total)
	VFX.ring_pulse(get_tree(), global_position, Color(0.4, 0.9, 1.0), 3.0, 0.5)
	queue_free()
