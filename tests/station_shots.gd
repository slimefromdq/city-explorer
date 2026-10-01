extends Node3D
## Screenshots of the station in the city. Env: OUT=dir, ONLY=shot_name,..., CITY=0 for the station alone.
const CITY_GEN := preload("res://city/city_generator.gd")
const FIGURE_H := PlayerScale.HEIGHT

var cam: Camera3D
var city: Node3D
var station: StationComplex
var transit: TransitSystem


func _ready() -> void:
	cam = Camera3D.new()
	cam.far = 4000.0
	cam.near = 0.1
	add_child(cam)
	cam.current = true
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.8
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.transform = Transform3D(Basis(Vector3(0.866, 0, -0.5), Vector3(-0.354, 0.707, -0.612), Vector3(0.354, 0.707, 0.612)), Vector3(0, 500, 0))
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 600.0
	sun.light_color = Color(1.0, 0.93, 0.8)
	add_child(sun)
	if OS.get_environment("CITY") != "0":
		city = CITY_GEN.new()
		add_child(city)
		station = city.station
		transit = city.transit
	else:
		station = StationComplex.new()
		station.position = StationLayout.HUB
		add_child(station)
		transit = TransitSystem.new()
		transit.station = station
		add_child(transit)
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	await _shots()
	get_tree().quit()


func _look(pos: Vector3, target: Vector3, fov := 70.0, up := Vector3.UP) -> void:
	cam.fov = fov
	cam.global_position = pos
	cam.look_at(target, up)


func _figure(feet: Vector3) -> Node3D:
	var person := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.height = FIGURE_H
	mesh.radius = PlayerScale.RADIUS
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.9, 0.2, 0.15)
	mesh.material = m
	person.mesh = mesh
	person.position = feet + Vector3(0, FIGURE_H * 0.5, 0)
	add_child(person)
	return person


func _shots() -> void:
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://tests/out"
	var only := OS.get_environment("ONLY").split(",", false)
	var h := StationLayout.HUB
	var list: Array = _shot_list(h)
	for s in list:
		if only.size() > 0 and not only.has(s["name"]):
			continue
		if s.has("setup"):
			await call(s["setup"])
		var fig: Node3D = null
		if s.get("feet") != null:
			fig = _figure(s["feet"])
		_look(s["pos"], s["target"], s.get("fov", 70.0), s.get("up", Vector3.UP))
		await get_tree().process_frame
		await get_tree().process_frame
		await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var path: String = "%s/station_%s.png" % [out, s["name"]]
		img.save_png(path)
		print("saved ", path)
		if fig != null:
			fig.queue_free()


func _put_tower_in_tunnel() -> void:
	var svc: LineService = transit.services["tower"]
	svc.state = LineService.State.RUN
	svc.debug_place(330.0)
	await get_tree().process_frame


func _shot_list(h: Vector3) -> Array:
	return [
		{"name": "map_east_wall", "pos": h + Vector3(14.0, 1.7, 0.5), "target": h + Vector3(31.9, 6.8, 0.0), "fov": 50.0},
		{"name": "map_platform", "pos": h + Vector3(-18.0, -8 + 1.7, 5.5), "target": h + Vector3(-18.0, -8 + 1.9, 0.0), "fov": 60.0, "feet": h + Vector3(-15, -8, 3.5)},
		{"name": "concourse_map", "pos": h + Vector3(-12.0, 1.7, 2.0), "target": h + Vector3(31.0, 6.5, 0.0), "feet": h + Vector3(-5, 0, -2), "fov": 60.0},
		{"name": "bridge_sign", "pos": h + Vector3(28.0, 1.7, 0.0), "target": h + Vector3(8.5, 6.9, 0.0), "feet": h + Vector3(22, 0, -1.5), "fov": 62.0},
		{"name": "boards", "pos": h + Vector3(2.0, 1.7, 8.0), "target": h + Vector3(-4.0, 5.0, -14.5), "fov": 60.0},
		{"name": "tunnel_river", "pos": Vector3(922.7, -12.0 + 2.0, 640.0), "target": Vector3(922.7, -12.0 + 1.5, 600.0), "setup": "_put_tower_in_tunnel", "fov": 75.0},
		{"name": "train_waiting", "pos": h + Vector3(-8.0, -8 + 1.7, 3.0), "target": h + Vector3(-22, -8 + 1.5, 11.0), "feet": h + Vector3(-12, -8, 6.0), "fov": 75.0},
		{"name": "train_inside", "pos": h + Vector3(-10.0, -8 + 1.6, 11.45), "target": h + Vector3(-23, -8 + 1.4, 9.8), "fov": 75.0},
		{"name": "wellhead_east", "pos": h + Vector3(0.5, 1.7, 0.8), "target": h + Vector3(12, 1.0, 5.0), "feet": h + Vector3(4.5, 0, 1.2), "fov": 75.0},
		{"name": "well_down", "pos": h + Vector3(10.5, 5.0, 1.5), "target": h + Vector3(13, -4.0, 5.2), "fov": 70.0},
		{"name": "platform_east", "pos": h + Vector3(2.0, -8 + 1.7, 0.0), "target": h + Vector3(24, -8 + 1.2, 6.0), "feet": h + Vector3(6, -8, 3.0), "fov": 75.0},
		{"name": "platform_west", "pos": h + Vector3(-2.0, -8 + 1.7, 0.0), "target": h + Vector3(-24, -8 + 1.2, 6.0), "feet": h + Vector3(-6, -8, 3.0), "fov": 75.0},
		{"name": "west_court", "pos": h + Vector3(-100, 6, 30), "target": h + Vector3(-49, 5, 0), "fov": 60.0},
		{"name": "garden", "pos": h + Vector3(21, 1.7, -17), "target": h + Vector3(21, 1.5, -34), "feet": h + Vector3(22, 0, -22)},
		{"name": "arcade", "pos": h + Vector3(12, 1.7, 17), "target": h + Vector3(10, 2.5, 34), "feet": h + Vector3(12, 0, 22)},
		{"name": "waiting", "pos": h + Vector3(-21, 1.7, -17), "target": h + Vector3(-21, 1.5, -34), "feet": h + Vector3(-18, 0, -23)},
		{"name": "aerial", "pos": h + Vector3(120, 150, 150), "target": h + Vector3(40, 0, 0), "fov": 60.0},
		{"name": "facade", "pos": h + Vector3(215, 3.6 - 0.6, 0), "target": h + Vector3(49, 9, 0), "feet": h + Vector3(185, -0.6, 3), "fov": 45.0},
		{"name": "plaza_aerial", "pos": h + Vector3(190, 70, 70), "target": h + Vector3(90, 0, 0), "fov": 55.0},
		{"name": "plaza_entrance", "pos": h + Vector3(85, 1.7, 8), "target": h + Vector3(49, 6, 0), "feet": h + Vector3(75, 0, 2)},
		{"name": "corridor", "pos": h + Vector3(46, 1.7, 0), "target": h + Vector3(0, 6, 0), "feet": h + Vector3(40, 0, 1.5)},
	]
