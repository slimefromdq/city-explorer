class_name BuildingGenerator
extends RefCounted
## Turns five numbers (footprint width/depth, floors, floor height, seed) into
## a BuildingPlan. It never touches the scene: it only decides where boxes go.
##
## Anatomy, bottom to top (all in BuildingGrid units):
##   base    a plinth (1 m, or 1.5 m for some styles) covering the WHOLE footprint.
##           The footprint you ask for is the outer edge, so a building never
##           pokes outside its lot.
##   floors  one box per storey, stacked with no gap: each floor's bottom is
##           exactly the previous floor's top. The walls sit 0.5 m inside the base.
##           Tall buildings may step in ("setbacks") in whole-unit steps.
##   roof    a 0.5 m slab on top, plus a variant (parapet, steps, gable...).
##   rooftop sometimes a small plant-room box on the roof.
##   detail  a front door and windows on every floor (features, each in its own file).
##
## A style (BuildingStyle) narrows the choices: palette, windows, roofs, setbacks.
##
## Determinism: every choice comes from the seed, through a separate random
## stream per feature (colour, setbacks, rooftop). Streams are independent so
## adding a new feature later never changes how an existing one turns out.

const BASE_UNITS := 2              # default plinth (1 m); a style may override it
const WALL_INSET := 1              # walls start 0.5 m inside the footprint
const ROOF_UNITS := 1              # 0.5 m roof slab
const MIN_FOOTPRINT_UNITS := 14    # 7 m: smaller than this leaves no room for walls
const MIN_TIER_UNITS := 12         # a setback never shrinks a section below 6 m
const DEFAULT_FLOOR_M := 3.5

enum Stream { COLOR, TIERS, ROOFTOP, WINDOWS, DOORS, ROOF }

## How many floors give roughly `height_m` in total (base and roof included)?
## Used to recreate the existing city's building heights (e.g. 96 m) on the grid.
static func floors_for_height(height_m: float, floor_height_m: float, plinth_units := BASE_UNITS) -> int:
	var frame := BuildingGrid.to_metres(plinth_units + ROOF_UNITS)
	var fh := BuildingGrid.to_metres(BuildingGrid.to_units(floor_height_m))
	return maxi(1, roundi((height_m - frame) / maxf(fh, BuildingGrid.UNIT)))


## Convenience for "match the existing city": a lot rectangle (metres, as used
## by CityLayout / BuildingFactory) plus a target height. The style ("auto" or one
## of BuildingStyle.NAMES) is settled first because its plinth changes the floor count.
static func plan_for_lot(lot: Rect2, height_m: float, floor_height_m: float, seed_value: int, style_name := "auto") -> BuildingPlan:
	if style_name == "auto":
		style_name = BuildingStyle.auto_for(height_m, lot.size.x, lot.size.y)
	var style := BuildingStyle.get_style(style_name)
	var plinth := style.plinth_units if style != null else BASE_UNITS
	return plan(lot.size.x, lot.size.y, floors_for_height(height_m, floor_height_m, plinth), floor_height_m, seed_value, style_name)


static func plan(width_m: float, depth_m: float, floors: int, floor_height_m: float, seed_value: int, style_name := "auto") -> BuildingPlan:
	var p := BuildingPlan.new()
	p.seed_value = seed_value
	p.floors = floors
	p.width_u = BuildingGrid.to_units(width_m)
	p.depth_u = BuildingGrid.to_units(depth_m)
	p.floor_units = BuildingGrid.to_units(floor_height_m)
	# Input rules live in BuildingValidator so there is one source of truth.
	for issue in BuildingValidator.check_inputs(width_m, depth_m, floors, floor_height_m, style_name):
		p.errors.append(issue.text)
	if not p.errors.is_empty():
		return p
	if style_name == "auto":
		style_name = BuildingStyle.auto_for(floors * floor_height_m, width_m, depth_m)
	var style := BuildingStyle.get_style(style_name)
	p.style_name = style_name
	var base_u := style.plinth_units

	var w := p.width_u
	var d := p.depth_u
	var fh := p.floor_units
	p.palette_index = _rng(seed_value, Stream.COLOR).randi_range(0, style.palette.size() - 1)

	p.pieces.append(BuildingPlan.Piece.new("base", Vector3i.ZERO, Vector3i(w, base_u, d)))

	# Floors, in sections ("tiers"). Section k starts at floor cuts[k-1] and is
	# pulled in a further `step` units on every side, so the tower stays centred.
	var t := _tiers(floors, mini(w, d), style.max_setbacks, _rng(seed_value, Stream.TIERS))
	var cuts: Array[int] = t.cuts
	var step: int = t.step
	var tier := 0
	var inset := WALL_INSET
	for i in floors:
		if tier < cuts.size() and i == cuts[tier]:
			tier += 1
			inset = WALL_INSET + tier * step
		var at := Vector3i(inset, base_u + i * fh, inset)
		p.pieces.append(BuildingPlan.Piece.new("floor", at, Vector3i(w - 2 * inset, fh, d - 2 * inset), tier, i))

	var top_w := w - 2 * inset
	var top_d := d - 2 * inset
	var roof_y := base_u + floors * fh
	p.pieces.append(BuildingPlan.Piece.new("roof", Vector3i(inset, roof_y, inset), Vector3i(top_w, ROOF_UNITS, top_d)))

	# Feature: roof variant (seed-driven). Draws exactly one number from its own stream.
	var variant: BuildingRoofs.Variant = style.roof_variants[_rng(seed_value, Stream.ROOF).randi_range(0, style.roof_variants.size() - 1)] as BuildingRoofs.Variant
	p.roof_variant = BuildingRoofs.variant_name(variant)
	BuildingRoofs.add(p, variant, inset, top_w, top_d, roof_y + ROOF_UNITS)

	# Optional plant room. Always draw all numbers so the stream stays aligned; it only
	# goes on roofs that leave the surface free (flat, parapet).
	var rr := _rng(seed_value, Stream.ROOFTOP)
	var wanted := rr.randf() < 0.6
	var bw := clampi(floori(top_w / 3.0) + rr.randi_range(-1, 1), 4, top_w - 4)
	var bd := clampi(floori(top_d / 3.0) + rr.randi_range(-1, 1), 4, top_d - 4)
	var bh := rr.randi_range(4, 8)
	if wanted and BuildingRoofs.allows_rooftop(variant):
		var at := Vector3i(inset + ((top_w - bw) >> 1), roof_y + ROOF_UNITS, inset + ((top_d - bd) >> 1))
		p.pieces.append(BuildingPlan.Piece.new("rooftop", at, Vector3i(bw, bh, bd)))

	# Feature: front door (placed first so windows can keep clear of it).
	var door := BuildingDoors.add(p, style.door_width, style.door_height, _rng(seed_value, Stream.DOORS))

	# Feature: windows (seed-driven pitch, how many bays are filled, how many are lit).
	var wr := _rng(seed_value, Stream.WINDOWS)
	var pitch := style.window_pitches[wr.randi_range(0, style.window_pitches.size() - 1)]
	BuildingWindows.add(p, pitch, style.window_fill, style.window_lit, wr, door)
	return p


## Decides where a tall building steps in. Returns {cuts: floor indices where a
## new section starts, step: how many units each step pulls the walls in}.
static func _tiers(floors: int, min_side: int, style_max: int, r: RandomNumberGenerator) -> Dictionary:
	var max_cuts := mini(style_max, 0 if floors < 8 else (1 if floors < 16 else 2))
	var want := r.randi_range(0, max_cuts)
	var step := r.randi_range(2, 4)            # 1 to 2 m per setback
	var cuts: Array[int] = []
	var prev := 0
	for i in range(1, want + 1):
		var lo := prev + 2                     # every section is at least 2 floors tall
		var hi := floors - 2 * (want - i + 1)  # ...and leaves 2 floors for each section still to come
		if lo > hi:
			break
		var c := clampi(floori(float(floors * i) / float(want + 1)) + r.randi_range(-1, 1), lo, hi)
		cuts.append(c)
		prev = c
	# Never let the top section get too small to be a real floor plate.
	while not cuts.is_empty() and min_side - 2 * (WALL_INSET + cuts.size() * step) < MIN_TIER_UNITS:
		cuts.pop_back()
	return {"cuts": cuts, "step": step}


## A private random stream per (seed, feature). The integer mix just spreads
## nearby seeds (1, 2, 3...) far apart so they do not produce similar numbers.
static func _rng(seed_value: int, stream: Stream) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = (seed_value * 2654435761 + (int(stream) + 1) * 40503) & 0xFFFFFFFF
	return r
