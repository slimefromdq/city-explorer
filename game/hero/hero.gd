class_name Hero
extends CharacterBody3D
## The one shared hero body. Every hero (Sky Runner, Butcher, Engineer...) is
## this same scene; what makes them different arrives later as data (cards and a
## passive), never as different movement code.
##
## How a tick flows:
##   1. whoever controls us (PlayerInput, later a bot) has already written `intent`
##   2. the motor counts down its timers
##   3. the active state (Ground / Air / Crouch / Mantle ...) reads the intent and
##      asks the motor to move
##   4. we turn the model to face where we're going, and clear one-frame presses
##
## Movement events (OnJump, OnLand, OnDashLaunch...) go out through
## `emit_movement_event`, both as this hero's own signal (cards on THIS hero will
## listen to it in M2) and on the global Events bus (the debug overlay listens).

signal movement_event(type: int, data: Dictionary)

const LAYER_WORLD := 1
const LAYER_CHARACTER := 2
const DEFAULT_TUNING := "res://game/hero/movement/default_tuning.tres"

@export var display_name := "Hero"
## All movement numbers. Swap in a different .tres to try another feel.
@export var tuning: MovementTuning

var intent := HeroIntent.new()
## Which hero this body is playing (null until apply_definition).
var definition: HeroDefinition
var face_yaw := 0.0
var spawn_transform := Transform3D.IDENTITY
var spawn_yaw := 0.0
## Slows and burns from cards (StatusSet). Slow scales every movement speed.
var statuses := StatusSet.new()

@onready var body_shape: CollisionShape3D = $BodyShape
@onready var motor: HeroMotor = $Motor
@onready var states: MoveStateMachine = $States
@onready var model: HeroModel = $Model
@onready var defense: HeroDefense = $Defense
## Casts the equipped cards (M2). Optional so a bare body still works.
@onready var runner: AbilityRunner = get_node_or_null("Runner")
## Uses mirrors, doors and benches (player heroes only).
@onready var interactor: Interactor = get_node_or_null("Interactor")


func _ready() -> void:
	if tuning == null:
		push_warning("Hero '%s' has no MovementTuning assigned; using %s" % [display_name, DEFAULT_TUNING])
		tuning = load(DEFAULT_TUNING)
	collision_layer = LAYER_CHARACTER
	collision_mask = LAYER_WORLD
	add_to_group(&"heroes")
	# The body itself never rotates; only the model turns. That keeps the
	# capsule and all movement maths in plain world space.
	spawn_yaw = global_rotation.y
	face_yaw = spawn_yaw
	global_rotation = Vector3.ZERO
	spawn_transform = global_transform
	motor.setup(self, body_shape)
	defense.setup(self)
	states.setup(self, motor)
	if runner != null:
		runner.setup(self)
	states.state_changed.connect(func(from: StringName, to: StringName) -> void:
		Events.hero_state_changed.emit(self, from, to))


func _physics_process(dt: float) -> void:
	motor.tick_timers(dt)
	defense.tick(dt)
	statuses.tick(self, dt)
	states.physics_update(dt)
	_update_facing(dt)
	model.set_crouched(motor.crouched)
	model.set_guard(defense.blocking, defense.perfect_window_left > 0.0)
	if runner != null:
		runner.tick(dt)   # after movement, so casts start from where we are now
	if intent.interact_pressed and interactor != null:
		interactor.handle_press()
	intent.clear_presses()


func emit_movement_event(type: MoveEvent.Type, data: Dictionary = {}) -> void:
	movement_event.emit(type, data)
	Events.movement_event.emit(self, type, data)


## Every attack on the hero comes through here. Returns a HitData.Result.
func take_hit(hit: HitData) -> int:
	return defense.take_hit(hit)


## Instant respawn at the spawn point with everything reset.
func respawn() -> void:
	global_transform = spawn_transform
	velocity = Vector3.ZERO
	motor.reset()
	defense.reset()
	statuses.clear()
	face_yaw = spawn_yaw
	states.change(&"Air")
	reset_physics_interpolation()


## Knock the hero around (explosions, kicks, their own rocket jump). Goes into
## real momentum (run_vel / vy), so with low air control a blast really sends you.
func push(v: Vector3) -> void:
	motor.run_vel += Vector3(v.x, 0.0, v.z)
	if v.y > 0.0:
		motor.vy = maxf(motor.vy, 0.0) + v.y
	else:
		motor.vy += v.y
	# Grounded states pin us to the floor every tick; an upward shove has to
	# hand over to Air or it would be cancelled.
	if v.y > 1.0 and states.current_name in [&"Ground", &"Crouch", &"Slide", &"Block", &"Roll"]:
		states.change(&"Air")


func apply_status(kind: StatusSet.Kind, duration: float, magnitude: float, source: Node3D) -> void:
	if not statuses.has(kind):
		FloatingText.spawn(self, StatusSet.NAMES[kind], global_position + Vector3.UP * 2.2, StatusSet.COLORS[kind], 44)
	statuses.apply(kind, duration, magnitude, source)


## Movement speed multiplier from status effects (1 = normal).
func speed_mult() -> float:
	return statuses.speed_mult()


func is_dead() -> bool:
	return defense.dead


## Where hand-thrown cards start: chest height, a little to the right (the
## camera sits over the right shoulder).
func hand_position() -> Vector3:
	return global_position + Vector3.UP * (0.95 if motor.crouched else 1.35) + Basis(Vector3.UP, intent.aim_yaw) * Vector3(0.35, 0.0, -0.2)


## Instantly move (teleport cards). Optionally keep running speed.
func teleport_to(pos: Vector3, keep_momentum: bool) -> void:
	global_position = pos
	if not keep_momentum:
		motor.run_vel = Vector3.ZERO
		motor.impulse = Vector3.ZERO
	motor.vy = maxf(motor.vy, 0.0)
	reset_physics_interpolation()
	if states.current_name in [&"Ground", &"Crouch", &"Slide", &"Roll"]:
		states.change(&"Air")   # Air lands again at once if we arrived on a floor


## Become `def`: its colours and passive, with `cards` in the 4 slots
## (normally the player's saved loadout for that hero).
func apply_definition(def: HeroDefinition, cards: Array) -> void:
	if def == null:
		push_error("Hero.apply_definition: no hero definition")
		return
	definition = def
	display_name = def.display_name
	model.set_colors(def.body_color, def.accent_color)
	if runner != null:
		runner.set_cards(cards)
		runner.set_passive(def.passive)


func set_spawn(t: Transform3D, yaw: float) -> void:
	spawn_transform = Transform3D(Basis.IDENTITY, t.origin)
	spawn_yaw = yaw


func horizontal_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()


## The model faces where we're travelling (Block and the leap set face_yaw
## themselves, so we leave it alone in those states).
func _update_facing(dt: float) -> void:
	var h := Vector2(velocity.x, velocity.z)
	var locked := states.current_name in [&"Block", &"DashStartup", &"Roll"]
	if h.length() > 1.5 and not locked:
		face_yaw = lerp_angle(face_yaw, atan2(-h.x, -h.y), minf(1.0, tuning.turn_speed * dt))
	model.rotation.y = face_yaw
