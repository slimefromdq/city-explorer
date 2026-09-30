class_name CityLayout
extends RefCounted
## The whole map as DATA: a 7 x 5 grid of 82 m cells (64 m block + 18 m
## street). Each id below maps to a cell recipe. Growing the city = editing
## this file (add rows/cols, swap ids) and adding a builder for any new type.

const COLS := 7
const ROWS := 5
const CELL := 82.0
const BLOCK := 64.0
const HALF := 32.0
const STREET := 18.0
const PLAY_X := 296.0
const PLAY_Z := 214.0

const GRID := [
	["FIN_A",  "FIN_B",   "FIN_C", "CLOCK", "LIBRARY", "OLD_A", "OLD_B"],
	["FIN_D",  "OLD_C",   "PARK",  "PARK",  "PARK",    "OLD_D", "MIX_A"],
	["OLD_E",  "CHINA_A", "PARK",  "PARK",  "PARK",    "MIX_B", "MIX_C"],
	["CHINA_C", "CHINA_B", "OLD_F", "METRO", "FIN_E",   "FIN_F", "MIX_D"],
	["OLD_G",  "MARKET",  "OLD_H", "FIN_G", "FIN_H",   "MIX_E", "OLD_I"],
]

## Lot recipes: [NW, NE, SW, SE] = [style, height]. Heights are deliberately
## stair-stepped between neighbours so rooftop routes exist.
const LOTS := {
	"FIN_A": [["glass", 96], ["glass", 128], ["glass", 74], ["billboard", 60]],
	"FIN_B": [["glass", 110], ["round", 92], ["glass", 66], ["glass", 84]],
	"FIN_C": [["glass", 142], ["glass", 88], ["round", 72], ["glass", 102]],
	"FIN_D": [["round", 124], ["glass", 78], ["glass", 90], ["billboard", 54]],
	"FIN_E": [["glass", 104], ["glass", 176], ["billboard", 66], ["glass", 82]],
	"FIN_F": [["glass", 94], ["glass", 120], ["round", 86], ["glass", 70]],
	"FIN_G": [["glass", 92], ["glass", 112], ["glass", 68], ["plaza", 0]],
	"FIN_H": [["glass", 78], ["glass", 100], ["billboard", 72], ["glass", 60]],
	"OLD_A": [["brick", 28], ["oldtown", 24], ["concrete", 31], ["oldtown", 22]],
	"OLD_B": [["concrete", 17], ["brick", 23], ["oldtown", 14], ["brick", 20]],
	"OLD_C": [["oldtown", 17], ["brick", 23], ["concrete", 14], ["oldtown", 20]],
	"OLD_D": [["brick", 21], ["concrete", 27], ["oldtown", 18], ["brick", 24]],
	"OLD_E": [["oldtown", 21], ["brick", 27], ["concrete", 18], ["oldtown", 24]],
	"OLD_F": [["concrete", 28], ["oldtown", 24], ["brick", 31], ["oldtown", 22]],
	"OLD_G": [["brick", 22], ["oldtown", 24], ["concrete", 25], ["oldtown", 24]],
	"OLD_H": [["oldtown", 21], ["brick", 27], ["oldtown", 18], ["concrete", 24]],
	"OLD_I": [["brick", 25], ["concrete", 31], ["oldtown", 22], ["brick", 28]],
	"MARKET": [["oldtown", 20], ["oldtown", 17], ["oldtown", 23], ["oldtown", 14]],
	"MIX_A": [["brick", 31], ["brick", 22], ["billboard", 28], ["concrete", 25]],
	"MIX_B": [["brick", 23], ["brick", 14], ["concrete", 20], ["oldtown", 17]],
	"MIX_C": [["billboard", 18], ["brick", 24], ["brick", 21], ["concrete", 27]],
	"MIX_D": [["brick", 20], ["billboard", 17], ["brick", 23], ["concrete", 14]],
	"MIX_E": [["concrete", 24], ["brick", 21], ["brick", 27], ["billboard", 18]],
	"CHINA_A": [["chinese", 22], ["chinese", 22], ["chinese", 22], ["chinese", 22]],
	"CHINA_B": [["chinese", 16], ["pagoda", 0], ["chinese", 22], ["chinese", 22]],
	"CHINA_C": [["chinese", 22], ["chinese", 16], ["chinese", 16], ["chinese", 16]],
}

const SPECIAL := ["PARK", "CLOCK", "LIBRARY", "METRO"]

const DISTRICT_COLORS := {
	"financial": Color(0.35, 0.55, 0.95),
	"old town": Color(0.75, 0.5, 0.35),
	"chinatown": Color(0.9, 0.25, 0.25),
	"park": Color(0.3, 0.75, 0.4),
	"station": Color(0.6, 0.6, 0.7),
	"library": Color(0.95, 0.8, 0.35),
	"plaza": Color(0.85, 0.8, 0.7),
	"mixed": Color(0.65, 0.45, 0.85),
	"market": Color(0.9, 0.65, 0.3),
}


const QUAY_Z := 214.0          # end of the street grid; the harbour quay starts here
const WATER_Z := 251.0         # quay face; the river starts here
const WATER_Y := -1.5
const BED_Y := -2.7
const RIVER_MAX_Z := 480.0     # last walkable shallows (invisible wall + buoy line)


static func river_hole() -> Rect2:
	return Rect2(-1000.0, WATER_Z - 1.0, 2000.0, 900.0)


static func cell_center(c: int, r: int) -> Vector2:
	return Vector2((c - (COLS - 1) * 0.5) * CELL, (r - (ROWS - 1) * 0.5) * CELL)


static func avenues_x() -> Array:
	var a := []
	for i in COLS + 1:
		a.append((i - COLS * 0.5) * CELL)
	return a


static func streets_z() -> Array:
	var a := []
	for i in ROWS + 1:
		a.append((i - ROWS * 0.5) * CELL)
	return a


static func district_of(id: String) -> String:
	if id.begins_with("FIN"):
		return "financial"
	if id.begins_with("OLD"):
		return "old town"
	if id.begins_with("CHINA"):
		return "chinatown"
	if id.begins_with("MIX"):
		return "mixed"
	match id:
		"PARK": return "park"
		"METRO": return "station"
		"LIBRARY": return "library"
		"CLOCK": return "plaza"
		"MARKET": return "market"
	return "mixed"


static func park_rect() -> Rect2:
	var a := cell_center(2, 1)
	var b := cell_center(4, 2)
	return Rect2(a.x - HALF, a.y - HALF, (b.x - a.x) + BLOCK, (b.y - a.y) + BLOCK)


static func station_center() -> Vector2:
	return cell_center(3, 3)


static func station_pit() -> Rect2:
	var c := station_center()
	return Rect2(c.x - 20.0, c.y - 26.0, 40.0, 52.0)
