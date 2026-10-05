class_name CardBeam
extends RefCounted
## The BEAM body: no flying object, just an instant ray from the cast point.
## Whatever the ray touches gets ON CONTACT, exactly like a thrown body would.
## Spiky beams pass through up to `spiky_pierce` targets.


static func fire(cast: CastContext, dir: Vector3) -> void:
	var def := cast.card.body
	var space := cast.caster.get_world_3d().direct_space_state
	var from := cast.position
	var to := from + dir * def.beam_range
	var exclude: Array[RID] = []
	if cast.caster is CollisionObject3D:
		exclude.append((cast.caster as CollisionObject3D).get_rid())
	var pierces := def.spiky_pierce if def.spiky else 0
	var end := to
	while true:
		var q := PhysicsRayQueryParameters3D.create(from, to, CardEffect.LAYER_WORLD | CardEffect.LAYER_CHARACTER)
		q.exclude = exclude
		var r := space.intersect_ray(q)
		if r.is_empty():
			end = to
			break
		end = r.position
		var other := r.collider as Node3D
		var target: Node3D = other if other != null and other.has_method(&"take_hit") else null
		var c := cast.copy()
		c.position = r.position
		c.normal = r.normal
		c.target = target
		c.direction = dir
		cast.runner.run_list(cast.card.on_contact, c, &"on_contact")
		CardFx.flash(cast.caster, r.position, cast.card.color, 0.35)
		if target != null and pierces > 0 and r.collider is CollisionObject3D:
			pierces -= 1
			exclude.append((r.collider as CollisionObject3D).get_rid())
			from = r.position
			continue
		break
	CardFx.line(cast.caster, cast.position, end, cast.card.color, def.radius)
	Sfx.play_at_pos(cast.caster, cast.position, PlaceholderSfx.sweep("beam", 1400.0, 500.0, 0.07, 0.25, 0.1))
