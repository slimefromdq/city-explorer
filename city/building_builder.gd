# BuildingBuilder - draws the planned buildings with MultiMeshInstance3D.
#
# One job: turn the BuildingPlan into 3D. Every building is the SAME unit box, drawn
# many times with its own size, rotation, position and colour. That is what a
# MultiMesh is for: thousands of boxes cost the GPU about as much as one.
# One MultiMeshInstance3D per group (each district type, plus civic buildings) so each
# group can later get its own look, lights or level of detail.
extends RefCounted

const LotBuilder := preload("res://city/lot_builder.gd")
const BuildingPlan := preload("res://city/building_plan.gd")

const FOUNDATION := 2.0  # the box reaches this far below its lowest corner, so a slope never shows a gap (m)

# Presentation only: wall colour by group (a little brightness variation is added per building).
const COLORS := {
	"core": Color(0.55, 0.62, 0.72),
	"financial": Color(0.72, 0.62, 0.70),
	"midrise": Color(0.76, 0.68, 0.58),
	"lowrise": Color(0.82, 0.76, 0.66),
	"harbour": Color(0.55, 0.60, 0.62),
}


# Returns a Node3D "Buildings" holding one MultiMeshInstance3D per group.
static func build(plan, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "Buildings"
	var groups := {}
	for b in plan.buildings:
		if not groups.has(b["group"]):
			groups[b["group"]] = []
		groups[b["group"]].append(b)
	for group in groups:
		root.add_child(_group_instance(group, groups[group], terrain))
	return root


static func _group_instance(group: String, items: Array, terrain) -> MultiMeshInstance3D:
	# A 1 x 1 x 1 box, centred on its origin; each instance scales it and lifts it by half its height.
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true  # the per-instance colour
	mat.roughness = 0.85
	box.material = mat

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true  # must be set before instance_count
	multimesh.mesh = box
	multimesh.instance_count = items.size()
	for i in items.size():
		var b: Dictionary = items[i]
		multimesh.set_instance_transform(i, _transform(b, terrain))
		multimesh.set_instance_color(i, _color(b))

	var node := MultiMeshInstance3D.new()
	node.name = "Buildings_%s" % group
	node.multimesh = multimesh
	return node


# Position, rotation and size of one building. The box stands on the LOWEST point under its
# footprint, so on a hill it is flush downhill and partly buried uphill, never floating.
static func _transform(b: Dictionary, terrain) -> Transform3D:
	var u: Vector2 = b["u"]
	var size: Vector2 = b["size"]
	var low: float = BuildingPlan.base_elevation(b["center"], u, size, terrain)
	var along := Vector3(u.x, 0.0, u.y)
	var up := Vector3.UP
	var across := along.cross(up)  # keeps the transform right-handed (otherwise faces turn inside out)
	var total_height := float(b["height"]) + FOUNDATION
	var basis := Basis(along * size.x, up * total_height, across * size.y)
	return Transform3D(basis, Vector3(b["center"].x, low - FOUNDATION + total_height * 0.5, b["center"].y))


static func _color(b: Dictionary) -> Color:
	var base: Color
	if b["group"] == "civic":
		base = LotBuilder.SITE_COLORS.get(b["site_kind"], Color(0.6, 0.6, 0.6)).lightened(0.25)
	else:
		base = COLORS.get(b["group"], Color.MAGENTA)
	var shade := 0.88 + 0.24 * float(absi(hash(b["id"])) % 1000) / 1000.0
	return Color(base.r * shade, base.g * shade, base.b * shade)
