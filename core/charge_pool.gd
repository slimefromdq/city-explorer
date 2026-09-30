class_name ChargePool
extends RefCounted
## A small pool of regenerating charges (dodges, air-dashes). `charges` is a
## float: the integer part is usable stock, the fraction is regen progress.

var max_charges: int
var charges: float
var regen_time: float
var regen_delay: float
var _delay_left := 0.0


func _init(p_max: int, p_regen_time: float, p_regen_delay: float = 0.5) -> void:
	max_charges = p_max
	charges = float(p_max)
	regen_time = p_regen_time
	regen_delay = p_regen_delay


func available() -> int:
	return int(floor(charges + 0.0001))


func has_charge() -> bool:
	return charges >= 0.9999


func spend() -> bool:
	if not has_charge():
		return false
	charges -= 1.0
	_delay_left = regen_delay
	return true


func refund(n: float = 1.0) -> void:
	charges = minf(float(max_charges), charges + n)


func fill() -> void:
	charges = float(max_charges)
	_delay_left = 0.0


func tick(dt: float, rate: float = 1.0) -> void:
	if charges >= float(max_charges):
		return
	if _delay_left > 0.0:
		_delay_left -= dt
		return
	charges = minf(float(max_charges), charges + dt * rate / regen_time)
