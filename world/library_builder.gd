class_name LibraryBuilder
extends RefCounted
## The Grand Library: neoclassical portico and grand steps toward the park,
## an enterable reading hall with a U-shaped gallery and skylight roof, side
## wings with roof terraces, and a stepped golden dome you can climb - its
## lantern is a landmark visible across the city.

static func build(parent: Node, c: Vector2) -> Dictionary:
	var info := {"landmarks": [], "tp": [], "shards": [], "walks": []}
	var k := Kit.new(parent, "GrandLibrary")
	var cx := c.x
	var cz := c.y
	var stone := Color(0.78, 0.72, 0.62)
	var wall := Mats.facade(stone, 21.0, 0.3, Vector2(5.0, 7.0), Vector2(0.45, 0.72), 3.0)
	var stone_m := Mats.toon(stone, 0.35)
	var dark_stone := Mats.toon(stone.darkened(0.25), 0.5)
	var wood := Mats.toon(Color(0.4, 0.26, 0.18))
	var gold := Mats.glow(Color(1.0, 0.8, 0.3), 1.8)
	var floor_y := 3.0
	var H := 23.0

	# plinth + grand steps toward the park (south side)
	k.box(Vector3(cx, 0.0, cz), Vector3(62.0, floor_y, 62.0), stone_m, true)
	k.stairs(Vector3(cx, 0.0, cz + 37.0), Vector3(0, 0, -1), floor_y, 6.0, 26.0, stone_m)   # top lands flush on the plinth edge (cz+31)

	# main hall shell with a door on the south wall
	var hx0 := -22.0
	var hx1 := 22.0
	var hz0 := -26.0
	var hz1 := 14.0
	var t := 1.5
	k.box(Vector3(cx, floor_y, cz + hz0), Vector3(hx1 - hx0, H, t), wall, true)              # north
	k.box(Vector3(cx + hx0, floor_y, cz + (hz0 + hz1) * 0.5), Vector3(t, H, hz1 - hz0), wall, true)   # west
	k.box(Vector3(cx + hx1, floor_y, cz + (hz0 + hz1) * 0.5), Vector3(t, H, hz1 - hz0), wall, true)   # east
	k.box(Vector3(cx - 14.0, floor_y, cz + hz1), Vector3(16.0, H, t), wall, true)             # south left
	k.box(Vector3(cx + 14.0, floor_y, cz + hz1), Vector3(16.0, H, t), wall, true)             # south right
	k.box(Vector3(cx, floor_y + 9.0, cz + hz1), Vector3(12.0, H - 9.0, t), wall, true)        # lintel
	k.box(Vector3(cx, floor_y + H, cz + (hz0 + hz1) * 0.5), Vector3(hx1 - hx0 + 1.0, 1.0, hz1 - hz0 + 1.0), dark_stone, true)  # roof slab
	# portico columns + pediment
	for i in 8:
		var x := cx - 19.0 + i * (38.0 / 7.0)
		k.cyl(Vector3(x, floor_y, cz + hz1 + 5.0), 1.0, 15.0, stone_m, true, 14)
	k.box(Vector3(cx, floor_y + 15.0, cz + hz1 + 3.5), Vector3(42.0, 2.0, 5.0), stone_m, true)
	var ped := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(42.0, 6.0, 4.0)
	ped.mesh = pm
	ped.material_override = stone_m
	ped.position = Vector3(cx, floor_y + 17.0 + 3.0, cz + hz1 + 3.5)
	k.root.add_child(ped)
	k.label("GRAND LIBRARY", Vector3(cx, floor_y + 17.4, cz + hz1 + 5.6), 1.5, Color(1.0, 0.85, 0.5), 0.0)

	# interior: shelves as cover, reading tables, chandeliers
	var shelf_z := [-18.0, -10.0, -2.0, 6.0]
	for z in shelf_z:
		for side: float in [-1.0, 1.0]:
			k.box(Vector3(cx + side * 12.0, floor_y, cz + z), Vector3(9.0, 4.2, 1.0), wood, true)
			k.box(Vector3(cx + side * 12.0, floor_y + 4.2, cz + z), Vector3(9.0, 0.2, 1.2), Mats.glow(Color(1.0, 0.8, 0.5), 2.0), false, Vector3.ZERO, false)
	for i in 3:
		k.box(Vector3(cx, floor_y, cz - 14.0 + i * 8.0), Vector3(6.0, 1.0, 1.6), wood, true)
	# gallery (10 m): U-shape reached by two grand ramps
	var gy := 9.4
	k.box(Vector3(cx + hx0 + 3.25, gy, cz - 12.0), Vector3(5.0, 0.6, 24.0), wood, true)
	k.box(Vector3(cx + hx1 - 3.25, gy, cz - 12.0), Vector3(5.0, 0.6, 24.0), wood, true)
	k.box(Vector3(cx, gy, cz + hz0 + 3.25), Vector3(44.0, 0.6, 5.0), wood, true)
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(cx + sx * 16.6, gy + 0.6, cz - 12.0), Vector3(0.2, 1.0, 24.0), wood, true)
		k.stairs(Vector3(cx + sx * 19.0, floor_y, cz + 12.0), Vector3(0, 0, -1), gy + 0.6 - floor_y, 12.0, 4.0, wood)   # tops out flush with the gallery floor at cz
	k.box(Vector3(cx, gy + 0.6, cz + hz0 + 5.8), Vector3(36.0, 1.0, 0.2), wood, true)
	# skylight roof glow + chandeliers
	for i in 3:
		k.box(Vector3(cx, floor_y + H - 0.4, cz - 16.0 + i * 12.0), Vector3(14.0, 0.3, 4.0), Mats.glow(Color(1.0, 0.92, 0.75), 3.0), false, Vector3.ZERO, false)
		k.sphere(Vector3(cx, floor_y + 16.0, cz - 16.0 + i * 12.0), 1.2, Mats.glow(Color(1.0, 0.85, 0.5), 4.0))

	# side wings with roof terraces
	for sx: float in [-1.0, 1.0]:
		k.box(Vector3(cx + sx * 26.5, floor_y, cz - 5.0), Vector3(7.0, 14.0, 38.0), wall, true)
		k.box(Vector3(cx + sx * 26.5, floor_y + 14.0, cz - 5.0), Vector3(8.0, 0.8, 39.0), dark_stone, true)
		for i in 4:
			k.cyl(Vector3(cx + sx * 30.0, floor_y + 14.8, cz - 20.0 + i * 10.0), 0.6, 2.0, stone_m, false, 8)
	for sx: float in [-1.0, 1.0]:
		info.walks.append({"rect": Rect2(cx + sx * 26.5 - 4.0, cz - 24.5, 8.0, 39.0), "y": floor_y + 14.8, "avoid": Rect2(), "clutter": []})
	# rear reading tower
	k.box(Vector3(cx, floor_y, cz - 29.0), Vector3(14.0, 34.0, 6.0), wall, true)
	k.box(Vector3(cx, floor_y + 34.0, cz - 29.0), Vector3(15.0, 1.0, 7.0), dark_stone, true)
	k.box(Vector3(cx, floor_y + 35.0, cz - 29.0), Vector3(10.0, 0.4, 0.4), gold, false, Vector3.ZERO, false)

	# stepped golden dome over the hall
	var dome_c := Vector3(cx, floor_y + H + 0.5, cz - 6.0)
	var radii := [12.0, 10.5, 8.8, 7.0, 5.2, 3.4]
	for i in radii.size():
		var y0 := dome_c.y + i * 2.2
		k.cyl(Vector3(dome_c.x, y0, dome_c.z), radii[i], 2.2, Mats.toon(Color(0.35, 0.62, 0.6) if i % 2 == 0 else Color(0.3, 0.55, 0.52)), true, 24)
		k.cyl(Vector3(dome_c.x, y0 + 2.15, dome_c.z), radii[i] + 0.3, 0.12, gold, false, 24)
		if i == 2:
			info.shards.append(Vector3(dome_c.x + radii[i] * 0.8, y0 + 2.4, dome_c.z))
	var top_y := dome_c.y + radii.size() * 2.2
	k.cyl(Vector3(dome_c.x, top_y, dome_c.z), 1.6, 6.0, Mats.glow(Color(1.0, 0.85, 0.4), 2.4), true, 12)
	k.cyl(Vector3(dome_c.x, top_y + 6.0, dome_c.z), 0.25, 8.0, Mats.toon(Color(0.8, 0.7, 0.4)), false, 8)
	k.sphere(Vector3(dome_c.x, top_y + 14.5, dome_c.z), 0.9, Mats.glow(Color(1.0, 0.9, 0.5), 8.0))
	info.landmarks.append(["Grand Library", Vector3(dome_c.x, top_y + 14.0, dome_c.z)])
	info.tp.append(["Library hall", Vector3(cx, floor_y + 0.3, cz - 4.0), PI])
	info.tp.append(["Library gallery", Vector3(cx - 19.0, gy + 0.9, cz - 12.0), 0.0])
	info.tp.append(["Library dome", Vector3(dome_c.x + 8.0, dome_c.y + 3.0 * 2.2 + 0.3, dome_c.z), 0.0])
	info.shards.append(Vector3(cx, floor_y + 0.9, cz - 14.0))
	info.shards.append(Vector3(cx + 26.5, floor_y + 15.6, cz - 5.0))
	StaticBatch.merge(k.root)
	return info
