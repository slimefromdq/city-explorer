# PrecinctBuilder - builds what stands in Meridian Square around the tower.
#
# One job: turn the "precinct" features in city.json into 3D: lawns with a clipped hedge border,
# the fountain pool, the glass-vaulted mall at the foot of the tower, and the little shops.
# Positions, sizes and heights all come from the data, and every piece rests on the ground at
# its spot. (Trees in the gardens are planted by the greenery layer.)
extends RefCounted

const LIFT := 0.16  # paving is the lot patch at 0.12; lawns and pool sit a little above it

const LAWN := Color(0.36, 0.64, 0.30)
const HEDGE := Color(0.14, 0.38, 0.20)
const WATER := Color(0.20, 0.52, 0.72)
const FOUNTAIN := Color(0.92, 0.95, 1.0)
const MALL_WALL := Color(0.80, 0.80, 0.82)
const MALL_GLASS := Color(0.55, 0.78, 0.92, 0.55)
const ROOF := Color(0.30, 0.31, 0.34)
const SHOP_WALLS := [Color(0.92, 0.78, 0.62), Color(0.78, 0.86, 0.72), Color(0.95, 0.72, 0.72), Color(0.74, 0.80, 0.92)]
const AWNING := [Color(0.85, 0.25, 0.25), Color(0.25, 0.55, 0.85), Color(0.95, 0.75, 0.2), Color(0.3, 0.7, 0.4)]


static func build(city: Dictionary, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "Precinct"
	var shops := 0
	for feature in city["precinct"]["features"]:
		match feature["kind"]:
			"garden": _garden(root, feature, terrain)
			"pool": _pool(root, feature, terrain)
			"podium": _podium(root, feature, terrain)
			"pavilion":
				_pavilion(root, feature, terrain, shops)
				shops += 1
	return root


# A lawn, with a darker clipped hedge as a border (the hedge is the lawn's outline, the lawn is
# the same shape shrunk a little and laid just above it).
static func _garden(parent: Node3D, feature: Dictionary, terrain) -> void:
	var outline := PackedVector2Array()
	for p in feature["polygon"]:
		outline.append(Vector2(p[0], p[1]))
	_flat(parent, outline, terrain, HEDGE, LIFT + 0.05)
	for inner in Geometry2D.offset_polygon(outline, -1.4):
		_flat(parent, inner, terrain, LAWN, LIFT + 0.10)


static func _pool(parent: Node3D, feature: Dictionary, terrain) -> void:
	var centre := Vector2(feature["center"][0], feature["center"][1])
	var r := float(feature["radius"])
	var ground: float = terrain.height_at(centre)
	var rim := CylinderMesh.new()
	rim.top_radius = r + 1.2
	rim.bottom_radius = r + 1.2
	rim.height = 0.7
	_part(parent, rim, Vector3(centre.x, ground + 0.35, centre.y), Color(0.75, 0.74, 0.70), 0.9)
	var water := CylinderMesh.new()
	water.top_radius = r
	water.bottom_radius = r
	water.height = 0.5
	_part(parent, water, Vector3(centre.x, ground + 0.5, centre.y), WATER, 0.1)
	var jet := CylinderMesh.new()
	jet.top_radius = 0.15
	jet.bottom_radius = 0.7
	jet.height = 7.0
	_part(parent, jet, Vector3(centre.x, ground + 0.5 + 3.5, centre.y), FOUNTAIN, 0.3)


# A low hall: walls, a flat roof edge, and a glass barrel vault running along its length.
static func _podium(parent: Node3D, feature: Dictionary, terrain) -> void:
	var centre := Vector2(feature["center"][0], feature["center"][1])
	var size := Vector2(feature["size"][0], feature["size"][1])
	var yaw := deg_to_rad(float(feature.get("yaw", 0.0)))
	var h := float(feature["height"])
	var vault_h := h * 0.35
	var wall_h := h - vault_h
	var ground: float = terrain.height_at(centre)
	var holder := Node3D.new()
	holder.position = Vector3(centre.x, ground, centre.y)
	holder.rotation.y = -yaw
	parent.add_child(holder)
	_box(holder, Vector3(size.x, wall_h, size.y), Vector3(0.0, wall_h * 0.5, 0.0), MALL_WALL)
	_box(holder, Vector3(size.x + 1.0, 0.8, size.y + 1.0), Vector3(0.0, wall_h + 0.4, 0.0), ROOF)
	# the vault: a cylinder lying along the hall, squashed to the vault height, half sunk into the roof
	var vault := CylinderMesh.new()
	vault.top_radius = size.y * 0.5 * 0.9
	vault.bottom_radius = size.y * 0.5 * 0.9
	vault.height = size.x * 0.96
	var node := _part(holder, vault, Vector3(0.0, wall_h + 0.8, 0.0), MALL_GLASS, 0.1)
	node.rotation.z = deg_to_rad(90.0)
	node.scale = Vector3(vault_h / (size.y * 0.5 * 0.9), 1.0, 1.0)  # after the 90 degree turn, local x is vertical
	var mat := node.material_override as StandardMaterial3D
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.metallic = 0.5


# A small shop: coloured walls, a dark roof slab and a striped awning on the side facing the tower.
static func _pavilion(parent: Node3D, feature: Dictionary, terrain, index: int) -> void:
	var centre := Vector2(feature["center"][0], feature["center"][1])
	var size := Vector2(feature["size"][0], feature["size"][1])
	var yaw := deg_to_rad(float(feature.get("yaw", 0.0)))
	var h := float(feature["height"])
	var ground: float = terrain.height_at(centre)
	var holder := Node3D.new()
	holder.position = Vector3(centre.x, ground, centre.y)
	holder.rotation.y = -yaw
	parent.add_child(holder)
	_box(holder, Vector3(size.x, h, size.y), Vector3(0.0, h * 0.5, 0.0), SHOP_WALLS[index % SHOP_WALLS.size()])
	_box(holder, Vector3(size.x + 1.2, 0.4, size.y + 1.2), Vector3(0.0, h + 0.2, 0.0), ROOF)
	var toward_tower := 1.0 if centre.y < 325.0 else -1.0  # awning faces the tower (it stands at y = 325)
	_box(holder, Vector3(size.x * 0.8, 0.3, 2.2), Vector3(0.0, h * 0.62, toward_tower * (size.y * 0.5 + 1.1)), AWNING[index % AWNING.size()])


# ---- helpers -----------------------------------------------------------------------

# A flat coloured patch lying on the terrain, following its height at every corner.
static func _flat(parent: Node3D, poly: PackedVector2Array, terrain, color: Color, lift: float) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for p in poly:
		verts.append(Vector3(p.x, terrain.height_at(p) + lift, p.y))
	for t in range(0, tris.size(), 3):
		var a := poly[tris[t]]
		var b := poly[tris[t + 1]]
		var c := poly[tris[t + 2]]
		if (b - a).cross(c - a) > 0.0:
			indices.append_array([tris[t], tris[t + 1], tris[t + 2]])
		else:
			indices.append_array([tris[t], tris[t + 2], tris[t + 1]])
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 1.0
	node.material_override = mat
	parent.add_child(node)


static func _part(parent: Node3D, mesh: Mesh, at: Vector3, color: Color, roughness: float) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	node.material_override = mat
	parent.add_child(node)
	return node


static func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _part(parent, box, at, color, 0.85)
