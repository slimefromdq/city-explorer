extends RefCounted
## Shared primitive meshes, batched by shape, with per-instance color. All
## transforms derive from the planned lot orientation and lowest base elevation.
const BuildingPlan := preload("res://city/building_plan.gd")

static func build(plan, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "Architecture"
	var groups := {}
	for part in plan.parts:
		if not groups.has(part["kind"]):
			groups[part["kind"]] = []
		groups[part["kind"]].append(part)
	for kind in groups:
		var mesh: Mesh
		match kind:
			"box": mesh = BoxMesh.new()
			"cylinder":
				var cylinder := CylinderMesh.new()
				cylinder.top_radius = 0.5
				cylinder.bottom_radius = 0.5
				cylinder.height = 1.0
				cylinder.radial_segments = 32
				mesh = cylinder
			_: mesh = _roof_mesh(kind == "shed")
		if mesh is BoxMesh:
			mesh.size = Vector3.ONE
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = mesh
		mm.instance_count = groups[kind].size()
		for i in mm.instance_count:
			var part: Dictionary = groups[kind][i]
			var frame := building_frame(part["building"], terrain)
			mm.set_instance_transform(i, frame * Transform3D(Basis.from_scale(part["size"]), part["center"]))
			mm.set_instance_color(i, part["color"])
		var mat := StandardMaterial3D.new()
		mat.vertex_color_use_as_albedo = true
		mat.roughness = 0.65 if kind != "box" else 0.8
		var node := MultiMeshInstance3D.new()
		node.name = "Architecture_%s" % kind
		node.multimesh = mm
		node.material_override = mat
		root.add_child(node)
	for site in plan.civic:
		var holder := Node3D.new()
		holder.name = "Civic_%s" % site["building"]["site_kind"]
		holder.transform = building_frame(site["building"], terrain)
		root.add_child(holder)
		var b: Dictionary = site["building"]
		for sign in [-1, 1]:
			Greybox.label(holder, String(site["name"]).to_upper(), Vector3(0, 6, sign * b["size"].y * 0.498), 0.0 if sign > 0 else PI, 0.60, Color(0.96, 0.91, 0.75))
	return root

static func building_frame(b: Dictionary, terrain) -> Transform3D:
	var u: Vector2 = b["u"]
	var x := Vector3(u.x, 0, u.y)
	var base: float = b.get("base_y", BuildingPlan.base_elevation(b["center"], u, b["size"], terrain))
	return Transform3D(Basis(x, Vector3.UP, x.cross(Vector3.UP)), Vector3(b["center"].x, base, b["center"].y))

static func _roof_mesh(shed: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Triangular prism along X, either centered ridge or north-light sawtooth.
	var ridge_z := 0.5 if shed else 0.0
	var a := Vector3(-0.5, -0.5, -0.5)
	var b := Vector3(-0.5, -0.5, 0.5)
	var c := Vector3(-0.5, 0.5, ridge_z)
	var d := Vector3(0.5, -0.5, -0.5)
	var e := Vector3(0.5, -0.5, 0.5)
	var f := Vector3(0.5, 0.5, ridge_z)
	for face in [[a, b, c], [d, f, e], [a, c, f, d], [c, b, e, f], [a, d, e, b]]:
		var normal: Vector3 = (face[1] - face[0]).cross(face[2] - face[0]).normalized()
		st.set_normal(normal)
		for index in ([0, 2, 1] if face.size() == 3 else [0, 2, 1, 0, 3, 2]):
			st.add_vertex(face[index])
	return st.commit()
