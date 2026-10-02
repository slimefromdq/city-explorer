extends SceneTree
const Cache := preload("res://city/static_mesh_cache.gd")
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var ground := Cache.mesh("ground")
	var roads := Cache.mesh("roads")
	if ground == null or roads == null:
		push_error("Shipped static meshes are missing or stale")
		quit(1)
		return
	OS.set_environment("MERIDIA_REBUILD", "1")
	var okay := Cache.mesh("ground") == null
	okay = okay and Cache.source_hash("a\nb\n") == Cache.source_hash("a\r\nb\r\n") and Cache.source_hash("a\nb\n") != Cache.source_hash("a\nc\n")
	var scene = load("res://city/city_view.tscn").instantiate()
	root.add_child(scene)
	var gen = scene.get_node("CityGenerator")
	for pair in [[ground, gen.get_node("Ground").mesh], [roads, gen.get_node("Roads").mesh]]:
		var cached: ArrayMesh = pair[0]
		var fresh: ArrayMesh = pair[1]
		okay = okay and cached.get_surface_count() == fresh.get_surface_count()
		for i in cached.get_surface_count():
			var a := cached.surface_get_arrays(i)
			var b := fresh.surface_get_arrays(i)
			for attribute in [Mesh.ARRAY_VERTEX, Mesh.ARRAY_NORMAL, Mesh.ARRAY_INDEX, Mesh.ARRAY_COLOR]:
				okay = okay and a[attribute] == b[attribute]
	print("static_mesh_cache_test: ", "OK" if okay else "FAILED")
	quit(0 if okay else 1)
