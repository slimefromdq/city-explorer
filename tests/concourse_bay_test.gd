extends Node3D
## Greybox checks for the concourse kit. Renders two stages to tests/out/*.png:
##   1. a row of 5 ConcourseBay copies (concourse_bay_*.png)
##   2. the full ConcourseHall                (concourse_hall_*.png)
## Both get a floor/ground, a sun that shines in through the windows, and sky.
##   xvfb-run -a godot --rendering-driver vulkan --resolution 1600x900 res://tests/concourse_bay_test.tscn
## Env: STAGE=bay|hall (default both), OUT=res://tests/out, BAYS=5, KEEP_OPEN=1,
##      HALL_PROPS="name=number,..." sets numeric hall exports.

const BAY := preload("res://concourse/ConcourseBay.tscn")
const HALL := preload("res://concourse/ConcourseHall.tscn")
const FLOOR_MARGIN := 40.0   # bay-row floor extends this far past the row (m)
const FLOOR_DEPTH := 60.0    # bay-row floor depth in front of the wall (m)
const EYE_HEIGHT := 1.7
const GROUND_SIZE := 600.0   # outside ground under the hall (m)

var cam: Camera3D


func _ready() -> void:
	var stage := OS.get_environment("STAGE")
	cam = Camera3D.new()
	cam.far = 800.0
	add_child(cam)
	cam.current = true
	if stage == "" or stage == "bay":
		var rig := Node3D.new()  # the bay row has no lighting of its own; the hall does
		add_child(rig)
		_add_light(rig)
		_add_environment(rig)
		var row := _build_bay_row()
		await _settle()
		await _take_shots("concourse_bay", _bay_shots(row), 60.0)
		row.queue_free()
		rig.queue_free()
	if stage == "" or stage == "hall":
		var hall := _build_hall()
		await _settle()
		await _take_shots("concourse_hall", _hall_shots(hall), 75.0, _headroom_figure(hall))
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
	# Tuning without editing files: HALL_PROPS="sun_energy=0.4,ambient_energy=0.5"
	for kv in OS.get_environment("HALL_PROPS").split(",", false):
		var parts := kv.split("=")
		if parts.size() == 2:
			hall.set(parts[0], float(parts[1]))
	add_child(hall)
	_add_ground(self, GROUND_SIZE, GROUND_SIZE, Vector3(0, -0.6, 0), Color(0.25, 0.27, 0.22))
	return hall


func _hall_shots(hall: ConcourseHall) -> Array:
	var bay: ConcourseBay = hall.get_node("Generated/WallNegZ/Bay0")
	var length: float = hall.hall_bays * bay.bay_width
	var wall_h: float = bay.wall_height
	var half: float = length * 0.5
	var half_w: float = hall.hall_width * 0.5
	var deck_y: float = hall.mezzanine_height
	var clock_y: float = hall.landmark_height - 3.0  # about the clock faces' height
	var bridge_x: float = -hall.bridge_distance
	# stair foot: the landing edge is `depth` in from the end wall; the flight runs back from there
	var steps: int = ceili(deck_y / hall.step_height)
	var foot_x: float = half - hall.mezzanine_depth - (steps - 1) * hall.step_depth
	var stair_z: float = hall.entrance_width * 0.5 + 1.0 + hall.stair_width * 0.5
	return [
		# 1. at the near entrance, looking down the hall
		["entrance_down_hall", Vector3(-half + 2.0, EYE_HEIGHT, 0), Vector3(half, wall_h * 0.4, 0)],
		# 2. the whole hall from above (long axis horizontal)
		["top_down", Vector3(0, wall_h + 3.0, 0), Vector3(0, 0, 0), Vector3(0, 0, -1), 90.0],
		# 3. on the -Z balcony, looking across at the clock
		["mezzanine_to_clock", Vector3(-4.0, deck_y + EYE_HEIGHT, -half_w + 0.8), Vector3(0, clock_y, 0)],
		# 4. on the +Z balcony, looking down at the floor and booth
		["mezzanine_down_to_floor", Vector3(5.0, deck_y + EYE_HEIGHT, half_w - 0.8), Vector3(0, 0, -2.0)],
		# 5. from the floor, looking up at a bridge and the vault above it
		["floor_up_to_bridge", Vector3(bridge_x - 6.0, EYE_HEIGHT, -4.0), Vector3(bridge_x, deck_y + 9.0, 2.0)],
		# 6. at the foot of a grand staircase (+X end, +Z flight), looking up it
		["stair_foot_looking_up", Vector3(foot_x - 2.0, EYE_HEIGHT, stair_z), Vector3(half - hall.mezzanine_depth, deck_y + 2.5, stair_z)],
		# extra: headroom where a flight passes under a bridge, with a standing and a jumping 1.8 m figure at the tightest point
		["stair_headroom_check", Vector3(-bridge_x - 0.5, EYE_HEIGHT, 0.0), Vector3(-bridge_x + 1.5, 5.5, stair_z), Vector3.UP, 75.0, true],
		# extra: the far wall's round window. From the entrance the near bridge hides it, so look from between the bridges, off-axis so the clock is not in the way.
		["far_wall_window", Vector3(-6.0, EYE_HEIGHT, -7.0), Vector3(half, hall.rose_height - 4.0, 0)],
		# extras kept from earlier passes: the clock up close, and the view back from the far end
		["landmark_clock", Vector3(-8.0, EYE_HEIGHT, 6.0), Vector3(0, clock_y, 0)],
		["far_end_looking_back", Vector3(half - 2.0, EYE_HEIGHT, 0), Vector3(-half, wall_h * 0.4, 0)],
	]


## Two 1.8 m capsules on the tightest tread under a bridge (the flight's outer edge, at the bridge's
## landing-side edge): one standing, one at the top of a 1.2 m jump. Only shown for the headroom shot.
func _headroom_figure(hall: ConcourseHall) -> Node3D:
	var bay: ConcourseBay = hall.get_node("Generated/WallNegZ/Bay0")
	var half: float = hall.hall_bays * bay.bay_width * 0.5
	var steps: int = maxi(2, ceili(hall.mezzanine_height / hall.step_height))
	var riser: float = hall.mezzanine_height / steps
	var x: float = hall.bridge_distance + hall.bridge_width * 0.5
	var run_from_landing: float = (half - hall.mezzanine_depth) - x
	var tread_top: float = hall.mezzanine_height - (floorf(run_from_landing / hall.step_depth) + 1.0) * riser
	var inner_z: float = hall.hall_width * 0.5 - hall.mezzanine_depth
	var za: float = hall.entrance_width * 0.5 + 1.0
	var outer_z: float = minf(za + hall.stair_width, inner_z)
	var u: float = outer_z / inner_z
	var underside: float = hall.mezzanine_height + hall.bridge_arch_rise * (1.0 - u * u) - hall.mezzanine_thickness - 0.6
	var root := Node3D.new()
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.2, 0.15)
	for lift in [0.0, 1.2]:
		var person := MeshInstance3D.new()
		var mesh := CapsuleMesh.new()
		mesh.height = 1.8
		mesh.radius = 0.25
		mesh.material = mat
		person.mesh = mesh
		person.position = Vector3(x, tread_top + 0.9 + lift, outer_z - 0.5)
		root.add_child(person)
	hall.add_child(root)
	root.visible = false
	print("headroom check: tread top %.2f m, bridge underside over the flight's outer edge %.2f m, clearance %.2f m (standing 1.8 m, jumping 3.0 m)" % [tread_top, underside, underside - tread_top])
	return root


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


func _add_light(parent: Node) -> void:
	# Sun sits outside (behind the -Z wall) and shines into the hall (+Z), pitched down.
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35.0, 200.0, 0.0)
	sun.light_energy = 2.2
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	parent.add_child(sun)
	# Weak shadowless fill so the greybox reads where the sun doesn't reach.
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-20.0, 15.0, 0.0)
	fill.light_energy = 0.3
	parent.add_child(fill)


func _add_environment(parent: Node) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.70, 0.90)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	parent.add_child(we)


func _take_shots(prefix: String, shots: Array, fov: float, figure: Node3D = null) -> void:
	var out := OS.get_environment("OUT") if OS.get_environment("OUT") != "" else "res://tests/out"
	DirAccess.make_dir_recursive_absolute(out)
	for s in shots:
		if figure != null:
			figure.visible = s.size() > 5 and s[5]
		cam.fov = s[4] if s.size() > 4 else fov
		cam.position = s[1]
		cam.look_at(s[2], s[3] if s.size() > 3 else Vector3.UP)
		await RenderingServer.frame_post_draw
		await get_tree().process_frame
		await RenderingServer.frame_post_draw
		var img := get_viewport().get_texture().get_image()
		var path: String = "%s/%s_%s.png" % [out, prefix, s[0]]
		img.save_png(path)
		print("saved ", path, " ", img.get_size())
