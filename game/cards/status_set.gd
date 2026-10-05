class_name StatusSet
extends RefCounted
## The status effects currently on one character (a hero or a dummy).
## Each kind is stored once; re-applying refreshes the duration and keeps the
## stronger magnitude. The owner calls tick() every physics step.
##   SLOW - magnitude 0..1 = share of movement speed removed
##   BURN - magnitude = damage per second, dealt in ticks of BURN_TICK seconds

enum Kind { SLOW, BURN }

const BURN_TICK := 0.5
const COLORS := {Kind.SLOW: Color(0.45, 0.75, 1.0), Kind.BURN: Color(1.0, 0.45, 0.1)}
const NAMES := {Kind.SLOW: "SLOWED", Kind.BURN: "BURNING"}

var _active := {}   # Kind -> {left, magnitude, source, tick}


func apply(kind: Kind, duration: float, magnitude: float, source: Node3D) -> void:
	var e: Dictionary = _active.get(kind, {"left": 0.0, "magnitude": 0.0, "source": null, "tick": BURN_TICK})
	e.left = maxf(e.left, duration)
	e.magnitude = maxf(e.magnitude, magnitude)
	e.source = source
	_active[kind] = e


func has(kind: Kind) -> bool:
	return _active.has(kind)


func clear() -> void:
	_active.clear()


## Speed multiplier from SLOW (1 = normal).
func speed_mult() -> float:
	return 1.0 - clampf(_active[Kind.SLOW].magnitude, 0.0, 0.95) if _active.has(Kind.SLOW) else 1.0


## Advance timers. Burn damage goes through owner.take_hit so it shows numbers
## and can kill, but it doesn't count as a card hit (no ON HIT procs).
func tick(owner: Node3D, dt: float) -> void:
	for kind in _active.keys():
		var e: Dictionary = _active[kind]
		e.left -= dt
		if kind == Kind.BURN:
			e.tick -= dt
			if e.tick <= 0.0:
				e.tick += BURN_TICK
				var hit := HitData.new()
				hit.attacker = e.source if is_instance_valid(e.source) else null
				hit.damage = e.magnitude * BURN_TICK
				hit.guard_damage = 0.0
				hit.blockable = false
				hit.dodgeable = false
				hit.position = owner.global_position + Vector3.UP * 1.4
				hit.tag = &"Burn"
				if owner.has_method(&"take_hit"):
					owner.take_hit(hit)
		if e.left <= 0.0:
			_active.erase(kind)


## The colour to tint the owner with (strongest status wins), alpha 0 = none.
func tint() -> Color:
	if _active.has(Kind.BURN):
		return COLORS[Kind.BURN]
	if _active.has(Kind.SLOW):
		return COLORS[Kind.SLOW]
	return Color(0, 0, 0, 0)


func label() -> String:
	var parts := PackedStringArray()
	for kind in _active:
		parts.append(NAMES[kind])
	return " ".join(parts)
