extends RefCounted
## Public library and learning institute, inside the existing civic envelope.
## Wide central and longitudinal aisles connect both entrances and all rooms.
const ArchitectureBuilder := preload("res://city/architecture_builder.gd")
const FLOOR := 1.5
const INK := Color(0.12, 0.24, 0.25)
const PAPER := Color(0.94, 0.88, 0.72)

static func build(plan, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "LibraryInterior"
	for site in plan.civic:
		if site["building"]["site_kind"] == "library":
			_build(root, site["building"], terrain)
	return root

static func _build(root: Node3D, b: Dictionary, terrain) -> void:
	var room := Node3D.new()
	room.name = "ReadingHall"
	room.transform = ArchitectureBuilder.building_frame(b, terrain)
	root.add_child(room)
	var col := Greybox.body(room, "FurnitureCollision")
	var s: Vector2 = b["size"]
	var ceiling: float = b["interior_ceiling"]
	var timber := Greybox.mat(Color(0.38, 0.23, 0.13))
	var oak := Greybox.mat(Color(0.66, 0.46, 0.27))
	var brass := Greybox.mat(Color(0.68, 0.53, 0.28), 0.4)
	var teal := Greybox.mat(INK)
	var cream := Greybox.mat(PAPER)
	Greybox.box(room, Vector3(s.x * 0.958, 0.03, s.y * 0.58), Vector3(0, FLOOR + 0.015, 0), Greybox.mat(Color(0.71, 0.64, 0.51)))
	# Carpet runners make the main aisles readable from either doorway.
	Greybox.box(room, Vector3(4, 0.012, s.y * 0.58), Vector3(0, FLOOR + 0.035, 0), teal)
	Greybox.box(room, Vector3(s.x * 0.94, 0.012, 3), Vector3(0, FLOOR + 0.035, 0), teal)
	# Reception leaves the entrance axis completely open.
	Greybox.box(room, Vector3(6, 1.0, 1.4), Vector3(-7, FLOOR + 0.5, s.y * 0.19), oak, col)
	Greybox.box(room, Vector3(6.2, 0.12, 1.6), Vector3(-7, FLOOR + 1.06, s.y * 0.19), timber)
	Greybox.label(room, "INFORMATION / BORROW", Vector3(-7, FLOOR + 1.5, s.y * 0.19 + 0.72), 0, 0.22, PAPER)
	# Books: deterministic colored spines, shelf boards and closed end panels.
	for row in 7:
		var x := -14.0 - row * 6.4
		for z in [-5.5, 5.5]:
			_shelf(room, col, Vector3(x, FLOOR, z), timber, oak)
	# Shared reading tables, with chairs on both sides and ample cross aisles.
	for row in 5:
		var x := 12.0 + row * 7.5
		for z in [-5.5, 5.5]:
			_table(room, col, Vector3(x, FLOOR, z), oak, teal)
	# A teaching room occupies the far east wing; its central doorway opens
	# directly onto the longitudinal aisle, rather than a furniture dead end.
	var partition := s.x * 0.345
	var depth := s.y * 0.58
	for side in [-1.0, 1.0]:
		Greybox.box(room, Vector3(0.22, ceiling - FLOOR, depth * 0.5 - 1.8), Vector3(partition, (FLOOR + ceiling) * 0.5, side * (depth * 0.25 + 0.9)), cream, col)
	Greybox.box(room, Vector3(0.22, ceiling - FLOOR - 3.1, 3.6), Vector3(partition, (ceiling + FLOOR + 3.1) * 0.5, 0), cream, col)
	var seminar_x := (partition + s.x * 0.47) * 0.5
	for z in [-5.5, 5.5]:
		_table(room, col, Vector3(seminar_x, FLOOR, z), oak, teal)
	Greybox.box(room, Vector3(0.10, 2.1, 6), Vector3(s.x * 0.478, FLOOR + 2.6, 0), teal)
	Greybox.label(room, "MERIDIAN INSTITUTE\nPUBLIC LECTURES & WORKSHOPS", Vector3(s.x * 0.476, FLOOR + 2.6, 0), -PI * 0.5, 0.25, PAPER)
	# Archive display at the opposite end gives the stacks a destination.
	Greybox.box(room, Vector3(0.12, 2.8, 7), Vector3(-s.x * 0.478, FLOOR + 2.8, 0), teal)
	Greybox.label(room, "CITY ARCHIVE\nMAPS / HISTORY / LOCAL COLLECTIONS", Vector3(-s.x * 0.476, FLOOR + 2.8, 0), PI * 0.5, 0.23, PAPER)
	for z in [-5.5, 5.5]:
		Greybox.box(room, Vector3(5, 0.9, 1.8), Vector3(-s.x * 0.43, FLOOR + 0.45, z), timber, col)
		Greybox.box(room, Vector3(4.7, 0.04, 1.5), Vector3(-s.x * 0.43, FLOOR + 0.93, z), cream)
		for i in 3:
			Greybox.box(room, Vector3(1.15, 0.02, 1.1), Vector3(-s.x * 0.43 + (i - 1) * 1.4, FLOOR + 0.96, z), Greybox.mat(Color(0.62, 0.72, 0.63)))
	# Repeated ceiling ribs and warm pendants establish the hall's rhythm.
	for i in 11:
		var x := (i - 5) * s.x * 0.082
		Greybox.box(room, Vector3(0.24, 0.28, depth), Vector3(x, ceiling - 0.14, 0), timber)
		var lamp_y := minf(ceiling - 0.6, FLOOR + 5.2)
		Greybox.box(room, Vector3(0.05, ceiling - lamp_y, 0.05), Vector3(x, (ceiling + lamp_y) * 0.5, 0), brass)
		Greybox.box(room, Vector3(2.6, 0.12, 0.65), Vector3(x, lamp_y, 0), Greybox.mat(PAPER, 0.6, 0.6))
		Greybox.omni(room, Vector3(x, lamp_y - 0.25, 0), 1.3, 12, Color(1, 0.87, 0.68))
	for front in [-1.0, 1.0]:
		Greybox.label(room, "MERIDIAN LIBRARY\nREAD / RESEARCH / LEARN", Vector3(0, FLOOR + 3.0, front * (s.y * 0.30 + 0.05)), 0 if front > 0 else PI, 0.32, INK)
	Greybox.box(room, Vector3(12, 1.0, 0.12), Vector3(0, FLOOR + 2.6, 0), teal)
	for front in [-1.0, 1.0]:
		Greybox.label(room, "COLLECTIONS  <     |     >  READING & SEMINARS" if front > 0 else "READING & SEMINARS  <     |     >  COLLECTIONS", Vector3(0, FLOOR + 2.6, front * 0.065), 0 if front > 0 else PI, 0.27, PAPER)
	root.set_meta("tour_points", PackedVector3Array([Vector3(0, FLOOR, s.y * 0.38), Vector3(0, FLOOR, 0), Vector3(-s.x * 0.43, FLOOR, 0), Vector3(-10.5, FLOOR, 0), Vector3(-10.5, FLOOR, -9.5), Vector3(0, FLOOR, -9.5), Vector3(8, FLOOR, -9.5), Vector3(8, FLOOR, 0), Vector3(seminar_x - 4, FLOOR, 0), Vector3(seminar_x - 4, FLOOR, -9.5), Vector3(seminar_x - 4, FLOOR, 0), Vector3(0, FLOOR, 0), Vector3(0, FLOOR, -s.y * 0.38)]))

static func _shelf(room: Node3D, col: StaticBody3D, p: Vector3, timber: Material, oak: Material) -> void:
	Greybox.col_box(col, Vector3(1.0, 2.7, 5.2), p + Vector3(0, 1.35, 0))
	for z in [-2.55, 2.55]:
		Greybox.box(room, Vector3(1, 2.7, 0.10), p + Vector3(0, 1.35, z), timber)
	Greybox.box(room, Vector3(0.10, 2.7, 5.2), p + Vector3(0, 1.35, 0), timber)
	var colors := [Color(0.26, 0.42, 0.39), Color(0.59, 0.25, 0.18), Color(0.31, 0.36, 0.49), Color(0.73, 0.59, 0.35)]
	for level in 5:
		var y := 0.15 + level * 0.51
		Greybox.box(room, Vector3(1.05, 0.08, 5.2), p + Vector3(0, y, 0), oak)
		for side in [-1.0, 1.0]:
			for book in 20:
				var height := 0.28 + (book % 4) * 0.035
				Greybox.box(room, Vector3(0.36, height, 0.19), p + Vector3(side * 0.27, y + 0.04 + height * 0.5, -2.36 + book * 0.24), Greybox.mat(colors[(book + level) % colors.size()]))

static func _table(room: Node3D, col: StaticBody3D, p: Vector3, oak: Material, teal: Material) -> void:
	Greybox.box(room, Vector3(4.6, 0.14, 1.9), p + Vector3(0, 0.78, 0), oak, col)
	for x in [-1.9, 1.9]:
		for z in [-0.65, 0.65]:
			Greybox.box(room, Vector3(0.12, 0.71, 0.12), p + Vector3(x, 0.355, z), oak, col)
	for x in [-1.4, 0.0, 1.4]:
		for side in [-1.0, 1.0]:
			var chair := p + Vector3(x, 0, side * 1.55)
			Greybox.col_box(col, Vector3(0.55, 0.95, 0.60), chair + Vector3.UP * 0.475)
			Greybox.box(room, Vector3(0.55, 0.10, 0.55), chair + Vector3.UP * 0.45, teal)
			Greybox.box(room, Vector3(0.55, 0.50, 0.08), chair + Vector3(0, 0.73, side * 0.25), teal)
			for leg in [-0.2, 0.2]:
				Greybox.box(room, Vector3(0.07, 0.40, 0.45), chair + Vector3(leg, 0.2, 0), oak)
	Greybox.box(room, Vector3(0.5, 0.045, 0.7), p + Vector3(0.7, 0.875, 0), Greybox.mat(PAPER))
