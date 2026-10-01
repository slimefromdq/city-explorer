class_name Wayfinding
extends RefCounted
## Signs and maps inside the concourse: a route map and an exit sign over each entrance, a hanging
## "trains" sign from each bridge (two-sided, naming the two lines whose stairs lie to the left and
## right), and a small sign over each wing door. Hall frame (origin = hall centre on the floor).

const L := preload("res://station/station_layout.gd")

const DARK := Color(0.06, 0.07, 0.09)
const ORDER := {"west": 1, "east": 2, "tower": 3, "park": 4}


static func build(root: Node3D, routes: RouteData, hall: ConcourseHall, river: Array) -> void:
	var node := Node3D.new()
	node.name = "Wayfinding"
	root.add_child(node)
	var half: float = hall.hall_bays * 8.0 * 0.5      # inner end wall |x|
	# route map + exit sign over each end entrance (faces into the hall)
	for e in [1, -1]:
		var x: float = e * (half - 0.05)
		var yaw: float = -PI * 0.5 * e                 # faces -x at the +x wall, +x at the -x wall
		RouteMap.build(node, "RouteMap_%s" % ("E" if e > 0 else "W"), routes, Vector3(x, 7.45, 0), yaw, Vector2(7.6, 2.6), "central", "", river)
		var exit_text := "EXIT  -  MAIN ENTRANCE & FORECOURT" if e > 0 else "EXIT  -  WEST ENTRANCE"
		_board(node, Vector3(x, 5.25, 0), yaw, Vector2(7.0, 0.6), exit_text, Color(0.3, 1.0, 0.5))
	# trains sign under each bridge
	var bx: float = hall.bridge_distance
	for e in [1, -1]:
		_bridge_sign(node, routes, e, bx * e, hall)
	# wing door signs (hall side of the wall, above each door)
	var doors := [[-1, -20.0, "WAITING ROOM"], [-1, 20.0, "GARDEN COURT"], [1, 12.0, "SHOP ARCADE"]]
	for d in doors:
		var side: int = d[0]
		var z: float = side * (hall.hall_width * 0.5 - 0.05)
		_board(node, Vector3(d[1], 4.85, z), 0.0 if side < 0 else PI, Vector2(3.2, 0.5), String(d[2]), Color(1.0, 0.85, 0.4))


## A dark board with one line of glowing text, facing +z at yaw 0.
static func _board(parent: Node3D, pos: Vector3, yaw: float, size: Vector2, text: String, color: Color) -> void:
	var holder := Node3D.new()
	holder.position = pos
	holder.rotation.y = yaw
	parent.add_child(holder)
	Greybox.box(holder, Vector3(size.x, size.y, 0.08), Vector3(0, 0, -0.04), Greybox.mat(DARK))
	var l := Greybox.label(holder, text, Vector3(0, 0, 0.005), 0.0, size.y * 0.62, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER


## Hanging sign under a bridge at hall x = `x`; `e` = which end (+1 east, -1 west). Two faces.
static func _bridge_sign(parent: Node3D, routes: RouteData, e: int, x: float, hall: ConcourseHall) -> void:
	var holder := Node3D.new()
	holder.name = "TrainsSign_%s" % ("E" if e > 0 else "W")
	holder.position = Vector3(x, 0, 0)
	parent.add_child(holder)
	var y := 6.9
	var w := 6.8
	var h := 1.5
	Greybox.box(holder, Vector3(0.14, h, w), Vector3(0, y, 0), Greybox.mat(DARK))
	# two chains up to the bridge's underside
	for z in [-w * 0.5 + 0.4, w * 0.5 - 0.4]:
		Greybox.box(holder, Vector3(0.05, 3.2, 0.05), Vector3(0, y + h * 0.5 + 1.6, z), Greybox.mat(Color(0.3, 0.3, 0.33)))
	for face in [1, -1]:   # outward normal = face * e along x
		var normal := Vector3(float(face * e), 0, 0)
		var yaw: float = PI * 0.5 * normal.x
		var face_holder := Node3D.new()
		face_holder.position = Vector3(normal.x * 0.075, y, 0)
		face_holder.rotation.y = yaw
		holder.add_child(face_holder)
		# the viewer looks along -normal; their right-hand direction in the world:
		var right := (-normal).cross(Vector3.UP)
		for line in routes.lines:
			var q: Vector2i = PlatformLevel.QUADRANTS[line["id"]]
			if q.x != e:
				continue
			var on_right: bool = right.z * float(q.y) > 0.0
			var cx: float = w * 0.25 * (1.0 if on_right else -1.0)
			Greybox.box(face_holder, Vector3(w * 0.46, 0.3, 0.02), Vector3(cx, h * 0.5 - 0.22, 0.01), Greybox.mat(line["color"], 0.6, 0.8))
			var dest: String = routes.stop(line["stops"][1]["stop"])["name"]
			Greybox.label(face_holder, String(line["name"]).to_upper(), Vector3(cx, h * 0.5 - 0.22, 0.03), 0.0, 0.26, Color(0.05, 0.05, 0.05))
			Greybox.label(face_holder, "Platform %d - %s" % [ORDER[line["id"]], dest], Vector3(cx, 0.05, 0.03), 0.0, 0.2, Color(1, 1, 1))
			Greybox.label(face_holder, ("stairs  >" if on_right else "<  stairs"), Vector3(cx, -0.45, 0.03), 0.0, 0.2, Color(1.0, 0.85, 0.4))
