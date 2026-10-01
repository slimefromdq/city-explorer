class_name RiverPath
extends RefCounted
## The river's centre line from city.json (points [x, z, width]), for drawing on route maps.

static func load_path() -> Array:
	var city: Dictionary = preload("res://city/city_data.gd").load_city()
	if city.is_empty():
		return []
	return city["river"]["path"]
