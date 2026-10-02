extends RefCounted
## Shipped cache of the expensive terrain/road meshes. Source edits invalidate it.
const DIRECTORY := "res://data/meridia_cache/"
const SOURCES := ["res://data/city.json", "res://city/city_data.gd", "res://city/terrain_height.gd", "res://city/terrain_builder.gd", "res://city/road_builder.gd", "res://city/road_network.gd", "res://city/geo2d.gd", "res://city/city_generator.gd", "res://city/static_mesh_cache.gd"]

static func signature() -> String:
	var hashes: String = Engine.get_version_info()["string"]
	for path in SOURCES:
		hashes += source_hash(FileAccess.get_file_as_string(path))
	return hashes.sha256_text()

static func source_hash(text: String) -> String:
	# Git checkouts can use LF or CRLF; either must accept the same shipped cache.
	return text.replace("\r\n", "\n").sha256_text()

static func mesh(name: String) -> ArrayMesh:
	if OS.get_environment("MERIDIA_REBUILD") == "1" or not FileAccess.file_exists(DIRECTORY + "manifest.json"):
		return null
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(DIRECTORY + "manifest.json"))
	if not manifest is Dictionary or manifest.get("signature", "") != signature():
		return null
	var path := DIRECTORY + name + ".res"
	if not FileAccess.file_exists(path):
		return null
	return load(path) as ArrayMesh
