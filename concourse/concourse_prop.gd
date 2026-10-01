@tool
class_name ConcourseProp
extends Node3D
## Small dressing props for the undercroft, greybox, sized for the PlayerScale reference player.
## `kind` is "bench", "planter" or "lamp". Origin = floor level, centred; +Z is the front.

@export_enum("bench", "planter", "lamp") var kind := "bench": set = _set_kind
## Lamp only: the warm OmniLight3D's energy and reach.
@export_range(0.0, 8.0, 0.05) var lamp_light_energy := 1.4: set = _set_lamp_light_energy
@export_range(1.0, 20.0, 0.5, "suffix:m") var lamp_light_range := 9.0: set = _set_lamp_light_range

const GENERATED := "Generated"
# bench
const BENCH_LENGTH := 2.0
const BENCH_DEPTH := 0.5
const BENCH_SEAT_HEIGHT := 0.45        # knee height of the 1.8 m player
const BENCH_SEAT_THICKNESS := 0.07
const BENCH_BACK_HEIGHT := 0.45        # backrest above the seat
const BENCH_LEG := 0.08
# planter
const PLANTER_SIZE := 1.3
const PLANTER_HEIGHT := 0.75
const PLANTER_WALL := 0.1
const BUSH_RADIUS := 0.62
# lamp
const LAMP_HEIGHT := 3.2
const LAMP_POST_RADIUS := 0.06
const LAMP_BASE_RADIUS := 0.22
const LAMP_BASE_HEIGHT := 0.35
const LAMP_GLOBE_RADIUS := 0.26
const LAMP_GLOW := 3.0

## Adds a StaticBody3D so the player cannot walk through the prop.
var build_collision := false
var _rebuild_queued := false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var old := get_node_or_null(GENERATED)
	if old != null:
		remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = GENERATED
	add_child(root)
	match kind:
		"bench": _build_bench(root)
		"planter": _build_planter(root)
		"lamp": _build_lamp(root)
	if build_collision:
		var body := StaticBody3D.new()
		body.name = "Body"
		root.add_child(body)
		match kind:
			"bench": _shape(body, Vector3(0, BENCH_SEAT_HEIGHT * 0.5 + BENCH_BACK_HEIGHT * 0.5, 0), Vector3(BENCH_LENGTH, BENCH_SEAT_HEIGHT + BENCH_BACK_HEIGHT, BENCH_DEPTH))
			"planter": _shape(body, Vector3(0, PLANTER_HEIGHT * 0.5, 0), Vector3(PLANTER_SIZE, PLANTER_HEIGHT, PLANTER_SIZE))
			"lamp": _shape(body, Vector3(0, LAMP_HEIGHT * 0.5, 0), Vector3(LAMP_BASE_RADIUS * 2.0, LAMP_HEIGHT, LAMP_BASE_RADIUS * 2.0))


func _build_bench(root: Node3D) -> void:
	var wood := _mat(Color(0.42, 0.28, 0.17))
	var iron := _mat(Color(0.15, 0.15, 0.17))
	_box(root, Vector3(BENCH_LENGTH, BENCH_SEAT_THICKNESS, BENCH_DEPTH), Vector3(0, BENCH_SEAT_HEIGHT - BENCH_SEAT_THICKNESS * 0.5, 0), wood)
	# backrest on the rear edge, a little reclined: kept as a plain slab
	_box(root, Vector3(BENCH_LENGTH, BENCH_BACK_HEIGHT, BENCH_SEAT_THICKNESS), Vector3(0, BENCH_SEAT_HEIGHT + BENCH_BACK_HEIGHT * 0.5, -BENCH_DEPTH * 0.5 + BENCH_SEAT_THICKNESS * 0.5), wood)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			_box(root, Vector3(BENCH_LEG, BENCH_SEAT_HEIGHT - BENCH_SEAT_THICKNESS, BENCH_LEG),
				Vector3(sx * (BENCH_LENGTH * 0.5 - BENCH_LEG), (BENCH_SEAT_HEIGHT - BENCH_SEAT_THICKNESS) * 0.5, sz * (BENCH_DEPTH * 0.5 - BENCH_LEG)), iron)


func _build_planter(root: Node3D) -> void:
	var stone := _mat(Color(0.62, 0.56, 0.48))
	var soil := _mat(Color(0.22, 0.15, 0.10))
	var leaves := _mat(Color(0.16, 0.42, 0.18))
	_box(root, Vector3(PLANTER_SIZE, PLANTER_HEIGHT, PLANTER_SIZE), Vector3(0, PLANTER_HEIGHT * 0.5, 0), stone)
	# soil a hair below the rim, so the rim reads as a lip
	_box(root, Vector3(PLANTER_SIZE - PLANTER_WALL * 2.0, 0.02, PLANTER_SIZE - PLANTER_WALL * 2.0), Vector3(0, PLANTER_HEIGHT + 0.005, 0), soil)
	var bush := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = BUSH_RADIUS
	sphere.height = BUSH_RADIUS * 2.0
	sphere.material = leaves
	bush.mesh = sphere
	bush.position.y = PLANTER_HEIGHT + BUSH_RADIUS * 0.8
	root.add_child(bush)


func _build_lamp(root: Node3D) -> void:
	var iron := _mat(Color(0.14, 0.14, 0.16))
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = LAMP_POST_RADIUS * 2.0
	base_mesh.bottom_radius = LAMP_BASE_RADIUS
	base_mesh.height = LAMP_BASE_HEIGHT
	base_mesh.material = iron
	base.mesh = base_mesh
	base.position.y = LAMP_BASE_HEIGHT * 0.5
	root.add_child(base)
	var post := MeshInstance3D.new()
	var post_mesh := CylinderMesh.new()
	post_mesh.top_radius = LAMP_POST_RADIUS
	post_mesh.bottom_radius = LAMP_POST_RADIUS
	post_mesh.height = LAMP_HEIGHT - LAMP_GLOBE_RADIUS
	post_mesh.material = iron
	post.mesh = post_mesh
	post.position.y = (LAMP_HEIGHT - LAMP_GLOBE_RADIUS) * 0.5
	root.add_child(post)
	var globe_mat := StandardMaterial3D.new()
	globe_mat.albedo_color = Color(1.0, 0.88, 0.62)
	globe_mat.emission_enabled = true
	globe_mat.emission = Color(1.0, 0.82, 0.5)
	globe_mat.emission_energy_multiplier = LAMP_GLOW
	var globe := MeshInstance3D.new()
	var globe_mesh := SphereMesh.new()
	globe_mesh.radius = LAMP_GLOBE_RADIUS
	globe_mesh.height = LAMP_GLOBE_RADIUS * 2.0
	globe_mesh.material = globe_mat
	globe.mesh = globe_mesh
	globe.position.y = LAMP_HEIGHT - LAMP_GLOBE_RADIUS
	root.add_child(globe)
	var light := OmniLight3D.new()
	light.name = "Light"
	light.position.y = LAMP_HEIGHT - LAMP_GLOBE_RADIUS
	light.light_color = Color(1.0, 0.82, 0.55)
	light.light_energy = lamp_light_energy
	light.omni_range = lamp_light_range
	light.shadow_enabled = false
	root.add_child(light)


func _shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	body.add_child(cs)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func _set_kind(v: String) -> void: kind = v; _queue_rebuild()
func _set_lamp_light_energy(v: float) -> void: lamp_light_energy = v; _queue_rebuild()
func _set_lamp_light_range(v: float) -> void: lamp_light_range = v; _queue_rebuild()
