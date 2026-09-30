class_name BuildingRoofs
extends RefCounted
## Feature: roof variants. Every building has the flat 0.5 m "roof" slab; a
## variant adds boxes on top of it. All built from boxes, all laid out from the
## roof's own size (no hand-placed numbers):
##
##   FLAT     nothing extra (a plant-room box may sit on it)
##   PARAPET  a 1 m-high, 0.5 m-thick wall round the rim. Long sides run the full
##            length and the short sides fit BETWEEN them, so corners never overlap.
##   STEPPED  two layers, each 1 m tall and pulled in 1 m per side (a ziggurat)
##   GABLE    layers that shrink on the short axis only, like the steps of a
##            pitched roof with the ridge along the long axis (1 m tall each,
##            1 m in per side, up to 3 layers)
##
## Each piece rests exactly on the top face of the one below and lies inside it,
## which is precisely what the validator's support check verifies.

enum Variant { FLAT, PARAPET, STEPPED, GABLE }

const LAYER_UNITS := 2     # 1 m per layer / parapet height
const STEP_UNITS := 2      # 1 m in per side per layer
const PARAPET_THICK := 1   # 0.5 m


static func variant_name(v: Variant) -> String:
	return Variant.keys()[v].to_lower()


## Does this variant leave the roof surface free for a plant-room box?
static func allows_rooftop(v: Variant) -> bool:
	return v == Variant.FLAT or v == Variant.PARAPET


## `inset` = where the roof slab starts on x and z; `top_w/top_d` its size;
## `top_y` the height of the slab's top face.
static func add(plan: BuildingPlan, variant: Variant, inset: int, top_w: int, top_d: int, top_y: int) -> void:
	match variant:
		Variant.PARAPET:
			var t := PARAPET_THICK
			_piece(plan, "parapet", Vector3i(inset, top_y, inset), Vector3i(top_w, LAYER_UNITS, t))
			_piece(plan, "parapet", Vector3i(inset, top_y, inset + top_d - t), Vector3i(top_w, LAYER_UNITS, t))
			_piece(plan, "parapet", Vector3i(inset, top_y, inset + t), Vector3i(t, LAYER_UNITS, top_d - 2 * t))
			_piece(plan, "parapet", Vector3i(inset + top_w - t, top_y, inset + t), Vector3i(t, LAYER_UNITS, top_d - 2 * t))
		Variant.STEPPED:
			for k in range(1, 3):
				var g := k * STEP_UNITS
				_piece(plan, "roof_step", Vector3i(inset + g, top_y + (k - 1) * LAYER_UNITS, inset + g), Vector3i(top_w - 2 * g, LAYER_UNITS, top_d - 2 * g))
		Variant.GABLE:
			var ridge_along_z := top_w <= top_d
			var short_side := top_w if ridge_along_z else top_d
			var layers := clampi((short_side - 4) >> 2, 1, 3)
			for k in range(1, layers + 1):
				var g := k * STEP_UNITS
				var y := top_y + (k - 1) * LAYER_UNITS
				if ridge_along_z:
					_piece(plan, "roof_step", Vector3i(inset + g, y, inset), Vector3i(top_w - 2 * g, LAYER_UNITS, top_d))
				else:
					_piece(plan, "roof_step", Vector3i(inset, y, inset + g), Vector3i(top_w, LAYER_UNITS, top_d - 2 * g))


static func _piece(plan: BuildingPlan, kind: String, at: Vector3i, size: Vector3i) -> void:
	plan.pieces.append(BuildingPlan.Piece.new(kind, at, size))
