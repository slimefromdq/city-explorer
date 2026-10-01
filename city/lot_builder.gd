# LotBuilder - shows the lots as coloured ground parcels.
#
# One job: make the lot plan visible. Each lot becomes a thin coloured patch lying on
# the terrain (colour = district), shrunk a touch so neighbouring lots show a seam.
# Phase 5 puts a building on each patch. Nothing here decides where a lot is.
extends RefCounted

const LIFT := 0.12         # sits just above the ground, below the roads (which start at 0.15)
const MAX_EDGE := 10.0     # a lot surface is subdivided until its triangles are this small, so it follows the hills (m)
const DISPLAY_INSET := 0.5 # each patch is shrunk by this so the lot boundaries are visible (m)

# Presentation only: colour by district type, or by kind of special site.
const TYPE_COLORS := {
	"core": Color(0.60, 0.50, 0.72),
	"financial": Color(0.86, 0.52, 0.68),
	"midrise": Color(0.90, 0.68, 0.42),
	"lowrise": Color(0.93, 0.87, 0.58),
	"harbour": Color(0.50, 0.72, 0.84),
}
const PARK_COLOR := Color(0.38, 0.66, 0.32)  # park blocks (lawn) are drawn too, though they have no lots
const SITE_COLORS := {
	"station": Color(0.50, 0.48, 0.45),  # paving: the station complex stands on this lot
	"library": Color(0.50, 0.30, 0.15),
	"museum": Color(0.12, 0.50, 0.50),
	"performance_hall": Color(0.65, 0.15, 0.48),
	"plaza": Color(0.78, 0.74, 0.66),
}


static func build(plan, terrain) -> MeshInstance3D:
	var verts := PackedVector3Array()
	var colors := PackedColorArray()
	var indices := PackedInt32Array()
	var patches: Array = []  # {"polygon", "color"}: every lot, then the park lawns
	for lot in plan.lots:
		patches.append({"polygon": lot["polygon"], "color": _lot_color(lot)})
	for block in plan.block_map.blocks:
		if block["type"] == "park":
			patches.append({"polygon": block["polygon"], "color": PARK_COLOR})
	for patch in patches:
		var color: Color = patch["color"]
		for poly in Geometry2D.offset_polygon(patch["polygon"], -DISPLAY_INSET):
			var tris := Geometry2D.triangulate_polygon(poly)
			for t in range(0, tris.size(), 3):
				var a := poly[tris[t]]
				var b := poly[tris[t + 1]]
				var c := poly[tris[t + 2]]
				# clockwise seen from above is front-facing; flip a triangle if it came out the other way
				if (b - a).cross(c - a) < 0.0:
					var swap := b
					b = c
					c = swap
				_add_triangle(verts, colors, indices, terrain, a, b, c, color)
	var normals := PackedVector3Array()
	normals.resize(verts.size())
	normals.fill(Vector3.UP)
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_COLOR] = colors
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var node := MeshInstance3D.new()
	node.name = "Lots"
	node.mesh = mesh
	node.material_override = mat
	return node


# Add a triangle, first splitting it into four (repeatedly) until it is small, and give every
# corner the terrain height there. Without this a big flat triangle cuts through a hillside.
static func _add_triangle(verts: PackedVector3Array, colors: PackedColorArray, indices: PackedInt32Array, terrain, a: Vector2, b: Vector2, c: Vector2, color: Color) -> void:
	if maxf(a.distance_to(b), maxf(b.distance_to(c), c.distance_to(a))) > MAX_EDGE:
		var ab := (a + b) * 0.5
		var bc := (b + c) * 0.5
		var ca := (c + a) * 0.5
		_add_triangle(verts, colors, indices, terrain, a, ab, ca, color)
		_add_triangle(verts, colors, indices, terrain, ab, b, bc, color)
		_add_triangle(verts, colors, indices, terrain, ca, bc, c, color)
		_add_triangle(verts, colors, indices, terrain, ab, bc, ca, color)
		return
	var base := verts.size()
	for p in [a, b, c]:
		verts.append(Vector3(p.x, terrain.height_at(p) + LIFT, p.y))
		colors.append(color)
	indices.append_array([base, base + 1, base + 2])


# District colour (or site colour) with a small per-lot brightness change (stable: derived from the lot id).
static func _lot_color(lot: Dictionary) -> Color:
	var base: Color
	if lot["kind"] == "site":
		base = SITE_COLORS.get(lot["site_kind"], Color(0.5, 0.5, 0.5))
	else:
		base = TYPE_COLORS.get(lot["type"], Color.MAGENTA)
	var shade := 0.9 + 0.2 * float(absi(hash(lot["id"])) % 1000) / 1000.0
	return Color(base.r * shade, base.g * shade, base.b * shade)
