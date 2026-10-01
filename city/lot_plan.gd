# LotPlan - the finished list of building lots.
#
# One job: combine the blocks (where building is allowed) with the district rules
# (how big a lot is there) and the seed, and list every lot. The planned buildings
# in the next phase will read this list, one building per lot.
#
# Reproducible on purpose: each block gets its own random generator seeded from
# meta.seed and the block's id, so the same JSON always yields the same lots, and
# changing one district does not reshuffle the lots of another.
extends RefCounted

const CityData := preload("res://city/city_data.gd")
const Geo2D := preload("res://city/geo2d.gd")
const BlockMap := preload("res://city/block_map.gd")
const LotSplitter := preload("res://city/lot_splitter.gd")

# Each: {"id": String, "block": String, "district": String, "type": String,
#        "kind": "lot" | "site", "polygon": PackedVector2Array, "area": float,
#        "center": Vector2, "landmark": String ("" if none), "site_kind": String ("" for ordinary lots)}
var lots: Array = []
var block_map  # BlockMap, kept so others can see the blocks and parks too


func _init(city: Dictionary, network) -> void:
	block_map = BlockMap.new(city, network)
	var rules: Dictionary = city["lots"]
	var min_area := float(rules["min_lot_area"])
	var min_depth := float(rules["min_depth"])
	var jitter := float(rules["split_jitter"])
	var n := 0
	for block in block_map.blocks:
		if not rules["types"].has(block["type"]):
			continue  # park: greenery, no lots
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%d:%s" % [int(city["meta"]["seed"]), block["id"]])
		var type_rules: Dictionary = rules["types"][block["type"]]
		for piece in LotSplitter.split(block["polygon"], float(type_rules["max_area"]), float(type_rules["min_width"]), jitter, rng):
			var area := Geo2D.polygon_area(piece)
			var rect := Geo2D.min_area_rect(piece)
			if area >= min_area and not rect.is_empty() and float(rect["half"].y) * 2.0 >= min_depth:
				lots.append(_lot("lot_%d" % n, block["id"], block["district"], block["type"], "lot", piece, area))
				n += 1
	for site in block_map.site_footprints:
		var district := _district_at(city, Geo2D.polygon_centroid(site["polygon"]))
		var lot := _lot("site_%s" % site["id"], "", district["id"], district["type"], "site", site["polygon"], Geo2D.polygon_area(site["polygon"]))
		lot["site_kind"] = site["kind"]
		lots.append(lot)
	_tag_landmarks(city)


func _lot(id: String, block: String, district: String, type: String, kind: String, polygon: PackedVector2Array, area: float) -> Dictionary:
	return {"id": id, "block": block, "district": district, "type": type, "kind": kind,
		"polygon": polygon, "area": area, "center": Geo2D.polygon_centroid(polygon), "landmark": "", "site_kind": ""}


func _district_at(city: Dictionary, p: Vector2) -> Dictionary:
	for d in city["districts"]:
		if Geometry2D.is_point_in_polygon(p, CityData.to_points(d["polygon"])):
			return d
	return city["districts"][0]


# A lot that holds a landmark is reserved for it (the next phases build the landmark there,
# not an ordinary building).
func _tag_landmarks(city: Dictionary) -> void:
	for lm in city["landmarks"]:
		var p := Vector2(lm["position"][0], lm["position"][1])
		for lot in lots:
			if Geometry2D.is_point_in_polygon(p, lot["polygon"]):
				lot["landmark"] = lm["id"]
				break
