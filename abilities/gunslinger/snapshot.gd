class_name Snapshot
extends GunAbility
## Charged long-range shot. While charging you are slow, unable to block, and
## drawing a visible laser (anyone can see where you're aiming). Getting hit or
## dodging cancels it. Releasing fires a heavy, fast round - and a MISS locks
## you out of actions AND movement for over a second.

const MIN_CHARGE := 0.35
const FULL_CHARGE := 1.1
const MAX_HOLD := 3.0
const RANGE := 140.0

var charge := 0.0
var _laser: MeshInstance3D


func _init() -> void:
	ability_name = "Snapshot"
	cooldown = 8.0
	move_scale = 0.4


func can_use() -> bool:
	return super.can_use() and fighter.gun.can_fire(2)


func charge_fraction() -> float:
	return clampf(charge / FULL_CHARGE, 0.0, 1.0)


func _start() -> void:
	fighter.channel = self
	fighter.guard.drop()
	charge = 0.0
	fighter.engage(MAX_HOLD + 1.0)
	fighter.lock_sprint(MAX_HOLD + 1.0)


func _release() -> void:
	if fighter.channel != self:
		return
	fighter.channel = null
	fighter.aim_zoom = 0.0
	charge_visual = 0.0
	_hide_laser()
	if charge < MIN_CHARGE:
		start_cooldown(1.0)
		return
	_fire(charge_fraction())


func _on_interrupt() -> void:
	if fighter.channel == self:
		start_cooldown(cooldown * 0.5)
	charge = 0.0
	charge_visual = 0.0
	_hide_laser()


func _tick(dt: float) -> void:
	if fighter.channel != self:
		return
	charge += dt
	charge_visual = charge_fraction()
	fighter.aim_zoom = clampf(charge / 0.6, 0.0, 1.0)
	fighter.lock_sprint(0.2)
	fighter.engage(0.5)
	_update_laser()
	if charge >= MAX_HOLD:
		_release()


func _fire(c: float) -> void:
	fighter.gun.spend(2)
	var dir := fighter.gun.aim_direction()
	var p := _new_projectile(dir, 240.0)
	p.damage = lerpf(20.0, 58.0, c)
	p.guard_damage = lerpf(30.0, 75.0, c)
	p.weight = HitData.Weight.HEAVY
	p.flinch = 0.4
	p.life = RANGE / 240.0
	p.knockback_force = 9.0
	p.radius = 0.09
	p.trail_width = 0.3
	p.trail_life = 0.5
	p.color = Color(1.0, 0.35, 0.3)
	p.tag = &"snapshot"
	p.on_finish = _on_shot_finished
	_launch(p)
	fighter.recovery_left = 0.5
	fighter.slow(0.3, 0.5)
	var back := -Vector3(dir.x, 0.0, dir.z).normalized()
	fighter.loco.add_impulse(back * 7.0)
	Events.camera_shake.emit(0.35)
	start_cooldown()
	used.emit()


func _on_shot_finished(hit: bool) -> void:
	if not fighter.alive:
		return
	if hit:
		fighter.recovery_left = maxf(fighter.recovery_left, 0.45)
	else:
		fighter.recovery_left = maxf(fighter.recovery_left, 1.6)
		fighter.root_left = maxf(fighter.root_left, 1.25)
		fighter.slow(0.5, 1.6)
		Events.popup.emit("MISS", fighter.global_position + Vector3.UP * 2.4, Color(1.0, 0.5, 0.3))


func _update_laser() -> void:
	if _laser == null:
		_laser = MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1, 1, 1)
		_laser.mesh = b
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_laser.material_override = m
		_laser.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_laser.top_level = true
		fighter.add_child(_laser)
	var from := fighter.gun.muzzle_position()
	var dir := fighter.gun.aim_direction()
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * RANGE, Fighter.LAYER_WORLD | Fighter.LAYER_HURTBOX)
	q.collide_with_areas = true
	q.exclude = [fighter.hurtbox.get_rid()]
	var r := fighter.get_world_3d().direct_space_state.intersect_ray(q)
	var end: Vector3 = r.position if not r.is_empty() else from + dir * RANGE
	var len := from.distance_to(end)
	var c := charge_fraction()
	_laser.visible = true
	_laser.global_transform = Transform3D(Basis.looking_at(dir, Vector3.UP if absf(dir.y) < 0.95 else Vector3.RIGHT), from.lerp(end, 0.5))
	var w := lerpf(0.015, 0.05, c)
	_laser.scale = Vector3(w, w, len)
	(_laser.material_override as StandardMaterial3D).albedo_color = Color(1.0, 0.25, 0.2, lerpf(0.25, 0.9, c))


func _hide_laser() -> void:
	if _laser != null:
		_laser.visible = false
