class_name TeleportEffect
extends CardEffect
## Effect block 4: move the caster somewhere instantly. Sweeps the caster's
## capsule along the way first, so you stop at the first wall instead of ending
## up inside it. Leaves a fading afterimage where you were.

enum To {
	FORWARD,    ## `distance` metres along the aim (a blink)
	AIM_POINT,  ## to the crosshair point, up to `distance` metres
	HERE,       ## to the current spot (e.g. where a body landed)
}

@export var to: To = To.FORWARD
@export var distance := 8.0
## Keep running speed after the teleport? Off = arrive standing still.
@export var keep_momentum := true
## Steepest the blink may point up/down (FORWARD only), so it doesn't dive
## into the floor when you look down.
@export_range(0.0, 1.0, 0.05) var max_vertical := 0.35


func apply(ctx: CastContext) -> void:
	var hero := ctx.caster as Hero
	if hero == null:
		push_error("Teleport: caster of %s is not a Hero" % ctx.card.label())
		return
	var start := hero.global_position + Vector3.UP * 0.05
	var goal := start
	match to:
		To.FORWARD:
			var d := hero.intent.aim_dir
			d.y = clampf(d.y, -max_vertical, max_vertical)
			goal = start + d.normalized() * distance
		To.AIM_POINT:
			var off := hero.intent.aim_point - start
			goal = start + off.limit_length(distance)
		To.HERE:
			goal = ctx.position
	var motion := goal - start
	var safe := 1.0
	var shape := hero.body_shape.shape
	if shape != null and motion.length() > 0.01:
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = shape
		q.transform = Transform3D(Basis.IDENTITY, start + hero.body_shape.position)
		q.motion = motion
		q.collision_mask = LAYER_WORLD
		q.exclude = [hero.get_rid()]
		var r := hero.get_world_3d().direct_space_state.cast_motion(q)
		safe = r[0]
	var dest := start + motion * safe
	CardFx.afterimage(hero, hero.global_position, ctx.card.color)
	hero.teleport_to(dest, keep_momentum)
	CardFx.flash(hero, dest + Vector3.UP, ctx.card.color, 1.2)
	Sfx.play_at_pos(hero, dest, PlaceholderSfx.sweep("blink", 900.0, 1800.0, 0.18, 0.4, 0.2))
