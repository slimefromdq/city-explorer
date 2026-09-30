class_name RoadPaint
extends RefCounted
## Batches flat painted rectangles (lane lines, zebra crossings) into ONE mesh
## with vertex colours instead of hundreds of nodes.

var _verts := PackedVector3Array()
var _cols := PackedColorArray()
var _idx := PackedInt32Array()
var y := 0.03


func _init(height := 0.03) -> void:
	y = height


func rect(x0: float, z0: float, x1: float, z1: float, color: Color) -> void:
	var b := _verts.size()
	_verts.append_array([Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(x0, y, z1)])
	for i in 4:
		_cols.append(color)
	_idx.append_array([b, b + 2, b + 1, b, b + 3, b + 2])


## Rotated stripe from a to b (XZ plane) with the given width.
func strip(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var d := (b - a).normalized()
	var n := Vector2(-d.y, d.x) * width * 0.5
	var i := _verts.size()
	_verts.append_array([Vector3(a.x - n.x, y, a.y - n.y), Vector3(b.x - n.x, y, b.y - n.y), Vector3(b.x + n.x, y, b.y + n.y), Vector3(a.x + n.x, y, a.y + n.y)])
	for k in 4:
		_cols.append(color)
	_idx.append_array([i, i + 2, i + 1, i, i + 3, i + 2])


func build(parent: Node) -> MeshInstance3D:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_COLOR] = _cols
	arrays[Mesh.ARRAY_INDEX] = _idx
	var normals := PackedVector3Array()
	normals.resize(_verts.size())
	normals.fill(Vector3.UP)
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi
