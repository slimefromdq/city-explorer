@tool
class_name ConcourseMezzanine
extends Node3D
## Second-level walkway for ConcourseHall, greybox. Built by the hall (it sets the
## plain properties below, then calls rebuild()); tune it through the hall's exports.
##
## Hall-local coordinates: the hall runs along X, centred on the origin; the long
## walls' front faces are at z = +-hall_width / 2; the end walls' inner faces at
## x = +-hall_length / 2.
##
## Pieces
##  - a balcony strip, `depth` deep, along each long wall, carried on a fascia beam
##    and stepped corbels (one stack per bay, under the window)
##  - two bridges across the hall at 1/4 and 3/4 of its length, with girders
##  - at each end, two straight flights flanking the entrance, rising toward the
##    end wall to a landing that joins the balcony strip
##  - balustrades (posts + rails) on every open edge
## All boxes are drawn with two MultiMeshInstance3Ds (stone, and the deck tone), so
## hundreds of posts and treads cost two draw calls.

var hall_length := 40.0
var hall_width := 30.0
var bay_width := 8.0
var bay_count := 5
var entrance_width := 10.0
var height := 8.0           # top of the walking surface
var depth := 3.0            # balcony and landing depth
var thickness := 0.5        # balcony / landing slab thickness
var bridge_thickness := 0.25  # bridge slab thickness (thinner: a flight passes under each bridge)
var undercroft_props := PackedStringArray(["bench", "planter", "lamp", ""])  # one per flight: (+X,+Z) (+X,-Z) (-X,-Z) (-X,+Z)
var bridge_width := 3.5
var bridge_distance := 8.5   # each bridge's centre, measured from the hall centre along X
var bridge_arch_rise := 3.0  # how far the middle of a bridge is raised above the balcony level
var stair_width := 4.0
var step_height := 0.2      # target riser; adjusted so a whole number of risers reaches `height`
var step_depth := 0.3       # tread
var undercroft_enabled := true
var undercroft_height := 3.8   # minimum clear height under a flight: the flight is hollowed out wherever it is tall enough
var floor_color := Color(0.40, 0.28, 0.21)       # walking surfaces only
var underside_color := Color(0.74, 0.68, 0.58)   # warm stone: slabs, girders, fascia, corbels
var stone_color := Color(0.55, 0.55, 0.57)

const MIN_STAIR_HEADROOM := PlayerScale.HEIGHT + PlayerScale.JUMP_HEIGHT + PlayerScale.HEADROOM_MARGIN  # above the treads under a bridge: stand, jump, margin
const SEGMENT_OVERLAP := 0.1
const BRIDGE_SEGMENTS := 24             # straight pieces per arched bridge (about 1 m each)
const STAIR_GAP := 1.0                  # between the entrance edge and the flights
const FASCIA_HEIGHT := 0.8
const FASCIA_THICKNESS := 0.3
const CORBEL_STEPS := 3
const CORBEL_STEP_HEIGHT := 0.5
const CORBEL_STEP_PROJECTION := 0.7     # each higher step projects this much further from the wall
const CORBEL_WIDTH := 1.4
const GIRDER_HEIGHT := 0.4              # kept shallow: a flight rises under each bridge, so depth eats headroom
const DECK_SURFACE := 0.06              # the walking-surface layer on top of a slab (the only brown part)
const GIRDER_WIDTH := 0.4
const RAIL_HEIGHT := PlayerScale.CHEST_HEIGHT  # top rail at chest height of the reference player
const POST_SIZE := 0.07
const POST_SPACING := 1.0
const TOP_RAIL_SIZE := 0.09
const LOWER_RAIL_HEIGHT := 0.35
const LOWER_RAIL_SIZE := 0.05
const SOFFIT_THICKNESS := 0.5           # thickness of the stair slab / landing deck above the undercroft
const LANDING_COLUMN := 0.8             # side of the square columns that carry a hollowed landing
const STAIR_POST_EVERY := 2             # a post on every Nth tread

var _stone: Array[Transform3D] = []
var _decks: Array[Transform3D] = []   # walking surfaces (brown)
var _under: Array[Transform3D] = []   # slabs and structure under them (warm stone)


func rebuild() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()
	_stone.clear()
	_decks.clear()
	_under.clear()

	var half_l := hall_length * 0.5
	var half_w := hall_width * 0.5
	var inner_z := half_w - depth  # |z| of a balcony's open edge
	var bridge_xs: Array[float] = [-bridge_distance, bridge_distance]

	_build_balconies(half_l, half_w, inner_z, bridge_xs)
	for bx in bridge_xs:
		_build_bridge(bx, inner_z)
	for e in [-1, 1]:
		for s in [-1, 1]:
			_build_flight(e, s, half_l, half_w, inner_z)

	_check_stair_headroom(half_l, inner_z)
	_check_undercroft()

	_commit("MezzanineStone", _stone, _material(stone_color))
	_commit("MezzanineDecks", _decks, _material(floor_color))
	_commit("MezzanineUnder", _under, _material(underside_color))


## The undercroft should feel roomy: about twice the player's height, and the flight (so the
## walkway) at least three times the player's width.
func _check_undercroft() -> void:
	if not undercroft_enabled:
		return
	if undercroft_height < PlayerScale.HEIGHT * 2.0 or stair_width < PlayerScale.WIDTH * 3.0:
		push_warning("ConcourseMezzanine: undercroft is %.1f m high and %.1f m wide; want at least %.1f x %.1f m (2x the player's height, 3x their width)." % [undercroft_height, stair_width, PlayerScale.HEIGHT * 2.0, PlayerScale.WIDTH * 3.0])


## A flight rises toward its end wall at the same slope whatever the mezzanine height, so
## the room under a bridge depends on where the bridge crosses the flight and how high the
## bridge arches over the flight's outer edge (the lowest part of the span above it).
## Warn when a player could not stand, and jump, on the treads there.
func _check_stair_headroom(half_l: float, inner_z: float) -> void:
	var slope := (height / maxi(2, ceili(height / step_height))) / step_depth
	var land_x := half_l - depth
	var outer_z := minf(entrance_width * 0.5 + STAIR_GAP + stair_width, inner_z)
	var underside := _bridge_top(outer_z, inner_z) - bridge_thickness - GIRDER_HEIGHT
	for edge in [absf(bridge_distance) - bridge_width * 0.5, absf(bridge_distance) + bridge_width * 0.5]:
		var run_from_landing: float = land_x - edge
		if run_from_landing <= 0.0:
			continue  # beyond the landing's inner edge: no flight there
		var tread_top: float = height - run_from_landing * slope
		if tread_top > 0.0 and underside - tread_top < MIN_STAIR_HEADROOM:
			push_warning("ConcourseMezzanine: only %.1f m of headroom where a flight passes under a bridge (want %.1f). Raise bridge_arch_rise, or move the bridges toward the hall centre (bridge_distance)." % [underside - tread_top, MIN_STAIR_HEADROOM])
			return


# ------------------------------------------------------------------- balconies

func _build_balconies(half_l: float, half_w: float, inner_z: float, bridge_xs: Array[float]) -> void:
	for s in [-1, 1]:
		_add_deck(Vector3(0, height - thickness * 0.5, s * (half_w - depth * 0.5)), Vector3(hall_length, thickness, depth))
		# fascia beam hanging off the open edge
		_add(_under, Vector3(0, height - thickness - FASCIA_HEIGHT * 0.5, s * (inner_z + FASCIA_THICKNESS * 0.5)),
			Vector3(hall_length, FASCIA_HEIGHT, FASCIA_THICKNESS))
		# corbel stacks: the lowest step projects least, the one under the deck most
		for i in bay_count:
			var xc := (i - (bay_count - 1) * 0.5) * bay_width
			for k in CORBEL_STEPS:
				var proj := (k + 1) * CORBEL_STEP_PROJECTION
				var top := height - thickness - (CORBEL_STEPS - 1 - k) * CORBEL_STEP_HEIGHT
				_add(_under, Vector3(xc, top - CORBEL_STEP_HEIGHT * 0.5, s * (half_w - proj * 0.5)),
					Vector3(CORBEL_WIDTH, CORBEL_STEP_HEIGHT, proj))
		# balustrade along the open edge, except where a bridge or a landing joins
		var cuts: Array = [[-half_l, -half_l + depth], [half_l - depth, half_l]]
		for bx in bridge_xs:
			cuts.append([bx - bridge_width * 0.5, bx + bridge_width * 0.5])
		var z: float = s * (inner_z + POST_SIZE * 0.5)
		for run in _free_intervals(-half_l, half_l, cuts):
			_balustrade(Vector3(run[0], height, z), Vector3(run[1], height, z))


## The parts of [lo, hi] not covered by any of the [a, b] cuts.
func _free_intervals(lo: float, hi: float, cuts: Array) -> Array:
	var sorted := cuts.duplicate()
	sorted.sort_custom(func(p, q): return p[0] < q[0])
	var out := []
	var cursor := lo
	for c in sorted:
		if c[0] > cursor:
			out.append([cursor, minf(c[0], hi)])
		cursor = maxf(cursor, c[1])
	if cursor < hi:
		out.append([cursor, hi])
	return out


# --------------------------------------------------------------------- bridges

## Walking-surface height of a bridge at cross-hall position z: balcony level at both
## ends (|z| = inner_z), raised by `bridge_arch_rise` at the middle, on a parabola.
func _bridge_top(z: float, inner_z: float) -> float:
	var u := z / inner_z
	return height + bridge_arch_rise * (1.0 - u * u)


## An arched bridge: deck and two girders as short straight pieces following the
## curve, with a balustrade on each side. The arch lifts the middle of the span, which
## is where the stair flights pass underneath.
func _build_bridge(bx: float, inner_z: float) -> void:
	var n := BRIDGE_SEGMENTS
	var zs: Array[float] = []
	for i in n + 1:
		zs.append(-inner_z + 2.0 * inner_z * i / n)
	for i in n:
		var p0 := Vector3(0, _bridge_top(zs[i], inner_z), zs[i])
		var p1 := Vector3(0, _bridge_top(zs[i + 1], inner_z), zs[i + 1])
		var dir := p1 - p0
		var length := dir.length()
		var z_axis := dir / length
		var y_axis := Vector3(0, z_axis.z, -z_axis.y)  # perpendicular to the piece, pointing up
		var rot := Basis(Vector3.RIGHT, y_axis, z_axis)
		var mid := (p0 + p1) * 0.5
		var seg_len := length + SEGMENT_OVERLAP  # a little extra so bends leave no wedge-shaped gap
		_add_deck(Vector3(bx, mid.y, mid.z) - y_axis * (bridge_thickness * 0.5), Vector3(bridge_width, bridge_thickness, seg_len), rot)
		for sx in [-1, 1]:
			var gx: float = bx + sx * (bridge_width * 0.5 - GIRDER_WIDTH * 0.5)
			_add(_under, Vector3(gx, mid.y, mid.z) - y_axis * (bridge_thickness + GIRDER_HEIGHT * 0.5), Vector3(GIRDER_WIDTH, GIRDER_HEIGHT, seg_len), rot)
	for sx in [-1, 1]:
		var x: float = bx + sx * (bridge_width * 0.5 - POST_SIZE * 0.5)
		_arched_balustrade(x, zs, inner_z)


## Posts at each node of the arch, with top and lower rails between them.
func _arched_balustrade(x: float, zs: Array[float], inner_z: float) -> void:
	var prev := Vector3.ZERO
	for i in zs.size():
		var base := Vector3(x, _bridge_top(zs[i], inner_z), zs[i])
		_add(_stone, base + Vector3(0, RAIL_HEIGHT * 0.5, 0), Vector3(POST_SIZE, RAIL_HEIGHT, POST_SIZE))
		if i > 0:
			_rail(prev + Vector3(0, RAIL_HEIGHT, 0), base + Vector3(0, RAIL_HEIGHT, 0), TOP_RAIL_SIZE)
			_rail(prev + Vector3(0, LOWER_RAIL_HEIGHT, 0), base + Vector3(0, LOWER_RAIL_HEIGHT, 0), LOWER_RAIL_SIZE)
		prev = base


# ---------------------------------------------------------------------- stairs

## One flight at end `e` (+1 = +X end), side `s` (+1 = +Z side). It rises toward the
## end wall; the landing at the top joins the balcony strip on the same side.
func _build_flight(e: int, s: int, half_l: float, half_w: float, inner_z: float) -> void:
	var za := entrance_width * 0.5 + STAIR_GAP
	var zb := za + stair_width
	if zb > inner_z:
		push_warning("ConcourseMezzanine: stair_width does not fit between the entrance and the balcony; reduce it.")
		zb = inner_z
	var width := zb - za
	var zc := s * (za + zb) * 0.5
	var x_land := e * (half_l - depth)  # inner edge of the landing

	# landing: deck on a solid base, from the flight over to the balcony strip
	var land_z0 := za
	var land_z1 := inner_z
	var land_cz := s * (land_z0 + land_z1) * 0.5
	var land_cx := e * (half_l - depth * 0.5)
	_add_deck(Vector3(land_cx, height - thickness * 0.5, land_cz), Vector3(depth, thickness, land_z1 - land_z0))
	if undercroft_enabled:
		# open underneath: two columns at the flight side carry the deck (the end wall carries the other edge)
		var col_x := x_land + e * (LANDING_COLUMN * 0.5 + 0.1)
		for col_z in [land_z0 + LANDING_COLUMN * 0.5 + 0.1, land_z1 - LANDING_COLUMN * 0.5 - 0.1]:
			_add(_stone, Vector3(col_x, (height - thickness) * 0.5, s * col_z), Vector3(LANDING_COLUMN, height - thickness, LANDING_COLUMN))
	else:
		_add(_stone, Vector3(land_cx, (height - thickness) * 0.5, land_cz), Vector3(depth, height - thickness, land_z1 - land_z0))

	# treads, numbered from the landing; the first riser up to the landing is the one at x_land
	var n := maxi(2, ceili(height / step_height))
	var riser := height / n
	var tread_cx: Array[float] = []
	var tread_top: Array[float] = []
	var open_far := undercroft_open_run(riser)  # the flight is hollowed out up to this far from the landing
	for j in n - 1:
		var top := height - (j + 1) * riser
		var cx := x_land - e * (j + 0.5) * step_depth
		tread_cx.append(cx)
		tread_top.append(top)
		if undercroft_enabled and (j + 0.5) * step_depth < open_far:
			# hollowed: each tread is just a slab (a riser's height plus SOFFIT_THICKNESS), so the underside steps up with the flight
			var slab := riser + SOFFIT_THICKNESS
			_add(_stone, Vector3(cx, top - slab * 0.5, zc), Vector3(step_depth, slab, width))
		else:
			_add(_stone, Vector3(cx, top * 0.5, zc), Vector3(step_depth, top, width))

	# side balustrades following the slope, plus a post on every Nth tread
	var last := n - 2
	for z_edge in [s * (za + POST_SIZE * 0.5), s * (zb - POST_SIZE * 0.5)]:
		var a := Vector3(tread_cx[last], tread_top[last] + RAIL_HEIGHT, z_edge)
		var b := Vector3(x_land, height + RAIL_HEIGHT, z_edge)
		_rail(a, b, TOP_RAIL_SIZE)
		_rail(a - Vector3(0, RAIL_HEIGHT - LOWER_RAIL_HEIGHT, 0), b - Vector3(0, RAIL_HEIGHT - LOWER_RAIL_HEIGHT, 0), LOWER_RAIL_SIZE)
		for j in range(0, n - 1, STAIR_POST_EVERY):
			_add(_stone, Vector3(tread_cx[j], tread_top[j] + RAIL_HEIGHT * 0.5, z_edge), Vector3(POST_SIZE, RAIL_HEIGHT, POST_SIZE))

	# landing edges that are open: beside the entrance, and between the flight and the balcony
	var edge_z := s * (za + POST_SIZE * 0.5)
	_balustrade(Vector3(x_land, height, edge_z), Vector3(e * half_l, height, edge_z))
	if zb < inner_z - POST_SIZE:
		var edge_x := x_land - e * POST_SIZE * 0.5
		_balustrade(Vector3(edge_x, height, s * zb), Vector3(edge_x, height, s * inner_z))

	if undercroft_enabled:
		_place_undercroft_prop(e, s, half_l, x_land, zc)


## Dress one undercroft with a bench, planter or lamp (or nothing), so that no two neighbouring
## undercrofts look alike. Index: (+X,+Z) 0, (+X,-Z) 1, (-X,-Z) 2, (-X,+Z) 3.
func _place_undercroft_prop(e: int, s: int, half_l: float, x_land: float, zc: float) -> void:
	var idx := (0 if s > 0 else 1) if e > 0 else (2 if s < 0 else 3)
	if idx >= undercroft_props.size() or undercroft_props[idx] == "":
		return
	var prop := ConcourseProp.new()
	prop.kind = undercroft_props[idx]
	prop.name = "Undercroft%s%d" % [prop.kind.capitalize(), idx]
	match prop.kind:
		"bench":  # against the end wall, facing the hall
			prop.position = Vector3(e * (half_l - 0.6), 0, zc)
			prop.rotation.y = -e * PI * 0.5
		"planter":  # between the landing columns, under the deck
			prop.position = Vector3(x_land + e * 1.8, 0, zc)
		"lamp":  # under the stair slab, where it is already tall
			prop.position = Vector3(x_land - e * 1.0, 0, zc)
	add_child(prop)


## How far from the landing's inner edge (along the flight) the flight is hollowed out: up to where
## the stair slab's underside is still `undercroft_height` above the floor. Beyond that the flight is
## solid, so there is no low crawl space. Under the landing itself the space is open.
func undercroft_open_run(riser: float) -> float:
	var slope := riser / step_depth
	return maxf(0.0, (height - undercroft_height - SOFFIT_THICKNESS) / slope)


# ------------------------------------------------------------------ primitives

## Balustrade between two points at deck level: posts, a top rail and a lower rail.
func _balustrade(a: Vector3, b: Vector3) -> void:
	var length := a.distance_to(b)
	if length < POST_SIZE:
		return
	var count := maxi(1, roundi(length / POST_SPACING))
	for i in count + 1:
		var p := a.lerp(b, float(i) / count)
		_add(_stone, p + Vector3(0, RAIL_HEIGHT * 0.5, 0), Vector3(POST_SIZE, RAIL_HEIGHT, POST_SIZE))
	_rail(a + Vector3(0, RAIL_HEIGHT, 0), b + Vector3(0, RAIL_HEIGHT, 0), TOP_RAIL_SIZE)
	_rail(a + Vector3(0, LOWER_RAIL_HEIGHT, 0), b + Vector3(0, LOWER_RAIL_HEIGHT, 0), LOWER_RAIL_SIZE)


## A square-section bar from a to b (rotated from the box's X axis).
func _rail(a: Vector3, b: Vector3, section: float) -> void:
	if a.x > b.x or (is_equal_approx(a.x, b.x) and a.z > b.z):
		var tmp := a
		a = b
		b = tmp
	var dir := (b - a)
	var length := dir.length()
	var rot := Basis(Quaternion(Vector3.RIGHT, dir / length))
	_add(_stone, (a + b) * 0.5, Vector3(length + section * 0.5, section, section), rot)


## A deck slab: warm stone below, a thin walking surface on top. `center` is the middle of the slab's
## thickness (size.y); `rot` tilts it (arched bridge pieces).
func _add_deck(center: Vector3, size: Vector3, rot := Basis.IDENTITY) -> void:
	var up := rot * Vector3.UP
	var slab := maxf(size.y - DECK_SURFACE, 0.01)
	_add(_under, center - up * (DECK_SURFACE * 0.5), Vector3(size.x, slab, size.z), rot)
	_add(_decks, center + up * (size.y * 0.5 - DECK_SURFACE * 0.5), Vector3(size.x, DECK_SURFACE, size.z), rot)


func _add(list: Array[Transform3D], center: Vector3, size: Vector3, rot := Basis.IDENTITY) -> void:
	list.append(Transform3D(rot * Basis.from_scale(size), center))


func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = 0.9
	return m


func _commit(node_name: String, list: Array[Transform3D], mat: Material) -> void:
	if list.is_empty():
		return
	var mesh := BoxMesh.new()
	mesh.size = Vector3.ONE
	mesh.material = mat
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = list.size()
	for i in list.size():
		mm.set_instance_transform(i, list[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = node_name
	mmi.multimesh = mm
	add_child(mmi)
