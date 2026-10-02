extends SceneTree
const Batcher := preload("res://station/static_box_batcher.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	if DisplayServer.get_name() == "headless":
		push_error("Batch transform verification requires a rendering backend; omit --headless")
		quit(1)
		return
	var holder := Node3D.new()
	holder.position = Vector3(762, 3.75, 850)
	root.add_child(holder)
	var nested := Node3D.new()
	nested.position = Vector3(3, 2, 4)
	nested.rotation.y = 0.4
	holder.add_child(nested)
	var sources: Array[MeshInstance3D] = []
	var expected: Array[Transform3D] = []
	var material := Greybox.mat(Color(0.5, 0.6, 0.7))
	for i in 4:
		var mesh := Greybox.box(nested, Vector3(1 + i, 0.3, 2), Vector3(i * 2, 0, 0), material.duplicate(), null, i * 0.2)
		mesh.layers = 3
		sources.append(mesh)
		var transform := holder.global_transform.affine_inverse() * mesh.global_transform
		transform.basis *= Basis.from_scale(mesh.mesh.size)
		expected.append(transform)
	var glass := Greybox.box(holder, Vector3.ONE, Vector3.ZERO, Greybox.mat(Color.WHITE, 0.1, 0, 0.4))
	var polished := Greybox.box(holder, Vector3.ONE, Vector3.ZERO, Greybox.mat(Color(0.5, 0.6, 0.7), 0.2))
	var col := Greybox.body(holder)
	Greybox.col_box(col, Vector3.ONE, Vector3.ZERO)
	var result := Batcher.build(holder)
	var batch: MultiMeshInstance3D = holder.get_node("StaticBoxes_0")
	var ok: bool = result["boxes"] == 4 and result["batches"] == 1 and batch.layers == 3 and glass.visible and polished.visible and col.get_child_count() == 1
	for i in 4:
		ok = ok and not sources[i].visible and batch.multimesh.get_instance_transform(i).is_equal_approx(expected[i])
	if not ok:
		push_error("Batching changed transforms, layers, glass or collision")
		quit(1)
		return
	print("[PASS] batching preserves nested transforms, lighting layers, glass and collision")
	var station := StationComplex.new()
	root.add_child(station)
	var stats: Dictionary = station.get_meta("static_batch_stats")
	print("Station batches: ", stats)
	if stats["boxes"] < 200 or stats["batches"] >= stats["boxes"] * 0.5:
		push_error("Station batching did not reduce static submissions")
		quit(1)
		return
	# Departure-board children stay live; they are deliberately excluded.
	var kiosks: Array = []
	_find_kiosks(station, kiosks)
	if kiosks.is_empty():
		push_error("No live departure boards were checked")
		quit(1)
		return
	for kiosk in kiosks:
		for chip in kiosk._row_chips:
			if chip.has_meta("static_batched"):
				push_error("Live departure chip was batched")
				quit(1)
				return
	print("static_batch_test: OK")
	quit()

func _find_kiosks(node: Node, found: Array) -> void:
	if node is ConcourseKiosk:
		found.append(node)
	for child in node.get_children():
		_find_kiosks(child, found)
