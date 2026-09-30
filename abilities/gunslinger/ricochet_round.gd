class_name RicochetRound
extends GunAbility
## Slow, fat round that bounces off walls. Direct hits are heavy (they crack a
## guard) and dodgeable. After the first bounce the round is faster, weaker,
## chips guard only lightly, and can NOT be dodged - it beats i-frames but not
## a raised guard, and since block only covers the front, bounces from behind
## cover slip past even that. Windup is long and glows so it can be read.

const WINDUP := 0.28

var _pending := false


func _init() -> void:
	ability_name = "Ricochet Round"
	cooldown = 7.0


func can_use() -> bool:
	return super.can_use() and fighter.gun.can_fire(1)


func _start() -> void:
	fighter.gun.spend(1)
	_pending = true
	fighter.recovery_left = WINDUP + 0.32
	fighter.slow(0.5, WINDUP + 0.1)
	fighter.lock_sprint(0.8)
	fighter.engage()
	fighter.model.charge_glow(Color(0.4, 0.9, 1.0), WINDUP)
	after(WINDUP, _fire)
	start_cooldown()
	used.emit()


func _fire() -> void:
	_pending = false
	if not fighter.alive:
		return
	var p := _new_projectile(fighter.gun.aim_direction(), 19.0)
	p.damage = 16.0
	p.guard_damage = 34.0
	p.weight = HitData.Weight.HEAVY
	p.flinch = 0.3
	p.life = 4.5
	p.bounces = 3
	p.bounce_speed_mult = 1.12
	p.bounce_damage_mult = 0.7
	p.bounce_guard_mult = 0.35
	p.bounce_dodgeable = false
	p.knockback_force = 5.0
	p.radius = 0.2
	p.trail_width = 0.4
	p.trail_life = 0.35
	p.color = Color(0.4, 0.9, 1.0)
	p.tag = &"ricochet"
	_launch(p)


func _on_interrupt() -> void:
	if _pending:
		_pending = false
		fighter.gun.ammo = mini(fighter.gun.mag_size, fighter.gun.ammo + 1)
