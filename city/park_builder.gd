# ParkBuilder - builds the named parts of Central Park and the footbridges over its creek.
#
# One job: turn the park zones in city.json into 3D, and the footbridges the greenery plan
# found into decks. Everything is placed from the data (zone polygons, court centres and
# directions) and rests on the ground at its spot.
#   cherry_garden / open_field: color lives on the terrain, avoiding overlapping faces.
#   Trees themselves come from the greenery layer.
#   basketball_court  a paved apron with marked courts (28 x 15 m) and a hoop at each end
extends RefCounted

const FlatPatch := preload("res://city/flat_patch.gd")
const CityData := preload("res://city/city_data.gd")

const COURT := Vector2(28.0, 15.0)   # a standard basketball court (m)
const KEY := Vector2(5.8, 4.9)       # the painted area under each hoop (m)
const LIFT := 0.20

const APRON := Color(0.52, 0.54, 0.58)
const COURT_BLUE := Color(0.18, 0.36, 0.62)
const KEY_RED := Color(0.72, 0.26, 0.22)
const LINE := Color(0.96, 0.96, 0.96)
const POLE := Color(0.25, 0.27, 0.30)
const BOARD := Color(0.94, 0.94, 0.96)
const RIM := Color(0.95, 0.45, 0.10)
const WOOD := Color(0.55, 0.38, 0.25)


static func build(city: Dictionary, greenery_plan, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "ParkFeatures"
	for zone in city["greenery"]["park_zones"]:
		var poly := CityData.to_points(zone["polygon"])
		match zone["kind"]:
			"cherry_garden":
				pass # Color is on the terrain mesh, not overlapping polygons.
			"open_field":
				pass
			"basketball_court":
				FlatPatch.add(root, poly, terrain, APRON, LIFT)
				for court in zone["courts"]:
					_court(root, Vector2(court["center"][0], court["center"][1]), deg_to_rad(float(court["yaw"])), terrain)
	for bridge in greenery_plan.footbridges:
		_footbridge(root, bridge, terrain, city.get("discovery_walk", {}).get("park_paths", []).has(bridge["path"]))
	return root


# ---- basketball court ------------------------------------------------------------

# One court: a blue slab, white lines, a painted key and a hoop at each end. `yaw` turns its
# long axis on the map (0 = along x).
static func _court(parent: Node3D, centre: Vector2, yaw: float, terrain) -> void:
	var holder := Node3D.new()
	holder.position = Vector3(centre.x, terrain.height_at(centre, false), centre.y)
	holder.rotation.y = -yaw
	parent.add_child(holder)
	var top := LIFT + 0.10
	_box(holder, Vector3(COURT.x, 0.12, COURT.y), Vector3(0.0, LIFT + 0.04, 0.0), COURT_BLUE)
	var half := COURT * 0.5
	for side in [-1.0, 1.0]:
		_box(holder, Vector3(KEY.x, 0.02, KEY.y), Vector3(side * (half.x - KEY.x * 0.5), top + 0.02, 0.0), KEY_RED)
	# boundary, halfway line and centre circle
	for edge_z in [-1.0, 1.0]:
		_box(holder, Vector3(COURT.x, 0.02, 0.12), Vector3(0.0, top + 0.04, edge_z * half.y), LINE)
	for edge_x in [-1.0, 1.0]:
		_box(holder, Vector3(0.12, 0.02, COURT.y), Vector3(edge_x * half.x, top + 0.04, 0.0), LINE)
	_box(holder, Vector3(0.12, 0.02, COURT.y), Vector3(0.0, top + 0.04, 0.0), LINE)
	var circle := TorusMesh.new()
	circle.inner_radius = 1.7
	circle.outer_radius = 1.82
	_part(holder, circle, Vector3(0.0, top + 0.05, 0.0), LINE, 1.0)
	for side in [-1.0, 1.0]:
		_hoop(holder, side, half.x)


# A hoop at one end: a post behind the baseline, an arm, a backboard and a ring.
static func _hoop(parent: Node3D, side: float, half_length: float) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.08
	post.bottom_radius = 0.1
	post.height = 3.6
	_part(parent, post, Vector3(side * (half_length + 1.0), LIFT + 1.8, 0.0), POLE, 0.6)
	_box(parent, Vector3(2.0, 0.1, 0.1), Vector3(side * (half_length + 0.05), LIFT + 3.2, 0.0), POLE)
	_box(parent, Vector3(0.06, 1.05, 1.8), Vector3(side * (half_length - 1.0), LIFT + 3.4, 0.0), BOARD)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.21
	ring.outer_radius = 0.25
	_part(parent, ring, Vector3(side * (half_length - 1.45), LIFT + 3.05, 0.0), RIM, 0.5)


# ---- footbridges -----------------------------------------------------------------

# A wooden deck with a handrail each side, level with the ground at both banks.
static func _footbridge(parent: Node3D, bridge: Dictionary, terrain, walkable := false) -> void:
	var a: Vector2 = bridge["from"]
	var b: Vector2 = bridge["to"]
	var centre := (a + b) * 0.5
	var width := float(bridge["width"])
	var holder := Node3D.new()
	holder.name = "Footbridge"
	parent.add_child(holder)
	# Follow the clipped path through bends instead of shortcutting its corner
	# with one straight box. Top remains 2 cm above the adjoining park paving.
	var points := PackedVector3Array()
	var top: float = terrain.height_at(centre, false) + 0.18
	for p in bridge["points"]:
		points.append(Vector3(p.x, top, p.y))
	var col := Greybox.body(holder, "BridgeCollision") if walkable else null
	_bridge_ribbon(holder, points, width, 0.35, WOOD, col)
	for side in [-1.0, 1.0]:
		var rail := PackedVector3Array()
		for i in points.size():
			var forward := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
			var across := forward.cross(Vector3.UP)
			rail.append(points[i] + across * side * (width * 0.5 - 0.06) + Vector3.UP * 0.9)
		_bridge_ribbon(holder, rail, 0.12, 0.9, WOOD.darkened(0.2), col)

static func _bridge_ribbon(parent: Node3D, points: PackedVector3Array, width: float, depth: float, color: Color, col: StaticBody3D) -> void:
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, preload("res://city/ribbon_mesh.gd").build(points, width, depth))
	_part(parent, mesh, Vector3.ZERO, color, 0.85)
	if col != null:
		var cs := CollisionShape3D.new()
		cs.shape = mesh.create_trimesh_shape()
		col.add_child(cs)


# ---- helpers ---------------------------------------------------------------------

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
