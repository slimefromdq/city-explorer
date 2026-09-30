class_name BuildingStyle
extends RefCounted
## Feature: simple styles. A style is nothing but a set of numbers the other
## features read: palette, plinth height, how dense the windows are, which roofs
## are allowed, how many setbacks, how big the door is. There is no style-specific
## code anywhere else, so adding a style = adding one entry below.
##
## A style narrows the seed's choices; it never replaces them. Two "tower"
## buildings with different seeds still differ (colour, setbacks, roof, which
## windows are lit), but they are recognisably the same kind of building.


class Style:
	var name := ""
	var palette: Array[Color] = []
	var plinth_units := 2                       # height of the base plinth
	var window_pitches: Array[int] = [8]        # bay spacing options, units
	var window_fill := 0.9                      # chance a bay has a window
	var window_lit := 0.25                      # chance a window is lit
	var roof_variants: Array[int] = []          # allowed BuildingRoofs.Variant values
	var max_setbacks := 0                       # most times the tower may step in
	var door_width := 4                         # units
	var door_height := 6                        # units


const NAMES := ["tower", "apartment", "warehouse", "cottage"]

static var _cache := {}


static func get_style(style_name: String) -> Style:
	if _cache.has(style_name):
		return _cache[style_name]
	var s := Style.new()
	s.name = style_name
	match style_name:
		"tower":        # glassy office/residential tower: dense windows, stepped crown, setbacks
			s.palette = [Color(0.34, 0.44, 0.56), Color(0.30, 0.38, 0.50), Color(0.42, 0.48, 0.58)]
			s.window_pitches = [8]
			s.window_fill = 0.95
			s.window_lit = 0.3
			s.roof_variants = [BuildingRoofs.Variant.FLAT, BuildingRoofs.Variant.STEPPED, BuildingRoofs.Variant.PARAPET]
			s.max_setbacks = 2
			s.door_width = 6
		"apartment":    # brick block: regular windows, parapet roof, no setbacks
			s.palette = [Color(0.62, 0.40, 0.34), Color(0.55, 0.42, 0.32), Color(0.50, 0.30, 0.26)]
			s.window_pitches = [10]
			s.window_fill = 0.88
			s.window_lit = 0.25
			s.roof_variants = [BuildingRoofs.Variant.PARAPET, BuildingRoofs.Variant.FLAT]
		"warehouse":    # low concrete shed: few windows, flat roof, big door
			s.palette = [Color(0.50, 0.52, 0.56), Color(0.56, 0.54, 0.50), Color(0.40, 0.43, 0.48)]
			s.window_pitches = [10]
			s.window_fill = 0.3
			s.window_lit = 0.1
			s.roof_variants = [BuildingRoofs.Variant.FLAT, BuildingRoofs.Variant.PARAPET]
			s.door_width = 8
			s.door_height = 8
		"cottage":      # small old-town house: raised 1.5 m plinth, gable roof
			s.palette = [Color(0.78, 0.68, 0.54), Color(0.72, 0.60, 0.50), Color(0.80, 0.72, 0.60)]
			s.plinth_units = 3
			s.window_pitches = [8]
			s.window_fill = 0.8
			s.window_lit = 0.35
			s.roof_variants = [BuildingRoofs.Variant.GABLE]
		_:
			return null
	_cache[style_name] = s
	return s


## Picks a style from the size of the building (deterministic, no randomness):
## tall -> tower; low and big -> warehouse; low and small -> cottage; otherwise apartment.
static func auto_for(height_m: float, width_m: float, depth_m: float) -> String:
	if height_m >= 40.0:
		return "tower"
	if height_m <= 14.0:
		return "warehouse" if width_m * depth_m >= 600.0 else "cottage"
	return "apartment"
