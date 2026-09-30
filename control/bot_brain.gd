class_name BotBrain
extends Node
## Test-bench opponent. Fills in the same intents a player would, so the bot
## uses the exact same Fighter rules (guard meter, dodge pool, ammo). No
## pathfinding: bots hold a leash around their spawn.

enum Mode { DUMMY, BLOCKER, DODGER, AGGRESSOR }

const MODE_NAMES := ["Dummy (idle)", "Blocker", "Dodger", "Aggressor"]

var fighter: Fighter
var target: Fighter
var mode: Mode = Mode.DUMMY
var leash := 7.0
var home := Vector3.ZERO

var _dodge_at := -1.0
var _strafe_dir := 1.0
var _strafe_t := 0.0
var _fire_t := 1.5
var _block_release_t := 0.0
var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	process_physics_priority = -20
	_rng.randomize()
	home = fighter.global_position


func set_mode(m: Mode) -> void:
	mode = m
	fighter.wants_block = false
	fighter.move_input = Vector2.ZERO


func _physics_process(dt: float) -> void:
	var f := fighter
	if not f.alive or target == null or not target.alive:
		f.move_input = Vector2.ZERO
		f.wants_block = false
		f.wants_sprint = false
		return
	# look at the target (chest height)
	var to := target.center() - f.center()
	var flat := Vector3(to.x, 0.0, to.z)
	f.aim_yaw = atan2(-flat.x, -flat.z) if flat.length() > 0.1 else f.aim_yaw
	f.aim_point = target.center() + Vector3(_rng.randf_range(-0.3, 0.3), _rng.randf_range(-0.2, 0.2), _rng.randf_range(-0.3, 0.3))
	f.aim_dir = (f.aim_point - f.center()).normalized()
	f.move_input = Vector2.ZERO
	f.wants_sprint = false
	if mode == Mode.DUMMY:
		f.wants_block = false
		return
	var dist := to.length()
	match mode:
		Mode.BLOCKER:
			_block_release_t -= dt
			f.wants_block = f.guard.value > 12.0 and dist < 60.0 and _block_release_t <= 0.0
			if f.guard.value < 12.0:
				_block_release_t = 1.2
		Mode.DODGER:
			f.wants_block = false
			_react_dodge(dt)
		Mode.AGGRESSOR:
			_aggressor(dt, dist)
			_react_dodge(dt, 0.35)


func _react_dodge(dt: float, reaction := 0.18) -> void:
	var f := fighter
	if _dodge_at >= 0.0:
		_dodge_at -= dt
		if _dodge_at < 0.0:
			f.dodge.try_dodge()
			_dodge_at = -1.0
		return
	for n in get_tree().get_nodes_in_group(&"projectiles"):
		var p := n as Projectile
		if p == null or p.attacker == f:
			continue
		var rel := f.center() - p.global_position
		var spd := p.velocity.length()
		var along := rel.dot(p.velocity) / spd
		if along < 0.0:
			continue
		var perp := (rel - p.velocity.normalized() * along).length()
		var eta := along / spd
		if perp < 1.1 and eta > 0.05 and eta < 0.5:
			_dodge_at = reaction
			return


func _aggressor(dt: float, dist: float) -> void:
	var f := fighter
	_strafe_t -= dt
	if _strafe_t <= 0.0:
		_strafe_t = _rng.randf_range(0.6, 1.6)
		_strafe_dir = -_strafe_dir if _rng.randf() < 0.6 else _strafe_dir
	var away_home := Vector3(f.global_position.x - home.x, 0.0, f.global_position.z - home.z)
	var fwd := 0.0
	if dist > 26.0:
		fwd = 1.0
	elif dist < 10.0:
		fwd = -1.0
	if away_home.length() > leash:
		fwd = -1.0 if away_home.dot(Vector3(-sin(f.aim_yaw), 0, -cos(f.aim_yaw))) < 0.0 else 1.0
		fwd *= -1.0
	f.move_input = Vector2(_strafe_dir, fwd).limit_length(1.0)
	_fire_t -= dt
	if _fire_t <= 0.0 and dist < 45.0:
		_fire_t = _rng.randf_range(1.2, 2.8)
		var roll := _rng.randf()
		if roll < 0.55:
			f.press_ability(0)
		elif roll < 0.8:
			f.press_ability(1)
		elif roll < 0.92:
			f.press_ability(3)
		else:
			f.press_ability(2)
	f.hold_ability(0, false)
