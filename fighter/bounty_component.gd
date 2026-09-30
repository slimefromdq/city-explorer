class_name BountyComponent
extends Node
## Streak + score. The more you win, the more you're worth: dying pays half your
## score to whoever landed the kill and wipes the streak. `threat()` (0..1) is
## what visuals read to scale afterimages, auras and ring glow.

signal changed

const BASE_VALUE := 100
const PER_STREAK := 75

var fighter: Fighter
var streak := 0
var kills := 0
var deaths := 0
var score := 0


func value() -> int:
	return BASE_VALUE + streak * PER_STREAK + int(score * 0.25)


func threat() -> float:
	return clampf(float(streak) / 8.0, 0.0, 1.0)


func on_kill(worth: int) -> void:
	streak += 1
	kills += 1
	score += worth
	changed.emit()


func on_death() -> int:
	var lost := int(score * 0.5)
	score -= lost
	streak = 0
	deaths += 1
	changed.emit()
	return lost


func add_streak(n: int) -> void:
	streak += n
	changed.emit()


func reset() -> void:
	streak = 0
	changed.emit()
