class_name Trail3D
extends MeshInstance3D
## Camera-facing ribbon that follows a moving point. Used for bullet streaks
## and speed trails; length/width are plain properties so streaks can scale
## with a fighter's threat level.

var lifetime := 0.25
var width := 0.25
var color := Color(1, 1, 1, 1)
var min_step := 0.08
var emitting := true

var _pts: Array[Vector3] = []
var _ages: Array[float] = []
var _im := ImmediateMesh.new()
static var _mat: StandardMaterial3D


func _ready() -> void:
	top_level = true
	mesh = _im
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	if _mat == null:
		_mat = StandardMaterial3D.new()
		_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_mat.vertex_color_use_as_albedo = true
		_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	material_override = _mat
	global_transform = Transform3D.IDENTITY


func push(p: Vector3) -> void:
	if _pts.is_empty() or _pts[_pts.size() - 1].distance_to(p) >= min_step:
		_pts.append(p)
		_ages.append(0.0)


func clear_points() -> void:
	_pts.clear()
	_ages.clear()
	_im.clear_surfaces()


func _process(dt: float) -> void:
	for i in _ages.size():
		_ages[i] += dt
	while not _ages.is_empty() and _ages[0] > lifetime:
		_ages.remove_at(0)
		_pts.remove_at(0)
	_im.clear_surfaces()
	if _pts.size() < 2:
		return
	var cam := get_viewport().get_camera_3d()
	var cpos := cam.global_position if cam != null else Vector3(0, 50, 0)
	_im.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP)
	for i in _pts.size():
		var p := _pts[i]
		var dir := (_pts[mini(i + 1, _pts.size() - 1)] - _pts[maxi(i - 1, 0)])
		var side := dir.cross(cpos - p).normalized()
		var life := 1.0 - _ages[i] / lifetime
		var w := width * life * 0.5
		var c := Color(color.r, color.g, color.b, color.a * life)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p + side * w)
		_im.surface_set_color(c)
		_im.surface_add_vertex(p - side * w)
	_im.surface_end()
