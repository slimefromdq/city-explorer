# smoke_generate - builds the 3D city headless and checks the result is sane.
#
# Run:  godot --headless --path . --script res://tools/smoke_generate.gd
# One job: prove the generator really produces geometry from the JSON (the data
# validator only checks the data, not that the 3D came out).
extends SceneTree

var _fails := 0


func _init() -> void:
	var started := Time.get_ticks_msec()
	var view: Node = load("res://city/city_view.tscn").instantiate()
	root.add_child(view)
	await process_frame
	var gen = view.get_node("CityGenerator")
	_expect(not gen.city.is_empty(), "generator loaded city.json")
	var ground: MeshInstance3D = gen.get_node_or_null("Ground")
	var water: MeshInstance3D = gen.get_node_or_null("Water")
	_expect(ground != null and water != null, "generator built Ground and Water nodes")
	if ground != null:
		var arrays := (ground.mesh as ArrayMesh).surface_get_arrays(0)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var finite := true
		var lo := INF
		var hi := -INF
		for v in verts:
			finite = finite and is_finite(v.y)
			lo = minf(lo, v.y)
			hi = maxf(hi, v.y)
		_expect(verts.size() > 10000 and finite, "ground mesh has %d finite vertices" % verts.size())
		_expect(lo < gen.terrain.sea_level - 5.0, "terrain has deep water (lowest %.1f m)" % lo)
		_expect(hi > gen.terrain.sea_level + 15.0, "terrain has hills (highest %.1f m)" % hi)
		var box := ground.get_aabb()
		_expect(box.position.x < 0.0 and box.end.x > gen.map_size.x and box.position.z < 0.0 and box.end.z > gen.map_size.y,
			"ground covers the whole map plus sea margin")
	var roads: MeshInstance3D = gen.get_node_or_null("Roads")
	var bridges: MeshInstance3D = gen.get_node_or_null("Bridges")
	_expect(roads != null and bridges != null, "generator built Roads and Bridges nodes")
	if roads != null and bridges != null:
		_expect((roads.mesh as ArrayMesh).get_surface_count() == 5, "roads have one surface per kind (street, avenue, diagonal, ring, quay)")
		_expect((bridges.mesh as ArrayMesh).get_surface_count() == 1, "bridges mesh has a surface")
		var deck_lo := INF
		var deck_hi := -INF
		for v in (bridges.mesh as ArrayMesh).surface_get_arrays(0)[Mesh.ARRAY_VERTEX]:
			deck_lo = minf(deck_lo, v.y)
			deck_hi = maxf(deck_hi, v.y)
		_expect(deck_hi > gen.terrain.sea_level + 3.0, "bridge decks rise clear of the water (top %.1f m)" % deck_hi)
	var cam: Camera3D = view.get_node("FlyCamera")
	_expect(cam.position.y > 100.0, "camera was framed above the city")
	print("generated in %d ms" % (Time.get_ticks_msec() - started))
	print("")
	print("%s: %d failure(s)" % ["SMOKE TEST FAILED" if _fails > 0 else "SMOKE TEST PASSED", _fails])
	quit(1 if _fails > 0 else 0)


func _expect(ok: bool, message: String) -> void:
	if not ok:
		_fails += 1
	print("[%s] %s" % ["PASS" if ok else "FAIL", message])
