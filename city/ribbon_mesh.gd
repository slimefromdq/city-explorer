# RibbonMesh - makes a strip of road (or a thick bridge deck) along 3D points.
#
# One job: geometry. Give it points that already have the right height and it
# builds the triangles. Roads, bridges and (later) rails, paths and fences can
# all be ribbons, so the maths lives in one place.
extends RefCounted


# `points` run along the centre line. thickness == 0 -> a flat surface only (road);
# thickness > 0 -> a solid slab with sides and an underside (bridge deck).
# Each face has its own vertices so every face shades with its own normal.
# Triangles are clockwise seen from outside, which is what Godot treats as the front.
static func build(points: PackedVector3Array, width: float, thickness: float = 0.0) -> Array:
	var n := points.size()
	var solid := thickness > 0.0
	var stride := 8 if solid else 2  # vertices per cross-section
	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var indices := PackedInt32Array()
	var half := width * 0.5
	for i in n:
		var f := (points[mini(i + 1, n - 1)] - points[maxi(i - 1, 0)]).normalized()
		var flat := Vector3(f.x, 0.0, f.z).normalized()
		var right := flat.cross(Vector3.UP).normalized()  # travelling east, right = south (+z)
		var up := right.cross(f).normalized()             # follows the slope of the road
		var l := points[i] - right * half
		var r := points[i] + right * half
		var drop := Vector3.DOWN * thickness
		verts.append_array([l, r])
		normals.append_array([up, up])
		if solid:
			verts.append_array([l, l + drop, r, r + drop, l + drop, r + drop])
			normals.append_array([-right, -right, right, right, Vector3.DOWN, Vector3.DOWN])
	for i in n - 1:
		var a := i * stride
		var b := a + stride
		indices.append_array([a, b, b + 1, a, b + 1, a + 1])                       # top
		if solid:
			indices.append_array([b + 2, a + 2, a + 3, b + 2, a + 3, b + 3])       # left side
			indices.append_array([a + 4, b + 4, b + 5, a + 4, b + 5, a + 5])       # right side
			indices.append_array([a + 6, a + 7, b + 7, a + 6, b + 7, b + 6])       # underside
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_INDEX] = indices
	return arrays
