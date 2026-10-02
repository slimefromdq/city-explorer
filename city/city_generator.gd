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
# Phase 7 layers: the tower precinct, greenery (trees, roof gardens, paths) and neon signs.
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
const PrecinctBuilder := preload("res://city/precinct_builder.gd")
const GreeneryPlan := preload("res://city/greenery_plan.gd")
const GreeneryBuilder := preload("res://city/greenery_builder.gd")
const ParkBuilder := preload("res://city/park_builder.gd")
const SignPlan := preload("res://city/sign_plan.gd")
const SignBuilder := preload("res://city/sign_builder.gd")
const DiscoveryWalkPlan := preload("res://city/discovery_walk_plan.gd")
const DiscoveryWalkBuilder := preload("res://city/discovery_walk_builder.gd")
const ArchitecturePlan := preload("res://city/architecture_plan.gd")
const ArchitectureBuilder := preload("res://city/architecture_builder.gd")
const HarbourPlan := preload("res://city/harbour_plan.gd")
const HarbourBuilder := preload("res://city/harbour_builder.gd")

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
var greenery_plan  # GreeneryPlan: trees, roof gardens, sky gardens, paths
var sign_plan  # SignPlan: the neon signs
var terrain  # TerrainHeight: kept so later layers (roads, lots...) ask the same height function
var station  # StationComplex: Central Station (hall, shell, plaza, platforms, trains); null when switched off
var with_station := true
var transit  # TransitSystem: shuttle lines, tunnels, trains
var discovery_walk  # shared promenade plan, including its actual bridge elevations
var architecture_plan  # roof families and civic exteriors inside planned envelopes
var harbour_plan
var park_walk
var library_walk


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
	var routes := RouteData.load_default()
	var reserved: Array = TransitSystem.reserve_rects(routes) if with_station else []
	building_plan = BuildingPlan.new(city, plan, terrain, sightlines, reserved)
	greenery_plan = GreeneryPlan.new(city, roads, plan, building_plan, sightlines, terrain, reserved)
	architecture_plan = ArchitecturePlan.new(building_plan, greenery_plan, city, terrain, sightlines)
	add_child(BuildingBuilder.build(architecture_plan, terrain))
	add_child(ArchitectureBuilder.build(architecture_plan, terrain))
	add_child(preload("res://city/civic_access_builder.gd").build(architecture_plan, terrain, roads, city))
	harbour_plan = HarbourPlan.new(city, terrain)
	add_child(HarbourBuilder.build(harbour_plan, terrain))
	add_child(LandmarkBuilder.build_all(city, terrain))
	if with_station:
		station = StationComplex.new()
		station.position = StationLayout.HUB
		add_child(station)
	add_child(PrecinctBuilder.build(city, terrain))
	add_child(GreeneryBuilder.build(greenery_plan, building_plan, terrain, city))
	add_child(ParkBuilder.build(city, greenery_plan, terrain))
	sign_plan = SignPlan.new(city, roads, architecture_plan)
	add_child(SignBuilder.build(sign_plan, building_plan, terrain))
	if station != null:
		transit = TransitSystem.new()
		transit.terrain = terrain
		transit.station = station
		add_child(transit)
		var ground_holes: Array[Rect2] = station.hole_rects()
		ground_holes.append_array(transit.hole_rects_ground())
		var water_holes: Array[Rect2] = station.hole_rects()
		water_holes.append_array(transit.hole_rects_water())
		SurfaceHoles.apply(self, ground_holes, water_holes)
	add_child(RoadBuilder.build_bridges(roads, terrain, float(city["roads"]["bridge_arch_height"]), float(city["roads"]["bridge_deck_thickness"])))
	discovery_walk = DiscoveryWalkPlan.new(city, terrain)
	var walk_holes: Array[Rect2] = []
	if station != null:
		walk_holes.append_array(station.hole_rects())
		walk_holes.append_array(transit.hole_rects_ground())
	add_child(DiscoveryWalkBuilder.build(discovery_walk, DiscoveryWalkPlan.solid_obstacles(building_plan.buildings, city), greenery_plan.trees, terrain, walk_holes))
	park_walk = preload("res://city/park_walk_plan.gd").new(city, greenery_plan, terrain, discovery_walk)
	var park_errors: Array = park_walk.validate(building_plan.buildings, city)
	if park_errors.is_empty():
		add_child(preload("res://city/park_walk_builder.gd").build(park_walk, terrain, greenery_plan.trees))
	else:
		push_error("Park walk invalid: %s" % [park_errors])
	library_walk = preload("res://city/library_walk_plan.gd").new(city, terrain, park_walk)
	var library_errors: Array = library_walk.validate(building_plan.buildings, city)
	var arrival: Node3D = get_node("CivicAccess/LibraryArrival")
	var endpoint: Vector3 = arrival.transform * arrival.get_meta("street_start")
	if library_walk.samples.is_empty() or library_walk.samples[library_walk.samples.size() - 1].distance_to(endpoint) > 0.05:
		library_errors.append("Library walk must meet the civic street approach")
	if library_errors.is_empty():
		add_child(preload("res://city/library_walk_builder.gd").build(library_walk, building_plan.buildings, greenery_plan.trees, terrain))
	else:
		push_error("Library walk invalid: %s" % [library_errors])


func _make_ground() -> MeshInstance3D:
	var area := Rect2(Vector2(-SEA_MARGIN, -SEA_MARGIN), map_size + Vector2.ONE * SEA_MARGIN * 2.0)
	var node := MeshInstance3D.new()
	node.name = "Ground"
	var cell := float(city["terrain"]["mesh_cell_size"])
	node.mesh = TerrainBuilder.build(terrain, area, cell, TerrainBuilder.detail_region(city, cell), minf(cell, 2.0))
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://city/hole_surface.gdshader")
	node.material_override = mat
	return node


# The terrain mesh only covers the map plus a margin. Past that, the sea floor is a
# flat plane at the same depth the terrain settles to, so the water has no visible edge.
func _make_deep_sea_floor() -> MeshInstance3D:
	var plane := PlaneMesh.new()
	plane.size = map_size + Vector2.ONE * WATER_REACH * 2.0
	var node := MeshInstance3D.new()
	node.name = "DeepSeaFloor"
	# Match the terrain's vertex colors and shader, including when the station
	# is disabled. Different color conversion made the mesh boundary visible.
	var arrays := plane.surface_get_arrays(0)
	var colors := PackedColorArray()
	colors.resize(arrays[Mesh.ARRAY_VERTEX].size())
	colors.fill(TerrainBuilder.SEABED)
	arrays[Mesh.ARRAY_COLOR] = colors
	var seabed := ArrayMesh.new()
	seabed.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	node.mesh = seabed
	node.position = Vector3(map_size.x * 0.5, terrain.sea_level - float(city["terrain"]["sea_depth"]) - 0.2, map_size.y * 0.5)
	# Ground is replaced with HoleSurface by SurfaceHoles. Use the same shader
	# here too: StandardMaterial converts vertex colors differently in Forward+.
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://city/hole_surface.gdshader")
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
