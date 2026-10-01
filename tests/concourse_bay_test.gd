extends Node3D
## Five ConcourseBay copies in a row, a floor, and a sun shining in through the
## windows; then 3 camera positions saved as PNGs to tests/out/.
##   xvfb-run -a godot --rendering-driver vulkan --resolution 1600x900 res://tests/concourse_bay_test.tscn
## Env: BAYS=5 (count), OUT=res://tests/out, KEEP_OPEN=1 (don't quit after shots).

const BAY := preload("res://concourse/ConcourseBay.tscn")
const FLOOR_MARGIN := 40.0   # floor extends this far past the row (m)
const FLOOR_DEPTH := 60.0    # floor depth in front of the wall (m)
const EYE_HEIGHT := 1.7

var bays: Array[ConcourseBay] = []


func _ready() -> void:
	var count := int(OS.get_environment("BAYS")) if OS.get_environment("BAYS") != "" else 5
	for i in count:
		var bay: ConcourseBay = BAY.instantiate()
		add_child(bay)
		bays.append(bay)
	var step := bays[0].bay_width
	var row_len := step * count
	var x0 := -row_len * 0.5 + step * 0.5
	for i in count:
		bays[i].position.x = x0 + i * step
	bays[0].cap_left = true
	bays[count - 1].cap_right = true

	_add_floor(row_len)
	_add_light()
	_add_environment()
	await get_tree().process_frame
	await get_tree().process_frame
	await _take_shots(row_len)
	if OS.get_environment("KEEP_OPEN") == "":
		get_tree().quit()


func _add_floor(row_len: float) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(row_len + FLOOR_MARGIN * 2.0, 0.2, FLOOR_DEPTH + 20.0)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.32, 0.30, 0.28)
	mesh.material = mat
	mi.mesh = mesh
	mi.position = Vector3(0, -0.1, FLOOR_DEPTH * 0.5 - 10.0)
	add_child(mi)


func _add_light() -> void:
	# Sun sits outside (behind the wall, -Z) and shines into the hall (+Z), pitched down.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 200.0, 0.0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 150.0
	add_child(sun)
	# Weak fill from inside the hall so the wall's front face (away from the sun) reads in greybox.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 15.0, 0.0)
	fill.light_energy = 0.6
	add_child(fill)


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.70, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _take_shots(row_len: float) -> void:
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://tests/out"
	DirAccess.make_dir_recursive_absolute(out)
	var wall_h: float = bays[0].wall_height
	var step: float = bays[0].bay_width
	var cam := Camera3D.new()
	cam.fov = 60.0
	cam.far = 500.0
	add_child(cam)
	cam.current = true
	var shots := [
		# name, camera position, look-at target
		["head_on", Vector3(0, EYE_HEIGHT, 38.0), Vector3(0, wall_h * 0.45, 0)],
		["three_quarter", Vector3(row_len * 0.5 + 18.0, 3.0, 26.0), Vector3(0, wall_h * 0.4, 0)],
		["seam_closeup", Vector3(bays[2].position.x + step * 0.5 + 3.0, 2.0, 12.0), Vector3(bays[2].position.x + step * 0.5, 2.5, 0)],
		["low_looking_up", Vector3(2.0, 0.3, 9.0), Vector3(1.0, wall_h * 0.85, 0)],
	]
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = "%s/concourse_bay_%s.png" % [out, s[0]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
