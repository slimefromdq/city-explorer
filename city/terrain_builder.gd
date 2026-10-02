# TerrainBuilder - turns a TerrainHeight into a 3D ground mesh.
#
# One job: sample the height function on a regular grid and make triangles.
# WHY a grid: it is the simplest mesh that can show any height field, and the
# vertex spacing (mesh_cell_size in the JSON) is the only quality knob.
# Map (x, y) becomes 3D (x, height, z).
extends RefCounted
const TerrainHeight := preload("res://city/terrain_height.gd")

const GRASS := Color(0.42, 0.58, 0.32)
const ROCK := Color(0.52, 0.48, 0.42)
const SAND := Color(0.80, 0.74, 0.55)
const SEABED := Color(0.45, 0.42, 0.33)


# `area` is the part of the map to cover, in map metres. The caller passes the
# map plus a margin so the sea floor does not end in a visible edge.
static func build(terrain, area: Rect2, cell: float, detail := Rect2(), detail_cell := 2.0, edge_cell := 0.0) -> ArrayMesh:
	var cols := int(ceil(area.size.x / cell))
	var rows := int(ceil(area.size.y / cell))
	var heights := PackedFloat32Array()
	heights.resize((cols + 1) * (rows + 1))
	for j in rows + 1:
		for i in cols + 1:
			heights[j * (cols + 1) + i] = _sample(terrain, area.position + Vector2(i, j) * cell, area, edge_cell)

	var verts := PackedVector3Array()
	var normals := PackedVector3Array()
	var colors := PackedColorArray()
	for j in rows + 1:
		for i in cols + 1:
			var h := heights[j * (cols + 1) + i]
			verts.append(Vector3(area.position.x + i * cell, h, area.position.y + j * cell))
			# Normal from the height difference of the neighbours: smooth shading for free.
			var hx := heights[j * (cols + 1) + mini(i + 1, cols)] - heights[j * (cols + 1) + maxi(i - 1, 0)]
			var hz := heights[mini(j + 1, rows) * (cols + 1) + i] - heights[maxi(j - 1, 0) * (cols + 1) + i]
			var run_x := cell * (mini(i + 1, cols) - maxi(i - 1, 0))
			var run_z := cell * (mini(j + 1, rows) - maxi(j - 1, 0))
			var n := Vector3(-hx / run_x, 1.0, -hz / run_z).normalized()
			normals.append(n)
			var color := _color(h, n, terrain.sea_level)
			if terrain is TerrainHeight and h > terrain.sea_level:
				color = park_color(terrain, Vector2(verts[-1].x, verts[-1].z), color)
			colors.append(color)

	# Godot treats clockwise triangles (seen from above) as front-facing.
	var indices := PackedInt32Array()
	for j in rows:
		for i in cols:
			if detail.has_area() and detail.has_point(area.position + Vector2(i + 0.5, j + 0.5) * cell):
				continue
			var a := j * (cols + 1) + i
			var b := a + 1
			var c := a + cols + 1
			var d := c + 1
			indices.append_array([a, b, d, a, d, c])
	if detail.has_area():
		var patch := build(terrain, detail, detail_cell, Rect2(), detail_cell, cell)
		var fine := patch.surface_get_arrays(0)
		var offset := verts.size()
		verts.append_array(fine[Mesh.ARRAY_VERTEX])
		normals.append_array(fine[Mesh.ARRAY_NORMAL])
		colors.append_array(fine[Mesh.ARRAY_COLOR])
		for index in fine[Mesh.ARRAY_INDEX]:
			indices.append(index + offset)

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

## Paint the actual ground vertices: no second lawn surface can intersect it.
static func park_color(terrain, p: Vector2, fallback: Color) -> Color:
	for zone in terrain.park_colors:
		if not Geometry2D.is_point_in_polygon(p, zone["polygon"]):
			continue
		if zone["kind"] == "cherry_garden":
			return Color(0.90, 0.74, 0.80)
		var rect: Dictionary = zone["rect"]
		var u: Vector2 = rect["u"]
		var stripe := floori(((p - rect["center"]).dot(u.orthogonal()) + rect["half"].y) / 7.0)
		return Color(0.50, 0.78, 0.38) if stripe % 2 == 0 else Color(0.43, 0.71, 0.33)
	return fallback

static func detail_region(city: Dictionary, cell: float) -> Rect2:
	var box := Rect2()
	var initialized := false
	for creek in city["terrain"].get("creeks", []):
		for point in creek["path"]:
			var p := Vector2(point[0], point[1])
			var radius := float(point[2]) + float(creek["bank_width"]) + cell * 2
			var piece := Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2)
			box = box.merge(piece) if initialized else piece
			initialized = true
	for pond in city["terrain"].get("ponds", []):
		var p := Vector2(pond["center"][0], pond["center"][1])
		var radius := float(pond["radius"]) + cell * 2
		var piece := Rect2(p - Vector2.ONE * radius, Vector2.ONE * radius * 2)
		box = box.merge(piece) if initialized else piece
		initialized = true
	if not initialized:
		return Rect2()
	var start := (box.position / cell).floor() * cell
	var end := (box.end / cell).ceil() * cell
	return Rect2(start, end - start)

## Fine boundary vertices interpolate the coarse edge instead of resampling it,
## preventing cracks where the two resolutions meet, including on coastal slopes.
static func _sample(terrain, p: Vector2, area: Rect2, edge_cell: float) -> float:
	if edge_cell <= 0:
		return terrain.height_at(p)
	var along := Vector2.ZERO
	if is_equal_approx(p.x, area.position.x) or is_equal_approx(p.x, area.end.x):
		along = Vector2.DOWN
	elif is_equal_approx(p.y, area.position.y) or is_equal_approx(p.y, area.end.y):
		along = Vector2.RIGHT
	else:
		return terrain.height_at(p)
	var coordinate := p.dot(along)
	var start := floorf(coordinate / edge_cell) * edge_cell
	var a := p + along * (start - coordinate)
	return lerpf(terrain.height_at(a), terrain.height_at(a + along * edge_cell), (coordinate - start) / edge_cell)

# Colour by what the ground is: under water = sea floor, just above = beach,
# then grass, going to rock where it is steep or high.
static func _color(h: float, normal: Vector3, sea_level: float) -> Color:
	if h < sea_level:
		return SEABED
	var above := h - sea_level
	var c := SAND.lerp(GRASS, smoothstep(0.3, 2.0, above))
	var rockiness := maxf(smoothstep(0.55, 0.85, 1.0 - normal.y), smoothstep(25.0, 60.0, above))
	return c.lerp(ROCK, rockiness)
