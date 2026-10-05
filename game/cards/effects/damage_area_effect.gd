class_name DamageAreaEffect
extends CardEffect
## Effect block 2: damage everything in a radius around the current spot.
## Radius 0 = only the thing that was touched (a bullet, a kick).
## Each target that takes damage runs the card's ON HIT list (and ON KILL if it
## died), which is where proc chains start.

@export var damage := 20.0
@export var radius := 0.0
## Damage share at the edge of the radius (1 = no falloff).
@export_range(0.0, 1.0, 0.05) var edge_damage := 0.5
## Can the caster hurt themselves with this?
@export var hits_caster := false
@export var weight: HitData.Weight = HitData.Weight.LIGHT
@export var blockable := true
@export var dodgeable := true
## Seconds of flinch on heroes (0 = none).
@export var flinch := 0.0
@export var camera_shake := 0.0


func apply(ctx: CastContext) -> void:
	var targets: Array[Node3D] = []
	var r := radius * ctx.mult(ModifierEffect.Stat.AREA)
	var dmg := damage * ctx.mult(ModifierEffect.Stat.DAMAGE) * ctx.power
	if r <= 0.0:
		if ctx.target != null and is_instance_valid(ctx.target) and ctx.target.has_method(&"take_hit"):
			targets.append(ctx.target)
	else:
		for n in find_in_radius(ctx, ctx.position, r):
			if n.has_method(&"take_hit"):
				targets.append(n)
		CardFx.explosion(ctx.caster, ctx.position, r, ctx.card.color)
		Sfx.play_at_pos(ctx.caster, ctx.position, PlaceholderSfx.sweep("boom", 160.0, 40.0, 0.5, 0.6, 0.9))
	if camera_shake > 0.0:
		Events.camera_shake.emit(camera_shake)
	for t in targets:
		if t == ctx.caster and not hits_caster:
			continue
		var amount := dmg
		if r > 0.0:
			var k := clampf(center_of(t).distance_to(ctx.position) / r, 0.0, 1.0)
			amount = dmg * lerpf(1.0, edge_damage, k)
		var hit := HitData.new()
		hit.attacker = ctx.caster
		hit.damage = amount
		hit.guard_damage = amount
		hit.weight = weight
		hit.blockable = blockable
		hit.dodgeable = dodgeable
		hit.flinch = flinch
		hit.position = center_of(t)
		var from := ctx.position - center_of(t)
		from.y = 0.0
		hit.from_dir = from.normalized() if from.length() > 0.01 else -ctx.direction
		hit.tag = StringName(ctx.card.display_name)
		var result: int = t.take_hit(hit)
		if ctx.runner != null:
			ctx.runner.report_hit(ctx, t, result, amount)


func validate(_card: AbilityCard) -> PackedStringArray:
	var p := PackedStringArray()
	if damage < 0.0:
		p.append("negative damage (use a heal block for healing)")
	return p
