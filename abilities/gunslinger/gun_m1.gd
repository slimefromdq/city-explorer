class_name GunM1
extends GunAbility
## Three-link shooting combo: single, single, double-tap finisher. Each link
## has a short recovery, the finisher a long one (exposed). Hold to keep going.

const LINKS := [
	{"rounds": 1, "damage": 5.0, "gap": 0.0, "rec": 0.17},
	{"rounds": 1, "damage": 5.0, "gap": 0.0, "rec": 0.17},
	{"rounds": 2, "damage": 6.0, "gap": 0.07, "rec": 0.5},
]
const COMBO_WINDOW := 0.65

var _idx := 0
var _combo_left := 0.0


func _init() -> void:
	ability_name = "Quickdraw"
	cooldown = 0.0
	auto_repeat = true


func can_use() -> bool:
	return fighter.can_act() and fighter.gun.can_fire(LINKS[_idx].rounds)


func _start() -> void:
	var link: Dictionary = LINKS[_idx]
	fighter.gun.spend(link.rounds)
	for i in int(link.rounds):
		after(i * float(link.gap), _fire_one.bind(float(link.damage)))
	fighter.recovery_left = float(link.rec)
	fighter.lock_sprint(0.4)
	fighter.slow(0.7, float(link.rec) + 0.1)
	fighter.engage()
	_idx = (_idx + 1) % LINKS.size()
	_combo_left = COMBO_WINDOW + float(link.rec)
	used.emit()


func _fire_one(dmg: float) -> void:
	if not fighter.alive:
		return
	var dir := spread(fighter.gun.aim_direction(), 0.6)
	var p := _new_projectile(dir, 75.0)
	p.damage = dmg
	p.guard_damage = 5.0
	p.flinch = 0.0
	p.life = 1.0
	p.falloff_start = 20.0
	p.falloff_end = 55.0
	p.falloff_min = 0.4
	p.knockback_force = 0.8
	p.tag = &"m1"
	_launch(p)


func _tick(dt: float) -> void:
	if _combo_left > 0.0:
		_combo_left -= dt
		if _combo_left <= 0.0:
			_idx = 0


func combo_index() -> int:
	return _idx
