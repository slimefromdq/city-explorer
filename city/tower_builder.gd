# TowerBuilder - builds the landmark tower: a slender glass skyscraper.
#
# One job: the shape of Meridian Tower. It is modelled on the very tall, smoothly tapering
# glass towers of modern skylines: a rounded-square plan that narrows gently with height,
# a finely ruled glass curtain wall, and an open lattice crown with a glowing core. Its
# size comes from the landmark's data (height, base_width, top_ratio, crown share), so
# editing the JSON reshapes the tower.
#
# The body is one generated mesh: a stack of rings, each a rounded square (a "superellipse")
# whose width shrinks with height. The crown is the same shape drawn as an open lattice.
extends RefCounted

const GLASS_SHADER := preload("res://city/glass_facade.gdshader")

const RINGS := 56          # horizontal slices up the tower
const SIDES := 64          # points around each slice
const BAYS := 96           # vertical glass frames around the tower
const CORNER_SHARPNESS := 5.0  # 2 = a circle, large = a square; ~5 = a soft rounded square
const TAPER_CURVE := 1.1       # >1: wider for longer, then narrowing faster toward the top
const LIFT := 0.0

const FRAME := Color(0.82, 0.87, 0.92)
const CORE_GLOW := Color(1.0, 0.78, 0.45)
const CAP := Color(0.24, 0.27, 0.31)
const BEACON := Color(1.0, 0.3, 0.25)


# Returns a Node3D with the tower standing at its local origin (ground level, y = 0).
static func build(lm: Dictionary) -> Node3D:
	var root := Node3D.new()
	var h := float(lm["height"])
	var base_half := float(lm["base_width"]) * 0.5
	var top_ratio := float(lm["top_ratio"])
	var crown_share := float(lm["crown"])
	var crown_start := h * (1.0 - crown_share)

	# the glass body, from the ground to the start of the crown
	root.add_child(_shell("Body", base_half, top_ratio, h, 0.0, crown_start, 0.0, false))
	# the open lattice crown above it
	root.add_child(_shell("Crown", base_half, top_ratio, h, crown_start, h, 0.0, true))

	# a glowing core inside the crown, so the open lattice reads as a lantern
	var crown_height := h - crown_start
	var core_half := _half_width(base_half, top_ratio, (crown_start + h) * 0.5 / h) * 0.4
	var core := BoxMesh.new()
	core.size = Vector3(core_half * 2.0, crown_height * 0.92, core_half * 2.0)
	var core_node := _part(root, core, Vector3(0.0, crown_start + crown_height * 0.5, 0.0), CORE_GLOW)
	var core_mat := core_node.material_override as StandardMaterial3D
	core_mat.emission_enabled = true
	core_mat.emission = CORE_GLOW
	core_mat.emission_energy_multiplier = 0.9

	# a flat cap, a short mast and a beacon
	var top_half := _half_width(base_half, top_ratio, 1.0)
	var cap := BoxMesh.new()
	cap.size = Vector3(top_half * 1.9, 1.4, top_half * 1.9)
	_part(root, cap, Vector3(0.0, h + 0.7, 0.0), CAP)
	var mast := CylinderMesh.new()
	mast.top_radius = 0.2
	mast.bottom_radius = 0.7
	mast.height = h * 0.02
	mast.height = maxf(mast.height, 4.0)
	mast.radial_segments = 8
	_part(root, mast, Vector3(0.0, h + 1.6 + mast.height * 0.5, 0.0), FRAME)
	var lamp := SphereMesh.new()
	lamp.radius = 1.6
	lamp.height = 3.2
	var lamp_node := _part(root, lamp, Vector3(0.0, h + 1.6 + mast.height + 1.0, 0.0), BEACON)
	var lamp_mat := lamp_node.material_override as StandardMaterial3D
	lamp_mat.emission_enabled = true
	lamp_mat.emission = BEACON
	lamp_mat.emission_energy_multiplier = 2.5
	return root


# Half the tower's width at height fraction t (0 = ground, 1 = top): a smooth taper.
static func _half_width(base_half: float, top_ratio: float, t: float) -> float:
	return base_half * (1.0 - (1.0 - top_ratio) * pow(clampf(t, 0.0, 1.0), TAPER_CURVE))


# A tube of rounded-square slices between two heights.
static func _shell(label: String, base_half: float, top_ratio: float, total_height: float, y_from: float, y_to: float, _unused: float, open_lattice: bool) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	var columns := SIDES + 1  # one extra so the texture wraps without a seam
	for r in RINGS + 1:
		var y := lerpf(y_from, y_to, float(r) / RINGS)
		var half := _half_width(base_half, top_ratio, y / total_height)
		for k in columns:
			var angle := TAU * float(k) / SIDES
			var p := _plan_point(angle, half)
			verts.append(Vector3(p.x, y, p.y))
			uvs.append(Vector2(float(k) / SIDES * BAYS, y))
	# normals from the neighbouring points (so the rounded corners shade smoothly)
	for r in RINGS + 1:
		for k in columns:
			var here := verts[r * columns + k]
			var next_k := verts[r * columns + (k + 1) % columns if k < SIDES else r * columns + 1]
			var prev_k := verts[r * columns + (k - 1 + SIDES) % SIDES if k > 0 else r * columns + SIDES - 1]
			var up := verts[mini(r + 1, RINGS) * columns + k] - verts[maxi(r - 1, 0) * columns + k]
			var around := next_k - prev_k
			var n := around.cross(up).normalized()
			if n.dot(Vector3(here.x, 0.0, here.z)) < 0.0:
				n = -n
			normals.append(n)
	# triangles, clockwise seen from outside (Godot's front face)
	for r in RINGS:
		for k in SIDES:
			var a := r * columns + k
			var b := a + 1
			var c := a + columns
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := ShaderMaterial.new()
	mat.shader = GLASS_SHADER
	mat.set_shader_parameter("lattice", 1.0 if open_lattice else 0.0)
	mat.set_shader_parameter("emission_strength", 0.6 if open_lattice else 0.0)
	var node := MeshInstance3D.new()
	node.name = label
	node.mesh = mesh
	node.material_override = mat
	if open_lattice:
		mat.render_priority = 0
	return node


# A point on the rounded-square outline of the given half-width, at the given angle.
static func _plan_point(angle: float, half: float) -> Vector2:
	var c := cos(angle)
	var s := sin(angle)
	var e := 2.0 / CORNER_SHARPNESS
	return Vector2(half * signf(c) * pow(absf(c), e), half * signf(s) * pow(absf(s), e))


static func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.5
	node.material_override = mat
	parent.add_child(node)
	return node
