class_name Ability
extends Node
## One button-triggered move. Subclasses override `_start()` (and optionally
## `_release()` / `_on_interrupt()`). Shared plumbing: cooldown, a tiny
## scheduler for timed steps, hold-to-repeat, and channel bookkeeping.

signal used

@export var ability_name := "Move"
@export var cooldown := 5.0
@export var auto_repeat := false        # holding the key re-fires (used by M1)
var move_scale := 1.0                   # applied to the fighter while channelling
var charge_visual := 0.0               # 0..1, read by the model for muzzle glow

var fighter: Fighter
var cd_left := 0.0
var held := false
var _queue: Array = []                  # [[time_left, Callable], ...]


func can_use() -> bool:
	return cd_left <= 0.0 and fighter.can_act()


func cooldown_fraction() -> float:
	return clampf(cd_left / cooldown, 0.0, 1.0) if cooldown > 0.0 else 0.0


func press() -> void:
	if can_use():
		_start()


func release() -> void:
	_release()


func interrupt() -> void:
	_queue.clear()
	_on_interrupt()
	if fighter.channel == self:
		fighter.channel = null
		fighter.aim_zoom = 0.0


func reset() -> void:
	interrupt()
	cd_left = 0.0


func start_cooldown(t: float = -1.0) -> void:
	cd_left = cooldown if t < 0.0 else t


func after(delay: float, fn: Callable) -> void:
	_queue.append([delay, fn])


# ---- overridables ----
func _start() -> void:
	pass


func _release() -> void:
	pass


func _on_interrupt() -> void:
	pass


func _tick(_dt: float) -> void:
	pass


func _physics_process(dt: float) -> void:
	cd_left = maxf(0.0, cd_left - dt)
	var i := 0
	while i < _queue.size():
		_queue[i][0] -= dt
		if _queue[i][0] <= 0.0:
			var fn: Callable = _queue[i][1]
			_queue.remove_at(i)
			fn.call()
		else:
			i += 1
	if not fighter.alive:
		return
	if auto_repeat and held:
		press()
	_tick(dt)
