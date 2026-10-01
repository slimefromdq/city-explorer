extends "res://tests/building_lab.gd"
## Phase 4 lab: generated buildings on the REAL city lots, in an empty scene.
##
##   godot res://tests/district_lab.tscn
##   DISTRICT_CELLS=FIN_A,OLD_A godot ...   which map cells to fill (default: the 2x2 north-west corner)
##   DISTRICT_ALL=1 godot ...               every lot in the city (slow to open: thousands of windows)
##
## Same camera, labels, validation and footprint overlay as the building lab. The only
## new thing is where the cases come from: BuildingDistrict reads CityLayout.
## Nothing here touches or loads the city scene.

const DEFAULT_CELLS := ["FIN_A", "FIN_B", "FIN_D", "OLD_C"]


func _cases() -> Array:
	var wanted: PackedStringArray = OS.get_environment("DISTRICT_CELLS").split(",", false)
	if wanted.is_empty():
		wanted = PackedStringArray(DEFAULT_CELLS)
	var all := OS.get_environment("DISTRICT_ALL") == "1"
	var lots := []
	for r in CityLayout.ROWS:
		for c in CityLayout.COLS:
			var id: String = CityLayout.GRID[r][c]
			if all or wanted.has(id):
				lots.append_array(BuildingDistrict.lots_for_cell(id, c, r))
	var cases := []
	for l: Dictionary in lots:
		var lot: Rect2 = l.lot
		cases.append({"name": l.name, "lot": lot, "h": l.height, "fh": 4.0 if l.height >= 40.0 else 3.5, "seed": l.seed, "pos": Vector3(lot.position.x, 0.0, lot.position.y)})
	return cases
