extends Node
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	var main: Node3D = load("res://main.tscn").instantiate()
	main.set("headless_test", true)
	add_child(main)
	await get_tree().physics_frame
	var meshes := 0
	var shapes := 0
	var bodies := 0
	var lights := 0
	var stack := [main]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D: meshes += 1
		elif n is MultiMeshInstance3D: meshes += 1
		elif n is CollisionShape3D: shapes += 1
		elif n is StaticBody3D: bodies += 1
		elif n is Light3D: lights += 1
		stack.append_array(n.get_children())
	print("nodes ", get_tree().get_node_count(), " mesh instances ", meshes, " shapes ", shapes, " static bodies ", bodies, " lights ", lights)
	print("build+first frame ms ", Time.get_ticks_msec() - t0)
	get_tree().quit()
