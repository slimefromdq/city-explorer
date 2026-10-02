# RoadBuilder - turns a RoadNetwork into 3D road and bridge meshes.
#
# One job: drape the road pieces over the terrain. Each road point takes the
# ground height at that spot (from TerrainHeight) plus a small lift so the road
# sits cleanly on top of the ground instead of flickering inside it.
extends RefCounted

const RibbonMesh := preload("res://city/ribbon_mesh.gd")

# Lift above the ground per road kind (m). Different lifts mean a street and an avenue
# crossing each other never occupy the same height, which would flicker.
const LIFT := {"street": 0.15, "avenue": 0.25, "diagonal": 0.35, "ring": 0.45, "quay": 0.5}
const BRIDGE_LIFT := 0.5   # same as the embankment, so a bridge meets it flush (roads end under it)
const KINDS := ["street", "avenue", "diagonal", "ring", "quay"]
const BRIDGE_STEP := 4.0
const CROSS_STEP := 2.0  # hillside roads must follow the terrain across their width

const COLORS := {
	"street": Color(0.20, 0.20, 0.22),
	"avenue": Color(0.29, 0.29, 0.31),
	"diagonal": Color(0.33, 0.30, 0.28),
	"ring": Color(0.25, 0.25, 0.27),
	"quay": Color(0.26, 0.27, 0.30),
}
const DECK_COLOR := Color(0.62, 0.61, 0.57)


# One MeshInstance3D "Roads" with one surface per road kind (so each kind has its own colour).
static func build_roads(network, terrain) -> MeshInstance3D:
	var mesh := ArrayMesh.new()
	for kind in KINDS:
		var combined := _empty_arrays()
		for seg in network.segments:
			if seg["kind"] != kind:
				continue
			_append(combined, draped_surface(seg["points"], float(seg["width"]), terrain, float(LIFT[kind])))
		if combined[Mesh.ARRAY_VERTEX].is_empty():
			continue
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
		mesh.surface_set_material(mesh.get_surface_count() - 1, _material(COLORS[kind]))
	var node := MeshInstance3D.new()
	node.name = "Roads"
	node.mesh = mesh
	return node


# Preserve the original road footprint and shared cross-sections at bends, but
# sample every transverse vertex. A centre-height ribbon cuts into uphill edges.
static func draped_surface(points: PackedVector2Array, width: float, terrain, lift: float) -> Array:
	var arrays := _empty_arrays()
	var across_steps := maxi(1, ceili(width / CROSS_STEP))
	var stride := across_steps + 1
	for i in points.size():
		var forward := (points[mini(i + 1, points.size() - 1)] - points[maxi(i - 1, 0)]).normalized()
		var across := Vector2(-forward.y, forward.x)
		for j in stride:
			var p := points[i] + across * width * (float(j) / across_steps - 0.5)
			var h: float = terrain.height_at(p)
			arrays[Mesh.ARRAY_VERTEX].append(Vector3(p.x, h + lift, p.y))
	var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	for i in points.size():
		for j in stride:
			var along := vertices[mini(i + 1, points.size() - 1) * stride + j] - vertices[maxi(i - 1, 0) * stride + j]
			var across := vertices[i * stride + mini(j + 1, across_steps)] - vertices[i * stride + maxi(j - 1, 0)]
			arrays[Mesh.ARRAY_NORMAL].append(across.cross(along).normalized())
	for i in points.size() - 1:
		for j in across_steps:
			var a := i * stride + j
			var b := a + stride
			arrays[Mesh.ARRAY_INDEX].append_array(PackedInt32Array([a, b, b + 1, a, b + 1, a + 1]))
	return arrays


# Bridges are thick ribbons. The deck follows the ground at both ends (so it meets
# the road flush) and arches up in the middle to clear the water.
static func build_bridges(network, terrain, arch_height: float, thickness: float) -> MeshInstance3D:
	var combined := _empty_arrays()
	for b in network.bridges:
		var a: Vector2 = b["from"]
		var c: Vector2 = b["to"]
		var h_a: float = terrain.height_at(a) + BRIDGE_LIFT
		var h_c: float = terrain.height_at(c) + BRIDGE_LIFT
		var steps := maxi(2, ceili(a.distance_to(c) / BRIDGE_STEP))
		var pts := PackedVector3Array()
		for i in steps + 1:
			var t := float(i) / steps
			var p := a.lerp(c, t)
			pts.append(Vector3(p.x, lerpf(h_a, h_c, t) + arch_height * sin(PI * t), p.y))
		_append(combined, RibbonMesh.build(pts, float(b["width"]), thickness))
	var mesh := ArrayMesh.new()
	if not combined[Mesh.ARRAY_VERTEX].is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, combined)
		mesh.surface_set_material(0, _material(DECK_COLOR))
	var node := MeshInstance3D.new()
	node.name = "Bridges"
	node.mesh = mesh
	return node


static func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat


static func _empty_arrays() -> Array:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array()
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array()
	arrays[Mesh.ARRAY_INDEX] = PackedInt32Array()
	return arrays


# Merge one ribbon into the combined arrays (indices shift by the vertices already there).
static func _append(into: Array, part: Array) -> void:
	var offset: int = (into[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
	into[Mesh.ARRAY_VERTEX].append_array(part[Mesh.ARRAY_VERTEX])
	into[Mesh.ARRAY_NORMAL].append_array(part[Mesh.ARRAY_NORMAL])
	for idx in part[Mesh.ARRAY_INDEX]:
		into[Mesh.ARRAY_INDEX].append(idx + offset)
