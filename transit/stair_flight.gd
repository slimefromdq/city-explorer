class_name StairFlight
extends RefCounted
## A straight, solid stair flight (axis-aligned run) built from tread blocks that reach down to a base
## level, so there is no hollow underside. Collision is one ramp along the nosing line (walkable by the
## character controller), not a block per tread.
##
##   origin  : the point where the run starts, at its starting height (x, y, z)
##   dir     : horizontal unit vector along the run (+-X or +-Z)
##   riser   : signed: > 0 descends along dir, < 0 ascends
##   Returns the end point (x, y, z) after `steps` treads.

const RAMP_THICKNESS := 0.4


static func build(parent: Node3D, origin: Vector3, dir: Vector3, width: float, steps: int, riser: float, run: float,
		base_y: float, mat: Material, col: StaticBody3D = null, top_mat: Material = null) -> Vector3:
	var lat := Vector3(-dir.z, 0.0, dir.x)
	var along_x := absf(dir.x) > 0.5
	var st := SurfaceTool.new()      # sides (stone)
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var st_top := SurfaceTool.new()  # walking surfaces
	st_top.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in steps:
		var y_top := origin.y - riser * (i + 1)
		var h := y_top - base_y
		if h < 0.02:
			continue
		var c0 := origin + dir * (run * i) - lat * (width * 0.5)
		var c1 := origin + dir * (run * (i + 1)) + lat * (width * 0.5)
		var lo := Vector3(minf(c0.x, c1.x), base_y, minf(c0.z, c1.z))
		var hi := Vector3(maxf(c0.x, c1.x), y_top, maxf(c0.z, c1.z))
		_box_faces(st, st_top, lo, hi)
	var mesh := ArrayMesh.new()
	st.set_material(mat)
	st.commit(mesh)
	st_top.set_material(top_mat if top_mat != null else mat)
	st_top.commit(mesh)
	var mi := MeshInstance3D.new()
	mi.name = "Treads"
	mi.mesh = mesh
	parent.add_child(mi)
	var end := origin + dir * (run * steps) + Vector3(0, -riser * steps, 0)
	if col != null:
		var a := origin
		var b := end
		var f := (b - a).normalized()
		var n := lat.cross(f)
		var basis := Basis(f, n, lat)
		var len := a.distance_to(b)
		var center := (a + b) * 0.5 - n * (RAMP_THICKNESS * 0.5 - 0.02)
		Greybox.col_box(col, Vector3(len + 0.2, RAMP_THICKNESS, width), center, basis)
	return end


static func _box_faces(st: SurfaceTool, st_top: SurfaceTool, lo: Vector3, hi: Vector3) -> void:
	var a := lo
	var b := Vector3(hi.x, lo.y, lo.z)
	var c := Vector3(hi.x, hi.y, lo.z)
	var d := Vector3(lo.x, hi.y, lo.z)
	var e := Vector3(lo.x, lo.y, hi.z)
	var f := Vector3(hi.x, lo.y, hi.z)
	var g := hi
	var hh := Vector3(lo.x, hi.y, hi.z)
	var faces := [
		[Vector3.BACK, [e, f, g, hh]], [Vector3.FORWARD, [b, a, d, c]], [Vector3.UP, [hh, g, c, d]],
		[Vector3.RIGHT, [f, b, c, g]], [Vector3.LEFT, [a, e, hh, d]],
	]
	for face in faces:
		var target: SurfaceTool = st_top if face[0] == Vector3.UP else st
		target.set_normal(face[0])
		for i in [0, 2, 1, 0, 3, 2]:
			target.add_vertex(face[1][i])
