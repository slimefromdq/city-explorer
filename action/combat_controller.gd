class_name ActionCombatController
extends RefCounted
## Timed attack state only. Hit sweeps, damage, animation and shield resolution
## subscribe to these hooks; no animation frames or damage rules live here.
signal on_block_started
signal on_block_ended
signal attack_started(hit: int)
signal attack_phase_changed(hit: int, phase: StringName)
signal attack_active_started(hit: int)
signal attack_active_ended(hit: int)
signal attack_ended(hit: int)

var tuning: ActionControllerTuning
var is_blocking := false
var hit := -1
var elapsed := 0.0
var phase: StringName = &""
var queued := false


func set_block(active: bool) -> void:
	if active == is_blocking:
		return
	is_blocking = active
	if active:
		on_block_started.emit()
	else:
		on_block_ended.emit()


func press_attack() -> bool:
	if hit < 0:
		_start(0)
		return true
	if hit < 2 and elapsed >= tuning.combo_window_start[hit] and elapsed <= tuning.combo_window_end[hit]:
		queued = true
		return true
	return false


func _start(index: int) -> void:
	hit = index
	elapsed = 0.0
	queued = false
	phase = &"startup"
	attack_started.emit(hit + 1)
	attack_phase_changed.emit(hit + 1, phase)


func tick(dt: float) -> void:
	if hit < 0:
		return
	elapsed += dt
	var active_at := tuning.attack_startup[hit]
	var recovery_at := active_at + tuning.attack_active[hit]
	if phase == &"startup" and elapsed >= active_at:
		phase = &"active"
		attack_phase_changed.emit(hit + 1, phase)
		attack_active_started.emit(hit + 1)
	if phase == &"active" and elapsed >= recovery_at:
		attack_active_ended.emit(hit + 1)
		phase = &"recovery"
		attack_phase_changed.emit(hit + 1, phase)
	if elapsed >= recovery_at + tuning.attack_recovery[hit]:
		var next := hit + 1 if queued and hit < 2 else -1
		attack_ended.emit(hit + 1)
		hit = -1
		phase = &""
		if next >= 0:
			_start(next)


func cancel() -> void:
	set_block(false)
	if hit >= 0:
		if phase == &"active":
			attack_active_ended.emit(hit + 1)
		attack_ended.emit(hit + 1)
	hit = -1
	queued = false
	phase = &""
