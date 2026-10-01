class_name Forecourt
extends RefCounted
## The paved forecourt in front of the main facade: two-tone tiles with a border band and a compass
## inlay, steps and a ramp down to street level, a paved apron to the avenue with a zebra crossing,
## trees in planters, lamp posts, benches, a kiosk and a sign pillar. The axis (|z| < 4) is left
## free so the main arch frames the clock booth. Station frame; plaza top is the hall floor (y = 0).

const L := preload("res://station/station_layout.gd")
const PLAZA_SHADER := preload("res://station/plaza_stone.gdshader")

const X0 := 49.0                  # facade front
const X1 := 113.0                 # far edge of the plaza
const HALF := 42.5
const STREET := -0.60             # street level in the frame (ground 3.0 + 0.15 -> 3.15 world; hall floor 3.75)
const APRON_END := 145.0          # the avenue's kerb (world x 907)
const AVENUE_END := 171.0         # far kerb (world 933)
const STEP_HALF := 15.0           # the steps span z = +-15
const RAMP_Z := 26.0              # the ramp's centre line
const RAMP_W := 3.0
const PARAPET_H := 0.9
const STEP_RISE := 0.2
const STEP_RUN := 0.3

const STONE := Color(0.55, 0.55, 0.57)
const WARM := Color(0.74, 0.68, 0.58)
const WOOD := Color(0.40, 0.28, 0.21)


static func build(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "Forecourt"
	root.add_child(node)
	var col := Greybox.body(node, "ForecourtCollision")
	_paving(node, col)
	_edges(node, col)
	_steps_and_ramp(node, col)
	_crossing(node)
	_furniture(node, col)
	_rear_court(node, col)


static func _tile_material(center: Vector2, half: Vector2, border: float, inlay: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = PLAZA_SHADER
	mat.set_shader_parameter("center", center)
	mat.set_shader_parameter("half_size", half)
	mat.set_shader_parameter("border_width", border)
	mat.set_shader_parameter("inlay_radius", inlay)
	return mat


static func _paving(node: Node3D, col: StaticBody3D) -> void:
	# plaza slab: a box mesh built in frame coordinates (the shader reads vertex xz), plus its collider
	_tile_box(node, Vector3(X0, -0.8, -HALF), Vector3(X1, 0.0, HALF), _tile_material(Vector2((X0 + X1) * 0.5, 0), Vector2((X1 - X0) * 0.5, HALF), 1.6, 9.0))
	Greybox.add_box_shape(col, Vector3(X1 - X0, 0.8, HALF * 2.0), Vector3((X0 + X1) * 0.5, -0.4, 0))
	# the paved apron at street level from the steps to the avenue: same tiles, no border or inlay
	_tile_box(node, Vector3(X1, STREET - 0.4, -HALF), Vector3(APRON_END, STREET, HALF), _tile_material(Vector2.ZERO, Vector2(1000, 1000), 0.0, 0.0))
	Greybox.add_box_shape(col, Vector3(APRON_END - X1, 0.4, HALF * 2.0), Vector3((X1 + APRON_END) * 0.5, STREET - 0.2, 0))


## Edges: a low parapet along the north, south and east edges (gaps where the steps and ramp are).
static func _edges(node: Node3D, col: StaticBody3D) -> void:
	var stone := Greybox.mat(STONE)
	var cap := Greybox.mat(WARM)
	for s in [-1, 1]:
		Greybox.box(node, Vector3(X1 - X0, PARAPET_H, 0.4), Vector3((X0 + X1) * 0.5, PARAPET_H * 0.5, s * (HALF - 0.2)), stone, col)
		Greybox.box(node, Vector3(X1 - X0, 0.1, 0.6), Vector3((X0 + X1) * 0.5, PARAPET_H + 0.05, s * (HALF - 0.2)), cap)
	# east edge: from the north end to the steps, between the steps and the ramp, and from the ramp to the south end
	var gaps: Array = [Vector2(-STEP_HALF, STEP_HALF), Vector2(RAMP_Z - RAMP_W * 0.5 - 0.3, RAMP_Z + RAMP_W * 0.5 + 0.3)]
	var z := -HALF
	for g in gaps:
		_east_wall(node, col, z, g.x)
		z = g.y
	_east_wall(node, col, z, HALF)


static func _east_wall(node: Node3D, col: StaticBody3D, z0: float, z1: float) -> void:
	if z1 - z0 < 0.2:
		return
	var mid := (z0 + z1) * 0.5
	Greybox.box(node, Vector3(0.4, PARAPET_H, z1 - z0), Vector3(X1 - 0.2, PARAPET_H * 0.5, mid), Greybox.mat(STONE), col)
	Greybox.box(node, Vector3(0.6, 0.1, z1 - z0), Vector3(X1 - 0.2, PARAPET_H + 0.05, mid), Greybox.mat(WARM))


## Three steps down across the middle of the east edge, a ramp at the south end (1:12), both to street level.
## A collider ramp for a short stair: starts at `start` (x, y, z centre line), runs `run` along x (sign `dir`), drops `drop`, `width` wide.
static func _stair_ramp(col: StaticBody3D, start: Vector3, dir: float, run: float, drop: float, width: float) -> void:
	var length := sqrt(run * run + drop * drop)
	var mid := start + Vector3(dir * run * 0.5, -drop * 0.5, 0.0)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = Vector3(length + 0.2, 0.4, width)
	cs.shape = shape
	cs.position = mid + Vector3(0, -0.2 + 0.02, 0)
	cs.rotation.z = -atan2(drop, run) * dir
	col.add_child(cs)


static func _steps_and_ramp(node: Node3D, col: StaticBody3D) -> void:
	var warm := Greybox.mat(WARM)
	var n := int(round(-STREET / STEP_RISE))  # 3
	for i in n - 1:
		var rise: float = -STREET / n
		var x_lo: float = X1 + STEP_RUN * i
		# each step is a block from the street up to its top, so the face is solid (no collision of its own)
		Greybox.box_ab(node, Vector3(x_lo, STREET, -STEP_HALF), Vector3(x_lo + STEP_RUN, -rise * (i + 1), STEP_HALF), warm)
	# one walkable ramp along the nosing line stands in for the treads (a 0.2 m riser would stop the capsule)
	_stair_ramp(col, Vector3(X1, 0.0, 0.0), 1.0, n * STEP_RUN, -STREET, STEP_HALF * 2.0)
	# ramp: slopes from the plaza edge (y 0) down to street level over 7.2 m; walls each side
	var run := -STREET * 12.0
	var ang := atan2(STREET, run)  # negative: descending toward +x
	var len := sqrt(run * run + STREET * STREET)
	var ramp := Greybox.box(node, Vector3(len, 0.3, RAMP_W), Vector3(X1 + run * 0.5, STREET * 0.5 - 0.15, RAMP_Z), warm, null)
	ramp.rotation.z = ang
	var cs := CollisionShape3D.new()
	var shp := BoxShape3D.new()
	shp.size = Vector3(len, 0.3, RAMP_W)
	cs.shape = shp
	cs.position = ramp.position
	cs.rotation.z = ang
	col.add_child(cs)
	for s in [-1, 1]:
		var wz: float = RAMP_Z + s * (RAMP_W * 0.5 + 0.15)
		# triangular side wall: a stack of thin boxes following the slope would be overkill; one sloped slab
		var wall := Greybox.box(node, Vector3(len, PARAPET_H * 0.6, 0.3), Vector3(X1 + run * 0.5, STREET * 0.5 + PARAPET_H * 0.3 - 0.15, wz), Greybox.mat(STONE), null)
		wall.rotation.z = ang
		var cw := CollisionShape3D.new()
		var sw := BoxShape3D.new()
		sw.size = Vector3(len, PARAPET_H * 0.6, 0.3)
		cw.shape = sw
		cw.position = wall.position
		cw.rotation.z = ang
		col.add_child(cw)


## A zebra crossing over the avenue on the station's axis (stripes run with the traffic, N-S).
static func _crossing(node: Node3D) -> void:
	var paint := Greybox.mat(Color(0.95, 0.95, 0.92))
	var x := APRON_END + 1.0
	while x < AVENUE_END - 1.0:
		Greybox.box(node, Vector3(0.9, 0.03, 3.0), Vector3(x, STREET + 0.03, 0), paint)
		x += 2.0
	# a tactile kerb strip on the apron side
	Greybox.box(node, Vector3(0.6, 0.02, 3.0), Vector3(APRON_END - 0.35, STREET + 0.01, 0), Greybox.mat(Color(0.85, 0.7, 0.2)))


static func _furniture(node: Node3D, col: StaticBody3D) -> void:
	var trunk := Greybox.mat(WOOD)
	var leaf := Greybox.mat(Color(0.25, 0.5, 0.25))
	var planter := Greybox.mat(Color(0.50, 0.46, 0.40))
	# six trees in square planters along the two long sides
	for s in [-1, 1]:
		for x in [64.0, 81.0, 98.0]:
			var p := Vector3(x, 0, s * 33.0)
			Greybox.box(node, Vector3(3.0, 0.5, 3.0), p + Vector3(0, 0.25, 0), planter, col)
			Greybox.cyl(node, 0.22, 3.2, p + Vector3(0, 2.1, 0), trunk, col)
			Greybox.sphere(node, 2.2, p + Vector3(0, 4.6, 0), leaf)
	# lamp posts: a row either side of the axis
	var pole := Greybox.mat(Color(0.2, 0.2, 0.22))
	var globe := Greybox.mat(Color(1.0, 0.92, 0.7), 0.4, 1.5)
	for s in [-1, 1]:
		for x in [58.0, 72.0, 90.0, 104.0]:
			var p := Vector3(x, 0, s * 13.0)
			Greybox.cyl(node, 0.07, 4.2, p + Vector3(0, 2.1, 0), pole, col)
			Greybox.sphere(node, 0.28, p + Vector3(0, 4.35, 0), globe)
	# two benches facing the facade
	for s in [-1, 1]:
		var p := Vector3(88.0, 0, s * 20.0)
		Greybox.box(node, Vector3(0.6, 0.45, 2.2), p + Vector3(0, 0.225, 0), Greybox.mat(WOOD), col)
		Greybox.box(node, Vector3(0.1, 0.5, 2.2), p + Vector3(0.3, 0.7, 0), Greybox.mat(WOOD))
	# small kiosk (news and coffee)
	var kp := Vector3(100.0, 0, -22.0)
	Greybox.box(node, Vector3(3.6, 2.8, 3.0), kp + Vector3(0, 1.4, 0), Greybox.mat(WARM), col)
	Greybox.box(node, Vector3(4.4, 0.2, 3.8), kp + Vector3(0, 3.0, 0), Greybox.mat(Color(0.75, 0.25, 0.22)))
	Greybox.box(node, Vector3(0.1, 1.0, 2.0), kp + Vector3(-1.82, 1.5, 0), Greybox.mat(Color(0.1, 0.12, 0.15)))
	Greybox.label(node, "NEWS & COFFEE", kp + Vector3(-1.86, 2.5, 0), -PI * 0.5, 0.3, Color(1.0, 0.9, 0.7))
	# sign pillar with the station name, readable from the avenue and from the facade
	var sp := Vector3(106.0, 0, 12.0)
	Greybox.box(node, Vector3(0.9, 5.0, 3.6), sp + Vector3(0, 2.5, 0), Greybox.mat(Color(0.18, 0.2, 0.28)), col)
	Greybox.box(node, Vector3(1.1, 0.2, 3.8), sp + Vector3(0, 5.1, 0), Greybox.mat(WARM))
	Greybox.label(node, "CENTRAL\nSTATION", sp + Vector3(0.47, 3.4, 0), PI * 0.5, 0.75, Color(1, 1, 1))
	Greybox.label(node, "CENTRAL\nSTATION", sp + Vector3(-0.47, 3.4, 0), -PI * 0.5, 0.75, Color(1, 1, 1))
	Greybox.label(node, "Trains to West, East, Tower, Park", sp + Vector3(0.47, 1.4, 0), PI * 0.5, 0.2, Color(0.9, 0.85, 0.5))


## Box faces with the tile material, in frame coordinates (outward normals, clockwise front faces).
static func _tile_box(parent: Node3D, lo: Vector3, hi: Vector3, mat: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := lo
	var b := Vector3(hi.x, lo.y, lo.z)
	var c := Vector3(hi.x, hi.y, lo.z)
	var d := Vector3(lo.x, hi.y, lo.z)
	var e := Vector3(lo.x, lo.y, hi.z)
	var f := Vector3(hi.x, lo.y, hi.z)
	var g := hi
	var hh := Vector3(lo.x, hi.y, hi.z)
	var faces := [
		[Vector3.BACK, [e, f, g, hh]], [Vector3.FORWARD, [b, a, d, c]], [Vector3.UP, [hh, g, c, d]],
		[Vector3.DOWN, [a, b, f, e]], [Vector3.RIGHT, [f, b, c, g]], [Vector3.LEFT, [a, e, hh, d]],
	]
	for face in faces:
		st.set_normal(face[0])
		for i in [0, 2, 1, 0, 3, 2]:
			st.add_vertex(face[1][i])
	st.set_material(mat)
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	parent.add_child(mi)
	return mi


## The west (rear) entrance court: a smaller paved court, steps down to street level, trees and a sign.
const REAR_X0 := -80.0
const REAR_X1 := -49.0
const REAR_HALF := 20.0
const REAR_APRON_END := -89.0   # kerb of the west avenue (world x 673)


static func _rear_court(node: Node3D, col: StaticBody3D) -> void:
	var cx := (REAR_X0 + REAR_X1) * 0.5
	_tile_box(node, Vector3(REAR_X0, -0.8, -REAR_HALF), Vector3(REAR_X1, 0.0, REAR_HALF), _tile_material(Vector2(cx, 0), Vector2((REAR_X1 - REAR_X0) * 0.5, REAR_HALF), 1.2, 0.0))
	Greybox.add_box_shape(col, Vector3(REAR_X1 - REAR_X0, 0.8, REAR_HALF * 2.0), Vector3(cx, -0.4, 0))
	_tile_box(node, Vector3(REAR_APRON_END, STREET - 0.4, -REAR_HALF), Vector3(REAR_X0, STREET, REAR_HALF), _tile_material(Vector2.ZERO, Vector2(1000, 1000), 0.0, 0.0))
	Greybox.add_box_shape(col, Vector3(REAR_X0 - REAR_APRON_END, 0.4, REAR_HALF * 2.0), Vector3((REAR_X0 + REAR_APRON_END) * 0.5, STREET - 0.2, 0))
	var warm := Greybox.mat(WARM)
	var stone := Greybox.mat(STONE)
	# steps (west edge, |z| < 8), parapet elsewhere
	var rise := -STREET / 3.0
	for i in 2:
		var x_hi: float = REAR_X0 - STEP_RUN * i
		Greybox.box_ab(node, Vector3(x_hi - STEP_RUN, STREET, -8.0), Vector3(x_hi, -rise * (i + 1), 8.0), warm)
	_stair_ramp(col, Vector3(REAR_X0, 0.0, 0.0), -1.0, 3.0 * STEP_RUN, -STREET, 16.0)
	for seg in [Vector2(-REAR_HALF, -8.5), Vector2(8.5, REAR_HALF)]:
		Greybox.box(node, Vector3(0.4, PARAPET_H, seg.y - seg.x), Vector3(REAR_X0 + 0.2, PARAPET_H * 0.5, (seg.x + seg.y) * 0.5), stone, col)
	for s in [-1, 1]:
		Greybox.box(node, Vector3(REAR_X1 - REAR_X0, PARAPET_H, 0.4), Vector3(cx, PARAPET_H * 0.5, s * (REAR_HALF - 0.2)), stone, col)
	# trees, lamps, sign
	var trunk := Greybox.mat(WOOD)
	var leaf := Greybox.mat(Color(0.25, 0.5, 0.25))
	for s in [-1, 1]:
		var p := Vector3(-65.0, 0, s * 14.0)
		Greybox.box(node, Vector3(3.0, 0.5, 3.0), p + Vector3(0, 0.25, 0), Greybox.mat(Color(0.50, 0.46, 0.40)), col)
		Greybox.cyl(node, 0.22, 3.2, p + Vector3(0, 2.1, 0), trunk, col)
		Greybox.sphere(node, 2.2, p + Vector3(0, 4.6, 0), leaf)
		Greybox.cyl(node, 0.07, 4.2, Vector3(-56.0, 2.1, s * 9.0), Greybox.mat(Color(0.2, 0.2, 0.22)), col)
		Greybox.sphere(node, 0.28, Vector3(-56.0, 4.35, s * 9.0), Greybox.mat(Color(1.0, 0.92, 0.7), 0.4, 1.5))
	var sp := Vector3(-75.0, 0, 11.0)
	Greybox.box(node, Vector3(0.9, 4.0, 3.0), sp + Vector3(0, 2.0, 0), Greybox.mat(Color(0.18, 0.2, 0.28)), col)
	Greybox.label(node, "WEST\nENTRANCE", sp + Vector3(-0.47, 2.6, 0), -PI * 0.5, 0.6, Color(1, 1, 1))
