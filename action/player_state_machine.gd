class_name ActionPlayerStateMachine
extends RefCounted
## Single authority for action eligibility. Automatic completion uses set_state;
## input handlers always consult allows first. A network controller can submit
## the same intents without depending on keyboard, animation or damage code.

signal state_changed(previous: int, current: int)

enum State { GROUNDED, AIRBORNE, CROUCHING, SLIDING, WALL_RUNNING, MANTLING,
	DODGING, AIR_DASH_STARTUP, AIR_DASH_LAUNCH, BLOCKING, ATTACKING }
enum Action { JUMP, CROUCH, DODGE, MANTLE, WALL_RUN, AIR_DASH, BLOCK, ATTACK }

const NAMES := ["Grounded", "Airborne", "Crouching", "Sliding", "WallRunning",
	"Mantling", "Dodging", "AirDashStartup", "AirDashLaunch", "Blocking", "Attacking"]
const ALLOWED := {
	Action.JUMP: [State.GROUNDED, State.AIRBORNE, State.CROUCHING, State.SLIDING, State.WALL_RUNNING, State.BLOCKING],
	Action.CROUCH: [State.GROUNDED, State.CROUCHING],
	Action.DODGE: [State.GROUNDED, State.CROUCHING, State.SLIDING, State.BLOCKING],
	Action.MANTLE: [State.AIRBORNE, State.WALL_RUNNING],
	Action.WALL_RUN: [State.AIRBORNE],
	Action.AIR_DASH: [State.AIRBORNE],
	Action.BLOCK: [State.GROUNDED, State.CROUCHING],
	Action.ATTACK: [State.GROUNDED, State.CROUCHING, State.ATTACKING],
}

var current: State = State.AIRBORNE
var elapsed := 0.0


func allows(action: Action, grounded: bool, tuning: ActionControllerTuning) -> bool:
	if action == Action.AIR_DASH and current == State.WALL_RUNNING:
		return tuning.allow_dash_from_wall_run and not grounded
	if current not in ALLOWED[action]:
		return false
	if action in [Action.DODGE, Action.CROUCH, Action.BLOCK, Action.ATTACK] and not grounded:
		return false
	if action in [Action.AIR_DASH, Action.WALL_RUN, Action.MANTLE] and grounded:
		return false
	if current == State.BLOCKING:
		if action == Action.JUMP:
			return tuning.jump_cancels_block
		if action == Action.DODGE:
			return tuning.dodge_cancels_block
	return true


func set_state(next: State) -> void:
	if current == next:
		return
	var previous := current
	current = next
	elapsed = 0.0
	state_changed.emit(previous, current)


func state_name() -> String:
	return NAMES[current]
