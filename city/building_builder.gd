# BuildingBuilder - draws the planned buildings with MultiMeshInstance3D.
#
# One job: draw the ordinary wall bodies. Each uses the SAME unit box, drawn
# many times with its own size, rotation, position and colour. Facade patterns use
# local metres and a shared material per district, keeping detail batched. That is what a
# MultiMesh is for: thousands of boxes cost the GPU about as much as one.
# One MultiMeshInstance3D per district. ArchitecturePlan supplies the reduced wall
# heights; ArchitectureBuilder draws crowns, roofs and the separate civic exteriors.
extends RefCounted

const LotBuilder := preload("res://city/lot_builder.gd")
const BuildingPlan := preload("res://city/building_plan.gd")
const FACADE := preload("res://city/district_facade.gdshader")

const FOUNDATION := 2.0  # the box reaches this far below its lowest corner, so a slope never shows a gap (m)

# Presentation only: wall colour by group (a little brightness variation is added per building).
const COLORS := {
	"core": Color(0.52, 0.63, 0.72),
	"financial": Color(0.40, 0.61, 0.61),
	"midrise": Color(0.68, 0.43, 0.30),
	"lowrise": Color(0.83, 0.73, 0.57),
	"harbour": Color(0.43, 0.52, 0.58),
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
	box.material = facade_material(group, float(items[0]["height"]) / int(items[0]["floors"]))

	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true  # must be set before instance_count
	multimesh.use_custom_data = true
	multimesh.mesh = box
	multimesh.instance_count = items.size()
	for i in items.size():
		var b: Dictionary = items[i]
		multimesh.set_instance_transform(i, _transform(b, terrain))
		multimesh.set_instance_color(i, _color(b))
		multimesh.set_instance_custom_data(i, Color(float(absi(hash(b["id"])) % 1000) / 1000.0, 0, 0, 0))

	var node := MultiMeshInstance3D.new()
	node.name = "Buildings_%s" % group
	node.multimesh = multimesh
	return node


# One material per group, not per building. Heights/floor counts come from the
# data-driven plan, so changing the JSON's floor height also changes the facade.
static func facade_material(group: String, floor_height: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = FACADE
	mat.set_shader_parameter("foundation", FOUNDATION)
	mat.set_shader_parameter("floor_height", floor_height)
	match group:
		"core":
			mat.set_shader_parameter("bay_width", 2.8)
			mat.set_shader_parameter("window_fraction", Vector2(0.88, 0.87))
			mat.set_shader_parameter("glass_color", Color(0.22, 0.37, 0.48))
			mat.set_shader_parameter("curtain_wall", 1.0)
		"financial":
			mat.set_shader_parameter("bay_width", 4.2)
			mat.set_shader_parameter("window_fraction", Vector2(0.90, 0.74))
			mat.set_shader_parameter("glass_color", Color(0.12, 0.31, 0.34))
			mat.set_shader_parameter("trim_color", Color(0.57, 0.67, 0.66))
			mat.set_shader_parameter("horizontal_bands", 1.0)
			mat.set_shader_parameter("curtain_wall", 1.0)
		"midrise":
			mat.set_shader_parameter("bay_width", 3.2)
			mat.set_shader_parameter("window_fraction", Vector2(0.62, 0.61))
			mat.set_shader_parameter("trim_color", Color(0.78, 0.67, 0.51))
			mat.set_shader_parameter("horizontal_bands", 0.6)
		"lowrise":
			mat.set_shader_parameter("bay_width", 2.6)
			mat.set_shader_parameter("window_fraction", Vector2(0.46, 0.59))
			mat.set_shader_parameter("trim_color", Color(0.52, 0.34, 0.23))
		"harbour":
			mat.set_shader_parameter("bay_width", 5.2)
			mat.set_shader_parameter("window_fraction", Vector2(0.72, 0.30))
			mat.set_shader_parameter("trim_color", Color(0.30, 0.39, 0.43))
			mat.set_shader_parameter("industrial", 1.0)
		"civic":
			mat.set_shader_parameter("bay_width", 4.5)
			mat.set_shader_parameter("window_fraction", Vector2(0.64, 0.72))
	return mat


# Position, rotation and size of one building. The box stands on the LOWEST point under its
# footprint, so on a hill it is flush downhill and partly buried uphill, never floating.
static func _transform(b: Dictionary, terrain) -> Transform3D:
	var u: Vector2 = b["u"]
	var size: Vector2 = b["size"]
	var low: float = BuildingPlan.base_elevation(b["center"], u, size, terrain)
	var along := Vector3(u.x, 0.0, u.y)
	var up := Vector3.UP
	var across := along.cross(up)  # keeps the transform right-handed (otherwise faces turn inside out)
	var total_height := float(b.get("render_height", b["height"])) + FOUNDATION
	var draw_size: Vector2 = b.get("render_size", size)
	var basis := Basis(along * draw_size.x, up * total_height, across * draw_size.y)
	return Transform3D(basis, Vector3(b["center"].x, low - FOUNDATION + total_height * 0.5, b["center"].y))


static func _color(b: Dictionary) -> Color:
	var base: Color
	if b["group"] == "civic":
		base = LotBuilder.SITE_COLORS.get(b["site_kind"], Color(0.6, 0.6, 0.6)).lightened(0.25)
	else:
		base = COLORS.get(b["group"], Color.MAGENTA)
		if b["group"] == "lowrise" and absi(hash(b["id"])) % 4 == 0:
			base = base.lerp(Color(0.67, 0.39, 0.27), 0.65)
	var shade := 0.88 + 0.24 * float(absi(hash(b["id"])) % 1000) / 1000.0
	return Color(base.r * shade, base.g * shade, base.b * shade)
