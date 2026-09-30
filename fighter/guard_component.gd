class_name GuardComponent
extends Node
## Hold-to-guard with a meter. Every blocked hit drains it, heavies drain more,
## and at zero the fighter is stunned and open. Only blocks hits from the front.

signal broke

const MAX := 100.0
const REGEN := 24.0
const REGEN_DELAY := 1.0
const RAISE_TIME := 0.09
const FRONT_DOT := 0.1
const BREAK_STUN := 1.8
const BREAK_RESET := 0.4

var fighter: Fighter
var value := MAX
var blocking := false
var flash := 0.0
var _raise_left := 0.0
var _delay_left := 0.0


func fraction() -> float:
	return value / MAX


func active() -> bool:
	return blocking and _raise_left <= 0.0


func set_wanted(want: bool) -> void:
	var can := want and fighter.can_block()
	if can and not blocking:
		blocking = true
		_raise_left = RAISE_TIME
	elif not can and blocking:
		drop()


func drop() -> void:
	blocking = false
	_raise_left = 0.0


func reset() -> void:
	value = MAX
	blocking = false
	_delay_left = 0.0
	flash = 0.0


func absorb(hit: HitData) -> HitData.Result:
	if not active() or not hit.blockable:
		return HitData.Result.NONE
	var flat := Vector3(hit.from_dir.x, 0.0, hit.from_dir.z)
	if flat.length() > 0.01 and fighter.facing_dir().dot(flat.normalized()) < FRONT_DOT:
		return HitData.Result.NONE
	value -= hit.guard_damage
	_delay_left = REGEN_DELAY
	flash = 1.0
	if value <= 0.0:
		value = MAX * BREAK_RESET
		_delay_left = REGEN_DELAY * 2.0
		drop()
		fighter.apply_stun(BREAK_STUN)
		broke.emit()
		return HitData.Result.GUARD_BREAK
	return HitData.Result.BLOCKED


func tick(dt: float) -> void:
	flash = maxf(0.0, flash - dt * 4.0)
	_raise_left = maxf(0.0, _raise_left - dt)
	if blocking and not fighter.can_block():
		drop()
	if not blocking:
		if _delay_left > 0.0:
			_delay_left -= dt
		else:
			value = minf(MAX, value + REGEN * dt)
