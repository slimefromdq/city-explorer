class_name ModifierEffect
extends CardEffect
## Effect block 6: change the numbers of the hero's cards, Risk of Rain item
## style. In a PASSIVE card it lasts as long as the card is equipped; anywhere
## else it's a timed buff (`duration` seconds). Modifiers stack: two +25%
## damage modifiers give +56% (they multiply).

enum Stat {
	DAMAGE,          ## +share of damage (0.25 = +25%)
	AREA,            ## +share of every radius (explosions, pushes, statuses)
	BODY_SPEED,      ## +share of thrown body speed
	COOLDOWN_SPEED,  ## +share of recharge speed (0.25 = cooldowns 25% faster)
	FIRE_RATE,       ## +share of HOLD fire rate
	EXTRA_BOUNCES,   ## + this many bounces on bodies that already bounce
	ENERGY_REGEN,    ## +share of energy regeneration
}

## Only counts while this is true for the hero (checked every time it's used).
enum When {
	ALWAYS,
	AIRBORNE,     ## not standing on the ground
	GROUNDED,
	LOW_HEALTH,   ## below half health
	BLOCKING,
}

@export var stat: Stat = Stat.DAMAGE
## A share for the "+share" stats (0.25 = +25%, -0.2 = -20%), a count for EXTRA_BOUNCES.
@export var amount := 0.25
## Seconds the buff lasts. Ignored on PASSIVE cards (they last while equipped).
@export var duration := 5.0
@export var only_when: When = When.ALWAYS


func apply(ctx: CastContext) -> void:
	if ctx.runner == null:
		return
	var passive := ctx.card != null and ctx.card.trigger == AbilityCard.Trigger.PASSIVE
	ctx.runner.add_modifier(stat, amount, -1.0 if passive else duration, ctx.card, only_when)
	if not passive and ctx.caster != null:
		FloatingText.spawn(ctx.caster, "%s %s" % [ctx.card.display_name.to_upper(), describe()], ctx.caster.global_position + Vector3.UP * 2.3, ctx.card.color, 44)


func describe() -> String:
	return describe_stat(stat, amount) + describe_when(only_when)


static func describe_when(w: int) -> String:
	match w:
		When.AIRBORNE: return " while airborne"
		When.GROUNDED: return " while grounded"
		When.LOW_HEALTH: return " below half health"
		When.BLOCKING: return " while blocking"
	return ""


## Is condition `w` true for `hero` right now?
static func condition_met(w: int, hero: Hero) -> bool:
	if hero == null:
		return w == When.ALWAYS
	match w:
		When.AIRBORNE: return not hero.motor.on_floor
		When.GROUNDED: return hero.motor.on_floor
		When.LOW_HEALTH: return hero.defense.health < hero.tuning.max_health * 0.5
		When.BLOCKING: return hero.defense.blocking
	return true


## "+25% damage", "+1 bounce": how the HUD and popups name a modifier.
static func describe_stat(s: int, a: float) -> String:
	if s == Stat.EXTRA_BOUNCES:
		return "%+d bounce%s" % [int(a), "" if absi(int(a)) == 1 else "s"]
	return "%+d%% %s" % [roundi(a * 100.0), Stat.keys()[s].to_lower().replace("_", " ")]
