extends Node3D
## Greybox checks for the concourse kit. Renders two stages to tests/out/*.png:
##   1. a row of 5 ConcourseBay copies (concourse_bay_*.png)
##   2. the full ConcourseHall                (concourse_hall_*.png)
## Both get a floor/ground, a sun that shines in through the windows, and sky.
##   xvfb-run -a godot --rendering-driver vulkan --resolution 1600x900 res://tests/concourse_bay_test.tscn
## Env: STAGE=bay|hall (default both), OUT=res://tests/out, BAYS=5, KEEP_OPEN=1.

const BAY := preload("res://concourse/ConcourseBay.tscn")
const HALL := preload("res://concourse/ConcourseHall.tscn")
const FLOOR_MARGIN := 40.0   # bay-row floor extends this far past the row (m)
const FLOOR_DEPTH := 60.0    # bay-row floor depth in front of the wall (m)
const EYE_HEIGHT := 1.7
const GROUND_SIZE := 600.0   # outside ground under the hall (m)

var cam: Camera3D


func _ready() -> void:
	var stage := OS.get_environment("STAGE")
	_add_light()
	_add_environment()
	cam = Camera3D.new()
	cam.far = 800.0
	add_child(cam)
	cam.current = true
	if stage == "" or stage == "bay":
		var row := _build_bay_row()
		await _settle()
		await _take_shots("concourse_bay", _bay_shots(row), 60.0)
		row.queue_free()
	if stage == "" or stage == "hall":
		var hall := _build_hall()
		await _settle()
		await _take_shots("concourse_hall", _hall_shots(hall), 75.0)
	if OS.get_environment("KEEP_OPEN") == "":
		get_tree().quit()


func _settle() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


# ------------------------------------------------------------------- stage 1

func _build_bay_row() -> Node3D:
	var count := int(OS.get_environment("BAYS")) if OS.get_environment("BAYS") != "" else 5
	var row := Node3D.new()
	add_child(row)
	var bays: Array[ConcourseBay] = []
	for i in count:
		var bay: ConcourseBay = BAY.instantiate()
		row.add_child(bay)
		bays.append(bay)
	var step := bays[0].bay_width
	var row_len := step * count
	for i in count:
		bays[i].position.x = -row_len * 0.5 + step * 0.5 + i * step
	bays[0].cap_left = true
	bays[count - 1].cap_right = true
	row.set_meta("bays", bays)
	row.set_meta("row_len", row_len)
	_add_ground(row, row_len + FLOOR_MARGIN * 2.0, FLOOR_DEPTH + 20.0, Vector3(0, -0.1, FLOOR_DEPTH * 0.5 - 10.0), Color(0.32, 0.30, 0.28))
	return row


func _bay_shots(row: Node3D) -> Array:
	var bays: Array = row.get_meta("bays")
	var row_len: float = row.get_meta("row_len")
	var wall_h: float = bays[0].wall_height
	var step: float = bays[0].bay_width
	return [
		["head_on", Vector3(0, EYE_HEIGHT, 38.0), Vector3(0, wall_h * 0.45, 0)],
		["three_quarter", Vector3(row_len * 0.5 + 18.0, 3.0, 26.0), Vector3(0, wall_h * 0.4, 0)],
		["seam_closeup", Vector3(bays[2].position.x + step * 0.5 + 3.0, 2.0, 12.0), Vector3(bays[2].position.x + step * 0.5, 2.5, 0)],
		["low_looking_up", Vector3(2.0, 0.3, 9.0), Vector3(1.0, wall_h * 0.85, 0)],
	]


# ------------------------------------------------------------------- stage 2

func _build_hall() -> ConcourseHall:
	var hall: ConcourseHall = HALL.instantiate()
	add_child(hall)
	_add_ground(self, GROUND_SIZE, GROUND_SIZE, Vector3(0, -0.6, 0), Color(0.25, 0.27, 0.22))
	return hall


func _hall_shots(hall: ConcourseHall) -> Array:
	var bay: ConcourseBay = hall.get_node("Generated/WallNegZ/Bay0")
	var length: float = hall.hall_bays * bay.bay_width
	var wall_h: float = bay.wall_height
	var half: float = length * 0.5
	return [
		# standing just inside one entrance, looking down the hall
		["entrance_down_hall", Vector3(-half + 2.0, EYE_HEIGHT, 0), Vector3(half, wall_h * 0.4, 0)],
		# mid-hall, looking up at the vault
		["mid_hall_vault", Vector3(0, EYE_HEIGHT, 0), Vector3(length * 0.2, wall_h + hall.vault_rise * 0.8, 0)],
		# from the far end (outside the opposite entrance, looking back)
		["far_end", Vector3(half - 2.0, EYE_HEIGHT, 0), Vector3(-half, wall_h * 0.4, 0)],
	]


# -------------------------------------------------------------------- shared

func _add_ground(parent: Node, size_x: float, size_z: float, pos: Vector3, color: Color) -> void:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size_x, 0.2, size_z)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mesh.material = mat
	mi.mesh = mesh
	mi.position = pos
	parent.add_child(mi)


func _add_light() -> void:
	# Sun sits outside (behind the -Z wall) and shines into the hall (+Z), pitched down.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 200.0, 0.0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	add_child(sun)
	# Weak shadowless fill so the greybox reads where the sun doesn't reach.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 15.0, 0.0)
	fill.light_energy = 0.3
	add_child(fill)


func _add_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.70, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)


func _take_shots(prefix: String, shots: Array, fov: float) -> void:
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://tests/out"
	DirAccess.make_dir_recursive_absolute(out)
	cam.fov = fov
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2], Vector3.UP)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = "%s/%s_%s.png" % [out, prefix, s[0]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
