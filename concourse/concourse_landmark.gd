@tool
class_name ConcourseLandmark
extends Node3D
## Freestanding information booth with a four-faced clock tower. Greybox:
## boxes, cylinders and flat discs. Origin = floor level, centred under the post.
##
## From the bottom: octagonal plinth -> counter (octagon, with a wider counter
## top) -> enclosed booth core with a roof -> slim post -> clock housing with a
## disc on each of its four faces -> pyramid cap. `tower_height` is the height
## of the cap's apex above the floor.

@export_range(4.0, 20.0, 0.1, "suffix:m") var tower_height := 8.0: set = _set_tower_height
@export_group("Booth")
@export_range(1.0, 6.0, 0.05, "suffix:m") var booth_radius := 2.5: set = _set_booth_radius
@export_range(0.5, 2.0, 0.05, "suffix:m") var counter_height := 1.1: set = _set_counter_height
@export_range(1.0, 5.0, 0.1, "suffix:m") var booth_height := 3.0: set = _set_booth_height
@export_group("Tower")
@export_range(0.05, 0.6, 0.01, "suffix:m") var post_radius := 0.15: set = _set_post_radius
## Side of the cube-shaped clock housing.
@export_range(0.8, 4.0, 0.05, "suffix:m") var clock_size := 1.8: set = _set_clock_size
@export_group("Colours")
@export var booth_color := Color(0.45, 0.38, 0.30): set = _set_booth_color
@export var counter_color := Color(0.62, 0.57, 0.50): set = _set_counter_color
@export var metal_color := Color(0.16, 0.16, 0.18): set = _set_metal_color
@export var housing_color := Color(0.50, 0.50, 0.52): set = _set_housing_color
@export var clock_face_color := Color(0.93, 0.90, 0.80): set = _set_clock_face_color
@export var hands_color := Color(0.08, 0.08, 0.10): set = _set_hands_color

const GENERATED := "Generated"
const OCTAGON := 8
const PLINTH_EXTRA := 0.3      # plinth sticks out past the booth (m)
const PLINTH_HEIGHT := 0.25
const COUNTER_OVERHANG := 0.2  # counter top sticks out past the counter body (m)
const COUNTER_TOP_THICKNESS := 0.12
const CORE_RATIO := 0.55       # booth core radius as a fraction of booth_radius
const ROOF_OVERHANG := 0.3
const ROOF_THICKNESS := 0.2
const CAP_HEIGHT_RATIO := 0.6  # cap height as a fraction of clock_size
const CAP_OVERHANG := 1.25     # cap base radius relative to the housing's half-diagonal
const FACE_RATIO := 0.4        # clock disc radius as a fraction of clock_size
const FACE_THICKNESS := 0.06
const HOUR_HAND_RATIO := 0.5   # hand lengths as a fraction of the disc radius
const MINUTE_HAND_RATIO := 0.78
const HAND_WIDTH_RATIO := 0.07
const TICK_LENGTH_RATIO := 0.14
const TICK_WIDTH_RATIO := 0.06
const HANDS_HOUR := 10.0
const HANDS_MINUTE := 10.0

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

	var cap_h := clock_size * CAP_HEIGHT_RATIO
	var housing_bottom := tower_height - cap_h - clock_size
	if housing_bottom <= booth_height + ROOF_THICKNESS:
		push_warning("ConcourseLandmark: tower_height is too low for the booth and clock; raise it.")
		housing_bottom = booth_height + ROOF_THICKNESS + 0.5

	# --- booth
	var r := booth_radius
	_cyl(root, "Plinth", r + PLINTH_EXTRA, PLINTH_HEIGHT, 0.0, booth_color, OCTAGON)
	_cyl(root, "Counter", r, counter_height, 0.0, booth_color, OCTAGON)
	_cyl(root, "CounterTop", r + COUNTER_OVERHANG, COUNTER_TOP_THICKNESS, counter_height, counter_color, OCTAGON)
	var core_r := r * CORE_RATIO
	var core_top := booth_height
	_cyl(root, "Core", core_r, core_top - counter_height, counter_height, housing_color, OCTAGON)
	_cyl(root, "Roof", core_r + ROOF_OVERHANG, ROOF_THICKNESS, core_top, counter_color, OCTAGON)

	# --- post
	var post_bottom := core_top + ROOF_THICKNESS
	_cyl(root, "Post", post_radius, housing_bottom - post_bottom, post_bottom, metal_color, 16)

	# --- clock
	var clock := Node3D.new()
	clock.name = "Clock"
	clock.position.y = housing_bottom
	root.add_child(clock)
	var hs := clock_size
	_box(clock, "Housing", Vector3(hs, hs, hs), Vector3(0, hs * 0.5, 0), housing_color)
	for k in 4:
		_build_face(clock, k, hs)
	var cap := _cyl(clock, "Cap", hs * 0.5 * sqrt(2.0) * CAP_OVERHANG, cap_h, hs, housing_color, 4, 0.0)
	cap.rotation.y = PI * 0.25  # a 4-sided cylinder has corners on the axes; turn it to match the box


func _build_face(clock: Node3D, k: int, hs: float) -> void:
	var face := Node3D.new()
	face.name = "Face%d" % k
	face.rotation.y = k * PI * 0.5
	face.position.y = hs * 0.5
	clock.add_child(face)
	var radius := hs * FACE_RATIO
	var z := hs * 0.5  # housing surface
	var disc := MeshInstance3D.new()
	disc.name = "Disc"
	var dm := CylinderMesh.new()
	dm.top_radius = radius
	dm.bottom_radius = radius
	dm.height = FACE_THICKNESS
	dm.radial_segments = 48
	dm.material = _mat(clock_face_color)
	disc.mesh = dm
	disc.rotation.x = PI * 0.5  # cylinder axis Y -> Z, so the disc faces outward
	disc.position.z = z + FACE_THICKNESS * 0.5
	face.add_child(disc)
	# hour ticks at 12 / 3 / 6 / 9
	for q in 4:
		var pivot := Node3D.new()
		pivot.rotation.z = -q * PI * 0.5
		pivot.position.z = z + FACE_THICKNESS + 0.005
		face.add_child(pivot)
		var tick_len := radius * TICK_LENGTH_RATIO
		_box(pivot, "Tick%d" % q, Vector3(radius * TICK_WIDTH_RATIO, tick_len, 0.01), Vector3(0, radius - tick_len * 0.5 - radius * 0.06, 0), hands_color)
	# hands (pivot at the disc centre; positive rotation.z is counter-clockwise seen from the front)
	var minute_angle := -TAU * HANDS_MINUTE / 60.0
	var hour_angle := -TAU * (fmod(HANDS_HOUR, 12.0) + HANDS_MINUTE / 60.0) / 12.0
	_hand(face, "HourHand", radius * HOUR_HAND_RATIO, radius * HAND_WIDTH_RATIO * 1.4, hour_angle, z + FACE_THICKNESS + 0.015)
	_hand(face, "MinuteHand", radius * MINUTE_HAND_RATIO, radius * HAND_WIDTH_RATIO, minute_angle, z + FACE_THICKNESS + 0.03)


func _hand(face: Node3D, hand_name: String, length: float, width: float, angle: float, z: float) -> void:
	var pivot := Node3D.new()
	pivot.name = hand_name
	pivot.rotation.z = angle
	pivot.position.z = z
	face.add_child(pivot)
	_box(pivot, "Blade", Vector3(width, length, 0.02), Vector3(0, length * 0.5, 0), hands_color)


# ---------------------------------------------------------------- primitives

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, c: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := BoxMesh.new()
	m.size = size
	m.material = _mat(c)
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## Upright cylinder standing on y = base_y. `sides` 8 gives an octagon.
func _cyl(parent: Node3D, node_name: String, radius: float, height: float, base_y: float, c: Color,
		sides: int, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	m.material = _mat(c)
	mi.mesh = m
	mi.position.y = base_y + height * 0.5
	parent.add_child(mi)
	return mi


# ---------------------------------------------------------------------- setters

func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func _set_tower_height(v: float) -> void: tower_height = v; _queue_rebuild()
func _set_booth_radius(v: float) -> void: booth_radius = v; _queue_rebuild()
func _set_counter_height(v: float) -> void: counter_height = v; _queue_rebuild()
func _set_booth_height(v: float) -> void: booth_height = v; _queue_rebuild()
func _set_post_radius(v: float) -> void: post_radius = v; _queue_rebuild()
func _set_clock_size(v: float) -> void: clock_size = v; _queue_rebuild()
func _set_booth_color(v: Color) -> void: booth_color = v; _queue_rebuild()
func _set_counter_color(v: Color) -> void: counter_color = v; _queue_rebuild()
func _set_metal_color(v: Color) -> void: metal_color = v; _queue_rebuild()
func _set_housing_color(v: Color) -> void: housing_color = v; _queue_rebuild()
func _set_clock_face_color(v: Color) -> void: clock_face_color = v; _queue_rebuild()
func _set_hands_color(v: Color) -> void: hands_color = v; _queue_rebuild()
