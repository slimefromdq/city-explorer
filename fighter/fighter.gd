class_name Fighter
extends CharacterBody3D
## The archetype-agnostic shared layer: body, hurtbox, health, guard, dodge,
## locomotion, bounty and visuals. Archetypes (see abilities/gunslinger) only
## add a kit of Ability nodes and a palette. Controllers (player or bot) never
## touch physics - they just fill in the intent fields below.

signal damaged(hit: HitData, result: int, amount: float)
signal died(victim: Fighter, killer: Fighter)
signal respawned

const LAYER_WORLD := 1
const LAYER_FIGHTER := 2
const LAYER_HURTBOX := 4
const STUN_DAMAGE_BONUS := 1.25
const RESPAWN_DELAY := 3.0

@export var display_name := "Fighter"
@export var max_health := 100.0

var health := 100.0
var alive := true
var respawn_delay := RESPAWN_DELAY
var kit: Array[Ability] = []            # slot 0 = M1, slots 1..4 = moves
var channel: Ability = null             # ability currently held/charging

# ---- intents (written by controllers) ----
var move_input := Vector2.ZERO          # x = right, y = forward, in aim_yaw space
var aim_yaw := 0.0
var aim_dir := Vector3.FORWARD
var aim_point := Vector3.ZERO
var face_yaw := 0.0
var wants_sprint := false
var wants_block := false
var jump_held := false
var aim_zoom := 0.0                     # 0..1, read by the camera

# ---- timers ----
var stun_left := 0.0                    # can do nothing
var recovery_left := 0.0                # can't start abilities / dodge / block
var root_left := 0.0                    # can't dash / jump / sprint
var sprint_lock_left := 0.0
var iframes_left := 0.0                 # extra invulnerability (e.g. slide start)
var engage_left := 0.0                  # >0: body faces the aim direction
var last_aggressor: Fighter = null
var spawn_transform := Transform3D.IDENTITY

var _slow_scale := 1.0
var _slow_left := 0.0

# ---- components ----
var loco: Locomotion
var guard: GuardComponent
var dodge: DodgeComponent
var bounty: BountyComponent
var gun: GunComponent
var model: CharacterModel
var hurtbox: Hurtbox
var ring: MeterRing
var nameplate: Nameplate
var _shape: CollisionShape3D
var _capsule := CapsuleShape3D.new()


func _init() -> void:
	collision_layer = LAYER_FIGHTER
	collision_mask = LAYER_WORLD
	floor_max_angle = deg_to_rad(50.0)
	floor_snap_length = 0.45
	floor_stop_on_slope = true
	safe_margin = 0.01
	add_to_group(&"fighters")

	_capsule.radius = 0.4
	_capsule.height = 1.8
	_shape = CollisionShape3D.new()
	_shape.shape = _capsule
	_shape.position = Vector3(0, 0.9, 0)
	add_child(_shape)

	hurtbox = Hurtbox.new()
	hurtbox.fighter = self
	add_child(hurtbox)

	loco = _add(Locomotion.new()) as Locomotion
	guard = _add(GuardComponent.new()) as GuardComponent
	dodge = _add(DodgeComponent.new()) as DodgeComponent
	bounty = _add(BountyComponent.new()) as BountyComponent

	model = CharacterModel.new()
	model.fighter = self
	add_child(model)
	ring = MeterRing.new()
	ring.fighter = self
	add_child(ring)
	nameplate = Nameplate.new()
	nameplate.fighter = self
	add_child(nameplate)


func _add(c: Node) -> Node:
	c.set(&"fighter", self)
	add_child(c)
	return c


func _ready() -> void:
	health = max_health
	spawn_transform = global_transform
	nameplate.set_name_text(display_name)
	loco.drive_ended.connect(_on_drive_ended)


func _on_drive_ended(kind: int) -> void:
	if kind == Locomotion.Drive.SLIDE:
		set_crouched(false)


# ------------------------------------------------------------------ queries

func world_move_dir() -> Vector3:
	var d := Basis(Vector3.UP, aim_yaw) * Vector3(move_input.x, 0.0, -move_input.y)
	return d.limit_length(1.0)


func facing_dir() -> Vector3:
	return Vector3(-sin(face_yaw), 0.0, -cos(face_yaw))


func center() -> Vector3:
	return global_position + Vector3.UP * 1.0


func can_act() -> bool:
	return alive and stun_left <= 0.0 and recovery_left <= 0.0 and channel == null and not loco.busy()


func can_block() -> bool:
	return can_act() and guard.value > 0.0


func can_dodge() -> bool:
	return alive and stun_left <= 0.0 and recovery_left <= 0.0 and not loco.mantling and loco.drive != Locomotion.Drive.SLIDE and loco.drive != Locomotion.Drive.DODGE


func can_move_act() -> bool:
	return alive and stun_left <= 0.0 and root_left <= 0.0 and not loco.mantling


func can_sprint() -> bool:
	return alive and root_left <= 0.0 and sprint_lock_left <= 0.0 and not guard.blocking and channel == null and stun_left <= 0.0


func is_invulnerable() -> bool:
	return dodge.in_iframes() or iframes_left > 0.0


func move_scale() -> float:
	if stun_left > 0.0:
		return 0.0
	var s := _slow_scale if _slow_left > 0.0 else 1.0
	if guard.blocking:
		s *= 0.55
	if channel != null:
		s *= channel.move_scale
	return s


# ------------------------------------------------------------------ control

func slow(scale: float, duration: float) -> void:
	if _slow_left <= 0.0 or scale < _slow_scale:
		_slow_scale = scale
	_slow_left = maxf(_slow_left, duration)


func engage(t: float = 1.4) -> void:
	engage_left = maxf(engage_left, t)


func lock_sprint(t: float) -> void:
	sprint_lock_left = maxf(sprint_lock_left, t)


func set_crouched(on: bool) -> void:
	hurtbox.set_stance(on)


func apply_stun(t: float) -> void:
	stun_left = maxf(stun_left, t)
	interrupt_channel()
	for a in kit:
		a.interrupt()
	guard.drop()


func interrupt_channel() -> void:
	if channel != null:
		channel.interrupt()


func press_ability(slot: int) -> void:
	if slot < kit.size() and alive:
		kit[slot].press()


func release_ability(slot: int) -> void:
	if slot < kit.size():
		kit[slot].release()


func hold_ability(slot: int, held: bool) -> void:
	if slot < kit.size():
		kit[slot].held = held


## Debug/test helper: refill every meter and clear every cooldown.
func reset_meters() -> void:
	health = max_health
	stun_left = 0.0
	recovery_left = 0.0
	root_left = 0.0
	guard.reset()
	dodge.reset()
	loco.dash_pool.fill()
	if gun != null:
		gun.refill()
	for a in kit:
		a.reset()


# ------------------------------------------------------------------ combat

func receive_hit(hit: HitData) -> HitData.Result:
	if not alive:
		return HitData.Result.NONE
	var attacker := hit.attacker as Fighter
	if is_invulnerable() and hit.dodgeable:
		_report(hit, HitData.Result.DODGED, 0.0)
		return HitData.Result.DODGED
	var g := guard.absorb(hit)
	if g != HitData.Result.NONE:
		if attacker != null:
			last_aggressor = attacker
		_report(hit, g, 0.0)
		return g
	var dmg := hit.damage * (STUN_DAMAGE_BONUS if stun_left > 0.0 else 1.0)
	health -= dmg
	if attacker != null:
		last_aggressor = attacker
	if hit.flinch > 0.0 and stun_left <= 0.0:
		recovery_left = maxf(recovery_left, hit.flinch)
		interrupt_channel()
		for a in kit:
			a.interrupt()
	loco.add_impulse(hit.knockback)
	guard.drop()
	model.flash_hit()
	_report(hit, HitData.Result.HIT, dmg)
	if health <= 0.0:
		_die(attacker)
	return HitData.Result.HIT


func _report(hit: HitData, result: HitData.Result, amount: float) -> void:
	damaged.emit(hit, result, amount)
	Events.hit_resolved.emit(hit.attacker, self, result, amount, hit.position)


func _die(killer: Fighter) -> void:
	alive = false
	health = 0.0
	hurtbox.set_active(false)
	interrupt_channel()
	for a in kit:
		a.interrupt()
	loco.reset()
	guard.drop()
	velocity = Vector3.ZERO
	var worth := bounty.value()
	bounty.on_death()
	if killer != null and killer != self:
		killer.bounty.on_kill(worth)
		Events.feed.emit("%s  >  %s   (+%d)" % [killer.display_name, display_name, worth])
	else:
		Events.feed.emit("%s went down" % display_name)
	died.emit(self, killer)
	Events.fighter_died.emit(self, killer)
	if respawn_delay > 0.0:
		get_tree().create_timer(respawn_delay).timeout.connect(respawn)


func respawn() -> void:
	if alive or not is_inside_tree():
		return
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	alive = true
	hurtbox.set_active(true)
	set_crouched(false)
	reset_meters()
	loco.reset()
	reset_physics_interpolation()
	respawned.emit()


# ------------------------------------------------------------------ tick

func _physics_process(delta: float) -> void:
	if not alive:
		return
	stun_left = maxf(0.0, stun_left - delta)
	recovery_left = maxf(0.0, recovery_left - delta)
	root_left = maxf(0.0, root_left - delta)
	sprint_lock_left = maxf(0.0, sprint_lock_left - delta)
	iframes_left = maxf(0.0, iframes_left - delta)
	engage_left = maxf(0.0, engage_left - delta)
	_slow_left = maxf(0.0, _slow_left - delta)
	guard.set_wanted(wants_block)
	guard.tick(delta)
	dodge.tick(delta)
	if gun != null:
		gun.tick(delta)
	_update_facing(delta)
	loco.step(delta)


## Body faces the aim while shooting/blocking/charging, the travel direction
## while dashing, and the run direction otherwise.
func _update_facing(delta: float) -> void:
	var want := face_yaw
	if engage_left > 0.0 or guard.blocking or channel != null:
		want = atan2(-aim_dir.x, -aim_dir.z)
	elif loco.drive != Locomotion.Drive.NONE:
		want = atan2(-loco.drive_dir.x, -loco.drive_dir.z)
	else:
		var h := Vector2(velocity.x, velocity.z)
		if h.length() > 1.5:
			want = atan2(-h.x, -h.y)
	face_yaw = lerp_angle(face_yaw, want, minf(1.0, 18.0 * delta))
