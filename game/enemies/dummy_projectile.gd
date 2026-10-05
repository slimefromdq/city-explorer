class_name DummyProjectile
extends Area3D
## A slow, glowing orb fired by a shooter dummy. Flies straight; hits the hero
## (block it or roll through it) or pops on the world.

var velocity := Vector3.ZERO
var hit: HitData
var source: Node3D
var life := 4.0


static func create(p_source: Node3D, from: Vector3, dir: Vector3, speed: float, p_hit: HitData) -> DummyProjectile:
	var p := DummyProjectile.new()
	p.source = p_source
	p.velocity = dir.normalized() * speed
	p.hit = p_hit
	var parent: Node = p_source.get_parent()
	parent.add_child(p)
	p.global_position = from
	return p


func _ready() -> void:
	collision_layer = 0
	collision_mask = Hero.LAYER_WORLD | Hero.LAYER_CHARACTER
	monitoring = true
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.25
	shape.shape = sphere
	add_child(shape)
	var mesh := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	mesh.mesh = sm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(1.0, 0.85, 0.3)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.75, 0.2)
	mat.emission_energy_multiplier = 4.0
	mesh.material_override = mat
	add_child(mesh)
	var light := OmniLight3D.new()
	light.light_color = Color(1.0, 0.8, 0.3)
	light.omni_range = 3.0
	light.light_energy = 1.5
	add_child(light)
	body_entered.connect(_on_body_entered)


func _physics_process(dt: float) -> void:
	global_position += velocity * dt
	life -= dt
	if life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body == source:
		return
	if body is Hero:
		hit.position = global_position
		hit.from_dir = -velocity.normalized()
		var result := (body as Hero).take_hit(hit)
		if result == HitData.Result.PERFECT_BLOCK and source is TrainingDummy and is_instance_valid(source):
			(source as TrainingDummy).stagger()
		if result == HitData.Result.DODGED:
			return   # rolled through it: let it fly on
	queue_free()
