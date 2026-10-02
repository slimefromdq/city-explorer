extends RefCounted
const ArchitectureBuilder := preload("res://city/architecture_builder.gd")
const RibbonMesh := preload("res://city/ribbon_mesh.gd")

static func build(plan, terrain) -> Node3D:
	var root := ArchitectureBuilder.build(plan, terrain)
	root.name = "Harbour"
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for approach in plan.approaches:
		var mesh := ArrayMesh.new()
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, RibbonMesh.build(approach["points"], approach["width"], 0.4))
		st.append_from(mesh, 0, Transform3D.IDENTITY)
	if not plan.approaches.is_empty():
		var node := MeshInstance3D.new()
		node.name = "PierApproaches"
		node.mesh = st.commit()
		node.material_override = Greybox.mat(Color(0.57, 0.59, 0.56))
		root.add_child(node)
	return root
