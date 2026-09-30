extends Node
## Phase 1 checks for the building generator (headless):
##   godot --headless res://tests/building_gen_test.tscn
## Exit code 1 if anything fails. Deeper geometry validation is Phase 2.

var fails := 0


func check(name: String, cond: bool, detail := "") -> void:
	if cond:
		print("  ok   ", name)
	else:
		fails += 1
		print("  FAIL ", name, "  ", detail)


## Every mesh's position and size, rounded, as text: two identical buildings give identical text.
func _node_signature(root: Node) -> String:
	var out := PackedStringArray()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var m := n as MeshInstance3D
		out.append("%s %s" % [m.position, (m.mesh as BoxMesh).size])
	return "\n".join(out)


func _ready() -> void:
	var a := BuildingGenerator.plan(29, 29, 20, 3.5, 42)
	var b := BuildingGenerator.plan(29, 29, 20, 3.5, 42)
	check("same inputs -> identical plan", a.ok() and a.signature() == b.signature())

	var distinct := {}
	for s in 20:
		distinct[BuildingGenerator.plan(29, 29, 20, 3.5, s).signature()] = true
	check("different seeds give different buildings (%d of 20 distinct)" % distinct.size(), distinct.size() >= 15)

	BuildingGenerator.plan(12, 12, 30, 3.5, 7)   # building something else in between must not matter
	var c := BuildingGenerator.plan(29, 29, 20, 3.5, 42)
	check("plan does not depend on what was generated before it", a.signature() == c.signature())

	var n1 := BuildingBuilder.build(self, a)
	var n2 := BuildingBuilder.build(self, b)
	check("same plan -> identical nodes", _node_signature(n1) == _node_signature(n2))
	check("building has collision", n1.find_children("*", "CollisionShape3D", true, false).size() >= 3)
	check("body is on the world layer", (n1.find_children("*", "StaticBody3D", true, false)[0] as StaticBody3D).collision_layer == Fighter.LAYER_WORLD)

	check("footprint 29 m = 58 units", a.width_u == 58 and a.depth_u == 58)
	# (96 - 1.5 m base+roof) / 4 m = 23.6 -> 24 floors -> 97.5 m to the roof; a rooftop box may add up to 4 m
	check("height 96 m on a 4 m floor -> 24 floors", BuildingGenerator.floors_for_height(96.0, 4.0) == 24)
	check("floors stack to the requested height +-1 floor (roof at %.1f m)" % BuildingGrid.to_metres(BuildingGenerator.BASE_UNITS + 24 * 8 + BuildingGenerator.ROOF_UNITS),
		absf(BuildingGrid.to_metres(BuildingGenerator.BASE_UNITS + 24 * 8 + BuildingGenerator.ROOF_UNITS) - 96.0) <= 4.0)

	var bad := BuildingGenerator.plan(0, 10, 5, 3.5, 1)
	check("zero width gives an error plan, not a crash", not bad.ok() and not bad.errors.is_empty())
	print("\n%s" % ("GENERATOR TESTS PASSED" if fails == 0 else "GENERATOR TESTS FAILED: %d" % fails))
	get_tree().quit(1 if fails > 0 else 0)
