# SignBuilder - draws the neon signs with a MultiMesh.
#
# One job: turn the SignPlan into glowing coloured panels. Every sign is the same unit box
# with its own size, position, direction and colour. The material is "unshaded" (it ignores
# lighting) so the colours stay bright and read as lit signs even in shadow.
extends RefCounted

const BuildingPlan := preload("res://city/building_plan.gd")

const NEON := [
	Color(1.0, 0.20, 0.60), Color(0.20, 0.90, 1.0), Color(1.0, 0.92, 0.20), Color(1.0, 0.30, 0.20),
	Color(0.50, 1.0, 0.30), Color(1.0, 0.55, 0.10), Color(0.95, 0.95, 1.0),
]


static func build(plan, building_plan, terrain) -> MultiMeshInstance3D:
	var by_id := {}
	for b in building_plan.buildings:
		by_id[b["id"]] = b
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.vertex_color_use_as_albedo = true
	box.material = mat
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = plan.signs.size()
	for i in plan.signs.size():
		var s: Dictionary = plan.signs[i]
		var b: Dictionary = by_id[s["building"]]
		var normal: Vector2 = s["normal"]
		var pos: Vector2 = s["pos"]
		var size: Vector3 = s["size"]
		# stand on the building's base, but never below the ground at the wall itself (uphill walls)
		var base: float = maxf(BuildingPlan.base_elevation(b["center"], b["u"], b["size"], terrain), terrain.height_at(pos))
		var out := Vector3(normal.x, 0.0, normal.y)
		var along := Vector3(normal.y, 0.0, -normal.x)  # chosen so (along, up, out) is right-handed
		var basis := Basis(along * size.x, Vector3.UP * size.y, out * size.z)
		var centre := Vector3(pos.x, base + float(s["above_base"]) + size.y * 0.5, pos.y) + out * (size.z * 0.5 + 0.03)
		multimesh.set_instance_transform(i, Transform3D(basis, centre))
		multimesh.set_instance_color(i, NEON[int(s["color"])])
	var node := MultiMeshInstance3D.new()
	node.name = "Signs"
	node.multimesh = multimesh
	return node
