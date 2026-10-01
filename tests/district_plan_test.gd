extends Node
## Phase 4 check, headless: plan a generated building for EVERY lot of the real city
## layout (no nodes built, so it is fast) and verify them as a group.
##   godot --headless res://tests/district_plan_test.tscn
## Exit code 0 = pass.

func _ready() -> void:
	var lots := BuildingDistrict.all_lots()
	var entries := BuildingDistrict.entries_for(lots)
	var fails := 0
	var worst := 0.0
	var worst_name := ""
	for e: Dictionary in entries:
		var issues := BuildingValidator.validate(e.plan)
		if not issues.is_empty():
			fails += 1
			print(BuildingValidator.format(e.name, issues))
		# how close is the generated height to the city's hand-made height?
		var err := absf(BuildingGrid.to_metres(e.plan.height_units()) - float(e.height))
		if err > worst:
			worst = err
			worst_name = e.name
	var group := BuildingValidator.check_footprints(entries)
	for i in group:
		fails += 1
		print("[%s] %s" % [i.code, i.text])
	# same inputs twice must give the same building (the whole point of seeds)
	var again := BuildingDistrict.entries_for(lots)
	for i in entries.size():
		if entries[i].plan.signature() != again[i].plan.signature():
			fails += 1
			print("not deterministic: ", entries[i].name)
	if entries.size() < 100:
		fails += 1
		print("expected ~100+ lots, found %d" % entries.size())
	print("district plan test: %d lots, %d problems, worst height error %.1f m (%s)" % [entries.size(), fails, worst, worst_name])
	print("PASSED" if fails == 0 else "FAILED")
	get_tree().quit(0 if fails == 0 else 1)
