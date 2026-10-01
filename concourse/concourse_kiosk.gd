@tool
class_name ConcourseKiosk
extends Node3D
## An information / ticket kiosk, greybox, sized for the PlayerScale reference player.
## Origin = floor level on the wall's front face, centred on the kiosk; +Z points into the hall.
##
## From the wall outward: a service room (box), a counter in front of it (counter top at
## waist height), and above it a departures-style board hung from the wall on two brackets.
## The board's lowest edge is well above head height so it reads from across the hall.

@export_range(1.5, 8.0, 0.1, "suffix:m") var width := 4.0: set = _set_width
@export_group("Counter")
@export_range(0.6, 1.4, 0.01, "suffix:m") var counter_height := PlayerScale.WAIST_HEIGHT: set = _set_counter_height
@export_range(0.4, 1.5, 0.05, "suffix:m") var counter_depth := 0.8: set = _set_counter_depth
@export_group("Service room")
@export_range(2.0, 4.0, 0.05, "suffix:m") var room_height := 2.6: set = _set_room_height
@export_range(0.4, 2.0, 0.05, "suffix:m") var room_depth := 0.9: set = _set_room_depth
@export_group("Board")
## Lowest edge of the board above the floor. At least 1.5x the player's height is comfortable.
@export_range(2.0, 6.0, 0.05, "suffix:m") var board_bottom := 3.0: set = _set_board_bottom
@export_range(1.0, 8.0, 0.1, "suffix:m") var board_width := 5.0: set = _set_board_width
@export_range(0.5, 3.0, 0.1, "suffix:m") var board_height := 2.0: set = _set_board_height
@export_group("Colours")
@export var body_color := Color(0.42, 0.36, 0.30): set = _set_body_color
@export var top_color := Color(0.68, 0.62, 0.54): set = _set_top_color
@export var board_color := Color(0.04, 0.05, 0.07): set = _set_board_color
@export var text_color := Color(1.0, 0.70, 0.18): set = _set_text_color
@export_range(0.0, 8.0, 0.1) var text_glow := 2.5: set = _set_text_glow

const GENERATED := "Generated"
const TOP_OVERHANG := 0.12       # counter top sticks out past the counter body (m)
const TOP_THICKNESS := 0.06
const ROOF_THICKNESS := 0.15
const ROOF_OVERHANG := 0.15
const BOARD_THICKNESS := 0.12
const BOARD_OFFSET := 0.45       # board's back is this far from the wall: clear of the room's roof, between the piers
const BRACKET_SIZE := 0.1
const TEXT_ROWS := 6
const TEXT_MARGIN := 0.1         # fraction of the board's width/height left blank around the text
const TEXT_BAR_HEIGHT_RATIO := 0.42  # bar height as a fraction of the row pitch
const TIME_BAR_RATIO := 0.16     # the short "time" bar, as a fraction of board width
const DEST_BAR_RATIOS := [0.55, 0.38, 0.62, 0.46, 0.34, 0.5]  # the long "destination" bars (fraction of board width)
const TEXT_SURFACE := 0.005      # text bars sit this far in front of the board face

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

	# service room against the wall, with a roof overhang
	_box(root, "Room", Vector3(width, room_height, room_depth), Vector3(0, room_height * 0.5, room_depth * 0.5), _solid(body_color))
	_box(root, "Roof", Vector3(width + ROOF_OVERHANG * 2.0, ROOF_THICKNESS, room_depth + counter_depth + ROOF_OVERHANG),
		Vector3(0, room_height + ROOF_THICKNESS * 0.5, (room_depth + counter_depth + ROOF_OVERHANG) * 0.5), _solid(body_color.darkened(0.15)))
	# counter in front of the room
	var body_h := counter_height - TOP_THICKNESS
	_box(root, "Counter", Vector3(width, body_h, counter_depth), Vector3(0, body_h * 0.5, room_depth + counter_depth * 0.5), _solid(body_color))
	_box(root, "CounterTop", Vector3(width + TOP_OVERHANG, TOP_THICKNESS, counter_depth + TOP_OVERHANG),
		Vector3(0, counter_height - TOP_THICKNESS * 0.5, room_depth + (counter_depth + TOP_OVERHANG) * 0.5), _solid(top_color))

	_build_board(root)


func _build_board(root: Node3D) -> void:
	var cy := board_bottom + board_height * 0.5
	var front := BOARD_OFFSET + BOARD_THICKNESS  # z of the board's front face
	var board := _box(root, "Board", Vector3(board_width, board_height, BOARD_THICKNESS), Vector3(0, cy, BOARD_OFFSET + BOARD_THICKNESS * 0.5), _solid(board_color))
	board.name = "Board"
	# two brackets from the wall to the board's top corners
	for sx in [-1, 1]:
		_box(root, "Bracket", Vector3(BRACKET_SIZE, BRACKET_SIZE, BOARD_OFFSET),
			Vector3(sx * (board_width * 0.5 - BRACKET_SIZE * 2.0), board_bottom + board_height - BRACKET_SIZE, BOARD_OFFSET * 0.5), _solid(body_color.darkened(0.3)))
	# glowing "text": one long bar (destination) and one short bar (time) per row
	var glow := StandardMaterial3D.new()
	glow.albedo_color = text_color
	glow.emission_enabled = true
	glow.emission = text_color
	glow.emission_energy_multiplier = text_glow
	var inner_w := board_width * (1.0 - TEXT_MARGIN * 2.0)
	var inner_h := board_height * (1.0 - TEXT_MARGIN * 2.0)
	var pitch := inner_h / TEXT_ROWS
	var left := -inner_w * 0.5
	for r in TEXT_ROWS:
		var y := board_bottom + board_height * (1.0 - TEXT_MARGIN) - (r + 0.5) * pitch
		var dest_w: float = board_width * DEST_BAR_RATIOS[r % DEST_BAR_RATIOS.size()]
		var time_w := board_width * TIME_BAR_RATIO
		var bar_h := pitch * TEXT_BAR_HEIGHT_RATIO
		_box(root, "Dest%d" % r, Vector3(dest_w, bar_h, TEXT_SURFACE * 2.0), Vector3(left + dest_w * 0.5, y, front + TEXT_SURFACE), glow)
		_box(root, "Time%d" % r, Vector3(time_w, bar_h, TEXT_SURFACE * 2.0), Vector3(inner_w * 0.5 - time_w * 0.5, y, front + TEXT_SURFACE), glow)


func _solid(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.name = node_name
	var m := BoxMesh.new()
	m.size = size
	m.material = mat
	mi.mesh = m
	mi.position = pos
	parent.add_child(mi)
	return mi


func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func _set_width(v: float) -> void: width = v; _queue_rebuild()
func _set_counter_height(v: float) -> void: counter_height = v; _queue_rebuild()
func _set_counter_depth(v: float) -> void: counter_depth = v; _queue_rebuild()
func _set_room_height(v: float) -> void: room_height = v; _queue_rebuild()
func _set_room_depth(v: float) -> void: room_depth = v; _queue_rebuild()
func _set_board_bottom(v: float) -> void: board_bottom = v; _queue_rebuild()
func _set_board_width(v: float) -> void: board_width = v; _queue_rebuild()
func _set_board_height(v: float) -> void: board_height = v; _queue_rebuild()
func _set_body_color(v: Color) -> void: body_color = v; _queue_rebuild()
func _set_top_color(v: Color) -> void: top_color = v; _queue_rebuild()
func _set_board_color(v: Color) -> void: board_color = v; _queue_rebuild()
func _set_text_color(v: Color) -> void: text_color = v; _queue_rebuild()
func _set_text_glow(v: float) -> void: text_glow = v; _queue_rebuild()
