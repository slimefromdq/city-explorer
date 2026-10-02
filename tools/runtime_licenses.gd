extends SceneTree
func _initialize() -> void:
	var directory := OS.get_environment("LICENSE_OUT")
	var file := FileAccess.open(directory + "/GODOT-LICENSE.txt", FileAccess.WRITE)
	file.store_string(Engine.get_license_text())
	file = FileAccess.open(directory + "/GODOT-THIRD-PARTY.json", FileAccess.WRITE)
	file.store_string(JSON.stringify({"copyright": Engine.get_copyright_info(), "licenses": Engine.get_license_info()}, "\t"))
	quit()
