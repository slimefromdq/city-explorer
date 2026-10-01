# CityData - loads res://data/city.json and converts it to Godot types.
#
# One job: be the ONLY place that reads the file. The debug map, the validator
# and (later) the generator all go through here, so there is exactly one answer
# to "what does the data say?" and no script parses JSON on its own.
extends RefCounted

const DEFAULT_PATH := "res://data/city.json"


# Returns the parsed city as a Dictionary, or {} (plus an error message) if the
# file is missing or is not valid JSON.
static func load_city(path: String = DEFAULT_PATH) -> Dictionary:
	if not FileAccess.file_exists(path):
		push_error("CityData: file not found: %s" % path)
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("CityData: %s is not valid JSON (top level must be an object)" % path)
		return {}
	return parsed


# JSON has no Vector2, so points arrive as [[x, y], ...]. Extra numbers per
# point (the river's width) are ignored here on purpose.
static func to_points(raw: Array) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for p in raw:
		pts.append(Vector2(float(p[0]), float(p[1])))
	return pts


static func map_size(city: Dictionary) -> Vector2:
	return Vector2(float(city["meta"]["map_size"][0]), float(city["meta"]["map_size"][1]))
