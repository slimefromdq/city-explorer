extends Node
## Phase 2: proves the validator works, then runs it on a batch of random buildings.
##   godot --headless res://tests/building_validation_test.tscn
##   BATCH=2000 godot --headless res://tests/building_validation_test.tscn   (bigger batch)
## Exit code 1 if a validator self-test fails or a generated building has a geometry problem.
## Buildings rejected for bad INPUT (e.g. a 5 m footprint) are listed but are correct behaviour.

var fails := 0


func check(name: String, cond: bool, detail := "") -> void:
	if cond:
		print("  ok   ", name)
	else:
		fails += 1
		print("  FAIL ", name, "  ", detail)


func has_code(issues: Array[BuildingValidator.Issue], code: String) -> bool:
	return BuildingValidator.codes(issues).has(code)


## A valid, multi-section tower: floors 0..n-1 found by index so tests can break one.
func good_plan() -> BuildingPlan:
	for s in 200:   # find a seed that has setbacks and a rooftop box so every piece kind exists
		var p := BuildingGenerator.plan(29, 29, 24, 3.5, s)
		var kinds := {}
		var tiers := {}
		for pc in p.pieces:
			kinds[pc.kind] = true
			tiers[pc.tier] = true
		if kinds.has("rooftop") and tiers.size() >= 3:
			return p
	return BuildingGenerator.plan(29, 29, 24, 3.5, 1)


## A fresh plan whose roof is the given variant (and, optionally, that has a plant room).
func _plan_with_roof(variant: String, with_rooftop := false) -> BuildingPlan:
	for sd in 400:
		var p := BuildingGenerator.plan(29, 29, 10, 3.5, sd)
		if p.roof_variant == variant and (not with_rooftop or not _pieces_of(p, "rooftop").is_empty()):
			return p
	return BuildingGenerator.plan(29, 29, 10, 3.5, 1)


func _pieces_of(p: BuildingPlan, kind: String) -> Array[BuildingPlan.Piece]:
	var out: Array[BuildingPlan.Piece] = []
	for pc in p.pieces:
		if pc.kind == kind:
			out.append(pc)
	return out


## One unit straight out of a wall: the direction a wall decoration sticks out.
func _outward(face: String) -> Vector3i:
	match face:
		"n": return Vector3i(0, 0, -1)
		"s": return Vector3i(0, 0, 1)
		"w": return Vector3i(-1, 0, 0)
	return Vector3i(1, 0, 0)


func piece(p: BuildingPlan, kind: String, floor_index := -1) -> BuildingPlan.Piece:
	for pc in p.pieces:
		if pc.kind == kind and pc.floor_index == floor_index:
			return pc
	return null


func _ready() -> void:
	print("validator self-tests (each breaks a good building on purpose):")
	var good := good_plan()
	var issues := BuildingValidator.validate(good)
	check("a good building has zero problems", issues.is_empty(), BuildingValidator.format("good", issues))

	var p := good_plan()
	piece(p, "floor", 5).at.y -= 1
	check("floor sunk into the one below -> OVERLAP", has_code(BuildingValidator.validate(p), "OVERLAP"))

	p = good_plan()
	piece(p, "floor", 6).at.y += 2
	var r := BuildingValidator.validate(p)
	check("floor lifted off the one below -> GAP and FLOATING", has_code(r, "GAP") and has_code(r, "FLOATING"), BuildingValidator.format("x", r))

	p = good_plan()
	piece(p, "roof").at.y += 4
	check("roof lifted off -> GAP and FLOATING", has_code(BuildingValidator.validate(p), "GAP") and has_code(BuildingValidator.validate(p), "FLOATING"))

	p = good_plan()
	piece(p, "rooftop").at.y += 2
	check("rooftop box hovering over the roof -> FLOATING", has_code(BuildingValidator.validate(p), "FLOATING"))

	p = good_plan()
	piece(p, "floor", 10).size.x = 0
	check("zero-width floor -> SIZE", has_code(BuildingValidator.validate(p), "SIZE"))

	p = good_plan()
	piece(p, "floor", 10).size.z = -2
	check("negative-depth floor -> SIZE", has_code(BuildingValidator.validate(p), "SIZE"))

	p = good_plan()
	piece(p, "floor", 2).at.x = -2
	check("floor poking out of the footprint -> OUTSIDE", has_code(BuildingValidator.validate(p), "OUTSIDE"))

	p = good_plan()
	piece(p, "floor", 23).size.x += 6
	piece(p, "floor", 23).at.x -= 0
	check("upper floor wider than the one under it -> OVERHANG", has_code(BuildingValidator.validate(p), "OVERHANG"))

	p = good_plan()
	piece(p, "floor", 4).size.y += 1
	check("one floor taller than the rest -> STACK", has_code(BuildingValidator.validate(p), "STACK"))

	p = good_plan()
	p.pieces.erase(piece(p, "floor", 7))
	check("a missing floor -> GAP and STACK", has_code(BuildingValidator.validate(p), "GAP") and has_code(BuildingValidator.validate(p), "STACK"))

	check("zero width input -> INPUT", has_code(BuildingValidator.validate(BuildingGenerator.plan(0, 20, 5, 3.5, 1)), "INPUT"))
	check("negative depth input -> INPUT", has_code(BuildingValidator.validate(BuildingGenerator.plan(20, -4, 5, 3.5, 1)), "INPUT"))
	check("zero floors input -> INPUT", has_code(BuildingValidator.validate(BuildingGenerator.plan(20, 20, 0, 3.5, 1)), "INPUT"))
	check("negative floor height input -> INPUT", has_code(BuildingValidator.validate(BuildingGenerator.plan(20, 20, 5, -3.0, 1)), "INPUT"))
	check("tiny footprint input -> INPUT", has_code(BuildingValidator.validate(BuildingGenerator.plan(4, 20, 5, 3.5, 1)), "INPUT"))

	# Windows (feature 1)
	var wins := _pieces_of(good, "window")
	check("a generated tower has windows (%d)" % wins.size(), wins.size() > 100)
	var wp := good_plan()
	var w0 := _pieces_of(wp, "window")[0]
	w0.at += _outward(w0.face)
	check("window pulled off its wall -> DETACHED (gap)", has_code(BuildingValidator.validate(wp), "DETACHED"))
	wp = good_plan()
	w0 = _pieces_of(wp, "window")[0]
	w0.at -= _outward(w0.face)
	var wr := BuildingValidator.validate(wp)
	check("window sunk into the wall -> OVERLAP and DETACHED", has_code(wr, "OVERLAP") and has_code(wr, "DETACHED"), BuildingValidator.format("x", wr))
	wp = good_plan()
	w0 = _pieces_of(wp, "window")[0]
	w0.at.y += 6
	check("window sliding past its floor's top -> DETACHED", has_code(BuildingValidator.validate(wp), "DETACHED"))
	wp = good_plan()
	var w1 := _pieces_of(wp, "window")[1]
	var dup := BuildingPlan.Piece.new("window", w1.at, w1.size, w1.tier, w1.floor_index)
	dup.face = w1.face
	wp.pieces.append(dup)
	check("two windows in the same spot -> OVERLAP", has_code(BuildingValidator.validate(wp), "OVERLAP"))
	wp = good_plan()
	w0 = _pieces_of(wp, "window")[0]
	w0.floor_index = 99
	check("window on a floor that does not exist -> DETACHED", has_code(BuildingValidator.validate(wp), "DETACHED"))
	wp = good_plan()
	w0 = _pieces_of(wp, "window")[0]
	w0.face = "x"
	check("window with no wall face -> DETACHED", has_code(BuildingValidator.validate(wp), "DETACHED"))
	var blocks := BuildingBuilder.collision_blocks(good)
	var any_decor := false
	for b in blocks:
		any_decor = any_decor or b.is_decoration()
	check("windows add no collision", not any_decor)

	# Doors (feature 2)
	var doors := _pieces_of(good, "door")
	check("a generated building has exactly one door", doors.size() == 1)
	var dp := good_plan()
	var d0 := _pieces_of(dp, "door")[0]
	d0.at.y += 2
	var dr := BuildingValidator.validate(dp)
	check("door lifted off the plinth -> FLOATING", has_code(dr, "FLOATING"), BuildingValidator.format("x", dr))
	dp = good_plan()
	d0 = _pieces_of(dp, "door")[0]
	d0.at += _outward(d0.face)
	check("door pulled off its wall -> DETACHED", has_code(BuildingValidator.validate(dp), "DETACHED"))
	dp = good_plan()
	d0 = _pieces_of(dp, "door")[0]
	var extra := BuildingPlan.Piece.new("window", d0.at, d0.size, d0.tier, 0)
	extra.face = d0.face
	dp.pieces.append(extra)
	check("a window placed over the door -> OVERLAP", has_code(BuildingValidator.validate(dp), "OVERLAP"))
	dp = good_plan()
	d0 = _pieces_of(dp, "door")[0]
	d0.size.y = 40
	check("door taller than the ground floor -> DETACHED", has_code(BuildingValidator.validate(dp), "DETACHED"))
	var door_faces := {}
	for sd in 40:
		for pc in BuildingGenerator.plan(29, 29, 6, 3.5, sd).pieces:
			if pc.kind == "door":
				door_faces[pc.face] = true
	check("the seed picks different faces for the door (%d of 4 seen in 40 seeds)" % door_faces.size(), door_faces.size() == 4)
	var clear := true
	for sd in 40:
		var pp := BuildingGenerator.plan(29, 29, 6, 3.5, sd)
		if not BuildingValidator.validate(pp).is_empty():
			clear = false
	check("windows keep clear of the door on 40 seeds", clear)

	# Roof variants (feature 3)
	var seen := {}
	for sd in 60:
		var rp := BuildingGenerator.plan(29, 29, 10, 3.5, sd)
		seen[rp.roof_variant] = true
		if not BuildingValidator.validate(rp).is_empty():
			check("roof variant %s (seed %d) is valid" % [rp.roof_variant, sd], false, BuildingValidator.format("x", BuildingValidator.validate(rp)))
	check("all four roof variants occur (%s)" % ", ".join(seen.keys()), seen.size() == 4)
	var parapet := _plan_with_roof("parapet")
	var kp := _pieces_of(parapet, "parapet")
	check("a parapet roof has 4 wall pieces", kp.size() == 4)
	kp[0].at.y += 2
	check("parapet lifted off the roof -> FLOATING", has_code(BuildingValidator.validate(parapet), "FLOATING"))
	var stepped := _plan_with_roof("stepped")
	var ks := _pieces_of(stepped, "roof_step")
	check("a stepped roof has 2 layers", ks.size() == 2)
	ks[1].size.x += 4
	check("stepped layer wider than the one below -> OVERHANG", has_code(BuildingValidator.validate(stepped), "OVERHANG"))
	var gable := _plan_with_roof("gable")
	var kg := _pieces_of(gable, "roof_step")
	check("a gable roof has 1-3 layers", kg.size() >= 1 and kg.size() <= 3)
	kg[0].at.y -= 1
	check("gable layer sunk into the roof -> OVERLAP", has_code(BuildingValidator.validate(gable), "OVERLAP"))
	var pr := _plan_with_roof("parapet", true)
	var box := _pieces_of(pr, "rooftop")
	if not box.is_empty():
		box[0].at.x = 1
		check("plant room pushed into the parapet -> OVERLAP", has_code(BuildingValidator.validate(pr), "OVERLAP"))
	var no_box := true
	for sd in 60:
		var rp2 := BuildingGenerator.plan(29, 29, 10, 3.5, sd)
		if rp2.roof_variant in ["stepped", "gable"] and not _pieces_of(rp2, "rooftop").is_empty():
			no_box = false
	check("stepped/gable roofs never carry a plant room", no_box)

	# Built nodes must match the plan.
	var built := BuildingBuilder.build(self, good)
	check("built nodes match the plan and have collision", BuildingValidator.check_built(built, good).is_empty(), BuildingValidator.format("built", BuildingValidator.check_built(built, good)))
	var shape: CollisionShape3D = built.find_children("*", "CollisionShape3D", true, false)[0]
	shape.get_parent().remove_child(shape)
	check("deleting a collision shape -> NO_COLLISION", has_code(BuildingValidator.check_built(built, good), "NO_COLLISION"))
	built.find_children("*", "MeshInstance3D", true, false)[3].position.y += 1.0
	check("a nudged mesh -> BUILT_MISMATCH", has_code(BuildingValidator.check_built(built, good), "BUILT_MISMATCH"))

	# Footprints of several buildings.
	var a := BuildingGenerator.plan(29, 29, 5, 3.5, 1)
	var b := BuildingGenerator.plan(29, 29, 5, 3.5, 2)
	var lot := Rect2(0, 0, 29, 29)
	check("buildings side by side (touching) -> no overlap", BuildingValidator.check_footprints([{"name": "A", "plan": a, "at": Vector3(0, 0, 0)}, {"name": "B", "plan": b, "at": Vector3(29, 0, 0)}]).is_empty())
	check("buildings sharing ground -> FOOTPRINT_OVERLAP", has_code(BuildingValidator.check_footprints([{"name": "A", "plan": a, "at": Vector3(0, 0, 0)}, {"name": "B", "plan": b, "at": Vector3(20, 0, 10)}]), "FOOTPRINT_OVERLAP"))
	check("building exactly filling its lot -> fine", BuildingValidator.check_footprints([{"name": "A", "plan": a, "at": Vector3(0, 0, 0), "lot": lot}]).is_empty())
	check("building shifted out of its lot -> OUTSIDE_LOT", has_code(BuildingValidator.check_footprints([{"name": "A", "plan": a, "at": Vector3(3, 0, 0), "lot": lot}]), "OUTSIDE_LOT"))

	_batch()
	print("\n%s" % ("VALIDATION TESTS PASSED" if fails == 0 else "VALIDATION TESTS FAILED: %d" % fails))
	get_tree().quit(1 if fails > 0 else 0)


## Random sizes across (and a little beyond) the useful range, so some inputs are rightly rejected.
func _batch() -> void:
	var n := int(OS.get_environment("BATCH")) if OS.get_environment("BATCH") != "" else 50
	var rng := RandomNumberGenerator.new()
	rng.seed = 2024   # the batch itself is reproducible
	var ok_count := 0
	var rejected: Array[String] = []
	var broken: Array[String] = []
	var by_code := {}
	for i in n:
		var w := snappedf(rng.randf_range(5.0, 60.0), 0.5)
		var d := snappedf(rng.randf_range(5.0, 60.0), 0.5)
		var fl := rng.randi_range(1, 45)
		var fh := snappedf(rng.randf_range(2.5, 5.0), 0.5)
		var s := rng.randi_range(0, 99999)
		var plan := BuildingGenerator.plan(w, d, fl, fh, s)
		var issues := BuildingValidator.validate(plan)
		if plan.ok():
			var node := BuildingBuilder.build(self, plan)
			issues.append_array(BuildingValidator.check_built(node, plan))
			node.queue_free()
		var title := "#%d seed %d: %.1f x %.1f m, %d floors of %.1f m" % [i + 1, s, w, d, fl, fh]
		if issues.is_empty():
			ok_count += 1
		elif BuildingValidator.codes(issues) == PackedStringArray(["INPUT"]):
			rejected.append("%s -> %s" % [title, issues[0].text])
		else:
			broken.append(BuildingValidator.format(title, issues))
			for c in BuildingValidator.codes(issues):
				by_code[c] = int(by_code.get(c, 0)) + 1
	print("\nbatch of %d random buildings:" % n)
	print("  %d valid" % ok_count)
	print("  %d rejected for bad input (correct behaviour):" % rejected.size())
	for line in rejected:
		print("     ", line)
	print("  %d FAILED with geometry problems%s" % [broken.size(), "" if broken.is_empty() else " (by reason: %s)" % by_code])
	for text in broken:
		print(text)
	check("no generated building has a geometry problem", broken.is_empty())
