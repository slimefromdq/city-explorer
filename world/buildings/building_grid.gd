class_name BuildingGrid
extends RefCounted
## The one unit every generated building is measured in: 0.5 m.
##
## Why 0.5 m?  (1) Half a metre is an exact binary fraction, so 3 x 0.5 or
## 400 x 0.5 has no rounding error: a floor's top and the next floor's bottom
## are the *same number*, not two numbers that almost match. (Try 0.1 or 0.3
## and they drift.) (2) It is fine enough for a 0.5 m wall inset, a 1 m
## plinth or a 3.5 m storey, yet coarse enough that every size is a small
## whole number. (3) The existing city lots (29 x 29 m) are whole multiples.
##
## Rule: geometry is decided in whole units (ints) and only converted to
## metres at the very last step, when a mesh is created.

const UNIT := 0.5


static func to_units(metres: float) -> int:
	return roundi(metres / UNIT)


static func to_metres(units: int) -> float:
	return units * UNIT


static func to_vec(units: Vector3i) -> Vector3:
	return Vector3(units) * UNIT


## Kit.box() wants the centre of the bottom face, in metres.
static func bottom_centre(at: Vector3i, size: Vector3i) -> Vector3:
	return Vector3(at.x + size.x * 0.5, at.y, at.z + size.z * 0.5) * UNIT
