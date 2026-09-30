class_name BuildingValidator
extends RefCounted
## Checks a building (and groups of buildings) for the mistakes that plagued the
## hand-placed city: pieces overlapping, pieces floating, gaps between floors,
## bad sizes, pieces poking out of the footprint.
##
## Because plans are whole-number grid units, every check is exact integer
## arithmetic: there is no "tolerance" to tune, and "touching" (one piece's top
## == the next piece's bottom) is unambiguously different from "overlapping" or
## "a gap". Each problem is returned as an Issue with a short CODE, so tests and
## the batch report can group failures by reason.
##
## Codes:  INPUT  SIZE  OUTSIDE  OVERLAP  FLOATING  OVERHANG  GAP  STACK
##         FOOTPRINT_OVERLAP  OUTSIDE_LOT  BUILT_MISMATCH  NO_COLLISION

class Issue:
	var code: String
	var text: String

	func _init(p_code: String, p_text: String) -> void:
		code = p_code
		text = p_text


const EPS := 0.001    # only used when comparing built nodes (metres as floats)


# ------------------------------------------------------------------ inputs

## The raw numbers someone asks for. Used by the generator before it builds anything.
static func check_inputs(width_m: float, depth_m: float, floors: int, floor_height_m: float) -> Array[Issue]:
	var out: Array[Issue] = []
	if width_m <= 0.0:
		out.append(Issue.new("INPUT", "width is %.2f m; it must be greater than zero" % width_m))
	if depth_m <= 0.0:
		out.append(Issue.new("INPUT", "depth is %.2f m; it must be greater than zero" % depth_m))
	if floors < 1:
		out.append(Issue.new("INPUT", "floor count is %d; a building needs at least 1 floor" % floors))
	if floor_height_m <= 0.0:
		out.append(Issue.new("INPUT", "floor height is %.2f m; it must be greater than zero" % floor_height_m))
	elif BuildingGrid.to_units(floor_height_m) < 1:
		out.append(Issue.new("INPUT", "floor height %.2f m is smaller than one grid unit (%.1f m)" % [floor_height_m, BuildingGrid.UNIT]))
	if out.is_empty():
		var min_m := BuildingGrid.to_metres(BuildingGenerator.MIN_FOOTPRINT_UNITS)
		if width_m < min_m or depth_m < min_m:
			out.append(Issue.new("INPUT", "footprint %.1f x %.1f m is too small; both sides must be at least %.1f m to fit walls" % [width_m, depth_m, min_m]))
	return out


# ------------------------------------------------------------------ one building

static func validate(plan: BuildingPlan) -> Array[Issue]:
	var out: Array[Issue] = []
	for e in plan.errors:
		out.append(Issue.new("INPUT", e))
	if plan.pieces.is_empty():
		if out.is_empty():
			out.append(Issue.new("STACK", "the plan has no pieces at all"))
		return out
	_check_sizes(plan, out)
	_check_inside_footprint(plan, out)
	_check_overlaps(plan, out)
	_check_support(plan, out)
	_check_stack(plan, out)
	return out


## A piece with a zero or negative side is meaningless (and breaks every later check).
static func _check_sizes(plan: BuildingPlan, out: Array[Issue]) -> void:
	for p in plan.pieces:
		if p.size.x <= 0 or p.size.y <= 0 or p.size.z <= 0:
			out.append(Issue.new("SIZE", "%s has a zero or negative size (%d x %d x %d grid units)" % [p.describe(), p.size.x, p.size.y, p.size.z]))


## Nothing may stick out past the footprint, or the building leaves its lot.
static func _check_inside_footprint(plan: BuildingPlan, out: Array[Issue]) -> void:
	for p in plan.pieces:
		if p.at.x < 0 or p.at.z < 0 or p.at.x + p.size.x > plan.width_u or p.at.z + p.size.z > plan.depth_u:
			out.append(Issue.new("OUTSIDE", "%s sticks out of the %s x %s footprint" % [p.describe(), _m(plan.width_u), _m(plan.depth_u)]))
		if p.at.y < 0:
			out.append(Issue.new("OUTSIDE", "%s is below the ground (y = %s)" % [p.describe(), _m(p.at.y)]))


## Two pieces may touch (share a face) but never share volume.
static func _check_overlaps(plan: BuildingPlan, out: Array[Issue]) -> void:
	var n := plan.pieces.size()
	for i in n:
		for j in range(i + 1, n):
			var a := plan.pieces[i]
			var b := plan.pieces[j]
			var ov := Vector3i(
				mini(a.at.x + a.size.x, b.at.x + b.size.x) - maxi(a.at.x, b.at.x),
				mini(a.at.y + a.size.y, b.at.y + b.size.y) - maxi(a.at.y, b.at.y),
				mini(a.at.z + a.size.z, b.at.z + b.size.z) - maxi(a.at.z, b.at.z))
			if ov.x > 0 and ov.y > 0 and ov.z > 0:
				out.append(Issue.new("OVERLAP", "%s overlaps %s by %s x %s x %s" % [a.describe(), b.describe(), _m(ov.x), _m(ov.y), _m(ov.z)]))


## Every piece must rest on the ground or fully on the top of the piece(s) below it.
static func _check_support(plan: BuildingPlan, out: Array[Issue]) -> void:
	for p in plan.pieces:
		if p.at.y <= 0:
			continue   # on the ground (or below it, which _check_inside_footprint reports)
		var holders: Array[BuildingPlan.Piece] = []
		var nearest_below := 0          # highest top under it, to say how far it floats
		var nearest_name := "the ground"
		for q in plan.pieces:
			if q == p or not _footprints_overlap(p, q) or q.top() > p.at.y:
				continue
			if q.top() > nearest_below:
				nearest_below = q.top()
				nearest_name = q.label()
			if q.top() == p.at.y:
				holders.append(q)
		if holders.is_empty():
			var gap := p.at.y - nearest_below
			out.append(Issue.new("FLOATING", "%s floats %s above %s" % [p.describe(), _m(gap), nearest_name]))
			continue
		var uncovered := _uncovered_cells(p, holders)
		if uncovered > 0:
			out.append(Issue.new("OVERHANG", "%s is only partly supported: %.1f m2 of its underside hangs in the air" % [p.describe(), uncovered * BuildingGrid.UNIT * BuildingGrid.UNIT]))


## The stack must read base, floor 0..n-1, roof with every join exactly flush.
static func _check_stack(plan: BuildingPlan, out: Array[Issue]) -> void:
	var bases: Array[BuildingPlan.Piece] = []
	var roofs: Array[BuildingPlan.Piece] = []
	var floors: Array[BuildingPlan.Piece] = []
	for p in plan.pieces:
		match p.kind:
			"base": bases.append(p)
			"roof": roofs.append(p)
			"floor": floors.append(p)
	if bases.size() != 1:
		out.append(Issue.new("STACK", "expected exactly 1 base, found %d" % bases.size()))
	if roofs.size() != 1:
		out.append(Issue.new("STACK", "expected exactly 1 roof, found %d" % roofs.size()))
	if floors.size() != plan.floors:
		out.append(Issue.new("STACK", "asked for %d floors but the plan has %d" % [plan.floors, floors.size()]))
	floors.sort_custom(func(a: BuildingPlan.Piece, b: BuildingPlan.Piece) -> bool: return a.floor_index < b.floor_index)
	var below_top := bases[0].top() if bases.size() == 1 else 0
	var below_name := "the base"
	for f in floors:
		if f.at.y > below_top:
			out.append(Issue.new("GAP", "gap of %s between %s and floor %d" % [_m(f.at.y - below_top), below_name, f.floor_index]))
		if f.size.y != plan.floor_units:
			out.append(Issue.new("STACK", "floor %d is %s tall but every floor should be %s" % [f.floor_index, _m(f.size.y), _m(plan.floor_units)]))
		below_top = f.top()
		below_name = "floor %d" % f.floor_index
	if roofs.size() == 1 and roofs[0].at.y > below_top:
		out.append(Issue.new("GAP", "gap of %s between %s and the roof" % [_m(roofs[0].at.y - below_top), below_name]))


# ------------------------------------------------------------------ many buildings

## `entries`: [{name: String, plan: BuildingPlan, at: Vector3 (metres, footprint NW corner),
##              lot: Rect2 (optional, metres)}]. Buildings may touch but not overlap, and a
## building with a `lot` must fit inside it.
static func check_footprints(entries: Array) -> Array[Issue]:
	var out: Array[Issue] = []
	var rects: Array[Rect2i] = []
	for e: Dictionary in entries:
		var plan: BuildingPlan = e.plan
		var at: Vector3 = e.at
		var r := Rect2i(BuildingGrid.to_units(at.x), BuildingGrid.to_units(at.z), plan.width_u, plan.depth_u)
		rects.append(r)
		if e.has("lot"):
			var lot: Rect2 = e.lot
			var lr := Rect2i(BuildingGrid.to_units(lot.position.x), BuildingGrid.to_units(lot.position.y), BuildingGrid.to_units(lot.size.x), BuildingGrid.to_units(lot.size.y))
			if not lr.encloses(r):
				out.append(Issue.new("OUTSIDE_LOT", "%s (footprint %s) does not fit inside its lot %s" % [e.name, _rect_m(r), _rect_m(lr)]))
	for i in entries.size():
		for j in range(i + 1, entries.size()):
			var ov := rects[i].intersection(rects[j])
			if ov.size.x > 0 and ov.size.y > 0:
				out.append(Issue.new("FOOTPRINT_OVERLAP", "%s and %s overlap by %s x %s at %s" % [entries[i].name, entries[j].name, _m(ov.size.x), _m(ov.size.y), _rect_m(ov)]))
	return out


# ------------------------------------------------------------------ built nodes

## Does the node tree the builder made really match the plan? Every piece must have
## a mesh of exactly its size and place, and be covered by some collision shape.
static func check_built(root: Node3D, plan: BuildingPlan) -> Array[Issue]:
	var out: Array[Issue] = []
	var meshes: Array[Node] = root.find_children("*", "MeshInstance3D", true, false)
	if meshes.size() != plan.pieces.size():
		out.append(Issue.new("BUILT_MISMATCH", "plan has %d pieces but %d meshes were built" % [plan.pieces.size(), meshes.size()]))
		return out
	var shapes: Array[AABB] = []
	for n in root.find_children("*", "CollisionShape3D", true, false):
		var cs := n as CollisionShape3D
		if cs.shape is BoxShape3D:
			var sz := (cs.shape as BoxShape3D).size
			shapes.append(AABB(cs.position - sz * 0.5, sz))
	for i in plan.pieces.size():
		var p := plan.pieces[i]
		var mi := meshes[i] as MeshInstance3D
		var want := AABB(Vector3(p.at) * BuildingGrid.UNIT, BuildingGrid.to_vec(p.size))
		var got := AABB(mi.position - (mi.mesh as BoxMesh).size * 0.5, (mi.mesh as BoxMesh).size)
		if not want.position.is_equal_approx(got.position) or not want.size.is_equal_approx(got.size):
			out.append(Issue.new("BUILT_MISMATCH", "%s was built at %s size %s instead" % [p.describe(), got.position, got.size]))
		var covered := false
		for s in shapes:
			if s.grow(EPS).encloses(want):
				covered = true
				break
		if not covered:
			out.append(Issue.new("NO_COLLISION", "%s has no collision shape around it" % p.describe()))
	return out


# ------------------------------------------------------------------ printing

## Readable multi-line report; empty string if there is nothing to say.
static func format(title: String, issues: Array[Issue]) -> String:
	if issues.is_empty():
		return ""
	var lines := PackedStringArray()
	lines.append("%s: %d problem%s" % [title, issues.size(), "" if issues.size() == 1 else "s"])
	for i in issues:
		lines.append("  [%s] %s" % [i.code, i.text])
	return "\n".join(lines)


static func codes(issues: Array[Issue]) -> PackedStringArray:
	var seen := PackedStringArray()
	for i in issues:
		if not seen.has(i.code):
			seen.append(i.code)
	return seen


# ------------------------------------------------------------------ helpers

static func _m(units: int) -> String:
	return "%.1f m" % BuildingGrid.to_metres(units)


static func _rect_m(r: Rect2i) -> String:
	return "(x %.1f..%.1f, z %.1f..%.1f)" % [BuildingGrid.to_metres(r.position.x), BuildingGrid.to_metres(r.end.x), BuildingGrid.to_metres(r.position.y), BuildingGrid.to_metres(r.end.y)]


static func _footprints_overlap(a: BuildingPlan.Piece, b: BuildingPlan.Piece) -> bool:
	return mini(a.at.x + a.size.x, b.at.x + b.size.x) > maxi(a.at.x, b.at.x) and mini(a.at.z + a.size.z, b.at.z + b.size.z) > maxi(a.at.z, b.at.z)


## How many grid cells of p's underside are NOT covered by any holder's top face?
static func _uncovered_cells(p: BuildingPlan.Piece, holders: Array[BuildingPlan.Piece]) -> int:
	var missing := 0
	for x in range(p.at.x, p.at.x + p.size.x):
		for z in range(p.at.z, p.at.z + p.size.z):
			var hit := false
			for h in holders:
				if x >= h.at.x and x < h.at.x + h.size.x and z >= h.at.z and z < h.at.z + h.size.z:
					hit = true
					break
			if not hit:
				missing += 1
	return missing
