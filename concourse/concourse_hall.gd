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

@export_group("End windows")
## Round window above each entrance (0 = none). It is a real opening, so light comes through.
@export_range(0.0, 12.0, 0.1, "suffix:m") var rose_radius := 3.8: set = _set_rose_radius
## Height of the window's centre above the floor.
@export_range(4.0, 40.0, 0.1, "suffix:m") var rose_height := 25.5: set = _set_rose_height
## Number of radial spokes (even; spokes are built as full diameters).
@export_range(2, 24, 2) var rose_spokes := 8: set = _set_rose_spokes

@export_group("Floor")
@export_range(0.1, 5.0, 0.05, "suffix:m") var floor_thickness := 0.5: set = _set_floor_thickness
@export_range(0.25, 6.0, 0.05, "suffix:m") var tile_size := 2.0: set = _set_tile_size
@export var tile_color_a := Color(0.74, 0.70, 0.64): set = _set_tile_color_a
@export var tile_color_b := Color(0.60, 0.56, 0.50): set = _set_tile_color_b
## Band along the walls (0 = none).
@export_range(0.0, 5.0, 0.05, "suffix:m") var border_width := 1.6: set = _set_border_width
@export var border_color := Color(0.46, 0.41, 0.36): set = _set_border_color
## Radius of the compass inlay at the hall centre (0 = none).
@export_range(0.0, 15.0, 0.1, "suffix:m") var inlay_radius := 7.0: set = _set_inlay_radius
@export var inlay_color := Color(0.40, 0.31, 0.22): set = _set_inlay_color

@export_group("Mezzanine")
@export var mezzanine_enabled := true: set = _set_mezzanine_enabled
## Height of the walking surface above the main floor.
@export_range(3.0, 20.0, 0.1, "suffix:m") var mezzanine_height := 8.0: set = _set_mezzanine_height
## Depth of the balcony strips (and the stair landings).
@export_range(1.5, 6.0, 0.1, "suffix:m") var mezzanine_depth := 3.0: set = _set_mezzanine_depth
@export_range(0.2, 1.5, 0.05, "suffix:m") var mezzanine_thickness := 0.5: set = _set_mezzanine_thickness
@export_range(1.0, 8.0, 0.1, "suffix:m") var bridge_width := 3.5: set = _set_bridge_width
## Distance of each bridge from the hall centre. The stair flights pass under the bridges, and the
## closer a bridge is to the hall centre, the more headroom it leaves (the hall warns below 4 m).
## Too close and the near bridge starts to hide the clock from the entrances.
@export_range(2.0, 18.0, 0.1, "suffix:m") var bridge_distance := 8.5: set = _set_bridge_distance
## How far the middle of each bridge is raised above the balcony level. The bridges arch up from
## the balconies, which lifts them over the stair flights (the hall warns if a player could not
## jump on the stairs under a bridge). Steeper arches are harder to walk: 0 = a flat bridge.
@export_range(0.0, 6.0, 0.1, "suffix:m") var bridge_arch_rise := 3.0: set = _set_bridge_arch_rise
## Width of each of the four flights (two at each end).
@export_range(1.0, 6.0, 0.1, "suffix:m") var stair_width := 4.0: set = _set_stair_width
## Target riser height; the hall adjusts it slightly so a whole number of steps reaches the mezzanine.
@export_range(0.1, 0.3, 0.005, "suffix:m") var step_height := 0.2: set = _set_step_height
@export_range(0.2, 0.5, 0.01, "suffix:m") var step_depth := 0.3: set = _set_step_depth
@export var mezzanine_floor_color := Color(0.40, 0.28, 0.21): set = _set_mezzanine_floor_color
## Raise the windows' sills to sit above the balustrade, so the walkway never crosses a
## window opening. The window tops stay where they are. Off = windows unchanged.
@export var raise_window_sills := true: set = _set_raise_window_sills

@export_group("Landmark")
@export var landmark_enabled := true: set = _set_landmark_enabled
## Height of the clock tower's apex above the floor.
@export_range(4.0, 30.0, 0.1, "suffix:m") var landmark_height := 11.0: set = _set_landmark_height
## Scales the booth base and the clock box (not the height).
@export_range(0.5, 3.0, 0.05) var landmark_booth_scale := 1.4: set = _set_landmark_booth_scale

@export_group("Lighting")
## Adds the sun, two wall-washing fills, and a WorldEnvironment (ambient + sky) to the hall.
@export var lighting_enabled := true: set = _set_lighting_enabled
## Compass direction the sun's light travels. 180 = straight from the -Z wall to the +Z wall;
## away from 180 makes the beams drift along the hall.
@export_range(0.0, 360.0, 1.0, "suffix:deg") var sun_yaw_degrees := 200.0: set = _set_sun_yaw
## Negative = shining downward. Steeper (more negative) lands the beams closer to the walls.
@export_range(-85.0, -5.0, 1.0, "suffix:deg") var sun_pitch_degrees := -38.0: set = _set_sun_pitch
## The sun's light_energy. Too high and the beams clip to white and hide the floor pattern.
@export_range(0.0, 8.0, 0.05) var sun_energy := 0.35: set = _set_sun_energy
## The sun's light_color (pale warm gold by default).
@export var sun_color := Color(1.0, 0.88, 0.62): set = _set_sun_color
## Soft light everywhere, so shadowed areas aren't black.
@export var ambient_color := Color(0.62, 0.66, 0.78): set = _set_ambient_color
@export_range(0.0, 4.0, 0.05) var ambient_energy := 0.5: set = _set_ambient_energy
## Two shadowless fills, one washing each wall, so piers and cornices read on both sides.
@export_range(0.0, 2.0, 0.05) var fill_energy := 0.25: set = _set_fill_energy
@export var sky_color := Color(0.55, 0.70, 0.90): set = _set_sky_color

@export_group("Look")
@export var stone_color := Color(0.55, 0.55, 0.57): set = _set_stone_color

const VAULT_STARS := preload("res://concourse/vault_stars.gdshader")
const FLOOR_STONE := preload("res://concourse/floor_stone.gdshader")
const GENERATED := "Generated"
const ROSE_RING_RADIUS_RATIO := 0.62    # tracery ring radius as a fraction of the window radius
const ROSE_BAR_RATIO := 0.09            # ring/spoke thickness as a fraction of the window radius
const ROSE_HUB_RATIO := 0.16
const ROSE_TRACERY_DEPTH_RATIO := 0.6   # tracery is thinner than the wall, so it reads as recessed
const SILL_OVER_DECK := 1.4  # window sill above the mezzanine walking surface (m): clears the balustrade
const SHADOW_DISTANCE := 200.0
const FILL_PITCH_DEGREES := -30.0
const FILL_YAW_TOWARD_NEG_Z := 10.0   # light travels toward -Z: washes the -Z wall
const FILL_YAW_TOWARD_POS_Z := 190.0  # light travels toward +Z: washes the +Z wall
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
	_build_landmark(root)
	_build_mezzanine(root, dims)
	_build_lighting(root)


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
			if mezzanine_enabled and raise_window_sills:
				var sill: float = mezzanine_height + SILL_OVER_DECK
				if bay.window_sill_height < sill:  # keep the window top where it was
					bay.window_height = bay.window_sill_height + bay.window_height - sill
					bay.window_sill_height = sill
			if first == null:
				first = bay
			bay.name = "Bay%d" % i
			bay.position.x = (i - (hall_bays - 1) * 0.5) * first.bay_width
			row.add_child(bay)
	dims.length = first.bay_width * hall_bays
	dims.wall_height = first.wall_height
	dims.wall_thickness = first.wall_thickness
	dims.bay_width = first.bay_width
	return dims


func _build_floor(root: Node3D, length: float, wall_t: float) -> void:
	var t: float = floor_thickness
	var mi := MeshInstance3D.new()
	mi.name = "Floor"
	var mesh := BoxMesh.new()
	# Under the end walls and the long walls too, so there is no seam at the edges.
	mesh.size = Vector3(length + 2.0 * wall_t, t, hall_width + 2.0 * wall_t)
	var mat := ShaderMaterial.new()
	mat.shader = FLOOR_STONE
	mat.set_shader_parameter("half_size", Vector2(length, hall_width) * 0.5)
	mat.set_shader_parameter("tile_size", tile_size)
	mat.set_shader_parameter("color_a", tile_color_a)
	mat.set_shader_parameter("color_b", tile_color_b)
	mat.set_shader_parameter("border_width", border_width)
	mat.set_shader_parameter("border_color", border_color)
	mat.set_shader_parameter("inlay_radius", inlay_radius)
	mat.set_shader_parameter("inlay_color", inlay_color)
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

	_build_rose_window(comb, t, stone)


## Round window with tracery, cut through an end wall. `comb` is the wall's CSG
## combiner (cylinders have their axis turned from Y to X). The tracery (ring,
## spokes, hub) is a nested combiner added after the cut, so it fills part of the hole.
func _build_rose_window(comb: CSGCombiner3D, t: float, stone: Material) -> void:
	if rose_radius <= 0.0:
		return
	var r := rose_radius
	var cut_t := t + CUT_OVERSHOOT * 2.0

	var hole := CSGCylinder3D.new()
	hole.name = "RoseHole"
	hole.operation = CSGShape3D.OPERATION_SUBTRACTION
	hole.radius = r
	hole.height = cut_t
	hole.sides = vault_segments
	hole.rotation.z = PI * 0.5
	hole.position.y = rose_height
	hole.material = stone
	comb.add_child(hole)

	var tracery := CSGCombiner3D.new()
	tracery.name = "RoseTracery"
	tracery.position.y = rose_height
	comb.add_child(tracery)

	var ring_out := CSGCylinder3D.new()
	ring_out.radius = r * ROSE_RING_RADIUS_RATIO + r * ROSE_BAR_RATIO * 0.5
	ring_out.height = t * ROSE_TRACERY_DEPTH_RATIO
	ring_out.sides = vault_segments
	ring_out.rotation.z = PI * 0.5
	ring_out.material = stone
	tracery.add_child(ring_out)
	var ring_in := CSGCylinder3D.new()
	ring_in.operation = CSGShape3D.OPERATION_SUBTRACTION
	ring_in.radius = r * ROSE_RING_RADIUS_RATIO - r * ROSE_BAR_RATIO * 0.5
	ring_in.height = t
	ring_in.sides = vault_segments
	ring_in.rotation.z = PI * 0.5
	ring_in.material = stone
	tracery.add_child(ring_in)

	var hub := CSGCylinder3D.new()
	hub.radius = r * ROSE_HUB_RATIO
	hub.height = t * ROSE_TRACERY_DEPTH_RATIO
	hub.sides = vault_segments
	hub.rotation.z = PI * 0.5
	hub.material = stone
	tracery.add_child(hub)

	# Spokes are full diameters, so N spokes need N / 2 boxes.
	for k in rose_spokes / 2:
		var spoke := CSGBox3D.new()
		spoke.name = "Spoke%d" % k
		spoke.size = Vector3(t * ROSE_TRACERY_DEPTH_RATIO, r * 2.0, r * ROSE_BAR_RATIO)
		spoke.rotation.x = k * TAU / rose_spokes
		spoke.material = stone
		tracery.add_child(spoke)


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


# ------------------------------------------------------------------- landmark

func _build_landmark(root: Node3D) -> void:
	if not landmark_enabled:
		return
	var lm := ConcourseLandmark.new()
	lm.name = "Landmark"
	lm.tower_height = landmark_height
	lm.booth_scale = landmark_booth_scale
	root.add_child(lm)


# ------------------------------------------------------------------ mezzanine

func _build_mezzanine(root: Node3D, dims: Dictionary) -> void:
	if not mezzanine_enabled:
		return
	var mz := ConcourseMezzanine.new()
	mz.name = "Mezzanine"
	mz.hall_length = dims.length
	mz.hall_width = hall_width
	mz.bay_width = dims.bay_width
	mz.bay_count = hall_bays
	mz.entrance_width = entrance_width
	mz.height = mezzanine_height
	mz.depth = mezzanine_depth
	mz.thickness = mezzanine_thickness
	mz.bridge_width = bridge_width
	mz.bridge_distance = bridge_distance
	mz.bridge_arch_rise = bridge_arch_rise
	mz.stair_width = stair_width
	mz.step_height = step_height
	mz.step_depth = step_depth
	mz.floor_color = mezzanine_floor_color
	mz.stone_color = stone_color
	root.add_child(mz)
	mz.rebuild()


# ------------------------------------------------------------------- lighting

func _build_lighting(root: Node3D) -> void:
	if not lighting_enabled:
		return
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation_degrees = Vector3(sun_pitch_degrees, sun_yaw_degrees, 0.0)
	sun.light_energy = sun_energy
	sun.light_color = sun_color
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = SHADOW_DISTANCE
	root.add_child(sun)

	for fill_yaw in [FILL_YAW_TOWARD_NEG_Z, FILL_YAW_TOWARD_POS_Z]:
		var fill := DirectionalLight3D.new()
		fill.name = "FillNegZ" if fill_yaw == FILL_YAW_TOWARD_NEG_Z else "FillPosZ"
		fill.rotation_degrees = Vector3(FILL_PITCH_DEGREES, fill_yaw, 0.0)
		fill.light_energy = fill_energy
		root.add_child(fill)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = sky_color
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = ambient_color
	env.ambient_light_energy = ambient_energy
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC  # keeps lit floor tiles from clipping to white
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	root.add_child(we)


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
func _set_tile_size(v: float) -> void: tile_size = v; _queue_rebuild()
func _set_tile_color_a(v: Color) -> void: tile_color_a = v; _queue_rebuild()
func _set_tile_color_b(v: Color) -> void: tile_color_b = v; _queue_rebuild()
func _set_border_width(v: float) -> void: border_width = v; _queue_rebuild()
func _set_border_color(v: Color) -> void: border_color = v; _queue_rebuild()
func _set_inlay_radius(v: float) -> void: inlay_radius = v; _queue_rebuild()
func _set_inlay_color(v: Color) -> void: inlay_color = v; _queue_rebuild()
func _set_landmark_enabled(v: bool) -> void: landmark_enabled = v; _queue_rebuild()
func _set_landmark_height(v: float) -> void: landmark_height = v; _queue_rebuild()
func _set_lighting_enabled(v: bool) -> void: lighting_enabled = v; _queue_rebuild()
func _set_mezzanine_enabled(v: bool) -> void: mezzanine_enabled = v; _queue_rebuild()
func _set_mezzanine_height(v: float) -> void: mezzanine_height = v; _queue_rebuild()
func _set_mezzanine_depth(v: float) -> void: mezzanine_depth = v; _queue_rebuild()
func _set_mezzanine_thickness(v: float) -> void: mezzanine_thickness = v; _queue_rebuild()
func _set_bridge_width(v: float) -> void: bridge_width = v; _queue_rebuild()
func _set_bridge_arch_rise(v: float) -> void: bridge_arch_rise = v; _queue_rebuild()
func _set_bridge_distance(v: float) -> void: bridge_distance = v; _queue_rebuild()
func _set_stair_width(v: float) -> void: stair_width = v; _queue_rebuild()
func _set_step_height(v: float) -> void: step_height = v; _queue_rebuild()
func _set_step_depth(v: float) -> void: step_depth = v; _queue_rebuild()
func _set_mezzanine_floor_color(v: Color) -> void: mezzanine_floor_color = v; _queue_rebuild()
func _set_raise_window_sills(v: bool) -> void: raise_window_sills = v; _queue_rebuild()
func _set_sun_yaw(v: float) -> void: sun_yaw_degrees = v; _queue_rebuild()
func _set_sun_pitch(v: float) -> void: sun_pitch_degrees = v; _queue_rebuild()
func _set_sun_energy(v: float) -> void: sun_energy = v; _queue_rebuild()
func _set_sun_color(v: Color) -> void: sun_color = v; _queue_rebuild()
func _set_rose_radius(v: float) -> void: rose_radius = v; _queue_rebuild()
func _set_rose_height(v: float) -> void: rose_height = v; _queue_rebuild()
func _set_rose_spokes(v: int) -> void: rose_spokes = v; _queue_rebuild()
func _set_landmark_booth_scale(v: float) -> void: landmark_booth_scale = v; _queue_rebuild()
func _set_ambient_color(v: Color) -> void: ambient_color = v; _queue_rebuild()
func _set_ambient_energy(v: float) -> void: ambient_energy = v; _queue_rebuild()
func _set_fill_energy(v: float) -> void: fill_energy = v; _queue_rebuild()
func _set_sky_color(v: Color) -> void: sky_color = v; _queue_rebuild()
func _set_floor_thickness(v: float) -> void: floor_thickness = v; _queue_rebuild()
func _set_stone_color(v: Color) -> void: stone_color = v; _queue_rebuild()
