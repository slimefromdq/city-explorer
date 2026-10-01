class_name TunnelBuilder
extends RefCounted
## Sweeps a dark tunnel along a path (world coordinates): floor with sleepers and rails, walls with a
## concrete band, a chamfered roof, lamps every LAMP_SPACING metres. One ArrayMesh (vertex colours),
## trimesh collision, and a MultiMesh of lamps (emissive). Interior faces only; nothing is visible from
## outside because the tunnel is buried (the validator checks the cover).

const HALF_WIDTH := 2.3
const FLOOR_Y := -0.8            # track bed, relative to the path (platform level)
const HEAD_Y := 4.1              # roof underside above the path
const BAND_Y := 0.5
const WALL_TOP_Y := 2.7
const CHAMFER := 0.4
const STEP := 2.0                # distance between rings (m)
const LAMP_SPACING := 10.0
const RIVER_TINT := Color(0.09, 0.14, 0.20)

const C_FLOOR := Color(0.13, 0.13, 0.14)
const C_BAND := Color(0.32, 0.32, 0.34)
const C_WALL := Color(0.17, 0.18, 0.21)
const C_ROOF := Color(0.13, 0.13, 0.15)


## Builds the tunnel between arc lengths s0 and s1 of `path`. `river` = Array of Vector2(s_from, s_to)
## where the tunnel runs under the river (darker, damper walls).
static func build(parent: Node3D, tunnel_name: String, path: PackedVector3Array, s0: float, s1: float, river: Array, with_collision := true) -> Node3D:
	var root := Node3D.new()
	root.name = tunnel_name
	parent.add_child(root)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rings: Array = []
	var s := s0
	while s <= s1 + 0.001:
		var smp := RouteData.sample(path, s)
		var p: Vector3 = smp["pos"]
		var dir: Vector3 = smp["dir"]
		var right := dir.cross(Vector3.UP).normalized()
		var up := right.cross(dir).normalized()
		var wet := false
		for r in river:
			if s >= r.x and s <= r.y:
				wet = true
		rings.append({"p": p, "dir": dir, "right": right, "up": up, "wet": wet, "s": s})
		s += STEP
	for i in range(rings.size() - 1):
		var a: Dictionary = rings[i]
		var b: Dictionary = rings[i + 1]
		var wet: bool = a["wet"]
		var wall_c: Color = RIVER_TINT if wet else C_WALL
		var pts_a := _ring(a)
		var pts_b := _ring(b)
		# strips: floor, low band, wall, chamfer, roof, chamfer, wall, band
		var colors := [C_FLOOR, C_BAND, wall_c, C_ROOF, C_ROOF, C_ROOF, wall_c, C_BAND]
		for k in 8:
			var k2 := (k + 1) % 8
			_quad(st, pts_a[k], pts_a[k2], pts_b[k2], pts_b[k], _inward(a, k), colors[k])
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mi := MeshInstance3D.new()
	mi.name = "Shell"
	mi.mesh = mesh
	mi.material_override = mat
	root.add_child(mi)
	if with_collision and rings.size() > 1:
		var body := StaticBody3D.new()
		body.name = "TunnelCollision"
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		body.add_child(cs)
		root.add_child(body)
	_furniture(root, rings)
	return root


## Ring vertices (world): index 0..7 go round the section: floor-right, floor-left... see the colour list.
static func _ring(r: Dictionary) -> Array:
	var p: Vector3 = r["p"]
	var rt: Vector3 = r["right"]
	var up: Vector3 = r["up"]
	var w := HALF_WIDTH
	# order: floor(right->left), then up the left wall, across the roof, down the right wall
	return [
		p + rt * w + up * FLOOR_Y,                 # 0 floor right
		p - rt * w + up * FLOOR_Y,                 # 1 floor left
		p - rt * w + up * BAND_Y,                  # 2 band top, left
		p - rt * w + up * WALL_TOP_Y,              # 3 wall top, left
		p - rt * (w - CHAMFER) + up * HEAD_Y,      # 4 roof, left
		p + rt * (w - CHAMFER) + up * HEAD_Y,      # 5 roof, right
		p + rt * w + up * WALL_TOP_Y,              # 6 wall top, right
		p + rt * w + up * BAND_Y,                  # 7 band top, right
	]


## The interior-facing normal of strip k.
static func _inward(r: Dictionary, k: int) -> Vector3:
	var rt: Vector3 = r["right"]
	var up: Vector3 = r["up"]
	match k:
		0: return up                                   # floor
		1: return rt                                   # left lower wall faces right
		2: return rt
		3: return (rt + -up).normalized()              # left chamfer faces right-down
		4: return -up                                  # roof
		5: return (-rt + -up).normalized()             # right chamfer
		6: return -rt
		_: return -rt                                  # right lower band (index 7 closes back to 0)


## One quad a-b-c-d with the given inward normal (front face = clockwise seen from the normal side).
static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, color: Color) -> void:
	for tri in [[a, b, c], [a, c, d]]:
		var v0: Vector3 = tri[0]
		var v1: Vector3 = tri[1]
		var v2: Vector3 = tri[2]
		# Godot front faces are clockwise: the right-hand normal must point AWAY from the viewer
		if (v1 - v0).cross(v2 - v0).dot(n) > 0.0:
			var tmp := v1
			v1 = v2
			v2 = tmp
		for v in [v0, v1, v2]:
			st.set_color(color)
			st.set_normal(n)
			st.add_vertex(v)


## Rails, sleepers and lamps as MultiMeshes along the rings.
static func _furniture(root: Node3D, rings: Array) -> void:
	var rails: Array[Transform3D] = []
	var sleepers: Array[Transform3D] = []
	var lamps: Array[Transform3D] = []
	var wall_lamps: Array[Transform3D] = []
	var streaks: Array[Transform3D] = []
	var next_lamp := 0.0
	for i in range(rings.size() - 1):
		var a: Dictionary = rings[i]
		var b: Dictionary = rings[i + 1]
		var pa: Vector3 = a["p"]
		var pb: Vector3 = b["p"]
		var mid := (pa + pb) * 0.5
		var dir := (pb - pa).normalized()
		var rt: Vector3 = a["right"]
		var up: Vector3 = a["up"]
		var basis := Basis(dir, up, dir.cross(up))   # x along the track, y up, z across (right-handed: x cross y = z)
		for side in [-0.72, 0.72]:
			rails.append(Transform3D(basis, mid + rt * side + up * (FLOOR_Y + 0.08)))
		sleepers.append(Transform3D(basis, mid + up * (FLOOR_Y + 0.03)))
		for side in [-1.0, 1.0]:
			streaks.append(Transform3D(basis, mid + rt * (side * (HALF_WIDTH - 0.03)) + up * 2.45))
		var s: float = a["s"]
		if fmod(s - float(rings[0]["s"]), 6.0) < STEP:   # a wall lamp every 6 m, alternating sides: they flash past the windows
			var side := 1.0 if int((s - float(rings[0]["s"])) / 6.0) % 2 == 0 else -1.0
			wall_lamps.append(Transform3D(basis, mid + rt * (side * (HALF_WIDTH - 0.06)) + up * 1.5))
		if s >= next_lamp:
			lamps.append(Transform3D(basis, mid + up * (HEAD_Y - 0.06)))
			next_lamp = s + LAMP_SPACING
	_multi(root, "Rails", rails, Vector3(STEP + 0.05, 0.16, 0.1), Color(0.55, 0.55, 0.58), 0.0)
	_multi(root, "Sleepers", sleepers, Vector3(0.35, 0.06, 2.3), Color(0.20, 0.15, 0.12), 0.0)
	_multi(root, "WallGlow", streaks, Vector3(STEP + 0.05, 0.07, 0.05), Color(1.0, 0.72, 0.30), 1.6)
	_multi(root, "WallLamps", wall_lamps, Vector3(0.5, 0.4, 0.1), Color(1.0, 0.95, 0.8), 3.0)
	_multi(root, "Lamps", lamps, Vector3(1.6, 0.1, 0.4), Color(1.0, 0.93, 0.75), 2.5)


static func _multi(root: Node3D, node_name: String, xforms: Array[Transform3D], size: Vector3, color: Color, emit: float) -> void:
	if xforms.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = size
	mm.mesh = box
	mm.instance_count = xforms.size()
	for i in xforms.size():
		mm.set_instance_transform(i, xforms[i])
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	if emit > 0.0:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = emit
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	mmi.material_override = mat
	root.add_child(mmi)
