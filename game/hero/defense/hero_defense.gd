class_name HeroDefense
extends Node
## Health, guard and the rules for what a hit does to the hero.
##
## Attacks never touch health directly. They build a HitData (core/hit_data.gd:
## damage, guard damage, blockable / dodgeable flags, direction, knockback,
## flinch) and call `hero.take_hit(hit)`. This script decides the result:
##   rolling inside the i-frame window + dodgeable hit  -> DODGED
##   guard up, hit from the front, inside perfect window -> PERFECT_BLOCK
##   guard up, hit from the front                        -> BLOCKED (reduced), maybe GUARD_BREAK
##   anything else (flank, unblockable, no guard)        -> HIT
## and shows it: floating text, a flash, a sound, camera shake.

signal hit_taken(hit: HitData, result: int, amount: float)
signal died

var hero: Hero
var tuning: MovementTuning

var health := 100.0
var guard := 100.0
var dead := false
## Set every tick by the Roll state while its invulnerable window is open.
var iframes := false
## Set by the Block state.
var blocking := false
var perfect_window_left := 0.0
var last_result := -1
var last_result_text := ""

var _rearm_left := 0.0
var _guard_delay_left := 0.0


func setup(p_hero: Hero) -> void:
	hero = p_hero
	tuning = hero.tuning
	reset()


func reset() -> void:
	health = tuning.max_health
	guard = tuning.guard_max
	dead = false
	iframes = false
	blocking = false
	perfect_window_left = 0.0
	_rearm_left = 0.0
	_guard_delay_left = 0.0


func tick(dt: float) -> void:
	perfect_window_left = maxf(0.0, perfect_window_left - dt)
	_rearm_left = maxf(0.0, _rearm_left - dt)
	_guard_delay_left = maxf(0.0, _guard_delay_left - dt)
	if not blocking and _guard_delay_left <= 0.0:
		guard = minf(tuning.guard_max, guard + tuning.guard_regen * dt)


func raise_guard() -> void:
	blocking = true
	perfect_window_left = tuning.perfect_block_window if _rearm_left <= 0.0 else 0.0


func lower_guard() -> void:
	if blocking:
		_rearm_left = tuning.perfect_block_rearm
	blocking = false
	perfect_window_left = 0.0


## Is the hit coming from inside the guarded front arc?
func is_in_front(hit: HitData) -> bool:
	var from := Vector3(hit.from_dir.x, 0.0, hit.from_dir.z)
	if from.length() < 0.01:
		return true
	var facing := Vector3(-sin(hero.face_yaw), 0.0, -cos(hero.face_yaw))
	return facing.dot(from.normalized()) >= cos(deg_to_rad(tuning.block_arc_degrees * 0.5))


func take_hit(hit: HitData) -> int:
	if dead:
		return HitData.Result.NONE
	var head := hero.global_position + Vector3.UP * 2.2
	if iframes and hit.dodgeable:
		return _resolve(hit, HitData.Result.DODGED, 0.0, "DODGED", Color(0.85, 0.9, 1.0), head)
	if blocking and hit.blockable and is_in_front(hit):
		if perfect_window_left > 0.0:
			hero.emit_movement_event(MoveEvent.Type.PERFECT_BLOCK, {"attacker": hit.attacker})
			Events.camera_shake.emit(0.25)
			return _resolve(hit, HitData.Result.PERFECT_BLOCK, 0.0, "PERFECT!", Color(1.0, 0.85, 0.2), head)
		var dmg := hit.damage * tuning.block_damage_mult
		health -= dmg
		guard -= hit.guard_damage
		_guard_delay_left = tuning.guard_regen_delay
		hero.motor.add_impulse(hit.knockback * tuning.block_knockback_mult)
		if guard <= 0.0:
			guard = 0.0
			Events.camera_shake.emit(0.6)
			hero.states.change(&"Hitstun", {"time": tuning.guard_break_stun, "reason": "guard break"})
			return _resolve(hit, HitData.Result.GUARD_BREAK, dmg, "GUARD BREAK", Color(1.0, 0.5, 0.15), head)
		return _resolve(hit, HitData.Result.BLOCKED, dmg, "BLOCKED -%d" % roundi(dmg), Color(0.45, 0.75, 1.0), head)
	health -= hit.damage
	hero.motor.add_impulse(hit.knockback)
	Events.camera_shake.emit(0.35 if hit.weight == HitData.Weight.HEAVY else 0.2)
	if hit.flinch > 0.0:
		# A flinch interrupts whatever you were doing, including a dash windup.
		hero.states.change(&"Hitstun", {"time": hit.flinch, "reason": "flinch"})
	return _resolve(hit, HitData.Result.HIT, hit.damage, "-%d" % roundi(hit.damage), Color(1.0, 0.3, 0.25), head)


func _resolve(hit: HitData, result: int, amount: float, label: String, color: Color, at: Vector3) -> int:
	last_result = result
	last_result_text = label
	FloatingText.spawn(hero, label, at, color, 72 if result == HitData.Result.PERFECT_BLOCK else 56)
	hero.model.flash(color)
	Sfx.play_at(hero, _sound_for(result))
	hit_taken.emit(hit, result, amount)
	Events.hit_resolved.emit(hit.attacker, hero, result, amount, hit.position)
	if health <= 0.0 and not dead:
		_die()
	return result


func _die() -> void:
	dead = true
	health = 0.0
	FloatingText.spawn(hero, "DOWN", hero.global_position + Vector3.UP * 2.6, Color(1, 0.2, 0.2), 80)
	hero.states.change(&"Hitstun", {"time": 999.0, "reason": "down"})
	died.emit()
	hero.get_tree().create_timer(tuning.death_respawn_delay).timeout.connect(hero.respawn)


func _sound_for(result: int) -> AudioStream:
	match result:
		HitData.Result.DODGED:
			return PlaceholderSfx.sweep("dodged", 1200.0, 1800.0, 0.12, 0.25, 0.3)
		HitData.Result.PERFECT_BLOCK:
			return PlaceholderSfx.sweep("perfect", 1300.0, 2600.0, 0.35, 0.45)
		HitData.Result.BLOCKED:
			return PlaceholderSfx.sweep("blocked", 700.0, 500.0, 0.12, 0.4, 0.4)
		HitData.Result.GUARD_BREAK:
			return PlaceholderSfx.sweep("guard_break", 300.0, 90.0, 0.45, 0.55, 0.6)
	return PlaceholderSfx.sweep("hurt", 260.0, 140.0, 0.18, 0.5, 0.5)
