class_name CardBody
extends RigidBody3D
## The physical thing a card throws (ball, grenade, bug). Built entirely from
## the card's CardBodyDef, so one script covers every body.
##
## It flies on Godot physics and reports two moments back to the caster's
## runner, which runs the card's effect lists:
##   contact - touched something (world or a target)    -> ON CONTACT
##   expire  - its life is over                         -> ON EXPIRE
## What happens after a contact depends on the properties:
##   sticky  -> glue to it, blink, expire after stick_fuse
##   spiky   -> pass through targets (up to spiky_pierce), stop on the world
##   bouncy  -> spend a bounce and keep flying; expire when out of bounces
##   none    -> expire right away

const LAYER_CARD_BODY := 1 << 4   # physics layer 5 "card_body"
const TRAIL_EVERY := 0.03

var def: CardBodyDef
var ctx: CastContext              # the cast this body belongs to
var bounces_left := 0
var pierces_left := 0
var life_left := 4.0
var stuck := false
var expired := false

var _touching := {}               # collider id -> true, so one long contact counts once
var _trail_t := 0.0
var _mat: StandardMaterial3D
var _blink_t := 0.0


## Throw a body for `cast` from its position, flying with `velocity`.
static func spawn(cast: CastContext, dir: Vector3, velocity: Vector3) -> CardBody:
	var parent: Node = cast.caster.get_tree().current_scene
	var b := CardBody.new()
	b.def = cast.card.body
	b.ctx = cast.copy()
	b.ctx.direction = dir
	b.ctx.body = b
	b._build()
	parent.add_child(b)
	b.global_position = cast.position + dir * (b.def.radius + 0.05)
	b.linear_velocity = velocity
	if cast.caster is PhysicsBody3D:
		b.add_collision_exception_with(cast.caster)
	return b


func _build() -> void:
	collision_layer = LAYER_CARD_BODY
	collision_mask = CardEffect.LAYER_WORLD | CardEffect.LAYER_CHARACTER
	contact_monitor = true
	max_contacts_reported = 6
	continuous_cd = true
	can_sleep = false
	gravity_scale = def.gravity_scale * (def.heavy_mult if def.heavy else 1.0)
	mass = 0.5 * (def.heavy_mult * 2.0 if def.heavy else 1.0)
	var pm := PhysicsMaterial.new()
	pm.bounce = def.bounciness if def.bounces > 0 else 0.0
	pm.friction = 0.6
	physics_material_override = pm
	bounces_left = def.bounces
	pierces_left = def.spiky_pierce if def.spiky else 0
	life_left = def.lifetime

	var cs := CollisionShape3D.new()
	var ss := SphereShape3D.new()
	ss.radius = def.radius
	cs.shape = ss
	add_child(cs)

	var color := ctx.card.color
	if def.heavy:
		color = color.darkened(0.35)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = color
	_mat.emission_enabled = true
	_mat.emission = ctx.card.color
	_mat.emission_energy_multiplier = 1.2
	_mat.metallic = 0.7 if def.heavy else 0.0
	_mat.roughness = 0.35
	var r := def.radius
	match def.shape:
		CardBodyDef.Shape.BALL:
			_mesh(_sphere(r), Vector3.ZERO, Vector3.ONE)
			_mesh(_torus(r * 1.02, 0.12 * r), Vector3.ZERO, Vector3.ONE, Color(1, 1, 1))   # a stripe so spin is visible
		CardBodyDef.Shape.GRENADE:
			_mesh(_sphere(r), Vector3.ZERO, Vector3.ONE)
			_mesh(_box(Vector3(r * 0.7, r * 0.5, r * 0.7)), Vector3(0, r * 0.95, 0), Vector3.ONE, Color(0.15, 0.15, 0.15))
		CardBodyDef.Shape.BUG:
			_mesh(_sphere(r), Vector3.ZERO, Vector3(1.0, 0.6, 1.3))
			for side in [-1.0, 1.0]:
				for j in 3:
					var leg := _mesh(_box(Vector3(r * 0.9, r * 0.12, r * 0.12)), Vector3(side * r * 0.95, -r * 0.25, (j - 1) * r * 0.55), Vector3.ONE, Color(0.1, 0.1, 0.1))
					leg.rotation.z = side * 0.5
			for side in [-1.0, 1.0]:
				_mesh(_sphere(r * 0.18), Vector3(side * r * 0.35, r * 0.25, -r * 1.15), Vector3.ONE, Color(1, 1, 0.6))
	if def.spiky:
		for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
			var spike := _mesh(_cone(r * 0.3, r * 0.9), d * r * 1.1, Vector3.ONE, Color(0.9, 0.9, 0.95))
			if absf(d.y) < 0.5:
				spike.look_at_from_position(spike.position, spike.position + d, Vector3.UP)
				spike.rotate_object_local(Vector3.RIGHT, -PI * 0.5)
			elif d.y < 0.0:
				spike.rotation.x = PI
	var light := OmniLight3D.new()
	light.light_color = ctx.card.color
	light.omni_range = 2.5
	light.light_energy = 1.2
	add_child(light)


func _physics_process(dt: float) -> void:
	if expired:
		return
	life_left -= dt
	if life_left <= 0.0:
		expire()
		return
	if stuck:
		# Blink faster as the fuse runs out: the "about to go off" tell.
		_blink_t += dt * lerpf(6.0, 22.0, 1.0 - life_left / maxf(def.stick_fuse, 0.01))
		_mat.emission_energy_multiplier = 0.5 + 3.5 * (0.5 + 0.5 * sin(_blink_t * TAU))
		if not is_instance_valid(get_parent()):
			expire()
		return
	_trail_t += dt
	if _trail_t >= TRAIL_EVERY and linear_velocity.length() > 2.0:
		_trail_t = 0.0
		CardFx.puff(self, global_position, ctx.card.color, def.radius * 0.6)


func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	if expired or stuck:
		return
	var now := {}
	for i in state.get_contact_count():
		var obj := state.get_contact_collider_object(i)
		if obj == null:
			continue
		var id := obj.get_instance_id()
		now[id] = true
		if _touching.has(id):
			continue
		_touching[id] = true
		var pos := state.get_contact_collider_position(i)
		var n := state.get_contact_local_normal(i)
		_on_contact.call_deferred(obj as Node3D, pos, n)
	_touching = now


func _on_contact(other: Node3D, pos: Vector3, n: Vector3) -> void:
	if expired or stuck or not is_instance_valid(self):
		return
	var target: Node3D = null
	if other != null and is_instance_valid(other) and other.has_method(&"take_hit"):
		target = other
	var c := ctx.copy()
	c.position = global_position
	c.normal = n
	c.target = target
	c.direction = linear_velocity.normalized() if linear_velocity.length() > 0.1 else ctx.direction
	if ctx.runner != null and is_instance_valid(ctx.runner):
		ctx.runner.run_list(ctx.card.on_contact, c, &"on_contact")
	if expired:
		return   # an effect (e.g. teleport-to-body) may have ended us
	if def.sticky:
		_stick(other)
	elif target != null and pierces_left > 0:
		pierces_left -= 1
		add_collision_exception_with(target)   # pass through it
		linear_velocity = c.direction * maxf(linear_velocity.length(), def.speed * 0.8)
	elif bounces_left > 0:
		bounces_left -= 1
		Sfx.play_at_pos(self, global_position, PlaceholderSfx.sweep("boing", 300.0, 520.0, 0.12, 0.3, 0.0))
		CardFx.flash(self, global_position, ctx.card.color, def.radius * 2.0)
	else:
		expire()


## Glue to whatever we hit; moving targets carry us along.
func _stick(other: Node3D) -> void:
	stuck = true
	life_left = def.stick_fuse
	freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
	set_deferred(&"freeze", true)
	collision_layer = 0
	collision_mask = 0
	linear_velocity = Vector3.ZERO
	Sfx.play_at_pos(self, global_position, PlaceholderSfx.sweep("stick", 200.0, 120.0, 0.08, 0.35, 0.5))
	if other != null and is_instance_valid(other) and other is Node3D and not other is StaticBody3D and not other is CSGShape3D:
		reparent.call_deferred(other, true)


## End of life: run ON EXPIRE where we are, then vanish.
func expire() -> void:
	if expired:
		return
	expired = true
	var c := ctx.copy()
	c.position = global_position
	c.target = null
	if ctx.runner != null and is_instance_valid(ctx.runner):
		ctx.runner.run_list(ctx.card.on_expire, c, &"on_expire")
	queue_free()


# ------------------------------------------------------------------ mesh bits

func _mesh(m: Mesh, pos: Vector3, scl: Vector3, tint := Color(0, 0, 0, 0)) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.position = pos
	mi.scale = scl
	if tint.a > 0.0:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = tint
		mi.material_override = mat
	else:
		mi.material_override = _mat
	add_child(mi)
	return mi


func _sphere(r: float) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	return s


func _box(size: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = size
	return b


func _torus(r: float, thickness: float) -> TorusMesh:
	var t := TorusMesh.new()
	t.inner_radius = r - thickness
	t.outer_radius = r + thickness
	return t


func _cone(r: float, h: float) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = 0.0
	c.bottom_radius = r
	c.height = h
	return c
