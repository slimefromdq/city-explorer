class_name Projectile
extends Node3D
## Swept-ray projectile. Every physics step it ray-casts from last to next
## position, so even the 260 m/s Snapshot can't tunnel. Handles falloff,
## ricochet bounces, dodge pass-through and a "missed" callback that skills use
## to hand out miss penalties.

const MASK := Fighter.LAYER_WORLD | Fighter.LAYER_HURTBOX

var attacker: Fighter
var velocity := Vector3.ZERO
var life := 2.0
var damage := 6.0
var guard_damage := 5.0
var weight: HitData.Weight = HitData.Weight.LIGHT
var blockable := true
var dodgeable := true
var flinch := 0.0
var knockback_force := 0.0
var falloff_start := 1000.0            # metres travelled before damage fades
var falloff_end := 1000.0
var falloff_min := 1.0
var bounces := 0
var bounce_speed_mult := 1.15
var bounce_damage_mult := 0.7
var bounce_guard_mult := 0.4
var bounce_dodgeable := true           # false: after a bounce, i-frames won't save you
var tag: StringName = &"bullet"
var color := Color(1.0, 0.85, 0.4)
var radius := 0.06
var trail_width := 0.14
var trail_life := 0.12
var on_finish: Callable = Callable()   # called with (hit_someone: bool)

var _travelled := 0.0
var _ignore: Array[RID] = []
var _done := false
var _did_hit := false
var _bounced := false
var _trail: Trail3D


func _ready() -> void:
	add_to_group(&"projectiles")
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = radius
	s.height = radius * 2.0
	s.radial_segments = 8
	s.rings = 4
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	_trail = Trail3D.new()
	_trail.width = trail_width
	_trail.lifetime = trail_life
	_trail.color = color
	_trail.min_step = 0.2
	add_child(_trail)
	if attacker != null:
		_ignore.append(attacker.hurtbox.get_rid())


func _physics_process(dt: float) -> void:
	if _done:
		return
	var from := global_position
	var step := velocity * dt
	var to := from + step
	life -= dt
	var space := get_world_3d().direct_space_state
	var remaining := 4
	while remaining > 0:
		remaining -= 1
		var q := PhysicsRayQueryParameters3D.create(from, to, MASK)
		q.collide_with_areas = true
		q.exclude = _ignore
		var r := space.intersect_ray(q)
		if r.is_empty():
			break
		var collider := r.collider as Object
		if collider is Hurtbox:
			var victim := (collider as Hurtbox).fighter
			var res := _hit_fighter(victim, r.position)
			if res == HitData.Result.DODGED:
				_ignore.append((collider as Hurtbox).get_rid())
				continue
			_did_hit = true
			_impact(r.position, r.normal, true)
			return
		# world
		if bounces > 0:
			var n: Vector3 = r.normal
			velocity = velocity.bounce(n) * bounce_speed_mult
			bounces -= 1
			_bounced = true
			VFX.spark(get_tree(), r.position, n, color, 8, 5.0)
			from = r.position + n * 0.05
			to = from + velocity.normalized() * maxf(0.0, to.distance_to(r.position))
			global_position = from
			_trail.push(from)
			continue
		_impact(r.position, r.normal, false)
		return
	global_position = to
	_travelled += step.length()
	_trail.push(to)
	if life <= 0.0:
		_finish()


func _hit_fighter(victim: Fighter, pos: Vector3) -> HitData.Result:
	var h := HitData.new()
	h.attacker = attacker
	var fall := 1.0
	if _travelled > falloff_start:
		fall = lerpf(1.0, falloff_min, clampf((_travelled - falloff_start) / maxf(falloff_end - falloff_start, 0.01), 0.0, 1.0))
	h.damage = damage * fall * (bounce_damage_mult if _bounced else 1.0)
	h.guard_damage = guard_damage * (bounce_guard_mult if _bounced else 1.0)
	h.weight = weight
	h.blockable = blockable
	h.dodgeable = dodgeable and not (_bounced and not bounce_dodgeable)
	h.flinch = flinch
	h.from_dir = -velocity.normalized()
	h.knockback = velocity.normalized() * knockback_force
	h.position = pos
	h.tag = tag
	return victim.receive_hit(h)


func _impact(pos: Vector3, normal: Vector3, hit_fighter: bool) -> void:
	VFX.spark(get_tree(), pos, normal, color, 6 if hit_fighter else 10, 4.0)
	global_position = pos
	_trail.push(pos)
	_finish()


func _finish() -> void:
	_done = true
	if on_finish.is_valid():
		on_finish.call(_did_hit)
	# leave the trail to fade out on its own
	if _trail != null:
		_trail.reparent(get_tree().current_scene)
		get_tree().create_timer(trail_life + 0.1).timeout.connect(_trail.queue_free)
	queue_free()
