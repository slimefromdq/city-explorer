class_name Kit
extends RefCounted
## Tiny builder for hand-authored geometry. A top-level Kit owns a Node3D root
## and ONE StaticBody3D; sub-kits (props) share that body, so a whole block is
## a single physics body with many shapes. `box()` adds a visible mesh and
## (optionally) a matching collision shape. All boxes are positioned by their
## bottom centre.

var root: Node3D
var body: StaticBody3D
var xform := Transform3D.IDENTITY   # this kit's root space -> body space


func _init(parent: Node, node_name := "Kit", at := Vector3.ZERO, yaw_deg := 0.0, shared: Kit = null) -> void:
	root = Node3D.new()
	root.name = node_name
	root.position = at
	root.rotation_degrees.y = yaw_deg
	parent.add_child(root)
	if shared == null:
		body = StaticBody3D.new()
		body.collision_layer = Fighter.LAYER_WORLD
		body.collision_mask = 0
		root.add_child(body)
	else:
		body = shared.body
		xform = shared.xform * Transform3D(Basis(Vector3.UP, deg_to_rad(yaw_deg)), at)


func sub(node_name: String, at: Vector3, yaw_deg := 0.0) -> Kit:
	return Kit.new(root, node_name, at, yaw_deg, self)


func _add_shape(shape: Shape3D, local: Transform3D) -> void:
	var cs := CollisionShape3D.new()
	cs.shape = shape
	cs.transform = xform * local
	body.add_child(cs)


func box(pos: Vector3, size: Vector3, mat: Material, collide := true, rot_deg := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = size
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos + Vector3(0.0, size.y * 0.5, 0.0)
	mi.rotation_degrees = rot_deg
	if not shadow:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if collide:
		var bs := BoxShape3D.new()
		bs.size = size
		_add_shape(bs, mi.transform)
	return mi


func cyl(pos: Vector3, radius: float, height: float, mat: Material, collide := false, sides := 14, top_radius := -1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := CylinderMesh.new()
	m.bottom_radius = radius
	m.top_radius = radius if top_radius < 0.0 else top_radius
	m.height = height
	m.radial_segments = sides
	m.rings = 1
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos + Vector3(0.0, height * 0.5, 0.0)
	root.add_child(mi)
	if collide:
		var s := CylinderShape3D.new()
		s.radius = radius
		s.height = height
		_add_shape(s, mi.transform)
	return mi


## Collision only (no mesh): invisible platforms, tree trunks, safety walls.
func collision_cyl(pos: Vector3, radius: float, height: float) -> void:
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = height
	_add_shape(s, Transform3D(Basis.IDENTITY, pos + Vector3(0.0, height * 0.5, 0.0)))


func collision_box(pos: Vector3, size: Vector3) -> void:
	var s := BoxShape3D.new()
	s.size = size
	_add_shape(s, Transform3D(Basis.IDENTITY, pos + Vector3(0.0, size.y * 0.5, 0.0)))


func sphere(pos: Vector3, radius: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * 2.0
	m.radial_segments = 12
	m.rings = 6
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	return mi


## Slab whose TOP surface runs from point a to point b (a walkable ramp).
func ramp(a: Vector3, b: Vector3, width: float, thickness: float, mat: Material, collide := true) -> MeshInstance3D:
	var fwd := (b - a).normalized()
	var right := fwd.cross(Vector3.UP).normalized()
	var up := right.cross(fwd).normalized()
	var basis := Basis(fwd, up, fwd.cross(up).normalized())
	var length := a.distance_to(b)
	var mi := MeshInstance3D.new()
	var m := BoxMesh.new()
	m.size = Vector3(length, thickness, width)
	mi.mesh = m
	mi.material_override = mat
	mi.transform = Transform3D(basis, (a + b) * 0.5 - up * thickness * 0.5)
	root.add_child(mi)
	if collide:
		var bs := BoxShape3D.new()
		bs.size = m.size
		_add_shape(bs, mi.transform)
	return mi


## Stairs: a gentle collision ramp under stepped visuals (CharacterBody3D
## doesn't step, so the ramp is what you actually walk on).
func stairs(bottom: Vector3, dir: Vector3, rise: float, run: float, width: float, mat: Material) -> void:
	var d := Vector3(dir.x, 0.0, dir.z).normalized()
	var n := maxi(2, int(round(rise / 0.2)))
	ramp(bottom, bottom + d * run + Vector3.UP * rise, width, 0.3, mat)
	var basis := Basis.looking_at(d, Vector3.UP)
	for i in n:
		var t0 := float(i) / float(n)
		var h := rise * (t0 + 1.0 / float(n))
		var p := bottom + d * (run * t0)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(width, h, run / float(n))
		mi.mesh = bm
		mi.material_override = mat
		mi.transform = Transform3D(basis, p + d * (run / float(n)) * 0.5 + Vector3.UP * h * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)


func label(text: String, pos: Vector3, size: float, color: Color, yaw_deg := 0.0, _emissive := true) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.font_size = 96
	l.pixel_size = size / 96.0
	l.modulate = color
	l.outline_size = 0
	l.shaded = false
	l.double_sided = false
	l.position = pos
	l.rotation_degrees.y = yaw_deg
	l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(l)
	return l


func mural_quad(pos: Vector3, size: Vector2, yaw_deg: float, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = size
	mi.mesh = q
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees.y = yaw_deg
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	return mi
