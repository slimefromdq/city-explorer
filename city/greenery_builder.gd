# GreeneryBuilder - draws the trees, green roofs, sky gardens and footpaths.
#
# One job: turn the GreeneryPlan into 3D. Trees are the big count, so they are MultiMeshes
# (trunks, round crowns and conical crowns each one MultiMesh). Roof gardens and sky-garden
# bands are green boxes placed on top of / around the planned buildings. Footpaths are ribbons
# draped over the terrain.
extends RefCounted

const BuildingPlan := preload("res://city/building_plan.gd")
const RibbonMesh := preload("res://city/ribbon_mesh.gd")

const TRUNK_HEIGHT := 3.0
const ROUND_RADIUS := 3.2   # a round crown is a sphere of this radius
const CONE_RADIUS := 3.0
const CONE_HEIGHT := 7.0
const PATH_LIFT := 0.16
const BAND_HEIGHT := 1.4

const TRUNK := Color(0.38, 0.27, 0.18)
const PATH := Color(0.80, 0.72, 0.56)


static func build(plan, building_plan, terrain, city: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Greenery"
	_trees(root, plan.trees, terrain)
	var by_id := {}
	for b in building_plan.buildings:
		by_id[b["id"]] = b
	var roof_h := float(city["greenery"]["roof_garden_height"])
	root.add_child(_green_boxes("RoofGardens", plan.roofs, by_id, terrain, roof_h, false))
	root.add_child(_green_boxes("SkyGardens", plan.sky_gardens, by_id, terrain, BAND_HEIGHT, true))
	var replaced: Array = []
	for spur in city.get("discovery_walk", {}).get("spurs", []):
		replaced.append(spur.get("replaces_path", ""))
	root.add_child(_paths(plan.paths, terrain, replaced))
	return root


# ---- trees -------------------------------------------------------------------------

static func _trees(root: Node3D, trees: Array, terrain) -> void:
	var round_trees: Array = []
	var cone_trees: Array = []
	for t in trees:
		(round_trees if t["kind"] == "round" else cone_trees).append(t)
	# trunk: one MultiMesh for all trees
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.22
	trunk.bottom_radius = 0.32
	trunk.height = TRUNK_HEIGHT
	root.add_child(_tree_group("TreeTrunks", trunk, trees, terrain, TRUNK_HEIGHT * 0.5, 1.0, false))
	var sphere := SphereMesh.new()
	sphere.radius = ROUND_RADIUS
	sphere.height = ROUND_RADIUS * 2.0
	sphere.radial_segments = 12
	sphere.rings = 6
	root.add_child(_tree_group("TreeCrownsRound", sphere, round_trees, terrain, TRUNK_HEIGHT + ROUND_RADIUS, 1.0, true))
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = CONE_RADIUS
	cone.height = CONE_HEIGHT
	cone.radial_segments = 10
	root.add_child(_tree_group("TreeCrownsCone", cone, cone_trees, terrain, TRUNK_HEIGHT + CONE_HEIGHT * 0.5, 1.0, true))


static func _tree_group(label: String, mesh: Mesh, items: Array, terrain, lift: float, _unused: float, colored: bool) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.95
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = mesh
	multimesh.instance_count = items.size()
	for i in items.size():
		var t: Dictionary = items[i]
		var p: Vector2 = t["pos"]
		var s := float(t["scale"])
		var base: float = terrain.height_at(p)
		multimesh.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * s), Vector3(p.x, base + lift * s, p.y)))
		multimesh.set_instance_color(i, _crown_color(t) if colored else TRUNK)
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multimesh
	node.material_override = mat
	return node


static func _crown_color(t: Dictionary) -> Color:
	var tint := float(t["tint"])
	if t["zone"] == "cherry":
		return Color(0.98, 0.76, 0.84).lerp(Color(0.93, 0.58, 0.74), tint)  # the cherry blossom garden: brighter pinks
	if t["zone"] == "garden" and t["kind"] == "round":
		return Color(0.95, 0.66, 0.74).lerp(Color(0.88, 0.50, 0.66), tint)  # blossom trees in the square
	if t["kind"] == "cone":
		return Color(0.14, 0.38, 0.22).lerp(Color(0.22, 0.50, 0.28), tint)
	return Color(0.26, 0.56, 0.26).lerp(Color(0.42, 0.66, 0.30), tint)


# ---- roof gardens and sky gardens ---------------------------------------------------

# A green slab for each entry. A roof garden sits ON TOP of the building; a sky-garden band wraps
# around it at a floor level (so it stands `level` metres above the building's base).
static func _green_boxes(label: String, items: Array, by_id: Dictionary, terrain, thickness: float, is_band: bool) -> MultiMeshInstance3D:
	var box := BoxMesh.new()
	box.size = Vector3.ONE
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	box.material = mat
	var multimesh := MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.use_colors = true
	multimesh.mesh = box
	multimesh.instance_count = items.size()
	for i in items.size():
		var item: Dictionary = items[i]
		var b: Dictionary = by_id[item["building"]]
		var base: float = BuildingPlan.base_elevation(b["center"], b["u"], b["size"], terrain)
		var y := base + (float(item["level"]) if is_band else float(b["height"])) + thickness * 0.5
		var u: Vector2 = item["u"]
		var along := Vector3(u.x, 0.0, u.y)
		var basis := Basis(along * item["size"].x, Vector3.UP * thickness, along.cross(Vector3.UP) * item["size"].y)
		multimesh.set_instance_transform(i, Transform3D(basis, Vector3(item["center"].x, y, item["center"].y)))
		var shade := 0.85 + 0.3 * float(absi(hash(item["building"] + str(item.get("level", 0)))) % 1000) / 1000.0
		multimesh.set_instance_color(i, Color(0.20 * shade, 0.44 * shade, 0.20 * shade))
	var node := MultiMeshInstance3D.new()
	node.name = label
	node.multimesh = multimesh
	return node


# ---- footpaths ----------------------------------------------------------------------

static func _paths(paths: Array, terrain, replaced: Array = []) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	for path in paths:
		# The playable spur owns this paving, avoiding coplanar path meshes.
		if replaced.has(path["name"]):
			continue
		var pts := PackedVector3Array()
		for p in path["points"]:
			pts.append(Vector3(p.x, terrain.height_at(p, false) + PATH_LIFT, p.y))  # level over creeks (a footbridge carries it)
		var part := RibbonMesh.build(pts, float(path["width"]))
		var offset := verts.size()
		verts.append_array(part[Mesh.ARRAY_VERTEX])
		normals.append_array(part[Mesh.ARRAY_NORMAL])
		for idx in part[Mesh.ARRAY_INDEX]:
			indices.append(idx + offset)
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		var arrays := []
		arrays.resize(Mesh.ARRAY_MAX)
		arrays[Mesh.ARRAY_VERTEX] = verts
		arrays[Mesh.ARRAY_NORMAL] = normals
		arrays[Mesh.ARRAY_INDEX] = indices
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = PATH
	mat.roughness = 1.0
	var node := MeshInstance3D.new()
	node.name = "Paths"
	node.mesh = mesh
	node.material_override = mat
	return node
