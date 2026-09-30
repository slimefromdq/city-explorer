class_name BurstShot
extends GunAbility
## Mid-range triple tap. Light damage, tight spread, costs 3 rounds and leaves
## a recovery window - great pressure vs an empty dodge pool, bad vs a dodger.

const ROUNDS := 3
const GAP := 0.075


func _init() -> void:
	ability_name = "Burst Shot"
	cooldown = 3.5


func can_use() -> bool:
	return super.can_use() and fighter.gun.can_fire(ROUNDS)


func _start() -> void:
	fighter.gun.spend(ROUNDS)
	for i in ROUNDS:
		after(i * GAP, _fire_one)
	fighter.recovery_left = GAP * (ROUNDS - 1) + 0.36
	fighter.lock_sprint(0.6)
	fighter.slow(0.6, fighter.recovery_left)
	fighter.engage()
	start_cooldown()
	used.emit()


func _fire_one() -> void:
	if not fighter.alive:
		return
	var p := _new_projectile(spread(fighter.gun.aim_direction(), 1.1), 80.0)
	p.damage = 6.5
	p.guard_damage = 6.0
	p.life = 1.0
	p.falloff_start = 18.0
	p.falloff_end = 45.0
	p.falloff_min = 0.45
	p.knockback_force = 1.0
	p.color = Color(1.0, 0.7, 0.3)
	p.tag = &"burst"
	_launch(p)
