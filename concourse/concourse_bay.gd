@tool
class_name ConcourseBay
extends Node3D
## One reusable greybox bay of a Grand Central-style concourse wall.
##
## Layout (bay origin = floor level, centred between the two piers):
##   +X runs along the wall, +Y is up, +Z is the hall side (the "front").
##   The wall slab fills z in [-wall_thickness, 0]. Piers, bases, capitals and
##   the cornice stand proud of the front face (z > 0).
##
## TILING: a bay is exactly `bay_width` wide, pier centre to pier centre. Each
## bay builds only HALF of the pier on each side (the half inside its own
## width), so two neighbours meet on the shared pier's centre line and form one
## whole pier - nothing doubled, nothing missing. Wall and cornice span exactly
## bay_width, so they butt together with no gap. The ends of a row show half
## piers; tick `cap_left` / `cap_right` on the end bays to add the missing half.
##
## The window is a real hole: a CSG subtraction (box + half-cylinder arch) cut
## through the wall slab. Everything is rebuilt from the exports below.

@export_group("Bay")
@export_range(2.0, 30.0, 0.1, "suffix:m") var bay_width := 8.0: set = _set_bay_width
@export_range(4.0, 80.0, 0.1, "suffix:m") var wall_height := 25.0: set = _set_wall_height
@export_range(0.2, 5.0, 0.05, "suffix:m") var wall_thickness := 1.0: set = _set_wall_thickness
@export var cap_left := false: set = _set_cap_left
@export var cap_right := false: set = _set_cap_right

@export_group("Pier")
@export_range(0.2, 6.0, 0.05, "suffix:m") var pier_width := 1.5: set = _set_pier_width
## How far the pier stands out from the wall's front face.
@export_range(0.0, 4.0, 0.05, "suffix:m") var pier_depth := 1.0: set = _set_pier_depth
@export_range(0.0, 3.0, 0.05, "suffix:m") var base_height := 1.6: set = _set_base_height
@export_range(0.0, 3.0, 0.05, "suffix:m") var capital_height := 1.4: set = _set_capital_height
## How far base and capital project past the pier shaft (sides and front).
@export_range(0.0, 1.0, 0.01, "suffix:m") var step_projection := 0.2: set = _set_step_projection

@export_group("Window")
@export_range(0.5, 20.0, 0.05, "suffix:m") var window_width := 4.5: set = _set_window_width
## Sill to the top of the arch.
@export_range(1.0, 60.0, 0.1, "suffix:m") var window_height := 16.0: set = _set_window_height
## Floor to the window sill.
@export_range(0.0, 20.0, 0.1, "suffix:m") var window_sill_height := 4.0: set = _set_window_sill_height
@export_range(8, 128, 1) var arch_segments := 48: set = _set_arch_segments

@export_group("Cornice")
@export_range(0.1, 5.0, 0.05, "suffix:m") var cornice_height := 1.2: set = _set_cornice_height
## How far the cornice stands out beyond the pier front face.
@export_range(0.0, 3.0, 0.05, "suffix:m") var cornice_projection := 0.6: set = _set_cornice_projection

@export_group("Look")
@export var stone_color := Color(0.55, 0.55, 0.57): set = _set_stone_color

## Cutters poke this far past the wall faces so the CSG subtraction never
## leaves a coplanar skin over the hole.
const CUT_OVERSHOOT := 0.05
const GENERATED := "Generated"

var _material: StandardMaterial3D
var _rebuild_queued := false


func _ready() -> void:
	rebuild()


## Rebuilds the bay now. Property setters call this lazily (once per frame).
func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree():
		return
	var old := get_node_or_null(GENERATED)
	if old != null:
		remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = GENERATED
	add_child(root)  # deliberately not owned: never saved into the .tscn

	_material = StandardMaterial3D.new()
	_material.albedo_color = stone_color
	_material.roughness = 1.0

	var warning := _validate()
	if warning != "":
		push_warning("ConcourseBay: " + warning)

	_build_wall(root)
	_build_piers(root)
	_build_cornice(root)


func _validate() -> String:
	var side_room := (bay_width - window_width) * 0.5
	if side_room < pier_width * 0.5 + step_projection:
		return "window_width leaves no room for the half piers (and their base/capital steps)."
	if window_sill_height + window_height > wall_height - cornice_height - capital_height:
		return "window top runs into the capitals/cornice; lower window_height or the sill."
	if window_height < window_width * 0.5:
		return "window_height is shorter than the arch (window_width / 2)."
	return ""


# ---------------------------------------------------------------- wall + window

func _build_wall(root: Node3D) -> void:
	var wall_top := wall_height - cornice_height
	var comb := CSGCombiner3D.new()
	comb.name = "Wall"
	comb.use_collision = true
	root.add_child(comb)

	var slab := CSGBox3D.new()
	slab.name = "Slab"
	slab.size = Vector3(bay_width, wall_top, wall_thickness)
	slab.position = Vector3(0, wall_top * 0.5, -wall_thickness * 0.5)
	slab.material = _material
	comb.add_child(slab)

	var radius := window_width * 0.5
	var spring_y := window_sill_height + window_height - radius  # where the arch starts
	var cut_depth := wall_thickness + CUT_OVERSHOOT * 2.0
	var cut_z := -wall_thickness * 0.5

	var rect_h := spring_y - window_sill_height
	var rect := CSGBox3D.new()
	rect.name = "WindowRect"
	rect.operation = CSGShape3D.OPERATION_SUBTRACTION
	rect.size = Vector3(window_width, rect_h, cut_depth)
	rect.position = Vector3(0, window_sill_height + rect_h * 0.5, cut_z)
	rect.material = _material
	comb.add_child(rect)

	var arch := CSGCylinder3D.new()
	arch.name = "WindowArch"
	arch.operation = CSGShape3D.OPERATION_SUBTRACTION
	arch.radius = radius
	arch.height = cut_depth
	arch.sides = arch_segments
	arch.rotation.x = PI * 0.5  # cylinder axis (Y) -> Z, so the arch is a half disc in the XY plane
	arch.position = Vector3(0, spring_y, cut_z)
	arch.material = _material
	comb.add_child(arch)


# ---------------------------------------------------------------------- piers

func _build_piers(root: Node3D) -> void:
	var left_edge := -bay_width * 0.5
	var right_edge := bay_width * 0.5
	var half := pier_width * 0.5
	# Half pier on the inside of each edge (the shared pier's other half belongs to the neighbour).
	_add_pier_part(root, "PierL", left_edge, left_edge + half)
	_add_pier_part(root, "PierR", right_edge - half, right_edge)
	if cap_left:
		_add_pier_part(root, "PierCapL", left_edge - half, left_edge)
	if cap_right:
		_add_pier_part(root, "PierCapR", right_edge, right_edge + half)


## Adds shaft + base + capital for the pier slice between x0 and x1. Steps flare
## outward only on the pier's real outside faces, i.e. on x0 / x1 beyond the
## pier centre line - so they also meet cleanly at the seam with a neighbour.
func _add_pier_part(root: Node3D, part_name: String, x0: float, x1: float) -> void:
	var centre_line := _pier_centre_line(x0, x1)
	var step := step_projection
	var pier_top := wall_height - cornice_height
	# Flare only on the side away from the shared centre line.
	var f0 := step if x0 != centre_line else 0.0
	var f1 := step if x1 != centre_line else 0.0
	var shaft_y0 := base_height
	var shaft_y1 := pier_top - capital_height

	# The face on the shared centre line is left out: it would be an interior
	# face once the neighbour is placed, and edge-on it shows as a hairline.
	var skip_x0 := f0 == 0.0
	var skip_x1 := f1 == 0.0
	_add_box(root, part_name + "Shaft", Vector3(x0, shaft_y0, 0.0), Vector3(x1, shaft_y1, pier_depth), skip_x0, skip_x1)
	_add_box(root, part_name + "Base", Vector3(x0 - f0, 0.0, 0.0), Vector3(x1 + f1, base_height, pier_depth + step), skip_x0, skip_x1)
	_add_box(root, part_name + "Capital", Vector3(x0 - f0, shaft_y1, 0.0), Vector3(x1 + f1, pier_top, pier_depth + step), skip_x0, skip_x1)


## A half pier touches its centre line on exactly one side: the pier's own
## centre is bay edge (shared) for normal parts, and the far edge for caps.
func _pier_centre_line(x0: float, x1: float) -> float:
	var edge_l := -bay_width * 0.5
	var edge_r := bay_width * 0.5
	for e in [edge_l, edge_r]:
		if is_equal_approx(x0, e) or is_equal_approx(x1, e):
			return e
	return x0


## Axis-aligned box between lo and hi. skip_x0 / skip_x1 omit the -X / +X end
## face (used where a neighbouring bay supplies the matching solid).
func _add_box(root: Node3D, box_name: String, lo: Vector3, hi: Vector3, skip_x0 := false, skip_x1 := false) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Each face: outward normal, then 4 corners counter-clockwise seen from outside
	# (_quad flips them to Godot's clockwise front-face winding).
	var a := lo
	var b := Vector3(hi.x, lo.y, lo.z)
	var c := Vector3(hi.x, hi.y, lo.z)
	var d := Vector3(lo.x, hi.y, lo.z)
	var e := Vector3(lo.x, lo.y, hi.z)
	var f := Vector3(hi.x, lo.y, hi.z)
	var g := hi
	var h := Vector3(lo.x, hi.y, hi.z)
	_quad(st, Vector3.BACK, [e, f, g, h])
	_quad(st, Vector3.FORWARD, [b, a, d, c])
	_quad(st, Vector3.UP, [h, g, c, d])
	_quad(st, Vector3.DOWN, [a, b, f, e])
	if not skip_x1:
		_quad(st, Vector3.RIGHT, [f, b, c, g])
	if not skip_x0:
		_quad(st, Vector3.LEFT, [a, e, h, d])
	var mi := MeshInstance3D.new()
	mi.name = box_name
	mi.mesh = st.commit()
	mi.material_override = _material
	root.add_child(mi)


func _quad(st: SurfaceTool, normal: Vector3, v: Array) -> void:
	st.set_normal(normal)
	for i in [0, 2, 1, 0, 3, 2]:  # Godot front faces wind clockwise
		st.add_vertex(v[i])


# --------------------------------------------------------------------- cornice

func _build_cornice(root: Node3D) -> void:
	var front := pier_depth + cornice_projection
	_add_box(root, "Cornice",
		Vector3(-bay_width * 0.5, wall_height - cornice_height, -wall_thickness),
		Vector3(bay_width * 0.5, wall_height, front))


# ---------------------------------------------------------------------- setters

func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func _set_bay_width(v: float) -> void: bay_width = v; _queue_rebuild()
func _set_wall_height(v: float) -> void: wall_height = v; _queue_rebuild()
func _set_wall_thickness(v: float) -> void: wall_thickness = v; _queue_rebuild()
func _set_cap_left(v: bool) -> void: cap_left = v; _queue_rebuild()
func _set_cap_right(v: bool) -> void: cap_right = v; _queue_rebuild()
func _set_pier_width(v: float) -> void: pier_width = v; _queue_rebuild()
func _set_pier_depth(v: float) -> void: pier_depth = v; _queue_rebuild()
func _set_base_height(v: float) -> void: base_height = v; _queue_rebuild()
func _set_capital_height(v: float) -> void: capital_height = v; _queue_rebuild()
func _set_step_projection(v: float) -> void: step_projection = v; _queue_rebuild()
func _set_window_width(v: float) -> void: window_width = v; _queue_rebuild()
func _set_window_height(v: float) -> void: window_height = v; _queue_rebuild()
func _set_window_sill_height(v: float) -> void: window_sill_height = v; _queue_rebuild()
func _set_arch_segments(v: int) -> void: arch_segments = v; _queue_rebuild()
func _set_cornice_height(v: float) -> void: cornice_height = v; _queue_rebuild()
func _set_cornice_projection(v: float) -> void: cornice_projection = v; _queue_rebuild()
func _set_stone_color(v: Color) -> void: stone_color = v; _queue_rebuild()
