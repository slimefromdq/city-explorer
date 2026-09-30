class_name BuildingPlan
extends RefCounted
## A building described purely as numbers: no nodes, no meshes. The generator
## fills this in, the builder turns it into nodes, and (Phase 2) the validator
## checks it. Keeping "what the building is" apart from "how it is drawn"
## means we can test a building without ever rendering it.
##
## All positions/sizes are whole grid units (see BuildingGrid).
## Origin = the footprint's north-west corner on the ground; +x east, +z south, +y up.


class Piece:
	var kind: String           # "base" | "floor" | "roof" | "rooftop"
	var tier := -1             # which section of the tower (0 = lowest); -1 if not a floor
	var floor_index := -1      # 0 = first floor above the base
	var at := Vector3i.ZERO    # minimum corner
	var size := Vector3i.ZERO

	func _init(p_kind: String, p_at: Vector3i, p_size: Vector3i, p_tier := -1, p_floor := -1) -> void:
		kind = p_kind
		at = p_at
		size = p_size
		tier = p_tier
		floor_index = p_floor

	func top() -> int:
		return at.y + size.y

	## Short name, e.g. "floor 7", "roof".
	func label() -> String:
		return kind if floor_index < 0 else "%s %d" % [kind, floor_index]

	## Name plus where it is, in metres (the units a human thinks in).
	func describe() -> String:
		var s := BuildingGrid.to_vec(size)
		var a := BuildingGrid.to_vec(at)
		return "%s (x %.1f, y %.1f, z %.1f; size %.1f x %.1f x %.1f m)" % [label(), a.x, a.y, a.z, s.x, s.y, s.z]


var seed_value := 0
var width_u := 0
var depth_u := 0
var floors := 0
var floor_units := 0
var palette_index := 0
var pieces: Array[Piece] = []
var errors: PackedStringArray = []


func ok() -> bool:
	return errors.is_empty() and not pieces.is_empty()


func height_units() -> int:
	var h := 0
	for p in pieces:
		h = maxi(h, p.top())
	return h


## Plain-text fingerprint of every decision. Two plans are the same building
## exactly when their signatures are equal (used by the tests).
func signature() -> String:
	var lines := PackedStringArray()
	lines.append("%d|%d|%d|%d|%d|%d" % [seed_value, width_u, depth_u, floors, floor_units, palette_index])
	for p in pieces:
		lines.append("%s,%d,%d,%d,%d,%d,%d,%d" % [p.kind, p.tier, p.at.x, p.at.y, p.at.z, p.size.x, p.size.y, p.size.z])
	return "\n".join(lines)
