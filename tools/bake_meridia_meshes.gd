extends SceneTree
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	OS.set_environment("MERIDIA_REBUILD", "1")
	var scene = load("res://city/city_view.tscn").instantiate()
	root.add_child(scene)
	var gen = scene.get_node("CityGenerator")
	var cache = preload("res://city/static_mesh_cache.gd")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(cache.DIRECTORY))
	for pair in [["ground", "Ground"], ["roads", "Roads"]]:
		var mesh: ArrayMesh = gen.get_node(pair[1]).mesh
		if ResourceSaver.save(mesh, cache.DIRECTORY + pair[0] + ".res", ResourceSaver.FLAG_COMPRESS) != OK:
			quit(1)
			return
	var file := FileAccess.open(cache.DIRECTORY + "manifest.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"signature": cache.signature(), "engine": Engine.get_version_info()["string"]}, "\t"))
	print("Meridia static mesh cache baked")
	quit()
