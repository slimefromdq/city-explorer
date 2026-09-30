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
	"OLD_A": [["brick", 24], ["oldtown", 14], ["concrete", 32], ["oldtown", 18]],
	"OLD_B": [["concrete", 30], ["brick", 22], ["oldtown", 12], ["brick", 36]],
	"OLD_C": [["oldtown", 16], ["brick", 28], ["concrete", 22], ["oldtown", 12]],
	"OLD_D": [["brick", 34], ["concrete", 26], ["oldtown", 16], ["brick", 20]],
	"OLD_E": [["oldtown", 12], ["brick", 24], ["concrete", 38], ["oldtown", 18]],
	"OLD_F": [["concrete", 30], ["oldtown", 14], ["brick", 22], ["oldtown", 20]],
	"OLD_G": [["brick", 26], ["oldtown", 14], ["concrete", 34], ["oldtown", 12]],
	"OLD_H": [["oldtown", 16], ["brick", 30], ["oldtown", 12], ["concrete", 24]],
	"OLD_I": [["brick", 32], ["concrete", 24], ["oldtown", 16], ["brick", 28]],
	"MARKET": [["oldtown", 12], ["oldtown", 14], ["oldtown", 10], ["oldtown", 16]],
	"MIX_A": [["glass", 58], ["brick", 30], ["billboard", 44], ["concrete", 26]],
	"MIX_B": [["brick", 40], ["glass", 66], ["concrete", 28], ["oldtown", 16]],
	"MIX_C": [["billboard", 52], ["brick", 34], ["glass", 48], ["concrete", 30]],
	"MIX_D": [["glass", 72], ["billboard", 46], ["brick", 36], ["concrete", 28]],
	"MIX_E": [["concrete", 32], ["glass", 56], ["brick", 26], ["billboard", 48]],
	"CHINA_A": [["chinese", 17], ["chinese", 21], ["chinese", 14], ["chinese", 23]],
	"CHINA_B": [["chinese", 19], ["pagoda", 0], ["chinese", 15], ["chinese", 21]],
	"CHINA_C": [["chinese", 16], ["chinese", 22], ["chinese", 14], ["chinese", 18]],
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
