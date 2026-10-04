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
var face_yaw := 0.0
var spawn_transform := Transform3D.IDENTITY
var spawn_yaw := 0.0

@onready var body_shape: CollisionShape3D = $BodyShape
@onready var motor: HeroMotor = $Motor
@onready var states: MoveStateMachine = $States
@onready var model: HeroModel = $Model
@onready var defense: HeroDefense = $Defense


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
	states.state_changed.connect(func(from: StringName, to: StringName) -> void:
		Events.hero_state_changed.emit(self, from, to))


func _physics_process(dt: float) -> void:
	motor.tick_timers(dt)
	defense.tick(dt)
	states.physics_update(dt)
	_update_facing(dt)
	model.set_crouched(motor.crouched)
	model.set_guard(defense.blocking, defense.perfect_window_left > 0.0)
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
	face_yaw = spawn_yaw
	states.change(&"Air")
	reset_physics_interpolation()


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
