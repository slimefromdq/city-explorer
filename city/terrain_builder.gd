# TerrainBuilder - turns a TerrainHeight into a 3D ground mesh.
#
# One job: sample the height function on a regular grid and make triangles.
# WHY a grid: it is the simplest mesh that can show any height field, and the
# vertex spacing (mesh_cell_size in the JSON) is the only quality knob.
# Map (x, y) becomes 3D (x, height, z).
extends RefCounted

const GRASS := Color(0.42, 0.58, 0.32)
const ROCK := Color(0.52, 0.48, 0.42)
const SAND := Color(0.80, 0.74, 0.55)
const SEABED := Color(0.45, 0.42, 0.33)


# `area` is the part of the map to cover, in map metres. The caller passes the
# map plus a margin so the sea floor does not end in a visible edge.
static func build(terrain, area: Rect2, cell: float) -> ArrayMesh:
	var cols := int(ceil(area.size.x / cell))
	var rows := int(ceil(area.size.y / cell))
	var heights := PackedFloat32Array()
	heights.resize((cols + 1) * (rows + 1))
	for j in rows + 1:
		for i in cols + 1:
			heights[j * (cols + 1) + i] = terrain.height_at(area.position + Vector2(i, j) * cell)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for j in rows + 1:
		for i in cols + 1:
			var h := heights[j * (cols + 1) + i]
			verts.append(Vector3(area.position.x + i * cell, h, area.position.y + j * cell))
			# Normal from the height difference of the neighbours: smooth shading for free.
			var hx := heights[j * (cols + 1) + mini(i + 1, cols)] - heights[j * (cols + 1) + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, rows) * (cols + 1) + i] - heights[maxi(j - 1, 0) * (cols + 1) + i]
			var run_x := cell * (mini(i + 1, cols) - maxi(i - 1, 0))
			var run_z := cell * (mini(j + 1, rows) - maxi(j - 1, 0))
			var n := Vector3(-hx / run_x, 1.0, -hz / run_z).normalized()
			normals.append(n)
			colors.append(_color(h, n, terrain.sea_level))

	# Godot treats clockwise triangles (seen from above) as front-facing.
	var indices := PackedInt32Array()
	for j in rows:
		for i in cols:
			var a := j * (cols + 1) + i
			var b := a + 1
			var c := a + cols + 1
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


# Colour by what the ground is: under water = sea floor, just above = beach,
# then grass, going to rock where it is steep or high.
static func _color(h: float, normal: Vector3, sea_level: float) -> Color:
	if h < sea_level:
		return SEABED
	var above := h - sea_level
	var c := SAND.lerp(GRASS, smoothstep(0.3, 2.0, above))
	var rockiness := maxf(smoothstep(0.55, 0.85, 1.0 - normal.y), smoothstep(25.0, 60.0, above))
	return c.lerp(ROCK, rockiness)
