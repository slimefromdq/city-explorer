# FlatPatch - a flat coloured patch lying on the terrain.
#
# One job: draw a polygon on the ground (a lawn, a court apron, a pond rim...). Every corner
# takes the terrain height there plus a small lift, so the patch hugs the ground instead of
# floating or sinking. Shared by the square's gardens and the park's zones.
extends RefCounted


static func add(parent: Node3D, poly: PackedVector2Array, terrain, color: Color, lift: float) -> void:
	var tris := Geometry2D.triangulate_polygon(poly)
	if tris.is_empty():
		return
	var verts := PackedVector3Array()
	var indices := PackedInt32Array()
	for p in poly:
		verts.append(Vector3(p.x, terrain.height_at(p, false) + lift, p.y))
	for t in range(0, tris.size(), 3):
		var a := poly[tris[t]]
		var b := poly[tris[t + 1]]
		var c := poly[tris[t + 2]]
		# clockwise seen from above is front-facing; flip a triangle if it came out the other way
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
