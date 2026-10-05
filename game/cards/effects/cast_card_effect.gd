class_name CastCardEffect
extends CardEffect
## Effect block 7: cast ANOTHER card right here. This is how proc chains work:
## put it in ON HIT and every hit casts the other card; that card can cast a
## third, and so on. Each link adds 1 to the chain depth; the runner stops the
## chain past its max_proc_depth (logged as a warning), so a card that casts
## itself can't hang the game.
## Proc casts are free: no cooldown, charges or energy.

enum Dir {
	SAME,     ## keep going the way this cast was going
	REFLECT,  ## bounce off the surface that was touched
	AIM,      ## where the caster is aiming
	UP,
	AWAY_FROM_CASTER,
}

@export var card: AbilityCard
@export var direction: Dir = Dir.SAME
## Cast it this many times.
@export_range(1, 16) var times := 1


func apply(ctx: CastContext) -> void:
	if card == null:
		push_error("Card %s: 'Cast card' has no card to cast (set its Card field)" % ctx.card.label())
		return
	if ctx.runner == null:
		return
	for i in times:
		var c := ctx.copy()
		c.depth = ctx.depth + 1
		c.direction = _dir(ctx)
		c.is_reaction = false   # the new card gets its own ON HIT
		c.target = null
		c.body = null
		# Start a little off the surface/target so new bodies don't spawn inside it.
		c.position = ctx.position + ctx.normal * 0.15 if ctx.target == null else ctx.position
		c.ignore = ctx.target
		ctx.runner.cast(card, c)


func _dir(ctx: CastContext) -> Vector3:
	match direction:
		Dir.REFLECT:
			return ctx.direction.bounce(ctx.normal).normalized() if ctx.normal != Vector3.ZERO else -ctx.direction
		Dir.AIM:
			return (ctx.caster as Hero).intent.aim_dir if ctx.caster is Hero else ctx.direction
		Dir.UP:
			return Vector3.UP
		Dir.AWAY_FROM_CASTER:
			var d := ctx.position - CardEffect.center_of(ctx.caster)
			return d.normalized() if d.length() > 0.01 else ctx.direction
	return ctx.direction


func validate(_card: AbilityCard) -> PackedStringArray:
	var p := PackedStringArray()
	if card == null:
		p.append("no Card set")
	elif card.trigger != AbilityCard.Trigger.PROC_ONLY:
		pass   # casting a normal card is allowed; it just ignores that card's costs
	return p
