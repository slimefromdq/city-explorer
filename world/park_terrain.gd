class_name ParkTerrain
extends RefCounted
## Heightfield for the central park: rolling hills, two rivers, a lake with an
## island, and painted-in footpaths. One height function feeds the visual
## mesh, the HeightMapShape3D collider, tree placement and wading checks, so
## they can never disagree.

const WATER_LEVEL := -0.7

var rect: Rect2
var step := 2.0
var w := 0
var d := 0
var heights := PackedFloat32Array()
var noise := FastNoiseLite.new()
var forest_noise := FastNoiseLite.new()
var rivers: Array[PackedVector2Array] = []
var ponds: Array[Vector3] = []          # x, z, radius
var lake_c := Vector2.ZERO
var lake_r := Vector2(34, 22)
var island := Vector3.ZERO              # x, z, radius
var hills: Array[Vector4] = []          # x, z, sigma, height
var paths: Array[PackedVector2Array] = []
var clearings: Array[Vector3] = []      # x, z, radius (no trees)


func _init(p_rect: Rect2, p_step := 2.0) -> void:
	rect = p_rect
	step = p_step
	w = int(rect.size.x / step) + 1
	d = int(rect.size.y / step) + 1
	noise.seed = 4711
	noise.frequency = 0.011
	noise.fractal_octaves = 3
	forest_noise.seed = 99
	forest_noise.frequency = 0.03


func configure() -> void:
	var rc := rect.get_center()
	# everything below is authored relative to the park centre so the park can move
	rivers = [
		_pl(rc, [Vector2(-88, -80), Vector2(-76, -60), Vector2(-56, -50), Vector2(-40, -36), Vector2(-24, -26)]),
		_pl(rc, [Vector2(62, -8), Vector2(74, 10), Vector2(64, 30), Vector2(44, 46), Vector2(14, 52), Vector2(-24, 54)]),
	]
	ponds = [Vector3(rc.x - 88, rc.y - 80, 9.0), Vector3(rc.x - 30, rc.y + 54, 10.0)]
	lake_c = rc + Vector2(18, -22)
	lake_r = Vector2(34, 22)
	island = Vector3(lake_c.x - 6, lake_c.y, 6.5)
	hills = [Vector4(rc.x + 62, rc.y - 34, 24.0, 9.0), Vector4(rc.x - 78, rc.y + 20, 18.0, 5.5), Vector4(rc.x + 6, rc.y + 34, 20.0, 4.0)]
	clearings = [Vector3(rc.x - 14, rc.y + 24, 20.0)]
	paths = [
		_pl(rc, [Vector2(-104, -60), Vector2(-104, 60), Vector2(104, 60), Vector2(104, -60), Vector2(104, -60), Vector2(-104, -60)]),
		_pl(rc, [Vector2(-26, -60), Vector2(-26, 60)]),
		_pl(rc, [Vector2(-104, 14), Vector2(-40, 14), Vector2(20, 22), Vector2(60, 28), Vector2(104, 28)]),
		_pl(rc, [Vector2(20, -60), Vector2(40, -44), Vector2(62, -34)]),
	]


func _pl(origin: Vector2, pts: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in pts:
		out.append(origin + (p as Vector2))
	return out


func compute() -> void:
	heights.resize(w * d)
	for j in d:
		for i in w:
			heights[j * w + i] = raw_height(rect.position.x + i * step, rect.position.y + j * step)


func _gauss(p: Vector2, c: Vector2, sigma: float) -> float:
	return exp(-p.distance_squared_to(c) / (2.0 * sigma * sigma))


func dist_to_polyline(p: Vector2, pts: PackedVector2Array) -> float:
	var best := 1e9
	for i in pts.size() - 1:
		var a := pts[i]
		var b := pts[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		best = minf(best, p.distance_to(a + ab * t))
	return best


func path_distance(p: Vector2) -> float:
	var best := 1e9
	for pl in paths:
		best = minf(best, dist_to_polyline(p, pl))
	return best


func raw_height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var lx := x - rect.position.x
	var lz := z - rect.position.y
	var ed := minf(minf(lx, rect.size.x - lx), minf(lz, rect.size.y - lz))
	var edge := smoothstep(0.0, 14.0, ed)
	var n := noise.get_noise_2d(x, z) * 0.5 + 0.5
	var h := pow(n, 1.7) * 5.5
	for hl in hills:
		h += _gauss(p, Vector2(hl.x, hl.y), hl.z) * hl.w
	h *= edge
	# rivers + ponds
	var dr := 1e9
	for r in rivers:
		dr = minf(dr, dist_to_polyline(p, r))
	for pd in ponds:
		dr = minf(dr, maxf(0.0, p.distance_to(Vector2(pd.x, pd.y)) - pd.z))
	h = lerpf(h, -2.6, smoothstep(10.0, 4.0, dr))
	# lake
	var q := (p - lake_c) / lake_r
	var dl := q.length_squared()
	h = lerpf(h, -3.2, smoothstep(1.45, 0.8, dl))
	# island rising out of the lake
	var di := p.distance_to(Vector2(island.x, island.y))
	h = maxf(h, lerpf(-3.2, 1.6, smoothstep(island.z + 6.0, island.z - 1.0, di)))
	return h


func height_at(x: float, z: float) -> float:
	var fx := clampf((x - rect.position.x) / step, 0.0, float(w - 1) - 0.001)
	var fz := clampf((z - rect.position.y) / step, 0.0, float(d - 1) - 0.001)
	var i := int(fx)
	var j := int(fz)
	var tx := fx - i
	var tz := fz - j
	var h00 := heights[j * w + i]
	var h10 := heights[j * w + i + 1]
	var h01 := heights[(j + 1) * w + i]
	var h11 := heights[(j + 1) * w + i + 1]
	return lerpf(lerpf(h00, h10, tx), lerpf(h01, h11, tx), tz)


func normal_at(i: int, j: int) -> Vector3:
	var hl := heights[j * w + maxi(i - 1, 0)]
	var hr := heights[j * w + mini(i + 1, w - 1)]
	var hd := heights[maxi(j - 1, 0) * w + i]
	var hu := heights[mini(j + 1, d - 1) * w + i]
	return Vector3(hl - hr, 2.0 * step, hd - hu).normalized()


func forest_density(x: float, z: float) -> float:
	return forest_noise.get_noise_2d(x, z) * 0.5 + 0.5


func _color(x: float, z: float, h: float, n: Vector3) -> Color:
	var grass_a := Color(0.24, 0.5, 0.3)
	var grass_b := Color(0.36, 0.62, 0.36)
	var g := grass_a.lerp(grass_b, clampf(noise.get_noise_2d(x * 3.0, z * 3.0) * 0.5 + 0.5, 0.0, 1.0))
	g = g.lerp(Color(0.5, 0.72, 0.42), smoothstep(3.0, 9.0, h) * 0.6)
	var dark := forest_density(x, z)
	g = g.lerp(Color(0.16, 0.36, 0.26), smoothstep(0.55, 0.8, dark) * 0.6)
	if h < WATER_LEVEL + 0.5:
		g = g.lerp(Color(0.5, 0.46, 0.34), smoothstep(WATER_LEVEL + 0.5, WATER_LEVEL - 0.6, h))
	if h < -1.6:
		g = g.lerp(Color(0.14, 0.2, 0.26), smoothstep(-1.6, -3.0, h))
	if n.y < 0.82:
		g = g.lerp(Color(0.42, 0.38, 0.32), smoothstep(0.82, 0.68, n.y))
	var pd := path_distance(Vector2(x, z))
	if pd < 1.9 and h > WATER_LEVEL:
		g = g.lerp(Color(0.66, 0.62, 0.55), smoothstep(1.9, 1.2, pd))
	return g


func build_mesh() -> ArrayMesh:
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	verts.resize(w * d)
	norms.resize(w * d)
	cols.resize(w * d)
	for j in d:
		for i in w:
			var x := rect.position.x + i * step
			var z := rect.position.y + j * step
			var h := heights[j * w + i]
			var n := normal_at(i, j)
			var k := j * w + i
			verts[k] = Vector3(x, h, z)
			norms[k] = n
			cols[k] = _color(x, z, h, n)
	for j in d - 1:
		for i in w - 1:
			var a := j * w + i
			var b := a + 1
			var c := a + w
			var e := c + 1
			idx.append_array([a, b, c, b, e, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


func build_shape() -> HeightMapShape3D:
	var s := HeightMapShape3D.new()
	s.map_width = w
	s.map_depth = d
	s.map_data = heights
	return s
