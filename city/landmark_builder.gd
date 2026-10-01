# LandmarkBuilder - builds the landmarks from simple primitives.
#
# One job: give each landmark in city.json its 3D shape. Everything is boxes, cones,
# cylinders, spheres and a torus, sized from the landmark's height (and base width) in
# the data, so changing the height in the JSON changes the structure. Each landmark
# stands at its data position, turned by its data "yaw", on the lowest ground under
# its footprint.
#   tower             a steel lattice tower: four leaning legs, two platforms, a tapering
#                     needle and a beacon (the one tower the whole city is organised around)
#   observation_wheel an upright ring on an A-frame, with spokes and cabins
#   basilica          a stone nave with a domed crossing and a tall bell tower
extends RefCounted

const BuildingPlan := preload("res://city/building_plan.gd")

const STEEL := Color(0.30, 0.27, 0.25)
const PLATFORM := Color(0.58, 0.52, 0.46)
const BEACON := Color(1.0, 0.25, 0.2)
const WHEEL_FRAME := Color(0.85, 0.85, 0.88)
const CABIN := Color(0.25, 0.55, 0.78)
const STONE := Color(0.90, 0.86, 0.76)
const DOME := Color(0.50, 0.62, 0.58)
const ROOF := Color(0.55, 0.30, 0.22)
const FOUNDATION := 3.0  # structures reach this far below their lowest corner, so a slope shows no gap (m)


static func build_all(city: Dictionary, terrain) -> Node3D:
	var root := Node3D.new()
	root.name = "Landmarks"
	for lm in city["landmarks"]:
		var shape := Node3D.new()
		match lm["kind"]:
			"tower": _tower(shape, lm)
			"observation_wheel": _wheel(shape, lm)
			"basilica": _basilica(shape, lm)
			_:
				continue
		shape.name = "Landmark_%s" % lm["id"]
		var footprint := ground_footprint(lm)
		var yaw := deg_to_rad(float(lm.get("yaw", 0.0)))
		var centre := Vector2(lm["position"][0], lm["position"][1])
		var u := Vector2.from_angle(yaw)
		shape.position = Vector3(centre.x, BuildingPlan.base_elevation(centre, u, footprint["half"] * 2.0, terrain), centre.y)
		shape.rotation.y = -yaw  # a map angle runs from +x towards +y (south), which is -rotation about Y
		root.add_child(shape)
	return root


# The patch of ground a landmark stands on, as {"half": Vector2 (along its axis, across)}.
# (The validator checks this fits inside the lot or plaza reserved for the landmark.)
static func ground_footprint(lm: Dictionary) -> Dictionary:
	var h := float(lm["height"])
	match lm["kind"]:
		"tower":
			return {"half": Vector2.ONE * float(lm["base_width"]) * 0.5}
		"observation_wheel":
			return {"half": Vector2((h - 6.0) * 0.5 * 0.55, 6.0)}
		"basilica":
			return {"half": Vector2(11.0, 8.0)}
	return {"half": Vector2(5.0, 5.0)}


# ---- tower -------------------------------------------------------------------

static func _tower(parent: Node3D, lm: Dictionary) -> void:
	var h := float(lm["height"])
	var w := float(lm["base_width"])
	var y1 := h * 0.30  # first platform
	var y2 := h * 0.62  # second platform
	var y3 := h * 0.93  # where the needle ends and the antenna starts
	# four legs leaning inwards from the corners of the base to the first platform
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			var bottom := Vector3(sx * w * 0.5, 0.0, sz * w * 0.5)
			var top := Vector3(sx * w * 0.17, y1, sz * w * 0.17)
			_beam(parent, bottom, top, w * 0.10, STEEL)
	_box(parent, Vector3(w * 0.52, h * 0.016, w * 0.52), Vector3(0.0, y1, 0.0), PLATFORM)
	_frustum(parent, w * 0.17, w * 0.10, y1, y2, STEEL)
	_box(parent, Vector3(w * 0.34, h * 0.014, w * 0.34), Vector3(0.0, y2, 0.0), PLATFORM)
	_frustum(parent, w * 0.09, w * 0.02, y2, y3, STEEL)
	var antenna := CylinderMesh.new()
	antenna.top_radius = 0.25
	antenna.bottom_radius = 0.8
	antenna.height = h - y3
	antenna.radial_segments = 8
	_mesh(parent, antenna, Vector3(0.0, (y3 + h) * 0.5, 0.0), STEEL)
	var lamp := SphereMesh.new()
	lamp.radius = 2.4
	lamp.height = 4.8
	var lamp_node := _mesh(parent, lamp, Vector3(0.0, h, 0.0), BEACON)
	var lamp_mat := lamp_node.material_override as StandardMaterial3D
	lamp_mat.emission_enabled = true
	lamp_mat.emission = BEACON
	lamp_mat.emission_energy_multiplier = 2.0


# A square-sectioned tapering block (a 4-sided cone cut off at both ends).
static func _frustum(parent: Node3D, half_bottom: float, half_top: float, y_from: float, y_to: float, color: Color) -> void:
	var mesh := CylinderMesh.new()
	mesh.radial_segments = 4
	mesh.rings = 1
	mesh.bottom_radius = half_bottom * sqrt(2.0)  # a 4-sided "cylinder" is measured corner to centre
	mesh.top_radius = half_top * sqrt(2.0)
	mesh.height = y_to - y_from
	var node := _mesh(parent, mesh, Vector3(0.0, (y_from + y_to) * 0.5, 0.0), color)
	node.rotation.y = deg_to_rad(45.0)  # turn the diamond into a square aligned with the axes


# ---- observation wheel -------------------------------------------------------

static func _wheel(parent: Node3D, lm: Dictionary) -> void:
	var h := float(lm["height"])
	var radius := (h - 6.0) * 0.5
	var hub_y := 6.0 + radius
	var ring := TorusMesh.new()
	ring.inner_radius = radius - 1.0
	ring.outer_radius = radius + 1.0
	ring.rings = 56
	ring.ring_segments = 8
	var ring_node := _mesh(parent, ring, Vector3(0.0, hub_y, 0.0), WHEEL_FRAME)
	ring_node.rotation.x = deg_to_rad(90.0)  # stand the ring upright (it is modelled lying flat)
	for k in 8:  # 8 full-width spokes = 16 spokes
		var spoke := _box(parent, Vector3(radius * 2.0, 0.5, 0.5), Vector3(0.0, hub_y, 0.0), WHEEL_FRAME)
		spoke.rotation.z = deg_to_rad(22.5 * k)
	var hub := CylinderMesh.new()
	hub.top_radius = 3.0
	hub.bottom_radius = 3.0
	hub.height = 6.0
	var hub_node := _mesh(parent, hub, Vector3(0.0, hub_y, 0.0), STEEL)
	hub_node.rotation.x = deg_to_rad(90.0)
	for k in 16:  # passenger cabins hang around the rim and stay upright
		var angle := TAU * k / 16.0
		_box(parent, Vector3(5.0, 4.0, 3.0), Vector3(cos(angle) * radius, hub_y + sin(angle) * radius - 2.0, 0.0), CABIN)
	for side in [-1.0, 1.0]:  # the A-frame the wheel hangs on
		_beam(parent, Vector3(side * radius * 0.55, 0.0, 0.0), Vector3(0.0, hub_y, 0.0), 2.2, STEEL)
	_box(parent, Vector3(radius * 1.2, 1.0, 10.0), Vector3(0.0, 0.5, 0.0), PLATFORM)


# ---- basilica ----------------------------------------------------------------

static func _basilica(parent: Node3D, lm: Dictionary) -> void:
	var h := float(lm["height"])
	var nave_h := 16.0
	# nave: sunk into the ground by FOUNDATION so a hillside never leaves a gap beneath it
	_box(parent, Vector3(22.0, nave_h + FOUNDATION, 16.0), Vector3(0.0, (nave_h - FOUNDATION) * 0.5, 0.0), STONE)
	var roof := CylinderMesh.new()  # a 4-sided cone laid over the nave as a pitched roof cap
	roof.radial_segments = 4
	roof.bottom_radius = 13.0
	roof.top_radius = 9.0
	roof.height = 3.0
	var roof_node := _mesh(parent, roof, Vector3(0.0, nave_h + 1.5, 0.0), ROOF)
	roof_node.rotation.y = deg_to_rad(45.0)
	var drum := CylinderMesh.new()
	drum.top_radius = 6.2
	drum.bottom_radius = 6.2
	drum.height = 6.0
	_mesh(parent, drum, Vector3(0.0, nave_h + 3.0 + 3.0, 0.0), STONE)
	var dome := SphereMesh.new()
	dome.radius = 6.2
	dome.height = 6.2
	dome.is_hemisphere = true
	_mesh(parent, dome, Vector3(0.0, nave_h + 6.0 + 3.0, 0.0), DOME)
	var lantern := CylinderMesh.new()
	lantern.top_radius = 1.0
	lantern.bottom_radius = 1.4
	lantern.height = 5.0
	_mesh(parent, lantern, Vector3(0.0, nave_h + 6.0 + 3.0 + 6.2 + 2.0, 0.0), STONE)
	# bell tower on one corner, with a pyramid roof; its top is the landmark's full height
	var tower_h := h * 0.66
	_box(parent, Vector3(6.0, tower_h + FOUNDATION, 6.0), Vector3(8.0, (tower_h - FOUNDATION) * 0.5, -5.0), STONE)
	var spire := CylinderMesh.new()
	spire.radial_segments = 4
	spire.bottom_radius = 3.0 * sqrt(2.0)
	spire.top_radius = 0.0
	spire.height = h - tower_h
	var spire_node := _mesh(parent, spire, Vector3(8.0, tower_h + (h - tower_h) * 0.5, -5.0), ROOF)
	spire_node.rotation.y = deg_to_rad(45.0)


# ---- small helpers -----------------------------------------------------------

static func _mesh(parent: Node3D, mesh: Mesh, at: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	node.material_override = mat
	parent.add_child(node)
	return node


static func _box(parent: Node3D, size: Vector3, at: Vector3, color: Color) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	return _mesh(parent, box, at, color)


# A straight square beam between two points (a leg, a brace).
static func _beam(parent: Node3D, from: Vector3, to: Vector3, thickness: float, color: Color) -> void:
	var box := BoxMesh.new()
	box.size = Vector3(thickness, from.distance_to(to), thickness)
	var node := _mesh(parent, box, (from + to) * 0.5, color)
	node.basis = Basis(Quaternion(Vector3.UP, (to - from).normalized()))
