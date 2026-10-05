class_name SpawnBodyEffect
extends CardEffect
## Effect block 1: throw the card's body (ball / grenade / bug), or fire it as
## an instant ray (beam). The body then reports ON CONTACT / ON EXPIRE back to
## the runner, which runs the card's lists for those moments.

## How many to throw at once.
@export_range(1, 32) var count := 1
## Total fan angle when count > 1 (degrees), or random wobble when count == 1.
@export_range(0.0, 180.0) var spread_degrees := 0.0
## Tilts the throw upward (degrees), e.g. a lobbed kick.
@export_range(-45.0, 60.0) var pitch_up_degrees := 0.0
## Multiplies the body's launch speed.
@export var speed_mult := 1.0
## Share of the caster's own velocity added to the body (throwing while running).
@export_range(0.0, 1.0, 0.05) var inherit_velocity := 0.3


func apply(ctx: CastContext) -> void:
	var def := ctx.card.body
	if def == null:
		push_error("Card %s: 'Spawn body' has no body to spawn (set the card's Body field)" % ctx.card.label())
		return
	var base_dir := ctx.direction.normalized()
	if pitch_up_degrees != 0.0:
		var side := base_dir.cross(Vector3.UP)
		if side.length() > 0.01:
			base_dir = base_dir.rotated(side.normalized(), deg_to_rad(pitch_up_degrees))
	for i in count:
		var dir := _spread_dir(base_dir, i)
		if def.shape == CardBodyDef.Shape.BEAM:
			CardBeam.fire(ctx, dir)
		else:
			var inherit := Vector3.ZERO
			if ctx.caster is CharacterBody3D:
				inherit = (ctx.caster as CharacterBody3D).velocity * inherit_velocity
			var speed := def.speed * speed_mult * ctx.mult(ModifierEffect.Stat.BODY_SPEED) * ctx.power
			CardBody.spawn(ctx, dir, dir * speed + inherit)


func _spread_dir(base: Vector3, i: int) -> Vector3:
	if spread_degrees <= 0.0:
		return base
	var side := base.cross(Vector3.UP)
	if side.length() < 0.01:
		side = Vector3.RIGHT
	side = side.normalized()
	if count == 1:
		var up := side.cross(base).normalized()
		var r := deg_to_rad(spread_degrees) * 0.5
		return base.rotated(up, randf_range(-r, r)).rotated(side, randf_range(-r, r) * 0.5)
	var k := float(i) / float(count - 1) - 0.5
	return base.rotated(base.cross(side).normalized(), deg_to_rad(spread_degrees) * k)


func validate(card: AbilityCard) -> PackedStringArray:
	var p := PackedStringArray()
	if card.body == null:
		p.append("the card has no Body to spawn")
	return p
