extends SceneTree
## Repeatable captures of the actual city viewer lighting. Run with rendering
## enabled: godot --path . --script res://tools/capture_meridia.gd
## OUT selects the output directory; ONLY optionally filters shot names.
## Default output directory is tests/out/meridia.

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Screenshot capture requires a rendering window; omit --headless.")
		quit(1)
		return
	var scene = load("res://city/city_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var cam: Camera3D = scene.get_node("FlyCamera")
	cam.set_process(false)
	scene.get_node("Help").hide()
	root.size = Vector2i(1600, 900)
	var shots = [
		["01_overview", Vector3(800, 950, 1900), Vector3(800, 0, 570)],
		["02_skyline", Vector3(920, 150, 800), Vector3(920, 100, 325)],
		["03_station", Vector3(965, 70, 950), Vector3(762, 12, 850)],
		["04_park", Vector3(250, 160, 510), Vector3(500, 10, 270)],
		["05_neighborhoods", Vector3(330, 100, 1120), Vector3(450, 20, 850)],
		["06_riverside_street", Vector3(920, 5.5, 850), Vector3(780, 9, 850)],
		["07_financial", Vector3(1540, 100, 600), Vector3(1320, 65, 330)]
	]
	var walk = scene.get_node("CityGenerator").discovery_walk
	var gen = scene.get_node("CityGenerator")
	var bridge_index := 26
	for bridge in gen.park_walk.bridges:
		var points: PackedVector2Array = bridge["points"]
		var start := points[0]
		var target := points[points.size() / 2]
		shots.append(["%02d_lake_bridge" % bridge_index, Vector3(start.x, gen.park_walk.height_at(start) + 1.62, start.y), Vector3(target.x, gen.park_walk.height_at(target) + 1.5, target.y)])
		bridge_index += 1
	var lake: Array = gen.city["terrain"]["ponds"][0]["center"]
	var lake_center := Vector3(lake[0], 3, lake[1])
	shots.append(["28_lake_loop", lake_center + Vector3(-40, 100, 130), lake_center])
	var arrival = gen.get_node("CivicAccess/LibraryArrival")
	var museum = gen.get_node("CivicAccess/MuseumArrival")
	var museum_start: Vector3 = museum.transform * museum.get_meta("arrival_start")
	var museum_door: Vector3 = museum.transform * museum.get_meta("door_stop")
	shots.append(["24_museum_arrival", museum_start + Vector3(-18, 12, 15), museum_door + Vector3.UP * 4])
	shots.append(["25_museum_on_foot", museum_start + Vector3.UP * 1.62, museum_door + Vector3.UP * 2])
	var start: Vector3 = arrival.transform * arrival.get_meta("arrival_start")
	var end: Vector3 = arrival.transform * arrival.get_meta("arrival_end")
	shots.append(["21_library_arrival", start + Vector3(18, 15, 18), end + Vector3.UP * 3])
	shots.append(["22_library_steps", start + Vector3.UP * 1.62, end + Vector3.UP * 1.62])
	for bridge in gen.greenery_plan.footbridges:
		var p: Vector2 = (bridge["from"] + bridge["to"]) * 0.5
		var y: float = gen.terrain.height_at(p, false)
		shots.append(["23_park_water", Vector3(p.x + 30, y + 18, p.y + 30), Vector3(p.x, y, p.y)])
		break
	var civic_index := 16
	for site in gen.architecture_plan.civic:
		var b: Dictionary = site["building"]
		var frame := preload("res://city/architecture_builder.gd").building_frame(b, gen.terrain)
		shots.append(["%02d_%s" % [civic_index, b["site_kind"]], frame * Vector3(b["size"].x * 0.15, b["height"] * 1.7, maxf(b["size"].y * 1.6, b["size"].x * 0.75)), frame * Vector3(0, b["height"] * 0.35, 0)])
		civic_index += 1
	var warehouse := {}
	for b in gen.architecture_plan.buildings:
		if b["group"] == "harbour" and (warehouse.is_empty() or b["size"].x * b["size"].y > warehouse["size"].x * warehouse["size"].y):
			warehouse = b
	if not warehouse.is_empty():
		var frame := preload("res://city/architecture_builder.gd").building_frame(warehouse, gen.terrain)
		shots.append(["19_harbour_roofs", frame * Vector3(warehouse["size"].x * 0.6, warehouse["height"] + 35, warehouse["size"].y * 1.3), frame * Vector3(0, warehouse["height"] * 0.6, 0)])
	if not gen.harbour_plan.piers.is_empty():
		var pier: Dictionary = gen.harbour_plan.piers[0]
		var target := Vector3(pier["center"].x, pier["base_y"], pier["center"].y)
		shots.append(["20_harbour_piers", target + Vector3(140, 140, 130), target + Vector3(20, 0, 0)])
	var hub := StationLayout.HUB
	shots.append(["13_station_stair_head", hub + Vector3(7, 2.5, 3), hub + Vector3(16, -3, 3)])
	shots.append(["14_station_stair_landing", hub + Vector3(16.2, -2.3, 3), hub + Vector3(9, -6, 5.5)])
	shots.append(["15_station_stair_separation", hub + Vector3(10, 2, 10), hub + Vector3(19, 1, 6.7)])
	if walk != null and not walk.samples.is_empty() and walk.stops.size() >= 4:
		var crossing: Vector2 = walk.points[1]
		var bridge: Vector2 = walk.points[int(walk.stops[1]["index"])]
		var tower: Vector2 = walk.points[int(walk.stops[2]["index"])]
		var park: Vector2 = walk.points[int(walk.stops[3]["index"])]
		shots.append(["08_station_crossing", Vector3(crossing.x + 10, walk.height_at(crossing) + 1.62, crossing.y + 5), Vector3(crossing.x - 10, walk.height_at(crossing) + 1.5, crossing.y - 5)])
		shots.append(["09_bridge_walk", Vector3(bridge.x, walk.height_at(bridge) + 1.62, bridge.y + 10), Vector3(tower.x + 20, 30, tower.y)])
		shots.append(["10_tower_forecourt", Vector3(tower.x, walk.height_at(tower) + 1.62, tower.y + 18), Vector3(tower.x, walk.height_at(tower) + 1.62, tower.y - 40)])
		shots.append(["11_park_arrival", Vector3(park.x, walk.height_at(park) + 1.62, park.y), Vector3(park.x - 65, walk.height_at(park) + 1, park.y + 25)])
		var rest: Dictionary = walk.rest_points[0]
		var rest_pos := Vector2(rest["position"][0], rest["position"][1])
		var near_rest: Vector2 = walk.closest_point(rest_pos)
		shots.append(["12_riverside_rest", Vector3(near_rest.x, walk.height_at(near_rest) + 1.62, near_rest.y + 14), Vector3(rest_pos.x, walk.height_at(near_rest) + 1, rest_pos.y)])
	var out := OS.get_environment("OUT")
	if out.is_empty():
		out = "res://tests/out/meridia"
	out = ProjectSettings.globalize_path(out)
	var error := DirAccess.make_dir_recursive_absolute(out)
	if error != OK:
		push_error("Cannot create capture directory: %s (%s)" % [out, error_string(error)])
		quit(1)
		return
	for shot in shots:
		var only := OS.get_environment("ONLY").split(",", false)
		if not only.is_empty() and not only.has(shot[0]):
			continue
		cam.position = shot[1]
		cam.look_at(shot[2])
		cam.fov = 65
		cam.near = 0.1
		await create_timer(1.0).timeout
		await RenderingServer.frame_post_draw
		error = root.get_texture().get_image().save_png(out + "/" + shot[0] + ".png")
		if error != OK:
			push_error("Cannot save %s: %s" % [shot[0], error_string(error)])
			quit(1)
			return
		print("Captured ", shot[0])
	quit()

