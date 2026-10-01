# CityGenerator - reads city.json and builds the 3D city at runtime.
#
# One job: be the conductor. It loads the data once, then asks one small builder
# per layer to make nodes and adds them as children. Each phase adds a layer here;
# nothing in this file knows WHERE anything goes, that is all in the JSON.
#
# Phase 2 layers: ground (terrain mesh) and water (one flat sea-level plane).
# Phase 3 layers: roads (draped over the terrain) and bridges.
# Phase 4 layer: building lots (coloured parcels between the roads).
# Phase 5 layer: buildings (one MultiMesh per district group).
# Phase 6 layer: landmarks (tower, wheel, basilica); buildings keep the sightlines to the tower clear.
extends Node3D

const CityData := preload("res://city/city_data.gd")
const TerrainHeight := preload("res://city/terrain_height.gd")
const TerrainBuilder := preload("res://city/terrain_builder.gd")
const RoadNetwork := preload("res://city/road_network.gd")
const RoadBuilder := preload("res://city/road_builder.gd")
const LotPlan := preload("res://city/lot_plan.gd")
const LotBuilder := preload("res://city/lot_builder.gd")
const BuildingPlan := preload("res://city/building_plan.gd")
const BuildingBuilder := preload("res://city/building_builder.gd")
const Sightlines := preload("res://city/sightlines.gd")
const LandmarkBuilder := preload("res://city/landmark_builder.gd")

# Extra sea around the map so the edge of the world is open water, not a cliff.
# Pure presentation (the map itself is defined by the JSON), hence a constant here.
const SEA_MARGIN := 400.0
# The water plane reaches much further than the terrain, so the sea runs to the horizon.
const WATER_REACH := 6000.0

var city: Dictionary
var map_size := Vector2.ZERO
var roads  # RoadNetwork: the cut-down road pieces, shared with later layers (lots avoid them)
var plan  # LotPlan: blocks and building lots
var building_plan  # BuildingPlan: what stands on each lot (footprint, height)
var sightlines  # Sightlines: the lines of sight to the tower that buildings must keep clear
var terrain  # TerrainHeight: kept so later layers (roads, lots...) ask the same height function


func _ready() -> void:
	city = CityData.load_city()
	if city.is_empty():
		return
	map_size = CityData.map_size(city)
	terrain = TerrainHeight.new(city)
	add_child(_make_ground())
	add_child(_make_deep_sea_floor())
	add_child(_make_water())
	roads = RoadNetwork.new(city)
	add_child(RoadBuilder.build_roads(roads, terrain))
	plan = LotPlan.new(city, roads)
	add_child(LotBuilder.build(plan, terrain))
	sightlines = Sightlines.new(city, terrain)
	building_plan = BuildingPlan.new(city, plan, terrain, sightlines)
	add_child(BuildingBuilder.build(building_plan, terrain))
	add_child(LandmarkBuilder.build_all(city, terrain))
	add_child(RoadBuilder.build_bridges(roads, terrain, float(city["roads"]["bridge_arch_height"]), float(city["roads"]["bridge_deck_thickness"])))


func _make_ground() -> MeshInstance3D:
	var area := Rect2(Vector2(-SEA_MARGIN, -SEA_MARGIN), map_size + Vector2.ONE * SEA_MARGIN * 2.0)
	var node := MeshInstance3D.new()
	node.name = "Ground"
	node.mesh = TerrainBuilder.build(terrain, area, float(city["terrain"]["mesh_cell_size"]))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	node.material_override = mat
	return node


# The terrain mesh only covers the map plus a margin. Past that, the sea floor is a
# flat plane at the same depth the terrain settles to, so the water has no visible edge.
func _make_deep_sea_floor() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = map_size + Vector2.ONE * WATER_REACH * 2.0
	var node := MeshInstance3D.new()
	node.name = "DeepSeaFloor"
	node.mesh = plane
	node.position = Vector3(map_size.x * 0.5, terrain.sea_level - float(city["terrain"]["sea_depth"]) - 0.2, map_size.y * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = TerrainBuilder.SEABED
	mat.roughness = 1.0
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node


# Sea, river and harbour are all the same thing: low ground under one flat plane.
# WHY: no separate river geometry to keep in sync with the terrain.
func _make_water() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = map_size + Vector2.ONE * WATER_REACH * 2.0
	var node := MeshInstance3D.new()
	node.name = "Water"
	node.mesh = plane
	node.position = Vector3(map_size.x * 0.5, terrain.sea_level, map_size.y * 0.5)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.38, 0.62, 0.8)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness = 0.1
	node.material_override = mat
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return node
