class_name TerrainApron
extends RefCounted
## Walkable ground for the character: the city's terrain has no collision, so near the station and the
## destination entrances this builds a trimesh from the same height function, on a regular grid, with
## quads left out inside the given hole rectangles (stairwells and trenches). Sits at road level
## (terrain + ROAD_LIFT) so streets, lot patches and kerbs are all walkable.

const ROAD_LIFT := 0.15
const CELL := 2.0


static func build(parent: Node3D, apron_name: String, terrain, area: Rect2, holes: Array[Rect2], dry_only := false) -> StaticBody3D:
	var nx := int(ceil(area.size.x / CELL))
	var nz := int(ceil(area.size.y / CELL))
	var heights: Array = []
	for j in range(nz + 1):
		var row := PackedFloat32Array()
		for i in range(nx + 1):
			var p := Vector2(area.position.x + i * CELL, area.position.y + j * CELL)
			row.append(maxf(terrain.height_at(p), terrain.sea_level - 0.3) + ROAD_LIFT)
		heights.append(row)
	var tris := PackedVector3Array()
	for j in range(nz):
		for i in range(nx):
			var x0 := area.position.x + i * CELL
			var z0 := area.position.y + j * CELL
			var cell := Rect2(x0, z0, CELL, CELL)
			var skip := false
			if dry_only:
				for corner in [cell.position, Vector2(cell.end.x, cell.position.y), cell.end, Vector2(cell.position.x, cell.end.y)]:
					if terrain.height_at(corner) < terrain.sea_level:
						skip = true
			for h in holes:
				if h.intersects(cell):
					skip = true
					break
			if skip:
				continue
			var a := Vector3(x0, heights[j][i], z0)
			var b := Vector3(x0 + CELL, heights[j][i + 1], z0)
			var c := Vector3(x0 + CELL, heights[j + 1][i + 1], z0 + CELL)
			var d := Vector3(x0, heights[j + 1][i], z0 + CELL)
			tris.append_array([a, b, c, a, c, d])
	var body := StaticBody3D.new()
	body.name = apron_name
	var cs := CollisionShape3D.new()
	var shape := ConcavePolygonShape3D.new()
	shape.set_faces(tris)
	shape.backface_collision = true
	cs.shape = shape
	body.add_child(cs)
	parent.add_child(body)
	return body
