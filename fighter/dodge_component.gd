class_name DodgeComponent
extends Node
## A pool of 3 regenerating dodges. i-frames beat anything `dodgeable`, but an
## empty pool means a stumble and nothing to hide behind.

signal dodged(dir: Vector3)

const TIME := 0.32
const IFRAME_START := 0.03
const IFRAME_END := 0.26
const SPEED := 21.0
const COOLDOWN := 0.28
const EMPTY_PENALTY := 0.4

var fighter: Fighter
var pool := ChargePool.new(3, 3.4, 1.4)
var active := false
var cd_left := 0.0
var _t := 0.0


func in_iframes() -> bool:
	return active and _t >= IFRAME_START and _t <= IFRAME_END


func reset() -> void:
	pool.fill()
	cd_left = 0.0
	active = false


func try_dodge() -> bool:
	if cd_left > 0.0 or not fighter.can_dodge():
		return false
	if not pool.spend():
		fighter.recovery_left = maxf(fighter.recovery_left, EMPTY_PENALTY)
		cd_left = 0.5
		Events.popup.emit("NO DODGE", fighter.global_position + Vector3.UP * 2.3, Color(1.0, 0.4, 0.3))
		return false
	fighter.guard.drop()
	fighter.interrupt_channel()
	var dir := fighter.world_move_dir()
	if dir.length() < 0.1:
		dir = -fighter.facing_dir()
	dir = dir.normalized()
	fighter.loco.start_drive(Locomotion.Drive.DODGE, dir, SPEED, TIME, true, 0.35, 0.5)
	active = true
	_t = 0.0
	cd_left = COOLDOWN
	dodged.emit(dir)
	return true


func tick(dt: float) -> void:
	pool.tick(dt)
	cd_left = maxf(0.0, cd_left - dt)
	if active:
		_t += dt
		if _t >= TIME or fighter.loco.drive != Locomotion.Drive.DODGE:
			active = false
