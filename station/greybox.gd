class_name Greybox
extends RefCounted
## Small helpers for building greybox geometry from primitive meshes, with optional collision.
## Everything takes/returns plain nodes; materials are cached by their parameters.

static var _mats := {}


static func mat(color: Color, rough := 1.0, emit := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [color.to_html(true), rough, emit, alpha]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(color.r, color.g, color.b, alpha)
	m.roughness = rough
	if emit > 0.0:
		m.emission_enabled = true
		m.emission = color
		m.emission_energy_multiplier = emit
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mats[key] = m
	return m


## A StaticBody3D under `parent` that gathers box/cylinder shapes (so one node holds many shapes).
static func body(parent: Node, body_name := "Collision") -> StaticBody3D:
	var b := StaticBody3D.new()
	b.name = body_name
	parent.add_child(b)
	return b


## A box centred on `pos` (parent space). `col` (optional) is a body in the SAME space that gets a matching shape.
static func box(parent: Node3D, size: Vector3, pos: Vector3, m: Material, col: StaticBody3D = null, rot_y := 0.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation.y = rot_y
	parent.add_child(mi)
	if col != null:
		add_box_shape(col, size, pos, rot_y)
	return mi


## A box from corner `lo` to corner `hi` (any order).
static func box_ab(parent: Node3D, a: Vector3, b: Vector3, m: Material, col: StaticBody3D = null) -> MeshInstance3D:
	var lo := Vector3(minf(a.x, b.x), minf(a.y, b.y), minf(a.z, b.z))
	var hi := Vector3(maxf(a.x, b.x), maxf(a.y, b.y), maxf(a.z, b.z))
	return box(parent, hi - lo, (lo + hi) * 0.5, m, col)


static func add_box_shape(col: StaticBody3D, size: Vector3, pos: Vector3, rot_y := 0.0, rot_x := 0.0) -> void:
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	cs.position = pos
	cs.rotation = Vector3(rot_x, rot_y, 0.0)
	col.add_child(cs)


## A cylinder with its axis along Y (rot = Basis-free Euler to tip it over).
static func cyl(parent: Node3D, radius: float, height: float, pos: Vector3, m: Material, col: StaticBody3D = null, rot := Vector3.ZERO, sides := 24, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius if top_radius < 0.0 else top_radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = sides
	mesh.rings = 1
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	mi.rotation = rot
	parent.add_child(mi)
	if col != null:
		var cs := CollisionShape3D.new()
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = height
		cs.shape = shape
		cs.position = pos
		cs.rotation = rot
		col.add_child(cs)
	return mi


static func sphere(parent: Node3D, radius: float, pos: Vector3, m: Material, squash := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 * squash
	mesh.radial_segments = 16
	mesh.rings = 8
	mi.mesh = mesh
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## A triangular prism (gable): base on y=0 spanning z in [-half_w, half_w], apex at height `rise`,
## extruded along x from 0 to `depth`.
static func gable(parent: Node3D, half_w: float, rise: float, depth: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var p := [Vector3(0, 0, -half_w), Vector3(0, 0, half_w), Vector3(0, rise, 0),
		Vector3(depth, 0, -half_w), Vector3(depth, 0, half_w), Vector3(depth, rise, 0)]
	# front (x=depth side faces +x), back, sloped sides, bottom; winding is clockwise seen from outside
	var tris := [[3, 5, 4], [0, 1, 2], [0, 2, 5, 3], [1, 4, 5, 2], [0, 3, 4, 1]]
	for t in tris:
		if t.size() == 3:
			st.add_vertex(p[t[0]]); st.add_vertex(p[t[1]]); st.add_vertex(p[t[2]])
		else:
			st.add_vertex(p[t[0]]); st.add_vertex(p[t[1]]); st.add_vertex(p[t[2]])
			st.add_vertex(p[t[0]]); st.add_vertex(p[t[2]]); st.add_vertex(p[t[3]])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


## A four-sided pyramid roof: square-ish base centred on pos (y = base), apex `rise` above.
static func pyramid(parent: Node3D, size_x: float, size_z: float, rise: float, pos: Vector3, m: Material) -> MeshInstance3D:
	var hx := size_x * 0.5
	var hz := size_z * 0.5
	var c := [Vector3(-hx, 0, -hz), Vector3(hx, 0, -hz), Vector3(hx, 0, hz), Vector3(-hx, 0, hz)]
	var apex := Vector3(0, rise, 0)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = c[i]
		var b: Vector3 = c[(i + 1) % 4]
		st.add_vertex(a); st.add_vertex(apex); st.add_vertex(b)
	st.add_vertex(c[0]); st.add_vertex(c[1]); st.add_vertex(c[2])
	st.add_vertex(c[0]); st.add_vertex(c[2]); st.add_vertex(c[3])
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = m
	mi.position = pos
	parent.add_child(mi)
	return mi


static func label(parent: Node3D, text: String, pos: Vector3, rot_y: float, size: float, color := Color.WHITE, emit := true, bold := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = not emit
	l.double_sided = false
	l.position = pos
	l.rotation.y = rot_y
	parent.add_child(l)
	return l


static func omni(parent: Node3D, pos: Vector3, energy: float, rng: float, color := Color(1.0, 0.92, 0.76)) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.position = pos
	l.light_energy = energy
	l.omni_range = rng
	l.light_color = color
	l.shadow_enabled = false
	parent.add_child(l)
	return l
