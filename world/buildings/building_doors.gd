class_name BuildingDoors
extends RefCounted
## Feature: a front door. One door box on ground-floor wall, on a face chosen by
## the seed, centred on that wall (so its position is a function of the wall's
## size, never hand-placed).
##
## The door is 1 unit deep and stands on top of the base plinth: the plinth
## covers the whole footprint, so the strip between the wall and the footprint
## edge is solid ground for it to stand on, and it ends flush with the footprint.
## That gives the validator two things to check: the door is attached to the
## wall (like a window) AND it rests on something (like a structural piece).

const DEPTH := 1
const FACES := ["n", "e", "s", "w"]


## `r` must be the DOORS random stream. Draws exactly one number (the face).
## Returns the door piece (also appended to the plan), or null if the wall is too small.
static func add(plan: BuildingPlan, door_width: int, door_height: int, r: RandomNumberGenerator) -> BuildingPlan.Piece:
	var face: String = FACES[r.randi_range(0, 3)]
	var host: BuildingPlan.Piece = null
	for p in plan.pieces:
		if p.kind == "floor" and p.floor_index == 0:
			host = p
	var base: BuildingPlan.Piece = null
	for p in plan.pieces:
		if p.kind == "base":
			base = p
	if host == null or base == null:
		return null
	var along_x := face == "n" or face == "s"
	var length := host.size.x if along_x else host.size.z
	var dw := mini(door_width, length - 4)    # keep 2 units (1 m) of wall either side at least
	var dh := mini(door_height, host.size.y)  # never taller than the ground floor
	if dw < 2 or dh < 2:
		return null
	var along := (length - dw) >> 1
	var at := Vector3i.ZERO
	var size := Vector3i(dw, dh, DEPTH)
	match face:
		"n": at = Vector3i(host.at.x + along, base.top(), host.at.z - DEPTH)
		"s": at = Vector3i(host.at.x + along, base.top(), host.at.z + host.size.z)
		"w":
			at = Vector3i(host.at.x - DEPTH, base.top(), host.at.z + along)
			size = Vector3i(DEPTH, dh, dw)
		"e":
			at = Vector3i(host.at.x + host.size.x, base.top(), host.at.z + along)
			size = Vector3i(DEPTH, dh, dw)
	var door := BuildingPlan.Piece.new("door", at, size, host.tier, 0)
	door.face = face
	plan.pieces.append(door)
	return door
