class_name BuildingDistrict
extends RefCounted
## Phase 4: "where would generated buildings go?" for the existing city layout.
##
## This only READS CityLayout (the map as data) and returns a list of
## {name, lot, height, seed}. It builds nothing and changes nothing in the city:
## BlockBuilder / BuildingFactory still make the real buildings.
##
## Why a separate planner: the generator already knows how to fill one lot; this
## answers "which lots exist and how tall should each be", using exactly the same
## numbers the city uses. Lot rectangles are computed the same way BlockBuilder does
## (a 64 m block cut by a 6 m alley into four 29 m lots), so a generated building
## would land on the same ground as the hand-made one.

const ALLEY := 6.0   # same as BlockBuilder.ALLEY; kept here so this file does not depend on the builder


## The four lots of one block, in BlockBuilder's order: NW, NE, SW, SE.
static func lot_rects(c: Vector2) -> Array[Rect2]:
	var half := CityLayout.HALF
	var a := ALLEY * 0.5
	var s := half - a
	return [
		Rect2(c.x - half, c.y - half, s, s),
		Rect2(c.x + a, c.y - half, s, s),
		Rect2(c.x - half, c.y + a, s, s),
		Rect2(c.x + a, c.y + a, s, s),
	]


## One block -> the lots that would get a generated building. Plazas and the pagoda
## (height 0 in the data) are skipped: they are not "a box of floors".
static func lots_for_cell(id: String, c_idx: int, r_idx: int) -> Array:
	var out := []
	if not CityLayout.LOTS.has(id):
		return out   # park / clock / library / metro are special builders
	var c := CityLayout.cell_center(c_idx, r_idx)
	var rects := lot_rects(c)
	var recipes: Array = CityLayout.LOTS[id]
	for i in 4:
		var h := float(recipes[i][1])
		if h <= 0.0:
			continue
		out.append({
			"name": "%s/%s %s %.0f m" % [id, ["NW", "NE", "SW", "SE"][i], recipes[i][0], h],
			"lot": rects[i],
			"height": h,
			# the same seed formula BlockBuilder uses, so a lot always gets the same building
			"seed": c_idx * 13 + r_idx * 7 + i,
		})
	return out


## Every lot in the whole city grid.
static func all_lots() -> Array:
	var out := []
	for r in CityLayout.ROWS:
		for c in CityLayout.COLS:
			out.append_array(lots_for_cell(CityLayout.GRID[r][c], c, r))
	return out


## Turn a lot description into a generated plan. Tall things get taller floors so a
## 176 m tower does not need 50 floors.
static func plan_for(lot_info: Dictionary) -> BuildingPlan:
	var h: float = lot_info.height
	var fh := 4.0 if h >= 40.0 else 3.5
	return BuildingGenerator.plan_for_lot(lot_info.lot, h, fh, lot_info.seed)


## Same lots as dictionaries the lab and footprint check understand.
static func entries_for(lots: Array) -> Array:
	var entries := []
	for l: Dictionary in lots:
		var lot: Rect2 = l.lot
		entries.append({"name": l.name, "plan": plan_for(l), "at": Vector3(lot.position.x, 0.0, lot.position.y), "lot": lot, "height": l.height})
	return entries
