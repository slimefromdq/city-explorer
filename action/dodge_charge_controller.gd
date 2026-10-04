class_name ActionDodgeChargeController
extends RefCounted
## Each spent slot owns its own timer; spending again never delays another slot.
signal charges_changed(available: int)
var cooldown := 3.0
var remaining := PackedFloat32Array([0.0, 0.0, 0.0])


func available() -> int:
	var count := 0
	for timer in remaining:
		if timer <= 0.0:
			count += 1
	return count


func spend() -> bool:
	for i in remaining.size():
		if remaining[i] <= 0.0:
			remaining[i] = cooldown
			charges_changed.emit(available())
			return true
	return false


func tick(dt: float) -> void:
	var before := available()
	for i in remaining.size():
		remaining[i] = maxf(0.0, remaining[i] - dt)
	if available() != before:
		charges_changed.emit(available())


func reset() -> void:
	remaining.fill(0.0)
	charges_changed.emit(available())
