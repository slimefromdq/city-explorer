extends SceneTree
## Envelope/planting regressions and station shaft separation. Uses the actual
## generated city, including transit reservations, rather than toy footprints.
var failures := 0
const Plan := preload("res://city/architecture_plan.gd")
const Builder := preload("res://city/architecture_builder.gd")

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	var scene = load("res://city/city_view.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	var gen = scene.get_node("CityGenerator")
	var architecture = gen.architecture_plan
	check(architecture.validate().is_empty(), "all parts fit reserved footprint/height envelopes: %s" % [architecture.validate()])
	check(gen.harbour_plan.validate().is_empty() and gen.harbour_plan.piers.size() == gen.city["harbour"]["piers"].size(), "both authored piers have bounded harbour architecture")
	var repeated := Plan.new(gen.building_plan, gen.greenery_plan, gen.city, gen.terrain, gen.sightlines)
	check(repeated.parts == architecture.parts and repeated.buildings == architecture.buildings, "architecture is deterministic")
	var library_clear := true
	for site in architecture.civic:
		var b: Dictionary = site["building"]
		if b["site_kind"] != "library":
			continue
		for x in 9:
			for z in 9:
				var p: Vector2 = b["center"] + b["u"] * b["size"].x * (float(x) / 8 - 0.5) + b["u"].orthogonal() * b["size"].y * (float(z) / 8 - 0.5)
				library_clear = library_clear and b["base_y"] > gen.terrain.height_at(p)
	check(library_clear, "library terrace clears the hillside across its footprint")
	var by_id := {}
	for b in architecture.buildings:
		by_id[b["id"]] = b
	var roofs_supported := true
	for roof in gen.greenery_plan.roofs:
		var b: Dictionary = by_id[roof["building"]]
		roofs_supported = roofs_supported and is_equal_approx(b["render_height"], b["height"])
	check(roofs_supported, "every planted roof retains its full level support")
	var signs_supported := true
	for sign in gen.sign_plan.signs:
		var b: Dictionary = by_id[sign["building"]]
		signs_supported = signs_supported and sign["above_base"] + sign["size"].y <= b["render_height"] - 0.49
	check(signs_supported, "signs stay on walls beneath crown/roof transitions")
	# Exercise rejection, so the envelope check cannot silently become a no-op.
	repeated.parts[0]["size"] = Vector3(10000, 10000, 10000)
	check(not repeated.validate().is_empty(), "oversized architecture is rejected")
	for shed in [false, true]:
		var mesh := Builder._roof_mesh(shed)
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices := PackedInt32Array()
		if arrays[Mesh.ARRAY_INDEX] != null:
			indices = arrays[Mesh.ARRAY_INDEX]
		else:
			for i in vertices.size():
				indices.append(i)
		var outward := true
		for i in range(0, indices.size(), 3):
			var a := vertices[indices[i]]
			var b := vertices[indices[i + 1]]
			var c := vertices[indices[i + 2]]
			outward = outward and (c - a).cross(b - a).normalized().dot(normals[indices[i]]) > 0.99
		check(outward, "roof faces have outward normals and Godot front-face winding")
	var hall = gen.station.hall
	var mezz = hall.find_child("Mezzanine", true, false)
	var separation := true
	for hole in gen.station.platform_level.holes:
		separation = separation and mezz.stair_min_offset >= maxf(absf(hole.position.y), absf(hole.end.y)) + 0.59
	check(separation, "balcony flights clear all four platform shaft guardrails")
	var lights_clear := true
	for z in [-5.0, 5.0]:
		for interval in gen.station.platform_level._light_intervals(z, 0.4):
			for hole in gen.station.platform_level.holes:
				if hole.position.y <= z + 0.2 and hole.end.y >= z - 0.2:
					lights_clear = lights_clear and (interval.y <= hole.position.x or interval.x >= hole.end.x)
	check(lights_clear, "platform ceiling lights do not cross stair openings")
	print("architecture_test: %s" % ("OK" if failures == 0 else "%d FAILED" % failures))
	quit(0 if failures == 0 else 1)

func check(ok: bool, description: String) -> void:
	print("[PASS] " if ok else "[FAIL] ", description)
	if not ok:
		failures += 1
