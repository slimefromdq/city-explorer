@tool
class_name ConcourseHall
extends Node3D
## A full concourse hall built from ConcourseBay modules.
##
## Layout: the long axis runs along X, centred on the origin; floor level is
## y = 0. Two rows of `hall_bays` bays face each other across `hall_width`
## (measured between the walls' front faces, i.e. the open hall). The -Z row
## is the bay as authored; the +Z row is the same bay turned 180 degrees.
##
## Tiling: bays butt together (see ConcourseBay), so the hall is exactly
## hall_bays * bay_width long. Each end is closed by a stone end wall with an
## arched entrance cut through it. The end wall also fills the vault's end, so
## no part of the vault shell is ever seen edge-on.
##
## The barrel vault is an elliptical arch, `vault_rise` high, springing from the
## top of the cornice (y = wall_height) and spanning the hall between the wall
## front faces. Its underside carries the dark-teal star shader.
##
## Bay dimensions are tuned on the bay itself: edit ConcourseBay.tscn, or pass
## per-hall overrides in `bay_properties` (e.g. {"window_height": 18.0}).

@export_group("Hall")
@export_range(1, 40, 1) var hall_bays := 5: set = _set_hall_bays
## Distance between the two walls' front faces.
@export_range(8.0, 120.0, 0.5, "suffix:m") var hall_width := 30.0: set = _set_hall_width
@export var bay_scene: PackedScene = preload("res://concourse/ConcourseBay.tscn"): set = _set_bay_scene
@export var bay_properties: Dictionary = {}: set = _set_bay_properties

@export_group("Vault")
## Height of the vault above the spring line (the cornice top).
@export_range(0.5, 40.0, 0.1, "suffix:m") var vault_rise := 9.0: set = _set_vault_rise
@export_range(0.1, 4.0, 0.05, "suffix:m") var vault_thickness := 1.0: set = _set_vault_thickness
@export_range(8, 128, 1) var vault_segments := 64: set = _set_vault_segments
@export var ceiling_color := Color(0.03, 0.22, 0.25): set = _set_ceiling_color
@export_range(0.0, 1.0, 0.01) var star_density := 0.45: set = _set_star_density
@export_range(0.0, 16.0, 0.1) var star_energy := 4.0: set = _set_star_energy

@export_group("Entrances")
@export_range(1.0, 60.0, 0.1, "suffix:m") var entrance_width := 10.0: set = _set_entrance_width
## Floor to the top of the arch.
@export_range(2.0, 60.0, 0.1, "suffix:m") var entrance_height := 14.0: set = _set_entrance_height

@export_group("Floor")
@export var floor_color := Color(0.30, 0.28, 0.26): set = _set_floor_color
@export_range(0.1, 5.0, 0.05, "suffix:m") var floor_thickness := 0.5: set = _set_floor_thickness

@export_group("Look")
@export var stone_color := Color(0.55, 0.55, 0.57): set = _set_stone_color

const VAULT_STARS := preload("res://concourse/vault_stars.gdshader")
const GENERATED := "Generated"
const CUT_OVERSHOOT := 0.05  # entrance cutters poke past the wall so no skin remains

var _rebuild_queued := false


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	_rebuild_queued = false
	if not is_inside_tree() or bay_scene == null:
		return
	var old := get_node_or_null(GENERATED)
	if old != null:
		remove_child(old)
		old.queue_free()
	var root := Node3D.new()
	root.name = GENERATED
	add_child(root)  # not owned: never saved into the .tscn

	var stone := StandardMaterial3D.new()
	stone.albedo_color = stone_color
	stone.roughness = 1.0

	var dims := _build_bays(root)
	var length: float = dims.length
	_build_floor(root, length, dims.wall_thickness)
	_build_end_walls(root, length, dims, stone)
	_build_vault(root, length, dims)


## Instantiates both rows. Returns the facts about one bay the rest needs.
func _build_bays(root: Node3D) -> Dictionary:
	var dims := {}
	var first: ConcourseBay
	for side in [-1, 1]:  # -1: wall on -Z (as authored); +1: wall on +Z, turned round
		var row := Node3D.new()
		row.name = "WallNegZ" if side < 0 else "WallPosZ"
		row.position.z = side * hall_width * 0.5
		row.rotation.y = 0.0 if side < 0 else PI
		root.add_child(row)
		for i in hall_bays:
			var bay: ConcourseBay = bay_scene.instantiate()
			for k in bay_properties:
				bay.set(k, bay_properties[k])
			if first == null:
				first = bay
			bay.name = "Bay%d" % i
			bay.position.x = (i - (hall_bays - 1) * 0.5) * first.bay_width
			row.add_child(bay)
	dims.length = first.bay_width * hall_bays
	dims.wall_height = first.wall_height
	dims.wall_thickness = first.wall_thickness
	return dims


func _build_floor(root: Node3D, length: float, wall_t: float) -> void:
	var t: float = floor_thickness
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	var mesh := BoxMesh.new()
	# Under the end walls and the long walls too, so there is no seam at the edges.
	mesh.size = Vector3(length + 2.0 * wall_t, t, hall_width + 2.0 * wall_t)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = floor_color
	mat.roughness = 0.6
	mesh.material = mat
	mi.mesh = mesh
	mi.position.y = -t * 0.5
	root.add_child(mi)


# ------------------------------------------------------------------ end walls

func _build_end_walls(root: Node3D, length: float, dims: Dictionary, stone: Material) -> void:
	for side in [1, -1]:
		var holder := Node3D.new()
		holder.name = "EndWallPosX" if side > 0 else "EndWallNegX"
		holder.rotation.y = 0.0 if side > 0 else PI
		root.add_child(holder)
		_build_one_end_wall(holder, length, dims, stone)


## Built for the +X end; the -X end is the same node turned 180 degrees.
func _build_one_end_wall(holder: Node3D, length: float, dims: Dictionary, stone: Material) -> void:
	var t: float = dims.wall_thickness
	var wall_h: float = dims.wall_height
	var a_out := hall_width * 0.5 + vault_thickness  # outer vault half-span
	var b_out := vault_rise + vault_thickness

	var comb := CSGCombiner3D.new()
	comb.name = "Wall"
	comb.use_collision = true
	comb.position.x = length * 0.5 + t * 0.5  # inner face flush with the bay ends
	holder.add_child(comb)

	var slab := CSGBox3D.new()
	slab.size = Vector3(t, wall_h, a_out * 2.0)
	slab.position.y = wall_h * 0.5
	slab.material = stone
	comb.add_child(slab)

	# Gable: an elliptic cylinder (axis along X) matching the vault's outer profile.
	var gable := CSGCylinder3D.new()
	gable.name = "Gable"
	gable.radius = a_out
	gable.height = t
	gable.sides = vault_segments * 2
	gable.rotation.z = PI * 0.5       # cylinder axis Y -> X
	gable.scale.x = b_out / a_out     # local X ends up as world Y: squash the circle into the ellipse
	gable.position.y = wall_h
	gable.material = stone
	comb.add_child(gable)

	var ew := entrance_width
	var arch_r := ew * 0.5
	var spring_y := entrance_height - arch_r
	var cut_t := t + CUT_OVERSHOOT * 2.0

	var rect := CSGBox3D.new()
	rect.name = "EntranceRect"
	rect.operation = CSGShape3D.OPERATION_SUBTRACTION
	rect.size = Vector3(cut_t, spring_y + CUT_OVERSHOOT, ew)  # starts just below the floor
	rect.position.y = (spring_y - CUT_OVERSHOOT) * 0.5
	rect.material = stone
	comb.add_child(rect)

	var arch := CSGCylinder3D.new()
	arch.name = "EntranceArch"
	arch.operation = CSGShape3D.OPERATION_SUBTRACTION
	arch.radius = arch_r
	arch.height = cut_t
	arch.sides = vault_segments
	arch.rotation.z = PI * 0.5
	arch.position.y = spring_y
	arch.material = stone
	comb.add_child(arch)


# ---------------------------------------------------------------------- vault

func _build_vault(root: Node3D, length: float, dims: Dictionary) -> void:
	var spring_y: float = dims.wall_height
	var a_in := hall_width * 0.5
	var b_in := vault_rise
	var a_out := a_in + vault_thickness
	var b_out := b_in + vault_thickness
	var x0 := -length * 0.5
	var x1 := length * 0.5

	var inner_mat := ShaderMaterial.new()
	inner_mat.shader = VAULT_STARS
	inner_mat.set_shader_parameter("base_color", ceiling_color)
	inner_mat.set_shader_parameter("density", star_density)
	inner_mat.set_shader_parameter("star_energy", star_energy)
	var outer_mat := StandardMaterial3D.new()
	outer_mat.albedo_color = ceiling_color.darkened(0.3)
	outer_mat.roughness = 1.0

	var mesh := ArrayMesh.new()
	_add_vault_surface(mesh, inner_mat, a_in, b_in, spring_y, x0, x1, true)
	_add_vault_surface(mesh, outer_mat, a_out, b_out, spring_y, x0, x1, false)
	var mi := MeshInstance3D.new()
	mi.name = "Vault"
	mi.mesh = mesh
	root.add_child(mi)


## One elliptical surface swept along X. facing_in = the visible side points at
## the hall (inner shell); otherwise it points away from it (outer shell).
func _add_vault_surface(mesh: ArrayMesh, mat: Material, a: float, b: float, spring_y: float,
		x0: float, x1: float, facing_in: bool) -> void:
	var n := vault_segments
	var pts: Array[Vector2] = []  # (z, y) around the half ellipse, +Z side to -Z side
	var nrm: Array[Vector2] = []
	var arc: Array[float] = [0.0]
	for i in n + 1:
		var t := PI * i / n
		pts.append(Vector2(a * cos(t), spring_y + b * sin(t)))
		var out := Vector2(cos(t) / a, sin(t) / b).normalized()
		nrm.append(-out if facing_in else out)
		if i > 0:
			arc.append(arc[i - 1] + pts[i].distance_to(pts[i - 1]))

	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.set_material(mat)
	for i in n:
		var corners := [
			[Vector3(x0, pts[i].y, pts[i].x), Vector2(x0, arc[i]), nrm[i]],
			[Vector3(x1, pts[i].y, pts[i].x), Vector2(x1, arc[i]), nrm[i]],
			[Vector3(x1, pts[i + 1].y, pts[i + 1].x), Vector2(x1, arc[i + 1]), nrm[i + 1]],
			[Vector3(x0, pts[i + 1].y, pts[i + 1].x), Vector2(x0, arc[i + 1]), nrm[i + 1]],
		]
		_tri(st, corners[0], corners[1], corners[2])
		_tri(st, corners[0], corners[2], corners[3])
	mesh = st.commit(mesh)


## Emits one triangle wound for Godot (clockwise seen from the visible side).
## Each corner is [position, uv, normal(z, y)].
func _tri(st: SurfaceTool, c0: Array, c1: Array, c2: Array) -> void:
	var facing := Vector3(0.0, (c0[2].y + c1[2].y + c2[2].y) / 3.0, (c0[2].x + c1[2].x + c2[2].x) / 3.0)
	var flat: Vector3 = (c1[0] - c0[0]).cross(c2[0] - c0[0])  # points at the viewer when counter-clockwise
	var order := [c0, c1, c2] if flat.dot(facing) < 0.0 else [c0, c2, c1]
	for c in order:
		st.set_normal(Vector3(0.0, c[2].y, c[2].x))
		st.set_uv(c[1])
		st.add_vertex(c[0])


# ---------------------------------------------------------------------- setters

func _queue_rebuild() -> void:
	if _rebuild_queued or not is_inside_tree():
		return
	_rebuild_queued = true
	rebuild.call_deferred()


func _set_hall_bays(v: int) -> void: hall_bays = v; _queue_rebuild()
func _set_hall_width(v: float) -> void: hall_width = v; _queue_rebuild()
func _set_bay_scene(v: PackedScene) -> void: bay_scene = v; _queue_rebuild()
func _set_bay_properties(v: Dictionary) -> void: bay_properties = v; _queue_rebuild()
func _set_vault_rise(v: float) -> void: vault_rise = v; _queue_rebuild()
func _set_vault_thickness(v: float) -> void: vault_thickness = v; _queue_rebuild()
func _set_vault_segments(v: int) -> void: vault_segments = v; _queue_rebuild()
func _set_ceiling_color(v: Color) -> void: ceiling_color = v; _queue_rebuild()
func _set_star_density(v: float) -> void: star_density = v; _queue_rebuild()
func _set_star_energy(v: float) -> void: star_energy = v; _queue_rebuild()
func _set_entrance_width(v: float) -> void: entrance_width = v; _queue_rebuild()
func _set_entrance_height(v: float) -> void: entrance_height = v; _queue_rebuild()
func _set_floor_color(v: Color) -> void: floor_color = v; _queue_rebuild()
func _set_floor_thickness(v: float) -> void: floor_thickness = v; _queue_rebuild()
func _set_stone_color(v: Color) -> void: stone_color = v; _queue_rebuild()
