class_name ApplyImpulseEffect
extends CardEffect
## Effect block 3: push things. Heroes and dummies get knocked back, card
## bodies get shoved. Pushing the CASTER is how rocket jumps work.

enum Who {
	TARGET,  ## only what was touched/hit
	CASTER,  ## only the hero who cast the card
	AREA,    ## everything in `radius` (optionally including the caster)
}

enum Dir {
	AWAY_FROM_POINT,  ## outward from the current spot (explosions)
	ALONG_DIRECTION,  ## the way the cast/body was travelling
	AIM,              ## where the caster is aiming
	UP,
	TOWARD_CASTER,    ## pull in (hooks)
}

@export var who: Who = Who.TARGET
@export var direction: Dir = Dir.AWAY_FROM_POINT
## Speed added, in m/s.
@export var strength := 10.0
## Adds lift so pushes pop targets off the ground (0 = none, 1 = 45 degrees).
@export_range(0.0, 2.0, 0.05) var up_bias := 0.3
@export var radius := 4.0
## AREA only: push share at the edge of the radius.
@export_range(0.0, 1.0, 0.05) var edge_strength := 0.4
## AREA only: also push the caster (rocket jump).
@export var include_caster := false
## Multiplies the push the caster gets (so self-launch can be tuned separately).
@export var caster_mult := 1.0


func apply(ctx: CastContext) -> void:
	var nodes: Array[Node3D] = []
	var r := radius * ctx.mult(ModifierEffect.Stat.AREA)
	match who:
		Who.TARGET:
			if ctx.target != null and is_instance_valid(ctx.target):
				nodes.append(ctx.target)
		Who.CASTER:
			nodes.append(ctx.caster)
		Who.AREA:
			nodes = find_in_radius(ctx, ctx.position, r, LAYER_CHARACTER | (1 << 4))
			if include_caster and not nodes.has(ctx.caster) and ctx.caster != null:
				# The caster counts if their body is within the radius.
				if center_of(ctx.caster).distance_to(ctx.position) <= r + 1.0:
					nodes.append(ctx.caster)
	for n in nodes:
		if n == ctx.caster and who == Who.AREA and not include_caster:
			continue
		if n == ctx.body:
			continue
		var d := _dir_for(ctx, n)
		var s := strength * ctx.push_mult()
		if who == Who.AREA:
			var k := clampf(center_of(n).distance_to(ctx.position) / maxf(r, 0.01), 0.0, 1.0)
			s *= lerpf(1.0, edge_strength, k)
		if n == ctx.caster:
			s *= caster_mult
		var v := d * s
		if n.has_method(&"push"):
			n.push(v)
		elif n is RigidBody3D:
			(n as RigidBody3D).apply_central_impulse(v * (n as RigidBody3D).mass)


func _dir_for(ctx: CastContext, n: Node3D) -> Vector3:
	var d := Vector3.UP
	match direction:
		Dir.AWAY_FROM_POINT:
			d = center_of(n) - ctx.position
			if d.length() < 0.05:
				d = Vector3.UP
		Dir.ALONG_DIRECTION:
			d = ctx.direction
		Dir.AIM:
			if ctx.caster is Hero:
				d = (ctx.caster as Hero).intent.aim_dir
			else:
				d = ctx.direction
		Dir.UP:
			d = Vector3.UP
		Dir.TOWARD_CASTER:
			d = center_of(ctx.caster) - center_of(n) if ctx.caster != null else Vector3.UP
			d.y = 0.0
			if d.length() < 0.05:
				d = Vector3.UP
	d = d.normalized()
	if up_bias > 0.0 and direction != Dir.UP:
		d = (d + Vector3.UP * up_bias).normalized()
	return d
