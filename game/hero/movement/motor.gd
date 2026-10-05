class_name HeroMotor
extends Node
## The only thing that actually moves the hero's body.
##
## States decide WHAT should happen ("accelerate toward sprint speed", "jump");
## the motor does the physics: it sums the velocity parts, calls move_and_slide,
## walks over small steps, remembers walls, and answers geometry questions
## ("is there a ledge in front of me?", "is there room to stand up?").
##
## Velocity is a SUM of three separate parts instead of one overwritten number:
##   run_vel  - horizontal, input-driven movement
##   vy       - vertical: gravity and jumping
##   impulse  - decaying shoves (knockback, explosions, card effects later)
## Keeping them apart means a card can shove you (impulse) without fighting the
## code that steers you (run_vel).

var hero: Hero
var tuning: MovementTuning

var run_vel := Vector3.ZERO
var vy := 0.0
var impulse := Vector3.ZERO

# ---- read by states ----
var on_floor := true
var just_landed := false          # true for one tick after touching down
var land_speed := 0.0             # downward speed at the moment of landing
var coyote_left := 0.0
var jump_buffer_left := 0.0
var jumped := false               # true while rising from a jump (for jump-cut)
var wall_left := 0.0              # >0 = touched a wall recently
var wall_normal := Vector3.ZERO   # flat normal of that wall
var wall_kicks_used := 0
var crouched := false             # the capsule is currently short
var hold_crouch := false          # set by the Crouch state; otherwise we stand up when there's room
var dash_pool: ChargePool         # sigil leap charges (core/charge_pool.gd)
var dash_cd_left := 0.0
var dash_buffer_left := 0.0
var hang_left := 0.0              # >0 = low gravity (just after a leap)
var roll_pool: ChargePool         # dodge roll charges (stops roll spam; Lucy's pick)
var roll_cd_left := 0.0
var roll_buffer_left := 0.0

var _was_on_floor := true
var _shape: CollisionShape3D
var _capsule: CapsuleShape3D


func setup(p_hero: Hero, shape: CollisionShape3D) -> void:
	hero = p_hero
	tuning = hero.tuning
	_shape = shape
	_capsule = CapsuleShape3D.new()
	_shape.shape = _capsule
	_apply_height(tuning.stand_height)
	hero.floor_max_angle = deg_to_rad(tuning.max_floor_angle)
	hero.floor_snap_length = 0.45
	hero.floor_stop_on_slope = true
	hero.safe_margin = 0.01
	dash_pool = ChargePool.new(tuning.dash_charges, tuning.dash_recharge_time, 0.0)
	roll_pool = ChargePool.new(tuning.roll_charges, tuning.roll_recharge_time, 0.0)


func reset() -> void:
	run_vel = Vector3.ZERO
	vy = 0.0
	impulse = Vector3.ZERO
	jumped = false
	jump_buffer_left = 0.0
	wall_left = 0.0
	wall_kicks_used = 0
	hold_crouch = false
	dash_pool.fill()
	roll_pool.fill()
	dash_cd_left = 0.0
	dash_buffer_left = 0.0
	hang_left = 0.0
	roll_cd_left = 0.0
	roll_buffer_left = 0.0
	if crouched:
		crouched = false
		_apply_height(tuning.stand_height)


## Called once per physics tick by the hero, before the active state runs.
func tick_timers(dt: float) -> void:
	just_landed = false
	jump_buffer_left = maxf(0.0, jump_buffer_left - dt)
	wall_left = maxf(0.0, wall_left - dt)
	dash_buffer_left = maxf(0.0, dash_buffer_left - dt)
	dash_cd_left = maxf(0.0, dash_cd_left - dt)
	hang_left = maxf(0.0, hang_left - dt)
	dash_pool.tick(dt)
	roll_pool.tick(dt)
	if hero.intent.jump_pressed:
		jump_buffer_left = tuning.jump_buffer
	if hero.intent.dash_pressed:
		dash_buffer_left = tuning.dash_buffer
	roll_cd_left = maxf(0.0, roll_cd_left - dt)
	roll_buffer_left = maxf(0.0, roll_buffer_left - dt)
	if hero.intent.roll_pressed:
		roll_buffer_left = tuning.roll_buffer
	if on_floor:
		coyote_left = tuning.coyote_time
		wall_kicks_used = 0
	else:
		coyote_left = maxf(0.0, coyote_left - dt)
	# Stand back up as soon as nobody wants us crouched and there is headroom.
	if crouched and not hold_crouch and has_room_to_stand():
		set_crouched(false)


# ------------------------------------------------------------ steering helpers

## Desired horizontal direction from the intent, in world space (length 0..1).
func wish_dir() -> Vector3:
	var i := hero.intent
	var d := Basis(Vector3.UP, i.aim_yaw) * Vector3(i.move.x, 0.0, -i.move.y)
	return d.limit_length(1.0)


## Ground steering: move toward the wished velocity. Speed above the run speed
## (from a leap or knockback) bleeds off slowly, so landings skid.
func steer(target_speed: float, accel: float, brake: float, dt: float) -> void:
	var wish := wish_dir()
	var rate := accel if wish != Vector3.ZERO else brake
	if run_vel.length() > maxf(target_speed, tuning.sprint_speed) + 0.5:
		rate = minf(rate, tuning.ground_overspeed_brake)
	run_vel = run_vel.move_toward(wish * target_speed, rate * dt)


## Air steering: push toward the wished direction, but never past
## max(current speed, target speed), and never brake momentum you're not
## pushing against. Low air_accel = committed jumps; momentum carries.
func air_steer(target_speed: float, dt: float) -> void:
	var wish := wish_dir()
	if wish != Vector3.ZERO:
		var cap := maxf(run_vel.length(), target_speed)
		var nv := run_vel + wish * tuning.air_accel * dt
		run_vel = nv.limit_length(cap)
	run_vel = run_vel.move_toward(Vector3.ZERO, tuning.air_drag * dt)


func apply_gravity(dt: float, scale: float = 1.0) -> void:
	var g := tuning.gravity * scale
	if hang_left > 0.0:
		g *= 0.2
	if vy < 0.0:
		g *= tuning.fall_gravity_mult
	vy = maxf(vy - g * dt, -tuning.max_fall_speed)


## Short hop if jump is released while still rising.
func apply_jump_cut() -> void:
	if jumped and vy > 0.0 and not hero.intent.jump_held:
		vy *= tuning.jump_cut
		jumped = false
	if vy <= 0.0:
		jumped = false


func jump() -> void:
	vy = tuning.jump_speed
	jumped = true
	coyote_left = 0.0
	jump_buffer_left = 0.0


func can_wall_kick() -> bool:
	return wall_left > 0.0 and wall_kicks_used < tuning.wall_kicks_per_air


func wall_kick() -> void:
	vy = tuning.wall_kick_up_speed
	run_vel = wall_normal * tuning.wall_kick_out_speed + wish_dir() * 3.0
	impulse = Vector3.ZERO
	wall_kicks_used += 1
	wall_left = 0.0
	jumped = true
	jump_buffer_left = 0.0


func add_impulse(v: Vector3) -> void:
	impulse += v


## A leap was requested (recently) and is allowed right now.
func wants_dash() -> bool:
	return dash_buffer_left > 0.0 and dash_cd_left <= 0.0 and dash_pool.has_charge()


## A roll was requested (recently) and is allowed: grounded, off cooldown, a charge left.
func wants_roll() -> bool:
	return roll_buffer_left > 0.0 and roll_cd_left <= 0.0 and on_floor and roll_pool.has_charge()


## Direction of a leap: where the camera aims, clamped so it never goes
## straight up/down and never digs into the floor when grounded.
func dash_direction() -> Vector3:
	var aim := hero.intent.aim_dir.normalized()
	var flat := Vector3(aim.x, 0.0, aim.z)
	if flat.length() < 0.05:
		flat = Basis(Vector3.UP, hero.intent.aim_yaw) * Vector3.FORWARD
	flat = flat.normalized()
	var pitch := clampf(aim.y, tuning.dash_min_pitch, tuning.dash_max_pitch)
	if on_floor:
		pitch = maxf(pitch, tuning.dash_ground_min_pitch)
	var h := sqrt(1.0 - pitch * pitch)
	return Vector3(flat.x * h, pitch, flat.z * h)


# ------------------------------------------------------------ the actual move

## Sum the parts, try a step-up, then move_and_slide and record what we hit.
func move(dt: float) -> void:
	impulse *= exp(-(8.0 if on_floor else 1.5) * dt)
	hero.velocity = run_vel + Vector3.UP * vy + impulse
	var pre_vy := hero.velocity.y
	if on_floor:
		_try_step_up(dt)
	hero.move_and_slide()
	_after_move(pre_vy)


## Move with an exact velocity (used by the leap, which ignores steering).
## move_and_slide sweeps the capsule along the path, so fast moves can't skip
## through thin walls.
func move_direct(v: Vector3) -> void:
	hero.velocity = v
	hero.move_and_slide()
	_after_move(v.y)


func _after_move(pre_vy: float) -> void:
	on_floor = hero.is_on_floor()
	if on_floor and not _was_on_floor:
		just_landed = true
		land_speed = maxf(0.0, -pre_vy)
		vy = 0.0
	if on_floor and vy < 0.0:
		vy = 0.0
	if hero.is_on_ceiling():
		vy = minf(vy, 0.0)
		impulse.y = minf(impulse.y, 0.0)
	if hero.is_on_wall():
		var n := hero.get_wall_normal()
		var flat := Vector3(n.x, 0.0, n.z)
		if flat.length() > 0.01:
			wall_normal = flat.normalized()
			wall_left = tuning.wall_contact_grace
			# Don't keep pushing into the wall; that would build up hidden speed.
			run_vel -= wall_normal * minf(0.0, run_vel.dot(wall_normal))
			impulse -= wall_normal * minf(0.0, impulse.dot(wall_normal))
	_was_on_floor = on_floor


## Walks over curbs and single stairs. If something low blocks our feet and
## there's a flat top within step_height just past it, lift the body onto that
## height; move_and_slide then carries us over the edge as normal.
func _try_step_up(dt: float) -> bool:
	var hv := Vector3(hero.velocity.x, 0.0, hero.velocity.z)
	if hv.length() < 0.1 or tuning.step_height <= 0.0:
		return false
	var dir := hv.normalized()
	var probe := dir * (hv.length() * dt + 0.05)
	# Start the probe a hair above the feet so resting on the floor doesn't count as a hit.
	var t := hero.global_transform.translated(Vector3.UP * 0.03)
	var hit := KinematicCollision3D.new()
	if not hero.test_move(t, probe, hit):
		return false                                   # nothing in the way
	if hit.get_normal().y > cos(hero.floor_max_angle):
		return false                                   # a walkable slope, not a step
	# Look for the top of the obstacle just beyond the contact point.
	var p := hit.get_position() + dir * 0.08
	var feet := hero.global_position.y
	var space := hero.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(p.x, feet + tuning.step_height + 0.05, p.z), Vector3(p.x, feet + 0.01, p.z), Hero.LAYER_WORLD)
	q.exclude = [hero.get_rid()]
	var r := space.intersect_ray(q)
	if r.is_empty() or r.normal.y < cos(hero.floor_max_angle):
		return false                                   # too tall (a wall) or the top isn't standable
	var rise: float = r.position.y - feet + 0.02
	if rise > tuning.step_height + 0.02:
		return false
	var lift := Vector3.UP * rise
	if hero.test_move(hero.global_transform, lift):
		return false                                   # no headroom
	if hero.test_move(hero.global_transform.translated(lift), probe):
		return false                                   # still blocked higher up
	hero.global_position += lift
	return true


# ------------------------------------------------------------ geometry questions

## Is there a ledge in front (along -wall_normal) that we can pull up onto?
## Returns {} if not, or {"to": landing point, "height": ledge height above feet}.
func find_ledge() -> Dictionary:
	if wall_left <= 0.0:
		return {}
	var fwd := -wall_normal
	var base := hero.global_position
	var space := hero.get_world_3d().direct_space_state
	var top := base + fwd * tuning.mantle_reach + Vector3.UP * (tuning.mantle_max_height + 0.15)
	var span := tuning.mantle_max_height - tuning.mantle_min_height + 0.15
	var q := PhysicsRayQueryParameters3D.create(top, top + Vector3.DOWN * span, Hero.LAYER_WORLD)
	q.exclude = [hero.get_rid()]
	var r := space.intersect_ray(q)
	if r.is_empty() or r.normal.y < 0.7:
		return {}
	var height: float = r.position.y - base.y
	if height < tuning.mantle_min_height or height > tuning.mantle_max_height:
		return {}
	# Is there room for a standing body on top of the ledge?
	var head := PhysicsRayQueryParameters3D.create(r.position + Vector3.UP * 0.1, r.position + Vector3.UP * (tuning.stand_height + 0.05), Hero.LAYER_WORLD)
	head.exclude = [hero.get_rid()]
	if not space.intersect_ray(head).is_empty():
		return {}
	return {"to": r.position + fwd * (tuning.capsule_radius + 0.1), "height": height}


func has_room_to_stand() -> bool:
	var extra := tuning.stand_height - tuning.crouch_height
	return not hero.test_move(hero.global_transform, Vector3.UP * extra)


func set_crouched(on: bool) -> void:
	if on == crouched:
		return
	crouched = on
	_apply_height(tuning.crouch_height if on else tuning.stand_height)


## The capsule's bottom stays at the hero's origin (the feet), so changing the
## height shrinks it from the top.
func _apply_height(h: float) -> void:
	_capsule.radius = tuning.capsule_radius
	_capsule.height = h
	_shape.position = Vector3(0.0, h * 0.5, 0.0)
