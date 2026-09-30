class_name Locomotion
extends Node
## All movement lives here. Velocity is a SUM of separate contributions rather
## than one overwritten number:
##   run_vel  - horizontal input-driven velocity
##   vy       - gravity / jumping
##   impulse  - decaying shoves (dash carry, knockback, recoil)
## "Drives" (dash / dodge / slide) temporarily take over and hand back cleanly.
## Powers added later (gravity pull, teleport) just add another contribution.

signal landed(impact_speed: float)
signal dashed(dir: Vector3, chain: int)
signal mantled
signal wall_kicked
signal drive_ended(kind: int)

enum Drive { NONE, DASH, DODGE, SLIDE }

const WALK_SPEED := 9.0
const SPRINT_SPEED := 15.0
const GROUND_ACCEL := 70.0
const GROUND_BRAKE := 55.0
const AIR_ACCEL := 26.0
const JUMP_SPEED := 10.5
const GRAVITY := 28.0
const FALL_MULT := 1.35
const MAX_FALL := 55.0
const COYOTE := 0.12
const JUMP_BUFFER := 0.12
const JUMP_CUT := 0.5

const DASH_SPEED := 40.0
const DASH_TIME := 0.2
const DASH_BUFFER := 0.18
const DASH_HANG := 0.16
const DASH_HANG_GRAVITY := 0.2
const DASH_CARRY := 0.45
const DASH_COOLDOWN := 0.1
const DASH_GROUND_RECHARGE := 2.6
const CHAIN_WINDOW := 0.6
const CHAIN_SPEED_BONUS := 0.07
const CHAIN_MAX := 4
const WALL_KICKS := 3

const MANTLE_MIN := 0.35
const MANTLE_MAX := 2.5
const MANTLE_TIME := 0.28

var fighter: Fighter
var run_vel := Vector3.ZERO
var vy := 0.0
var impulse := Vector3.ZERO
var dash_pool := ChargePool.new(3, 1.5, 0.6)
var chain := 0

var drive := Drive.NONE
var drive_dir := Vector3.ZERO
var mantling := false

var _drive_speed := 0.0
var _drive_t := 0.0
var _drive_dur := 0.0
var _drive_keep_v := false
var _drive_end_mult := 0.5
var _drive_carry := 0.0
var _hang_left := 0.0
var _chain_left := 0.0
var _dash_cd := 0.0
var _dash_buf := 0.0
var _coyote := 0.0
var _jump_buf := 0.0
var _jumped := false
var _wall_left := 0.0
var _wall_normal := Vector3.ZERO
var _wall_kicks := 0
var _mantle_cd := 0.0
var _was_on_floor := true
var _m_from := Vector3.ZERO
var _m_to := Vector3.ZERO
var _m_t := 0.0
var _m_dur := MANTLE_TIME


func busy() -> bool:
	return drive != Drive.NONE or mantling


func reset() -> void:
	run_vel = Vector3.ZERO
	impulse = Vector3.ZERO
	vy = 0.0
	drive = Drive.NONE
	mantling = false
	dash_pool.fill()
	chain = 0
	_hang_left = 0.0


func request_jump() -> void:
	_jump_buf = JUMP_BUFFER


## Buffered dash press: chains feel snappy because a press during the tail of
## the previous dash still fires the moment the cooldown allows.
func request_dash() -> void:
	_dash_buf = DASH_BUFFER


func add_impulse(v: Vector3) -> void:
	impulse += v


## Air-dash: a burst along the aim direction. Looking up + dash = rooftop.
## Dashing again inside the chain window is faster (up to +28%).
func try_dash() -> bool:
	var f := fighter
	if not f.can_move_act() or mantling or _dash_cd > 0.0:
		return false
	if drive == Drive.DASH or drive == Drive.SLIDE:
		return false
	if not dash_pool.spend():
		return false
	f.guard.drop()
	f.interrupt_channel()
	if drive == Drive.DODGE:
		end_drive()
	var wish := f.world_move_dir()
	var flat_aim := Vector3(f.aim_dir.x, 0.0, f.aim_dir.z).normalized()
	var horiz := wish.normalized() if wish.length() > 0.1 else flat_aim
	var pitch := clampf(f.aim_dir.y, -0.5, 0.9)
	if f.is_on_floor():
		pitch = maxf(pitch, 0.12)
	var h := sqrt(1.0 - pitch * pitch)
	var dir := Vector3(horiz.x * h, pitch, horiz.z * h).normalized()
	chain = mini(chain + 1, CHAIN_MAX) if _chain_left > 0.0 else 0
	var speed := DASH_SPEED * (1.0 + CHAIN_SPEED_BONUS * chain)
	start_drive(Drive.DASH, dir, speed, DASH_TIME, false, 0.7, DASH_CARRY)
	impulse = Vector3.ZERO
	vy = 0.0
	dashed.emit(dir, chain)
	return true


func start_drive(kind: Drive, dir: Vector3, speed: float, dur: float, keep_vertical: bool, end_mult: float, carry: float) -> void:
	drive = kind
	drive_dir = dir
	_drive_speed = speed
	_drive_t = 0.0
	_drive_dur = dur
	_drive_keep_v = keep_vertical
	_drive_end_mult = end_mult
	_drive_carry = carry
	if keep_vertical:
		vy = minf(vy, 0.0)


func end_drive() -> void:
	if drive == Drive.NONE:
		return
	var kind := drive
	var k := clampf(_drive_t / maxf(_drive_dur, 0.001), 0.0, 1.0)
	var spd := _drive_speed * lerpf(1.0, _drive_end_mult, k * k)
	if kind == Drive.DASH:
		impulse = drive_dir * spd * _drive_carry
		vy = 0.0
		_hang_left = DASH_HANG
		_chain_left = CHAIN_WINDOW
		_dash_cd = DASH_COOLDOWN
	else:
		run_vel = Vector3(drive_dir.x, 0.0, drive_dir.z) * minf(spd, SPRINT_SPEED) * _drive_carry
	drive = Drive.NONE
	drive_ended.emit(kind)


func step(dt: float) -> void:
	var f := fighter
	var on_floor := f.is_on_floor()
	_tick_timers(dt, on_floor)
	if mantling:
		_step_mantle(dt)
		return
	if f.stun_left > 0.0 and drive == Drive.SLIDE:
		end_drive()
	if drive != Drive.NONE and _drive_t >= _drive_dur:
		end_drive()
	if _dash_buf > 0.0 and try_dash():
		_dash_buf = 0.0
	if _jump_buf > 0.0:
		_try_jump(on_floor)
	if drive != Drive.NONE:
		_step_drive(dt, on_floor)
	else:
		_step_free(dt, on_floor)
	var pre_vy := vy
	f.move_and_slide()
	_post_slide(pre_vy)


func _tick_timers(dt: float, on_floor: bool) -> void:
	dash_pool.tick(dt, DASH_GROUND_RECHARGE if on_floor else 1.0)
	_jump_buf = maxf(0.0, _jump_buf - dt)
	_dash_buf = maxf(0.0, _dash_buf - dt)
	_wall_left = maxf(0.0, _wall_left - dt)
	_mantle_cd = maxf(0.0, _mantle_cd - dt)
	_dash_cd = maxf(0.0, _dash_cd - dt)
	_hang_left = maxf(0.0, _hang_left - dt)
	if on_floor:
		_coyote = COYOTE
		_wall_kicks = 0
	else:
		_coyote = maxf(0.0, _coyote - dt)
	if drive != Drive.DASH:
		_chain_left = maxf(0.0, _chain_left - dt)
		if _chain_left <= 0.0:
			chain = 0


func _target_speed() -> float:
	var f := fighter
	var s := SPRINT_SPEED if (f.wants_sprint and f.can_sprint()) else WALK_SPEED
	return s * f.move_scale()


func _try_jump(on_floor: bool) -> void:
	var f := fighter
	if f.stun_left > 0.0 or f.root_left > 0.0 or not f.alive:
		return
	if drive == Drive.DASH:
		# dash-jump cancel: keep the dash momentum, add a hop
		end_drive()
		vy = JUMP_SPEED * 0.85
		_jump_buf = 0.0
		_jumped = false
		return
	if drive != Drive.NONE:
		return
	if on_floor or _coyote > 0.0:
		vy = JUMP_SPEED
		_coyote = 0.0
		_jump_buf = 0.0
		_jumped = true
	elif _wall_left > 0.0 and _wall_kicks < WALL_KICKS:
		var wish := f.world_move_dir()
		vy = 11.5
		run_vel = _wall_normal * 10.0 + wish * 3.0
		impulse = Vector3.ZERO
		_wall_kicks += 1
		_wall_left = 0.0
		_jump_buf = 0.0
		_jumped = true
		wall_kicked.emit()


func _step_free(dt: float, on_floor: bool) -> void:
	var f := fighter
	var wish := f.world_move_dir()
	var target := wish * _target_speed()
	var accel := AIR_ACCEL
	if on_floor:
		accel = GROUND_ACCEL if wish != Vector3.ZERO else GROUND_BRAKE
	run_vel = run_vel.move_toward(target, accel * dt)
	if on_floor and vy <= 0.0:
		vy = -3.0
	else:
		var g := GRAVITY * (DASH_HANG_GRAVITY if _hang_left > 0.0 else 1.0)
		if vy < 0.0:
			g *= FALL_MULT
		vy = maxf(vy - g * dt, -MAX_FALL)
	if _jumped and vy > 0.0 and not f.jump_held:
		vy *= JUMP_CUT
		_jumped = false
	impulse *= exp(-(10.0 if on_floor else 3.5) * dt)
	f.velocity = run_vel + Vector3.UP * vy + impulse


func _step_drive(dt: float, on_floor: bool) -> void:
	_drive_t += dt
	var k := clampf(_drive_t / maxf(_drive_dur, 0.001), 0.0, 1.0)
	var spd := _drive_speed * lerpf(1.0, _drive_end_mult, k * k)
	if _drive_keep_v:
		if on_floor and vy <= 0.0:
			vy = -3.0
		else:
			vy = maxf(vy - GRAVITY * dt, -MAX_FALL)
		fighter.velocity = Vector3(drive_dir.x, 0.0, drive_dir.z) * spd + Vector3.UP * vy
	else:
		fighter.velocity = drive_dir * spd
	impulse *= exp(-6.0 * dt)
	fighter.velocity += impulse


func _post_slide(pre_vy: float) -> void:
	var f := fighter
	var on_floor := f.is_on_floor()
	if on_floor and not _was_on_floor:
		landed.emit(maxf(0.0, -pre_vy))
		if drive == Drive.NONE:
			vy = 0.0
	if f.is_on_ceiling():
		vy = minf(vy, 0.0)
		impulse.y = minf(impulse.y, 0.0)
	if f.is_on_wall():
		var n := f.get_wall_normal()
		_wall_left = 0.18
		_wall_normal = Vector3(n.x, 0.0, n.z).normalized()
		run_vel -= _wall_normal * minf(0.0, run_vel.dot(_wall_normal))
		var into := impulse.dot(_wall_normal)
		var dash_into := drive == Drive.DASH and drive_dir.dot(_wall_normal) < -0.2
		if not on_floor and _mantle_cd <= 0.0:
			var wish := f.world_move_dir()
			if dash_into or wish.dot(-_wall_normal) > 0.2 or into < -1.0 or run_vel.dot(-_wall_normal) > 1.0:
				_try_mantle()
		if not mantling:
			impulse -= _wall_normal * minf(0.0, into)
			# a dash with real lift keeps climbing the wall; a flat one stops dead
			if drive == Drive.DASH and dash_into and absf(drive_dir.y) < 0.35:
				end_drive()
	_was_on_floor = on_floor


## Ledge grab: when airborne against a wall with a ledge inside reach, hoist up.
func _try_mantle() -> bool:
	var f := fighter
	var fwd := -_wall_normal
	var base := f.global_position
	var space := f.get_world_3d().direct_space_state
	var from := base + fwd * 0.75 + Vector3.UP * (MANTLE_MAX + 0.15)
	var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * (MANTLE_MAX - MANTLE_MIN + 0.15), Fighter.LAYER_WORLD)
	var r := space.intersect_ray(q)
	if r.is_empty() or r.normal.y < 0.7:
		return false
	var h: float = r.position.y - base.y
	if h < MANTLE_MIN or h > MANTLE_MAX:
		return false
	var head_q := PhysicsRayQueryParameters3D.create(r.position + Vector3.UP * 0.1, r.position + Vector3.UP * 1.85, Fighter.LAYER_WORLD)
	if not space.intersect_ray(head_q).is_empty():
		return false
	mantling = true
	if drive != Drive.NONE:
		end_drive()
	_m_from = base
	_m_to = r.position + fwd * 0.4
	_m_t = 0.0
	_m_dur = MANTLE_TIME + h * 0.04
	f.guard.drop()
	f.interrupt_channel()
	return true


func _step_mantle(dt: float) -> void:
	_m_t += dt
	var k := clampf(_m_t / _m_dur, 0.0, 1.0)
	var e := k * k * (3.0 - 2.0 * k)
	var p := _m_from.lerp(_m_to, e)
	p.y = lerpf(_m_from.y, _m_to.y, minf(1.0, e * 1.7))
	fighter.global_position = p
	fighter.velocity = Vector3.ZERO
	if k >= 1.0:
		mantling = false
		vy = 0.0
		var fwd := (_m_to - _m_from) * Vector3(1, 0, 1)
		run_vel = fwd.normalized() * 3.0 if fwd.length() > 0.01 else Vector3.ZERO
		impulse = Vector3.ZERO
		_mantle_cd = 0.25
		_wall_kicks = 0
		chain = 0
		_chain_left = 0.0
		dash_pool.refund(1.0)
		mantled.emit()
