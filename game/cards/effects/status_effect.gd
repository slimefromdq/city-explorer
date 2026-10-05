class_name StatusEffectBlock
extends CardEffect
## Effect block 5: put a status effect (slow, burn) on targets. Statused
## targets are tinted (blue = slowed, flickering orange = burning) and say so
## over their head, so you can see why they're slow or taking damage.

enum Who { TARGET, AREA, CASTER }

@export var kind: StatusSet.Kind = StatusSet.Kind.BURN
@export var duration := 3.0
## SLOW: share of speed removed (0.5 = half speed). BURN: damage per second.
@export var magnitude := 8.0
@export var who: Who = Who.TARGET
@export var radius := 3.0
## AREA only: also affect the caster.
@export var include_caster := false


func apply(ctx: CastContext) -> void:
	var nodes: Array[Node3D] = []
	match who:
		Who.TARGET:
			if ctx.target != null and is_instance_valid(ctx.target):
				nodes.append(ctx.target)
		Who.CASTER:
			nodes.append(ctx.caster)
		Who.AREA:
			for n in find_in_radius(ctx, ctx.position, radius * ctx.mult(ModifierEffect.Stat.AREA)):
				if n != ctx.caster or include_caster:
					nodes.append(n)
	for n in nodes:
		if n.has_method(&"apply_status"):
			n.apply_status(kind, duration, magnitude, ctx.caster)


func validate(_card: AbilityCard) -> PackedStringArray:
	var p := PackedStringArray()
	if duration <= 0.0:
		p.append("duration must be > 0")
	if kind == StatusSet.Kind.SLOW and (magnitude <= 0.0 or magnitude > 0.95):
		p.append("SLOW magnitude is the share of speed removed, between 0 and 0.95")
	return p
