# BlockMap - finds the BLOCKS: the pieces of land where buildings may stand.
#
# One job: start from the land inside the coast road and cut away everything that is
# not buildable, then label what is left by district.
#   cut away: the water and the embankment margin, every road plus a sidewalk gap,
#             and the special sites (station, plaza, library, museum, hall), which
#             become their own reserved lots later.
#   then split by district so a block never straddles two districts.
# The park is kept as a block of type "park" (greenery later) but never gets lots.
# Pure 2D: no terrain, no nodes.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")

# Each: {"id": String, "district": String, "type": String, "polygon": PackedVector2Array, "area": float}
var blocks: Array = []
# Each: {"id": String, "kind": String, "name": String, "polygon": PackedVector2Array}  (the site's buildable footprint)
var site_footprints: Array = []


func _init(city: Dictionary, network) -> void:
	var lots: Dictionary = city["lots"]
	var sidewalk := float(lots["sidewalk"])
	var min_area := float(lots["min_lot_area"])
	var road_cutters: Array = network.ribbons(sidewalk)

	var sites: Array = []
	for site in city["sites"]:
		sites.append(CityData.to_points(site["polygon"]))

	# 1. what is left of the land after water, roads and sites
	var pieces: Array = network.interior.duplicate()
	pieces = _subtract(pieces, network.water_zone)
	pieces = _subtract(pieces, road_cutters)

	# 2. sites keep their own footprint (clear of roads and water), so build them before cutting blocks
	for site in city["sites"]:
		var footprint: Array = [CityData.to_points(site["polygon"])]
		footprint = _subtract(footprint, network.water_zone)
		footprint = _subtract(footprint, road_cutters)
		var biggest := _largest(footprint)
		if not biggest.is_empty():
			site_footprints.append({"id": site["id"], "kind": site["kind"], "name": site["name"], "polygon": biggest})
	for site in sites:
		pieces = _carve(pieces, site)
	_assert_no_holes(pieces, "after cutting roads and sites")

	# 3. split by district
	var n := 0
	for piece in pieces:
		for d in city["districts"]:
			for part in Geometry2D.intersect_polygons(piece, CityData.to_points(d["polygon"])):
				var area := Geo2D.polygon_area(part)
				if area >= min_area:
					blocks.append({"id": "block_%d" % n, "district": d["id"], "type": d["type"], "polygon": part, "area": area})
					n += 1


# Take a site out of the land WITHOUT leaving a hole: split each piece it touches into the
# parts behind, ahead of, left of and right of the site's rectangle. (A polygon with a hole
# cannot be cut into lots, and Godot returns holes as separate polygons that are easy to
# mistake for land.)
func _carve(pieces: Array, site: PackedVector2Array) -> Array:
	var rect := Geo2D.min_area_rect(site)
	var u: Vector2 = rect["u"]
	var v := u.orthogonal()
	var c: Vector2 = rect["center"]
	var hu: float = rect["half"].x
	var hv: float = rect["half"].y
	var big := 100000.0
	var footprint := _rect(c, u, v, -hu, hu, -hv, hv)
	var regions := [
		_rect(c, u, v, -big, -hu, -big, big),
		_rect(c, u, v, hu, big, -big, big),
		_rect(c, u, v, -hu, hu, -big, -hv),
		_rect(c, u, v, -hu, hu, hv, big),
	]
	var out: Array = []
	for piece in pieces:
		if not _bounds(piece).intersects(_bounds(footprint)) or Geo2D.overlap_area(piece, footprint) < 0.01:
			out.append(piece)
			continue
		for region in regions:
			out.append_array(Geometry2D.intersect_polygons(piece, region))
	return out


func _rect(c: Vector2, u: Vector2, v: Vector2, u0: float, u1: float, v0: float, v1: float) -> PackedVector2Array:
	return PackedVector2Array([c + u * u0 + v * v0, c + u * u1 + v * v0, c + u * u1 + v * v1, c + u * u0 + v * v1])


# Land pieces must all be solid. If a cut ever leaves a hole, say so loudly: the order of
# cuts (see RoadNetwork.ribbons) is what prevents it.
func _assert_no_holes(pieces: Array, when: String) -> void:
	var holes := 0
	for piece in pieces:
		if Geometry2D.is_polygon_clockwise(piece):
			holes += 1
	if holes > 0:
		push_error("BlockMap: %d polygon(s) with the wrong orientation (probable holes) %s" % [holes, when])


# Cut every cutter polygon out of every piece. A box check first skips the many pairs
# that are nowhere near each other (the expensive polygon clipping only runs on real overlaps).
func _subtract(pieces: Array, cutters: Array) -> Array:
	var current := pieces
	for cutter in cutters:
		var cutter_box := _bounds(cutter)
		var next: Array = []
		for piece in current:
			if not _bounds(piece).intersects(cutter_box):
				next.append(piece)
				continue
			next.append_array(Geometry2D.clip_polygons(piece, cutter))
		current = next
	return current


func _bounds(poly: PackedVector2Array) -> Rect2:
	var box := Rect2(poly[0], Vector2.ZERO)
	for p in poly:
		box = box.expand(p)
	return box


func _largest(polys: Array) -> PackedVector2Array:
	var best := PackedVector2Array()
	var best_area := -1.0
	for poly in polys:
		var area := Geo2D.polygon_area(poly)
		if area > best_area:
			best_area = area
			best = poly
	return best
