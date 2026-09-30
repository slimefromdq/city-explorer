class_name SlideShot
extends GunAbility
## Close-range panic button: a low slide that fires twice. The crouched
## hurtbox lets chest-height shots pass over, and the first frames are
## invulnerable, but it commits you to a straight line and leaves you exposed
## at the end. Falls off hard past ~10 m.

const SLIDE_TIME := 0.62
const SLIDE_SPEED := 17.0


func _init() -> void:
	ability_name = "Slide-Shot"
	cooldown = 6.0


func can_use() -> bool:
	return super.can_use() and fighter.is_on_floor() and fighter.gun.can_fire(2)


func _start() -> void:
	fighter.gun.spend(2)
	var dir := fighter.world_move_dir()
	if dir.length() < 0.1:
		dir = Vector3(fighter.aim_dir.x, 0.0, fighter.aim_dir.z)
	dir = dir.normalized()
	fighter.guard.drop()
	fighter.loco.start_drive(Locomotion.Drive.SLIDE, dir, SLIDE_SPEED, SLIDE_TIME, true, 0.4, 0.6)
	fighter.set_crouched(true)
	fighter.iframes_left = 0.14
	fighter.engage(1.0)
	after(0.13, _fire_one)
	after(0.36, _fire_one)
	after(SLIDE_TIME, _finish)
	start_cooldown()
	used.emit()


func _finish() -> void:
	fighter.recovery_left = maxf(fighter.recovery_left, 0.28)


func _on_interrupt() -> void:
	if fighter.loco.drive == Locomotion.Drive.SLIDE:
		fighter.loco.end_drive()


func _fire_one() -> void:
	if not fighter.alive:
		return
	var p := _new_projectile(spread(fighter.gun.aim_direction(), 1.8), 70.0)
	p.damage = 7.0
	p.guard_damage = 7.0
	p.flinch = 0.2
	p.life = 0.5
	p.falloff_start = 8.0
	p.falloff_end = 22.0
	p.falloff_min = 0.3
	p.knockback_force = 2.0
	p.color = Color(1.0, 0.55, 0.25)
	p.tag = &"slide"
	_launch(p)
