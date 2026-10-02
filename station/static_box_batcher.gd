extends RefCounted
## Static station boxes share a unit mesh, grouped by material, lighting layers,
## shadow mode and spatial cell. Source nodes remain hidden for inspection;
## collision, text, glass and live departure boards keep their own nodes.
const CELL := Vector3(24, 12, 24)

static func build(station: Node3D) -> Dictionary:
	var groups := {}
	_collect(station, station, groups, {}, {})
	var unit := BoxMesh.new()
	unit.size = Vector3.ONE
	var count := 0
	var batches := 0
	for key in groups:
		var sources: Array = groups[key]
		if sources.size() < 3:
			continue
		var first: MeshInstance3D = sources[0]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = unit
		mm.instance_count = sources.size()
		for i in sources.size():
			var source: MeshInstance3D = sources[i]
			var transform := station.global_transform.affine_inverse() * source.global_transform
			transform.basis *= Basis.from_scale(source.mesh.size)
			mm.set_instance_transform(i, transform)
			source.hide()
			source.set_meta("static_batched", true)
		var node := MultiMeshInstance3D.new()
		node.name = "StaticBoxes_%d" % batches
		node.multimesh = mm
		node.material_override = first.get_active_material(0)
		node.layers = first.layers
		node.cast_shadow = first.cast_shadow
		station.add_child(node)
		count += sources.size()
		batches += 1
	var result := {"boxes": count, "batches": batches}
	station.set_meta("static_batch_stats", result)
	return result

static func _collect(node: Node, station: Node3D, groups: Dictionary, material_ids: Dictionary, materials: Dictionary) -> void:
	# The kiosk changes chip visibility and materials whenever trains update.
	if node is ConcourseKiosk or node.has_meta("static_batched"):
		return
	if node is MeshInstance3D and node.mesh is BoxMesh and node.is_visible_in_tree():
		var mat := node.get_active_material(0) as StandardMaterial3D
		if mat != null and mat.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED and node.mesh.subdivide_width == 0 and node.mesh.subdivide_height == 0 and node.mesh.subdivide_depth == 0:
			var id := mat.get_instance_id()
			if not material_ids.has(id):
				# Concourse pieces often allocate separate materials with identical
				# values. Compare every stored rendering property, including textures
				# and emission, instead of merging based on color alone.
				var values: Array = []
				for property in mat.get_property_list():
					var name: String = property["name"]
					if property["usage"] & PROPERTY_USAGE_STORAGE and not name.begins_with("resource_") and name != "script":
						values.append([name, mat.get(name)])
				var signature := hash(values)
				if not materials.has(signature):
					materials[signature] = []
				var canonical := id
				for entry in materials[signature]:
					if entry["values"] == values:
						canonical = entry["id"]
						break
				if canonical == id:
					materials[signature].append({"id": id, "values": values})
				material_ids[id] = canonical
			var local: Vector3 = station.global_transform.affine_inverse() * node.global_position
			var cell := (local / CELL).floor()
			var key := "%s:%s:%s:%s" % [material_ids[id], node.layers, node.cast_shadow, cell]
			if not groups.has(key):
				groups[key] = []
			groups[key].append(node)
	for child in node.get_children():
		_collect(child, station, groups, material_ids, materials)
