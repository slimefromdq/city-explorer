class_name BuildingWindows
extends RefCounted
## Feature: windows. Every floor gets a row of window boxes on each of its four
## walls, laid out on the grid (never hand-placed):
##
##   - bays repeat every `pitch` units along the wall, centred on the wall, and
##     stay 2 units (1 m) clear of the corners;
##   - each window is 4 units (2 m) wide, sits `sill` units above the floor and is
##     centred vertically, so it can never cross into the floor above or below;
##   - it is 1 unit (0.5 m) deep and touches the wall: walls sit 1 unit inside
##     the footprint, so a window ends exactly at the footprint edge (this is
##     why walls are inset: windows never push a building out of its lot).
##
## The seed decides which bays have a window (`fill`) and which are lit.

const DEPTH := 1
const WIDTH := 4
const CORNER_MARGIN := 2
const FACES := ["n", "e", "s", "w"]


## `r` must be the WINDOWS random stream. Exactly two numbers are drawn per bay,
## in a fixed order, so the result never depends on earlier decisions.
## `keep_clear` is an optional piece (the door): a window that would touch it is skipped,
## but its two random numbers are still drawn so the rest of the facade does not change.
static func add(plan: BuildingPlan, pitch: int, fill: float, lit: float, r: RandomNumberGenerator, keep_clear: BuildingPlan.Piece = null) -> void:
	var fh := plan.floor_units
	if fh < 4:
		return   # floors too short for a window to fit with a sill above and a lintel below
	var win_h := clampi(fh - 3, 2, 5)
	var sill := (fh - win_h) >> 1
	var floors: Array[BuildingPlan.Piece] = []
	for p in plan.pieces:
		if p.kind == "floor":
			floors.append(p)
	for f in floors:
		for face: String in FACES:
			var along_x := face == "n" or face == "s"
			var length := f.size.x if along_x else f.size.z
			var bays := floori(float(length - 2 * CORNER_MARGIN) / float(pitch))
			var start := (length - bays * pitch) >> 1
			for k in bays:
				var present := r.randf() < fill
				var is_lit := r.randf() < lit
				if not present:
					continue
				var along := start + k * pitch + ((pitch - WIDTH) >> 1)
				var y := f.at.y + sill
				var at := Vector3i.ZERO
				var size := Vector3i(WIDTH, win_h, DEPTH)
				match face:
					"n": at = Vector3i(f.at.x + along, y, f.at.z - DEPTH)
					"s": at = Vector3i(f.at.x + along, y, f.at.z + f.size.z)
					"w":
						at = Vector3i(f.at.x - DEPTH, y, f.at.z + along)
						size = Vector3i(DEPTH, win_h, WIDTH)
					"e":
						at = Vector3i(f.at.x + f.size.x, y, f.at.z + along)
						size = Vector3i(DEPTH, win_h, WIDTH)
				if keep_clear != null and f.floor_index == keep_clear.floor_index and face == keep_clear.face \
						and mini(at.x + size.x, keep_clear.at.x + keep_clear.size.x) > maxi(at.x, keep_clear.at.x) \
						and mini(at.z + size.z, keep_clear.at.z + keep_clear.size.z) > maxi(at.z, keep_clear.at.z):
					continue
				var w := BuildingPlan.Piece.new("window", at, size, f.tier, f.floor_index)
				w.face = face
				w.variant = 1 if is_lit else 0
				plan.pieces.append(w)
