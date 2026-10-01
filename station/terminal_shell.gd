class_name TerminalShell
extends RefCounted
## The building round the concourse hall: the main (east) facade with its ticket hall, the west
## portal with its ticket hall, and three wings (waiting room, garden court, shop arcade) on the
## long walls. Station frame (see StationLayout); everything is greybox from primitives and
## ConcourseBay walls, so it matches the hall's stone, arches and cornice.

const BAY := preload("res://concourse/ConcourseBay.tscn")
const L := preload("res://station/station_layout.gd")

const STONE := Color(0.55, 0.55, 0.57)
const DARK := Color(0.30, 0.30, 0.33)
const WARM := Color(0.74, 0.68, 0.58)
const ROOF := Color(0.40, 0.45, 0.50)
const DOOR_ROOM_DARK := Color(0.12, 0.12, 0.14)


static func build(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Shell"
	root.add_child(node)
	var col := Greybox.body(node, "ShellCollision")
	_floor_slabs(node, col)
	_east_facade(node, col)
	_west_portal(node, col)
	_wing(node, col, "WaitingRoom", -1, -32.0, -10.0, 20.0, 7.5, "waiting")
	_wing(node, col, "GardenCourt", -1, 10.0, 32.0, 20.0, 7.5, "garden")
	_wing(node, col, "ShopArcade", 1, 2.0, 22.0, 20.0, 7.5, "arcade")


static func _bay(parent: Node3D, bay_name: String, pos: Vector3, yaw: float, props: Dictionary) -> ConcourseBay:
	var b: ConcourseBay = BAY.instantiate()
	for k in props:
		b.set(k, props[k])
	b.name = bay_name
	b.position = pos
	b.rotation.y = yaw
	parent.add_child(b)
	return b


# --------------------------------------------------------------------------- floors

static func _floor_slabs(node: Node3D, col: StaticBody3D) -> void:
	var m := Greybox.mat(DARK)
	# under the facade block, the west portal, the wings: one slab each, top at the hall floor (y = 0)
	Greybox.box_ab(node, Vector3(L.HALL_END, -1.2, -L.FACADE_HALF), Vector3(L.FRONT_E, 0.0, L.FACADE_HALF), m, col)
	Greybox.box_ab(node, Vector3(L.FRONT_W, -1.2, -L.PORTAL_HALF), Vector3(-L.HALL_END, 0.0, L.PORTAL_HALF), m, col)


# --------------------------------------------------------------------------- east facade

static func _east_facade(node: Node3D, col: StaticBody3D) -> void:
	var stone := Greybox.mat(STONE)
	var roof_m := Greybox.mat(ROOF)
	var fx := L.FRONT_E
	var yaw := PI * 0.5
	var mid_w := 11.4
	for i in 5:
		var zc := (i - 2) * mid_w
		var props := {"bay_width": mid_w, "wall_height": L.FACADE_H, "window_width": 6.0, "window_height": 10.0,
			"window_sill_height": 2.0, "dress_back": true}
		if i == 2:
			props["door_width"] = L.GATE_W
			props["door_height"] = L.GATE_H
		_bay(node, "FacadeBay%d" % i, Vector3(fx, 0, zc), yaw, props)
	for s in [-1, 1]:
		var zc: float = s * (L.FACADE_HALF - L.PAVILION_W * 0.5)
		_bay(node, "Pavilion%s" % ("N" if s < 0 else "S"), Vector3(fx, 0, zc), yaw, {"bay_width": L.PAVILION_W,
			"wall_height": L.PAVILION_H, "window_width": 6.0, "window_height": 14.0, "window_sill_height": 2.5,
			"cap_left": true, "cap_right": true, "dress_back": true})
		# closing side wall and roof of the pavilion, pyramid on top
		Greybox.box(node, Vector3(L.FRONT_E - L.HALL_END, L.PAVILION_H - 1.2, 1.0),
			Vector3((L.FRONT_E + L.HALL_END) * 0.5, (L.PAVILION_H - 1.2) * 0.5, s * (L.FACADE_HALF - 0.5)), stone, col)
		Greybox.box(node, Vector3(L.FRONT_E - L.HALL_END, 0.5, L.PAVILION_W), Vector3((L.FRONT_E + L.HALL_END) * 0.5, L.PAVILION_H - 1.2 - 0.25, zc), roof_m)
		Greybox.pyramid(node, L.FRONT_E - L.HALL_END + 1.2, L.PAVILION_W + 1.2, 5.0,
			Vector3((L.FRONT_E + L.HALL_END) * 0.5, L.PAVILION_H - 1.2, zc), roof_m)
	# roof over the middle section (the hall's end wall rises behind it)
	Greybox.box(node, Vector3(L.FRONT_E - L.HALL_END, 0.5, L.FACADE_HALF * 2.0 - L.PAVILION_W * 2.0),
		Vector3((L.FRONT_E + L.HALL_END) * 0.5, L.FACADE_H - 1.2 - 0.25, 0), roof_m)
	# the back wall of the facade block: the hall's end wall covers |z| < 16; close the rest, beside it
	for s in [-1, 1]:
		var z_mid: float = s * (L.FACADE_HALF - L.PAVILION_W)
		Greybox.box_ab(node, Vector3(L.HALL_END - 1.0, 0, s * L.HALL_SIDE), Vector3(L.HALL_END, L.FACADE_H - 1.2, z_mid), stone, col)
		Greybox.box_ab(node, Vector3(L.HALL_END - 1.0, 0, z_mid), Vector3(L.HALL_END, L.PAVILION_H - 1.2, s * L.FACADE_HALF), stone, col)
	_ticket_hall(node, col, 1)
	_pediment(node)


## A low ticket hall: a corridor from the facade door (or portal door) to the hall opening, with a
## ceiling at TICKET_CEILING, a glass tympanum filling the tall arch above it, counters, lights.
static func _ticket_hall(node: Node3D, col: StaticBody3D, dir: int) -> void:
	var stone := Greybox.mat(STONE)
	var warm := Greybox.mat(WARM)
	var hw := L.TICKET_HALF_W
	var xa: float = L.HALL_END * dir
	var xb: float = (L.FRONT_E - 1.0) if dir > 0 else (L.FRONT_W + 1.0)
	var cx: float = (xa + xb) * 0.5
	var length: float = absf(xb - xa)
	var ceil_y := L.TICKET_CEILING
	# ceiling slab
	Greybox.box(node, Vector3(length, 0.5, hw * 2.0 + 1.2), Vector3(cx, ceil_y + 0.25, 0), stone, col)
	# side walls
	for s in [-1, 1]:
		Greybox.box(node, Vector3(length, ceil_y + 0.5, 0.6), Vector3(cx, (ceil_y + 0.5) * 0.5, s * (hw + 0.3)), stone, col)
	# warm lined ceiling strip with lamps
	var lamp_m := Greybox.mat(Color(1.0, 0.9, 0.7), 0.5, 1.2)
	for k in 3:
		var lx: float = xa + (xb - xa) * (k + 0.5) / 3.0
		Greybox.box(node, Vector3(1.6, 0.06, 1.6), Vector3(lx, ceil_y - 0.03, 0), lamp_m)
		Greybox.omni(node, Vector3(lx, ceil_y - 0.6, 0), 1.6, 9.0)
	# ticket counters along both sides (waist high, 0.8 deep), signs above
	for s in [-1, 1]:
		var counter_x: float = cx
		Greybox.box(node, Vector3(length * 0.45, PlayerScale.WAIST_HEIGHT, 0.8), Vector3(counter_x, PlayerScale.WAIST_HEIGHT * 0.5, s * (hw - 0.4 - 0.05)), warm, col)
		var face_z: float = s * (hw - 0.02)
		Greybox.label(node, "TICKETS", Vector3(counter_x, 3.1, face_z), PI if s > 0 else 0.0, 0.5, Color(1.0, 0.85, 0.4))
	# glass tympanum in the facade doorway, from the ceiling up to the arch
	var plane_x: float = (L.FRONT_E - 0.5) if dir > 0 else (L.FRONT_W + 0.5)
	var door_w: float = L.GATE_W if dir > 0 else 8.0
	var door_h: float = L.GATE_H if dir > 0 else 11.0
	var r := door_w * 0.5
	var spring := door_h - r
	var glass := CSGCombiner3D.new()
	glass.name = "Tympanum"
	glass.position = Vector3(plane_x, 0, 0)
	node.add_child(glass)
	var gm := Greybox.mat(Color(0.55, 0.78, 0.85), 0.1, 0.0, 0.35)
	var disc := CSGCylinder3D.new()
	disc.radius = r
	disc.height = 0.2
	disc.sides = 32
	disc.rotation.z = PI * 0.5
	disc.position.y = spring
	disc.material = gm
	glass.add_child(disc)
	var rect := CSGBox3D.new()
	rect.size = Vector3(0.2, spring - ceil_y + 0.2, door_w)
	rect.position.y = (spring + ceil_y - 0.2) * 0.5 + 0.1
	rect.material = gm
	glass.add_child(rect)
	var cut := CSGBox3D.new()
	cut.operation = CSGShape3D.OPERATION_SUBTRACTION
	cut.size = Vector3(1.0, 5.0, door_w + 2.0)
	cut.position.y = ceil_y - 2.5 + 0.3
	glass.add_child(cut)
	# mullions on the glass
	var mull := Greybox.mat(DARK)
	for k in range(-2, 3):
		Greybox.box(node, Vector3(0.12, door_h - ceil_y, 0.08), Vector3(plane_x + 0.02, (door_h + ceil_y) * 0.5, k * door_w / 5.0 * 0.9), mull)
	# doorway frame (the opening in the hall's end wall is cut by the hall itself)
	# threshold slab so the corridor floor meets both doors flush
	Greybox.box(node, Vector3(length + 1.0, 0.2, hw * 2.0), Vector3(cx, -0.1, 0), Greybox.mat(Color(0.46, 0.41, 0.36)), col)


static func _pediment(node: Node3D) -> void:
	var stone := Greybox.mat(STONE)
	var warm := Greybox.mat(WARM)
	var px: float = L.FRONT_E - 1.6
	var depth := 2.2
	Greybox.gable(node, 8.0, 3.6, depth, Vector3(px, L.FACADE_H, 0), stone)
	# clock on the pediment face
	var face_x: float = px + depth + 0.02
	var cy: float = L.FACADE_H + 1.7
	var white := Greybox.mat(Color(0.95, 0.94, 0.88))
	var dark := Greybox.mat(Color(0.12, 0.12, 0.14))
	Greybox.cyl(node, 1.55, 0.12, Vector3(face_x, cy, 0), white, null, Vector3(0, 0, PI * 0.5))
	Greybox.box(node, Vector3(0.1, 1.2, 0.12), Vector3(face_x + 0.1, cy + 0.5, 0), dark)
	Greybox.box(node, Vector3(0.1, 0.12, 0.9), Vector3(face_x + 0.1, cy, 0.4), dark)
	for k in 4:
		var ang := k * PI * 0.5
		Greybox.box(node, Vector3(0.1, 0.25, 0.08), Vector3(face_x + 0.08, cy + cos(ang) * 1.3, sin(ang) * 1.3), dark, null, 0.0)
	# station name in the frieze above the gate
	Greybox.label(node, "CENTRAL STATION", Vector3(L.FRONT_E + 0.04, L.FACADE_H - 1.9, 0), PI * 0.5, 1.0, Color(0.15, 0.15, 0.17), false)
	# flagpole on the pediment apex
	Greybox.cyl(node, 0.08, 9.0, Vector3(px + 1.0, L.FACADE_H + 3.6 + 4.5, 0), Greybox.mat(Color(0.8, 0.8, 0.82)))
	Greybox.box(node, Vector3(0.04, 1.2, 2.2), Vector3(px + 1.0, L.FACADE_H + 3.6 + 8.2, 1.2), Greybox.mat(Color(0.8, 0.15, 0.15)))
	warm = warm  # (kept for symmetry with other builders)


# --------------------------------------------------------------------------- west portal

static func _west_portal(node: Node3D, col: StaticBody3D) -> void:
	var stone := Greybox.mat(STONE)
	var fx := L.FRONT_W
	var yaw := -PI * 0.5
	for i in 3:
		var props := {"bay_width": 10.0, "wall_height": L.PORTAL_H, "window_width": 5.0, "window_height": 10.0,
			"window_sill_height": 2.0, "dress_back": true, "cap_left": i == 0, "cap_right": i == 2}
		if i == 1:
			props["door_width"] = 8.0
			props["door_height"] = 11.0
		_bay(node, "PortalBay%d" % i, Vector3(fx, 0, (i - 1) * 10.0), yaw, props)
	for s in [-1, 1]:
		var w: float = absf(L.FRONT_W) - L.HALL_END
		Greybox.box(node, Vector3(w, L.PORTAL_H - 1.2, 1.0), Vector3(-(L.HALL_END + w * 0.5), (L.PORTAL_H - 1.2) * 0.5, s * (L.PORTAL_HALF - 0.5)), stone, col)
	var wlen: float = absf(L.FRONT_W) - L.HALL_END
	Greybox.box(node, Vector3(wlen, 0.5, L.PORTAL_HALF * 2.0), Vector3(-(L.HALL_END + wlen * 0.5), L.PORTAL_H - 1.2 - 0.25, 0), Greybox.mat(ROOF))
	_ticket_hall(node, col, -1)
	Greybox.label(node, "STATION WEST", Vector3(L.FRONT_W - 0.04, L.PORTAL_H - 1.9, 0), -PI * 0.5, 0.8, Color(0.15, 0.15, 0.17), false)


# --------------------------------------------------------------------------- wings

## A single-storey wing on a long wall. `side` -1 = north (-Z), +1 = south. Spans x0..x1, `depth` out
## from the hall wall's back face. The hall wall carries the door (the hall cuts it from side_doors).
static func _wing(node: Node3D, col: StaticBody3D, wing_name: String, side: int, x0: float, x1: float, depth: float, h: float, kind: String) -> void:
	var stone := Greybox.mat(STONE)
	var roof_m := Greybox.mat(ROOF)
	var holder := Node3D.new()
	holder.name = wing_name
	node.add_child(holder)
	var z_in: float = side * L.HALL_SIDE
	var z_out: float = side * (L.HALL_SIDE + depth)
	var zc: float = (z_in + z_out) * 0.5
	var xc: float = (x0 + x1) * 0.5
	var w: float = x1 - x0
	var nb := 2
	var bw: float = w / nb
	var yaw: float = 0.0 if side > 0 else PI
	for i in nb:
		var bx: float = x0 + bw * (i + 0.5)
		_bay(holder, "Bay%d" % i, Vector3(bx, 0, z_out), yaw, {"bay_width": bw, "wall_height": h, "window_width": 3.0,
			"window_height": 3.6, "window_sill_height": 1.0, "cap_left": true, "cap_right": true})
	# end walls
	for e in [x0, x1]:
		Greybox.box(holder, Vector3(1.0, h - 1.2, depth), Vector3(e + (0.5 if e == x0 else -0.5), (h - 1.2) * 0.5, zc), stone, col)
	# floor
	Greybox.box(holder, Vector3(w, 1.2, depth), Vector3(xc, -0.6, zc), Greybox.mat(Color(0.46, 0.41, 0.36)), col)
	var has_roof := kind != "garden"
	if has_roof:
		Greybox.box(holder, Vector3(w, 0.5, depth), Vector3(xc, h - 1.2 - 0.25, zc), roof_m)
	match kind:
		"waiting":
			for r in 3:
				for c in 2:
					var bx: float = xc - 5.0 + c * 10.0
					Greybox.box(holder, Vector3(4.0, 0.45, 0.6), Vector3(bx, 0.225, z_in + side * (4.0 + r * 3.5)), Greybox.mat(Color(0.40, 0.28, 0.21)), col)
					Greybox.box(holder, Vector3(4.0, 0.5, 0.1), Vector3(bx, 0.7, z_in + side * (4.0 + r * 3.5) + side * 0.3), Greybox.mat(Color(0.40, 0.28, 0.21)))
			Greybox.label(holder, "WAITING ROOM", Vector3(xc, 4.6, z_out - side * 0.55), 0.0 if side < 0 else PI, 1.0, Color(1.0, 0.85, 0.4))
			for k in 2:
				Greybox.omni(holder, Vector3(xc - 5.0 + k * 10.0, h - 2.0, zc), 2.2, 16.0)
		"arcade":
			for k in 3:
				var sx: float = x0 + 3.5 + k * 6.5
				var sz: float = z_out - side * 4.5
				Greybox.box(holder, Vector3(4.6, PlayerScale.WAIST_HEIGHT, 0.8), Vector3(sx, PlayerScale.WAIST_HEIGHT * 0.5, sz), Greybox.mat(Color(0.74, 0.68, 0.58)), col)
				Greybox.box(holder, Vector3(4.6, 0.2, 1.8), Vector3(sx, 3.0, sz), Greybox.mat([Color(0.8, 0.25, 0.25), Color(0.25, 0.55, 0.75), Color(0.85, 0.7, 0.2)][k]))
				Greybox.box(holder, Vector3(0.1, 3.0, 0.1), Vector3(sx - 2.2, 1.5, sz - side * 0.8), Greybox.mat(Color(0.2, 0.2, 0.22)))
				Greybox.box(holder, Vector3(0.1, 3.0, 0.1), Vector3(sx + 2.2, 1.5, sz - side * 0.8), Greybox.mat(Color(0.2, 0.2, 0.22)))
				Greybox.label(holder, ["BOOKS", "COFFEE", "FLOWERS"][k], Vector3(sx, 3.6, sz - side * 0.05), PI if side > 0 else 0.0, 0.6, Color(1.0, 0.95, 0.8))
			for k in 2:
				Greybox.omni(holder, Vector3(x0 + 5.0 + k * 10.0, h - 2.0, zc), 2.2, 16.0)
		"garden":
			Greybox.box(holder, Vector3(w - 2.0, 0.15, depth - 2.0), Vector3(xc, 0.075, zc + side * 0.5), Greybox.mat(Color(0.34, 0.52, 0.28)))
			Greybox.box(holder, Vector3(2.4, 0.18, depth - 1.0), Vector3(xc, 0.09, zc), Greybox.mat(Color(0.74, 0.68, 0.58)))
			var trunk := Greybox.mat(Color(0.40, 0.28, 0.2))
			var leaf := Greybox.mat(Color(0.25, 0.5, 0.25))
			for t in [Vector2(-5.5, 5.0), Vector2(5.5, 5.0), Vector2(-5.5, 13.0), Vector2(5.5, 13.0)]:
				var tp := Vector3(xc + t.x, 0, z_in + side * t.y)
				Greybox.cyl(holder, 0.25, 3.0, tp + Vector3(0, 1.5, 0), trunk, col)
				Greybox.sphere(holder, 2.0, tp + Vector3(0, 4.2, 0), leaf)
			Greybox.cyl(holder, 1.8, 0.6, Vector3(xc, 0.3, z_in + side * 9.0), Greybox.mat(Color(0.74, 0.68, 0.58)), col)
			Greybox.cyl(holder, 1.5, 0.12, Vector3(xc, 0.62, z_in + side * 9.0), Greybox.mat(Color(0.3, 0.6, 0.8), 0.1))
			Greybox.label(holder, "GARDEN COURT", Vector3(xc, 4.6, z_out - side * 0.55), 0.0 if side < 0 else PI, 1.0, Color(0.7, 1.0, 0.7))
