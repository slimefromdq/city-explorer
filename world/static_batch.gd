class_name StaticBatch
extends RefCounted
## Merges every simple mesh under a root into one MeshInstance3D per
## (mesh type, material, shadow flag). The city is thousands of boxes; this
## turns them into a few dozen draw calls per building. Collision is untouched.

static func merge(root: Node3D) -> void:
	var groups := {}
	var inv := root.global_transform.affine_inverse()
	_collect(root, inv, groups)
	for key in groups.keys():
		var g: Dictionary = groups[key]
		var items: Array = g.items
		if items.size() < 2:
			continue
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for mi: MeshInstance3D in items:
			st.append_from(mi.mesh, 0, inv * mi.global_transform)
		var merged := MeshInstance3D.new()
		merged.mesh = st.commit()
		merged.material_override = g.mat
		merged.cast_shadow = g.shadow
		root.add_child(merged)
		for mi: MeshInstance3D in items:
			mi.get_parent().remove_child(mi)
			mi.free()


static func _collect(n: Node, inv: Transform3D, groups: Dictionary) -> void:
	for c in n.get_children():
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			var m := mi.mesh
			if m != null and mi.material_override != null and mi.get_child_count() == 0 and not mi.top_level and mi.visible \
					and (m is BoxMesh or m is CylinderMesh or m is SphereMesh or m is QuadMesh or m is PrismMesh):
				var key := "%s|%d|%d" % [m.get_class(), mi.material_override.get_instance_id(), mi.cast_shadow]
				if not groups.has(key):
					groups[key] = {"mat": mi.material_override, "shadow": mi.cast_shadow, "items": []}
				groups[key].items.append(mi)
		_collect(c, inv, groups)
