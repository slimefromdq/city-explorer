@tool
class_name ConcourseKiosk
extends Node3D
## An information / ticket kiosk, greybox, sized for the PlayerScale reference player.
## Origin = floor level on the wall's front face, centred on the kiosk; +Z points into the hall.
##
## From the wall outward: a service room (box) and the counter in front of it (counter top at
## waist height). High above it, a wide DEPARTURES / ARRIVALS board hangs from the faces of the two
## piers either side of the bay: a coloured header strip with a large label block, then rows of
## glowing text. A warm OmniLight3D in front of the board and a faintly emissive wall panel behind it
## make it glow. The board's lowest edge is far above head height so it reads from across the hall.

@export_range(1.5, 8.0, 0.1, "suffix:m") var width := 4.0: set = _set_width
@export_group("Counter")
@export_range(0.6, 1.4, 0.01, "suffix:m") var counter_height := PlayerScale.WAIST_HEIGHT: set = _set_counter_height
@export_range(0.4, 1.5, 0.05, "suffix:m") var counter_depth := 0.8: set = _set_counter_depth
@export_group("Service room")
@export_range(2.0, 4.0, 0.05, "suffix:m") var room_height := 2.6: set = _set_room_height
@export_range(0.4, 2.0, 0.05, "suffix:m") var room_depth := 0.9: set = _set_room_depth
@export_group("Board")
## Which board this is: "DEPARTURES" (amber) or "ARRIVALS" (green).
@export_enum("DEPARTURES", "ARRIVALS") var board_kind := "DEPARTURES": set = _set_board_kind
## Lowest edge of the board above the floor.
@export_range(2.0, 6.0, 0.05, "suffix:m") var board_bottom := 3.7: set = _set_board_bottom
@export_range(1.0, 20.0, 0.1, "suffix:m") var board_width := 12.0: set = _set_board_width
@export_range(0.8, 4.0, 0.1, "suffix:m") var board_height := 2.4: set = _set_board_height
@export_range(0.2, 1.5, 0.05, "suffix:m") var header_height := 0.7: set = _set_header_height
@export_group("Board light")
## Energy of the warm OmniLight3D in front of the board (0 = none).
@export_range(0.0, 8.0, 0.05) var board_light_energy := 1.2: set = _set_board_light_energy
@export_range(1.0, 30.0, 0.5, "suffix:m") var board_light_range := 11.0: set = _set_board_light_range
## How much the wall panel behind the board glows (0 = none).
@export_range(0.0, 3.0, 0.05) var panel_glow := 0.35: set = _set_panel_glow
@export_range(0.0, 8.0, 0.1) var text_glow := 1.8: set = _set_text_glow
@export_group("Mounting")
## Set by the hall from the bay: distance between the piers either side, and how far they stand out.
@export_range(2.0, 30.0, 0.1, "suffix:m") var pier_spacing := 8.0: set = _set_pier_spacing
@export_range(0.0, 4.0, 0.05, "suffix:m") var pier_depth := 1.0: set = _set_pier_depth
@export_group("Colours")
@export var body_color := Color(0.42, 0.36, 0.30): set = _set_body_color
@export var top_color := Color(0.68, 0.62, 0.54): set = _set_top_color
@export var board_color := Color(0.04, 0.05, 0.07): set = _set_board_color
@export var departures_color := Color(1.0, 0.58, 0.08): set = _set_departures_color
@export var arrivals_color := Color(0.18, 0.80, 0.36): set = _set_arrivals_color
@export var board_light_color := Color(1.0, 0.82, 0.55): set = _set_board_light_color

const GENERATED := "Generated"
const TOP_OVERHANG := 0.12       # counter top sticks out past the counter body (m)
const TOP_THICKNESS := 0.06
const ROOF_THICKNESS := 0.15
const ROOF_OVERHANG := 0.15
const BOARD_THICKNESS := 0.14
const BOARD_STANDOFF := 0.2      # the board's back is this far in front of the pier faces
const BRACKET_WIDTH := 0.5
const BRACKET_HEIGHT := 0.35
const LIGHT_DISTANCE := 1.8      # the board light hangs this far in front of the board
const PANEL_MARGIN := 0.5        # the glowing wall panel is this much larger than the board on every side
const PANEL_THICKNESS := 0.04
const WALL_CLEARANCE := 0.03     # the panel sits just off the wall
const LABEL_BLOCK_WIDTH_RATIO := 0.42   # width of the dark label block, as a fraction of the board
const LABEL_BLOCK_INSET := 0.08         # margin around the label block inside the header (fraction of header height)
const HEADER_GLOW_RATIO := 0.45         # the header strip glows less than the text, so amber stays amber
const LABEL_STANDOFF := 0.015
const LABEL_FONT_SIZE := 96
const LABEL_PIXEL_SIZE := 0.0072        # metres per font pixel: capitals about 0.4 m tall
const TEXT_ROWS := 6
const TEXT_MARGIN := 0.04        # blank margin round the text rows (fraction of the board's width / row area height)
const TEXT_BAR_HEIGHT_RATIO := 0.45   # bar height as a fraction of the row pitch
const TEXT_SURFACE := 0.005
# text columns, as fractions of the board width: [left edge, width] for time, destination, platform
const COLUMN_TIME := Vector2(0.0, 0.07)
const COLUMN_DEST := Vector2(0.10, 0.46)
const COLUMN_PLATFORM := Vector2(0.62, 0.05)
const COLUMN_STATUS := Vector2(0.70, 0.20)
const DEST_BAR_RATIOS := [0.95, 0.62, 0.8, 0.5, 0.7, 0.58]  # destination bar lengths (fraction of its column)

## Adds a StaticBody3D for the service room and counter.
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

	# service room against the wall, with a roof overhang
	_box(root, "Room", Vector3(width, room_height, room_depth), Vector3(0, room_height * 0.5, room_depth * 0.5), _solid(body_color))
	_box(root, "Roof", Vector3(width + ROOF_OVERHANG * 2.0, ROOF_THICKNESS, room_depth + counter_depth + ROOF_OVERHANG),
		Vector3(0, room_height + ROOF_THICKNESS * 0.5, (room_depth + counter_depth + ROOF_OVERHANG) * 0.5), _solid(body_color.darkened(0.15)))
	# counter in front of the room
	var body_h := counter_height - TOP_THICKNESS
	_box(root, "Counter", Vector3(width, body_h, counter_depth), Vector3(0, body_h * 0.5, room_depth + counter_depth * 0.5), _solid(body_color))
	_box(root, "CounterTop", Vector3(width + TOP_OVERHANG, TOP_THICKNESS, counter_depth + TOP_OVERHANG),
		Vector3(0, counter_height - TOP_THICKNESS * 0.5, room_depth + (counter_depth + TOP_OVERHANG) * 0.5), _solid(top_color))

	if build_collision:
		var body := StaticBody3D.new()
		body.name = "Body"
		root.add_child(body)
		_shape(body, Vector3(0, room_height * 0.5, room_depth * 0.5), Vector3(width, room_height, room_depth))
		_shape(body, Vector3(0, counter_height * 0.5, room_depth + counter_depth * 0.5), Vector3(width + TOP_OVERHANG, counter_height, counter_depth + TOP_OVERHANG))

	_build_board(root)


func _shape(body: StaticBody3D, pos: Vector3, size: Vector3) -> void:
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	cs.shape = box
	cs.position = pos
	body.add_child(cs)


func _kind_color() -> Color:
	return departures_color if board_kind == "DEPARTURES" else arrivals_color


func _glow_material(c: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = energy
	return m


func _build_board(root: Node3D) -> void:
	var kind_color := _kind_color()
	var back := pier_depth + BOARD_STANDOFF         # z of the board's back face
	var front := back + BOARD_THICKNESS             # z of its front face
	var cy := board_bottom + board_height * 0.5
	var top := board_bottom + board_height

	# faintly glowing wall panel behind the board
	var panel_w := board_width + PANEL_MARGIN * 2.0
	var panel_h := board_height + PANEL_MARGIN * 2.0
	var panel_mat := StandardMaterial3D.new()
	panel_mat.albedo_color = Color(0.62, 0.56, 0.46)
	panel_mat.emission_enabled = panel_glow > 0.0
	panel_mat.emission = board_light_color
	panel_mat.emission_energy_multiplier = panel_glow
	_box(root, "WallPanel", Vector3(panel_w, panel_h, PANEL_THICKNESS), Vector3(0, cy, WALL_CLEARANCE + PANEL_THICKNESS * 0.5), panel_mat)

	# the board itself, and four brackets onto the faces of the two piers
	_box(root, "Board", Vector3(board_width, board_height, BOARD_THICKNESS), Vector3(0, cy, back + BOARD_THICKNESS * 0.5), _solid(board_color))
	for sx in [-1, 1]:
		for y in [board_bottom + BRACKET_HEIGHT, top - BRACKET_HEIGHT]:
			_box(root, "Bracket", Vector3(BRACKET_WIDTH, BRACKET_HEIGHT, BOARD_STANDOFF + 0.05),
				Vector3(sx * pier_spacing * 0.5, y, pier_depth + (BOARD_STANDOFF - 0.05) * 0.5), _solid(body_color.darkened(0.3)))

	# coloured header strip with a large dark label block and the label
	var header_y := top - header_height * 0.5
	_box(root, "Header", Vector3(board_width, header_height, BOARD_THICKNESS * 0.5),
		Vector3(0, header_y, front + BOARD_THICKNESS * 0.25), _glow_material(kind_color, text_glow * HEADER_GLOW_RATIO))
	var inset := header_height * LABEL_BLOCK_INSET
	var block_w := board_width * LABEL_BLOCK_WIDTH_RATIO
	var block_x := -board_width * 0.5 + inset + block_w * 0.5
	_box(root, "LabelBlock", Vector3(block_w, header_height - inset * 2.0, BOARD_THICKNESS * 0.5),
		Vector3(block_x, header_y, front + BOARD_THICKNESS * 0.5 + 0.005), _solid(board_color))
	var label := Label3D.new()
	label.name = "Label"
	label.text = board_kind
	label.font_size = LABEL_FONT_SIZE
	label.pixel_size = LABEL_PIXEL_SIZE
	label.modulate = kind_color
	label.shaded = false
	label.double_sided = false
	label.position = Vector3(block_x, header_y, front + BOARD_THICKNESS * 0.75 + LABEL_STANDOFF)  # just in front of the label block's face
	root.add_child(label)

	# rows of glowing "text": time, destination, platform and status
	var glow := _glow_material(kind_color, text_glow)
	var rows_top := top - header_height
	var rows_h := (rows_top - board_bottom)
	var inner_h := rows_h * (1.0 - TEXT_MARGIN * 2.0)
	var pitch := inner_h / TEXT_ROWS
	var left := -board_width * 0.5 + board_width * TEXT_MARGIN
	var inner_w := board_width * (1.0 - TEXT_MARGIN * 2.0)
	var bar_h := pitch * TEXT_BAR_HEIGHT_RATIO
	for r in TEXT_ROWS:
		var y := rows_top - rows_h * TEXT_MARGIN - (r + 0.5) * pitch
		var dest_ratio: float = DEST_BAR_RATIOS[r % DEST_BAR_RATIOS.size()]
		for col in [[COLUMN_TIME, 1.0, "Time"], [COLUMN_DEST, dest_ratio, "Dest"], [COLUMN_PLATFORM, 1.0, "Platform"], [COLUMN_STATUS, 0.45 + 0.4 * ((r * 3) % 4) / 3.0, "Status"]]:
			var c: Vector2 = col[0]
			var w: float = inner_w * c.y * col[1]
			var x: float = left + inner_w * c.x + w * 0.5
			_box(root, "%s%d" % [col[2], r], Vector3(w, bar_h, TEXT_SURFACE * 2.0), Vector3(x, y, front + TEXT_SURFACE), glow)

	# warm light in front of the board
	if board_light_energy > 0.0:
		var light := OmniLight3D.new()
		light.name = "BoardLight"
		light.position = Vector3(0, cy, front + LIGHT_DISTANCE)
		light.light_color = board_light_color
		light.light_energy = board_light_energy
		light.omni_range = board_light_range
		light.light_specular = 0.0
		light.shadow_enabled = false
		root.add_child(light)


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
func _set_board_kind(v: String) -> void: board_kind = v; _queue_rebuild()
func _set_board_bottom(v: float) -> void: board_bottom = v; _queue_rebuild()
func _set_board_width(v: float) -> void: board_width = v; _queue_rebuild()
func _set_board_height(v: float) -> void: board_height = v; _queue_rebuild()
func _set_header_height(v: float) -> void: header_height = v; _queue_rebuild()
func _set_board_light_energy(v: float) -> void: board_light_energy = v; _queue_rebuild()
func _set_board_light_range(v: float) -> void: board_light_range = v; _queue_rebuild()
func _set_panel_glow(v: float) -> void: panel_glow = v; _queue_rebuild()
func _set_text_glow(v: float) -> void: text_glow = v; _queue_rebuild()
func _set_pier_spacing(v: float) -> void: pier_spacing = v; _queue_rebuild()
func _set_pier_depth(v: float) -> void: pier_depth = v; _queue_rebuild()
func _set_body_color(v: Color) -> void: body_color = v; _queue_rebuild()
func _set_top_color(v: Color) -> void: top_color = v; _queue_rebuild()
func _set_board_color(v: Color) -> void: board_color = v; _queue_rebuild()
func _set_departures_color(v: Color) -> void: departures_color = v; _queue_rebuild()
func _set_arrivals_color(v: Color) -> void: arrivals_color = v; _queue_rebuild()
func _set_board_light_color(v: Color) -> void: board_light_color = v; _queue_rebuild()
