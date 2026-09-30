class_name GunComponent
extends Node
## Shared ammo/reload rules for gun archetypes. "Every shot costs something":
## the magazine is small and an empty one means a reload window with no shots.

signal ammo_changed

var fighter: Fighter
var mag_size := 12
var ammo := 12
var reload_time := 1.35
var reloading := false
var _reload_left := 0.0


func can_fire(rounds: int = 1) -> bool:
	return not reloading and ammo >= rounds


func spend(rounds: int) -> void:
	ammo = maxi(0, ammo - rounds)
	ammo_changed.emit()
	if ammo == 0:
		start_reload()


func start_reload() -> void:
	if reloading or ammo >= mag_size or not fighter.alive:
		return
	reloading = true
	_reload_left = reload_time
	fighter.interrupt_channel()
	ammo_changed.emit()


func refill() -> void:
	ammo = mag_size
	reloading = false
	_reload_left = 0.0
	ammo_changed.emit()


func reload_fraction() -> float:
	return 1.0 - _reload_left / reload_time if reloading else 1.0


func muzzle_position() -> Vector3:
	return fighter.model.muzzle_global_position()


## Direction from the muzzle to whatever the fighter is aiming at.
func aim_direction() -> Vector3:
	var d := fighter.aim_point - muzzle_position()
	if d.length() < 1.5:
		return fighter.aim_dir
	return d.normalized()


func tick(dt: float) -> void:
	if reloading:
		_reload_left -= dt
		fighter.slow(0.8, 0.05)
		if _reload_left <= 0.0:
			refill()
