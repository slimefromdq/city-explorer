class_name GunAbility
extends Ability
## Shared helpers for gun moves: build a projectile, aim it, add spread, launch.


func _new_projectile(dir: Vector3, speed: float) -> Projectile:
	var p := Projectile.new()
	p.attacker = fighter
	p.velocity = dir.normalized() * speed
	return p


func _launch(p: Projectile) -> void:
	fighter.get_tree().current_scene.add_child(p)
	p.global_position = fighter.gun.muzzle_position()
	fighter.model.muzzle_flash(p.color)


static func spread(dir: Vector3, degrees: float) -> Vector3:
	if degrees <= 0.0:
		return dir
	var basis := Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT)
	var a := randf() * TAU
	var r := deg_to_rad(degrees) * sqrt(randf())
	return (basis * Vector3(sin(r) * cos(a), sin(r) * sin(a), -cos(r))).normalized()
