class_name PlatformLevel
extends RefCounted
## The hub's platform level, 8 m under the hall floor (station frame, see StationLayout):
## one island platform between two tracks, four colour-coded berths (West, East, Tower, Park), and
## four switchback stairwells from the hall floor, one per berth. Greybox, with collision.
##
##            z -14 ┌──────── north track (z -11.45): Park (west) | Tower (east) ────────┐
##                  │                          island platform                        │
##            z +14 └──────── south track (z +11.45): West (west) | East (east) ───────┘
##                  x -34                                                        x +34

const L := preload("res://station/station_layout.gd")

const PL := -8.0                 # platform floor, frame y
const TROUGH := PL - 0.8         # track bed
const HEAD := 4.1                # clear height above the platform
const CEIL_UNDER := PL + HEAD    # -3.9
const SLAB := 0.6
const X_HALF := 34.0             # chamber end walls (inner face)
const Z_HALF := 14.0             # chamber side walls (inner face)
const ISLAND_HALF := 9.88
const TRACK_Z := 11.45
const PORTAL_W := 4.8
const WELL_X_IN := 9.0           # |x| where a well's flight 1 starts (at the hall floor)
const WELL_Z_IN := 1.5           # |z| of the well's axis-side wall (leaves a 3 m walkway on the hall axis)
const LANE_W := 2.4
const DIVIDER := 0.4
const FLIGHT_STEPS := 20
const RISER := 0.2
const RUN := 0.3
const LANDING := 2.4

const WALL := Color(0.38, 0.39, 0.42)
const FLOOR := Color(0.62, 0.59, 0.55)
const DARK := Color(0.12, 0.12, 0.14)
const CEIL := Color(0.30, 0.31, 0.34)
const STONE := Color(0.55, 0.55, 0.57)

## quadrant (sx, sz) of each line: sx = side of the hall centre along x, sz = which track
const QUADRANTS := {"west": Vector2i(-1, 1), "east": Vector2i(1, 1), "tower": Vector2i(1, -1), "park": Vector2i(-1, -1)}
const MOODS := {
	"west": {"light": Color(1.0, 0.72, 0.40), "wall": Color(0.55, 0.38, 0.24), "name": "hill"},
	"east": {"light": Color(0.55, 0.78, 1.0), "wall": Color(0.80, 0.86, 0.90), "name": "harbour"},
	"tower": {"light": Color(0.85, 0.95, 1.0), "wall": Color(0.22, 0.26, 0.32), "name": "midtown"},
	"park": {"light": Color(0.70, 1.0, 0.72), "wall": Color(0.28, 0.40, 0.26), "name": "park"},
}

var routes: RouteData
var river: Array = []
var holes: Array[Rect2] = []     # frame-space (x, z) rectangles of the stairwells (for the hall floor)


static func well_rect(sx: int, sz: int) -> Rect2:
	var x0: float = WELL_X_IN if sx > 0 else -(WELL_X_IN + FLIGHT_STEPS * RUN + LANDING)
	var w: float = FLIGHT_STEPS * RUN + LANDING
	var depth: float = LANE_W * 2.0 + DIVIDER
	var z0: float = WELL_Z_IN if sz > 0 else -(WELL_Z_IN + depth)
	return Rect2(x0, z0, w, depth)


func _init(route_data: RouteData) -> void:
	routes = route_data
	river = RiverPath.load_path()
	for id in QUADRANTS:
		var q: Vector2i = QUADRANTS[id]
		holes.append(well_rect(q.x, q.y))


func build(root: Node3D) -> void:
	var node := Node3D.new()
	node.name = "PlatformLevel"
	root.add_child(node)
	var col := Greybox.body(node, "PlatformCollision")
	_chamber(node, col)
	for line in routes.lines:
		var q: Vector2i = QUADRANTS[line["id"]]
		var zone := Node3D.new()
		zone.name = "Berth_%s" % line["id"]
		node.add_child(zone)
		_berth(zone, col, line, q)
		_stairwell(node, col, line, q)


# ----------------------------------------------------------------- chamber

func _chamber(node: Node3D, col: StaticBody3D) -> void:
	var wall := Greybox.mat(WALL)
	var floor_m := Greybox.mat(FLOOR)
	var dark := Greybox.mat(DARK)
	var ceil_m := Greybox.mat(CEIL)
	var xh := X_HALF
	var zh := Z_HALF
	# track bed and its under-slab
	Greybox.box_ab(node, Vector3(-xh - 1.0, TROUGH - SLAB, -zh - 0.6), Vector3(xh + 1.0, TROUGH, zh + 0.6), dark, col)
	# island platform, top at PL, whole length
	Greybox.box_ab(node, Vector3(-xh, TROUGH, -ISLAND_HALF), Vector3(xh, PL, ISLAND_HALF), floor_m, col)
	# platform edge strip (tactile yellow) along both long edges
	var tactile := Greybox.mat(Color(0.85, 0.72, 0.18), 0.8)
	for s in [-1, 1]:
		Greybox.box_ab(node, Vector3(-xh, PL, s * (ISLAND_HALF - 0.45)), Vector3(xh, PL + 0.02, s * ISLAND_HALF), tactile)
	# side walls (z), full height from the track bed to the roof slab
	for s in [-1, 1]:
		Greybox.box_ab(node, Vector3(-xh - 0.8, TROUGH, s * zh), Vector3(xh + 0.8, CEIL_UNDER + SLAB, s * (zh + 0.6)), wall, col)
	# end walls (x) with a portal over each track
	for s in [-1, 1]:
		var x_in: float = s * xh
		var x_out: float = s * (xh + 0.8)
		# centre piece between the two portals
		Greybox.box_ab(node, Vector3(x_in, TROUGH, -(TRACK_Z - PORTAL_W * 0.5)), Vector3(x_out, CEIL_UNDER + SLAB, TRACK_Z - PORTAL_W * 0.5), wall, col)
		# slivers between portal and side wall
		for t in [-1, 1]:
			Greybox.box_ab(node, Vector3(x_in, TROUGH, t * (TRACK_Z + PORTAL_W * 0.5)), Vector3(x_out, CEIL_UNDER + SLAB, t * zh), wall, col)
	# roof slab: the stairwells are holes in it
	var well_rects: Array[Rect2] = holes
	_slab_with_holes(node, col, Rect2(-xh - 0.8, -zh - 0.6, (xh + 0.8) * 2.0, (zh + 0.6) * 2.0), CEIL_UNDER, CEIL_UNDER + SLAB, well_rects, ceil_m)
	# lights strips in the roof (emissive), and a few plain lights
	var strip := Greybox.mat(Color(1.0, 0.97, 0.88), 0.5, 1.6)
	for z in [-5.0, 5.0]:
		# The ceiling is cut at each shaft; its light strips must have the same cuts.
		for interval in _light_intervals(z, 0.4):
			Greybox.box(node, Vector3(interval.y - interval.x, 0.05, 0.4), Vector3((interval.x + interval.y) * 0.5, CEIL_UNDER - 0.03, z), strip)
	for s in [-1, 1]:
		Greybox.box(node, Vector3(60.0, 0.05, 0.3), Vector3(0, CEIL_UNDER - 0.03, s * 11.45), strip)

func _light_intervals(z: float, width: float) -> Array[Vector2]:
	var cuts: Array[Rect2] = []
	for hole in holes:
		if z + width * 0.5 >= hole.position.y and z - width * 0.5 <= hole.end.y:
			cuts.append(hole.grow(0.05))
	cuts.sort_custom(func(a, b): return a.position.x < b.position.x)
	var spans: Array[Vector2] = []
	var cursor := -30.0
	for cut in cuts:
		if cut.position.x > cursor:
			spans.append(Vector2(cursor, cut.position.x))
		cursor = maxf(cursor, cut.end.x)
	if cursor < 30.0:
		spans.append(Vector2(cursor, 30.0))
	return spans


## A slab (top y1, bottom y0) over `area`, cut into cells at every hole edge; cells inside a hole are left out.
func _slab_with_holes(node: Node3D, col: StaticBody3D, area: Rect2, y0: float, y1: float, hole_rects: Array[Rect2], m: Material) -> void:
	var xs: Array[float] = [area.position.x, area.end.x]
	var zs: Array[float] = [area.position.y, area.end.y]
	for h in hole_rects:
		xs.append_array([h.position.x, h.end.x])
		zs.append_array([h.position.y, h.end.y])
	xs.sort()
	zs.sort()
	for i in xs.size() - 1:
		for j in zs.size() - 1:
			var cell := Rect2(xs[i], zs[j], xs[i + 1] - xs[i], zs[j + 1] - zs[j])
			if cell.size.x < 0.01 or cell.size.y < 0.01 or not area.encloses(cell):
				continue
			var inside := false
			for h in hole_rects:
				if h.has_point(cell.get_center()):
					inside = true
			if not inside:
				Greybox.box_ab(node, Vector3(cell.position.x, y0, cell.position.y), Vector3(cell.end.x, y1, cell.end.y), m, col)


# ----------------------------------------------------------------- one berth (colour zone)

func _berth(zone: Node3D, col: StaticBody3D, line: Dictionary, q: Vector2i) -> void:
	var id: String = line["id"]
	var color: Color = line["color"]
	var mood: Dictionary = MOODS[id]
	var centre_x: float = (line["stops"][0]["pos"].x - L.HUB.x)
	var sx := q.x
	var sz := q.y
	var x_lo := centre_x - 13.0
	var x_hi := centre_x + 13.0
	var colour_m := Greybox.mat(color, 0.6, 0.5)
	var wall_m := Greybox.mat(mood["wall"])
	# floor-edge stripe in the line colour (inside the tactile strip), full berth length
	Greybox.box_ab(zone, Vector3(x_lo, PL, sz * (ISLAND_HALF - 0.9)), Vector3(x_hi, PL + 0.025, sz * (ISLAND_HALF - 0.5)), colour_m)
	# wall band behind the track, along the berth, in the mood colour with a line-colour stripe
	var wz := sz * (Z_HALF - 0.02)
	Greybox.box_ab(zone, Vector3(x_lo, PL + 0.6, wz), Vector3(x_hi, PL + 3.4, wz - sz * 0.06), wall_m)
	Greybox.box_ab(zone, Vector3(x_lo, PL + 1.7, wz - sz * 0.02), Vector3(x_hi, PL + 2.1, wz - sz * 0.1), colour_m)
	# coloured pillars between the doors
	for px in [centre_x + sx * 3.0, centre_x + sx * 12.0]:
		var pz: float = sz * 8.0
		Greybox.box(zone, Vector3(0.8, HEAD, 0.8), Vector3(px, PL + HEAD * 0.5, pz), Greybox.mat(color.darkened(0.15), 0.7), col)
		Greybox.box(zone, Vector3(0.9, 0.5, 0.9), Vector3(px, PL + 0.25, pz), Greybox.mat(STONE))
	# berth sign hanging from the roof: line colour board, line name + destination
	var dest_name: String = routes.stop(line["stops"][1]["stop"])["name"]
	var order := {"west": 1, "east": 2, "tower": 3, "park": 4}[id] as int
	var sign_pos := Vector3(centre_x, PL + 3.15, sz * 6.8)
	Greybox.box(zone, Vector3(5.0, 1.0, 0.12), sign_pos, Greybox.mat(Color(0.06, 0.07, 0.09)))
	Greybox.box(zone, Vector3(5.0, 0.3, 0.14), sign_pos + Vector3(0, 0.35, 0), colour_m)
	for k in [-1, 1]:
		Greybox.box(zone, Vector3(0.05, 0.9, 0.05), sign_pos + Vector3(k * 2.4, 0.95, 0), Greybox.mat(DARK))
	for face in [1, -1]:
		var yaw := 0.0 if face > 0 else PI
		Greybox.label(zone, "%s  -  PLATFORM %d" % [String(line["name"]).to_upper(), order], sign_pos + Vector3(0, 0.34, face * 0.075), yaw, 0.26, Color(0.05, 0.05, 0.05))
		Greybox.label(zone, "to %s" % dest_name, sign_pos + Vector3(0, -0.12, face * 0.075), yaw, 0.32, Color(1.0, 1.0, 1.0))
	# the berth's own light: mood colour, from above the track side
	Greybox.omni(zone, Vector3(centre_x - 6.0, CEIL_UNDER - 0.5, sz * 6.0), 2.4, 18.0, mood["light"])
	Greybox.omni(zone, Vector3(centre_x + 6.0, CEIL_UNDER - 0.5, sz * 6.0), 2.4, 18.0, mood["light"])
	_mood_decor(zone, col, id, centre_x, sz, color)
	# route map on a free-standing double-sided stand in the middle of the island ("you are here": the hub)
	var stand := Node3D.new()
	stand.name = "MapStand"
	stand.position = Vector3(centre_x, PL, 0.0)
	zone.add_child(stand)
	for post_x in [-1.9, 1.9]:
		Greybox.box(stand, Vector3(0.12, 2.9, 0.16), Vector3(post_x, 1.45, 0), Greybox.mat(DARK), col)
	Greybox.box(stand, Vector3(4.2, 0.12, 0.3), Vector3(0, 2.95, 0), Greybox.mat(DARK))
	for face in [1, -1]:
		RouteMap.build(stand, "RouteMap_%s" % ("S" if face > 0 else "N"), routes, Vector3(0, 1.95, face * 0.1), 0.0 if face > 0 else PI, Vector2(3.8, 1.7), "central", id, river)


func _mood_decor(zone: Node3D, col: StaticBody3D, id: String, cx: float, sz: int, color: Color) -> void:
	var wz: float = sz * (Z_HALF - 0.1)
	match id:
		"west":  # hillside: arched alcoves with lanterns
			for k in [-9.0, 9.0]:
				var ax: float = cx + k
				Greybox.box(zone, Vector3(2.2, 2.0, 0.1), Vector3(ax, PL + 2.0, wz - sz * 0.05), Greybox.mat(Color(0.20, 0.13, 0.09)))
				Greybox.cyl(zone, 1.1, 0.1, Vector3(ax, PL + 3.0, wz - sz * 0.05), Greybox.mat(Color(0.20, 0.13, 0.09)), null, Vector3(PI * 0.5, 0, 0))
				Greybox.sphere(zone, 0.22, Vector3(ax, PL + 2.4, wz - sz * 0.4), Greybox.mat(Color(1.0, 0.75, 0.35), 0.5, 2.5))
		"east":  # harbour: portholes
			for k in [-10.0, -6.0, 6.0, 10.0]:
				var ax: float = cx + k
				Greybox.cyl(zone, 0.75, 0.12, Vector3(ax, PL + 2.6, wz - sz * 0.08), Greybox.mat(Color(0.95, 0.95, 0.95)), null, Vector3(PI * 0.5, 0, 0))
				Greybox.cyl(zone, 0.58, 0.14, Vector3(ax, PL + 2.6, wz - sz * 0.1), Greybox.mat(Color(0.15, 0.40, 0.65), 0.3, 0.8), null, Vector3(PI * 0.5, 0, 0))
		"tower":  # midtown: tall light strips
			for k in [-11.0, -8.0, 8.0, 11.0]:
				Greybox.box(zone, Vector3(0.18, 3.0, 0.1), Vector3(cx + k, PL + 2.1, wz - sz * 0.08), Greybox.mat(Color(0.8, 0.95, 1.0), 0.4, 2.2))
		"park":  # park: planters with small trees along the island
			var leaf := Greybox.mat(Color(0.25, 0.55, 0.28))
			for k in [-9.0, 9.0]:
				var px: float = cx + k
				Greybox.box(zone, Vector3(1.6, 0.5, 1.6), Vector3(px, PL + 0.25, sz * 8.4), Greybox.mat(Color(0.45, 0.40, 0.34)), col)
				Greybox.cyl(zone, 0.12, 1.4, Vector3(px, PL + 1.2, sz * 8.4), Greybox.mat(Color(0.40, 0.28, 0.20)))
				Greybox.sphere(zone, 0.9, Vector3(px, PL + 2.3, sz * 8.4), leaf)


# ----------------------------------------------------------------- stairwell

func _stairwell(node: Node3D, col: StaticBody3D, line: Dictionary, q: Vector2i) -> void:
	var sx := q.x
	var sz := q.y
	var color: Color = line["color"]
	var rect := well_rect(sx, sz)
	var holder := Node3D.new()
	holder.name = "Well_%s" % line["id"]
	node.add_child(holder)
	var stone := Greybox.mat(Color(0.62, 0.58, 0.52))
	var wall := Greybox.mat(Color(0.48, 0.48, 0.50))
	var rail := Greybox.mat(Color(0.30, 0.31, 0.36))
	var tread := Greybox.mat(Color(0.40, 0.28, 0.21))
	var dirx := float(sx)
	var lane1_z: float = sz * (WELL_Z_IN + LANE_W * 0.5)
	var lane2_z: float = sz * (WELL_Z_IN + LANE_W + DIVIDER + LANE_W * 0.5)
	var x_in: float = sx * WELL_X_IN
	var x_land: float = sx * (WELL_X_IN + FLIGHT_STEPS * RUN)
	var x_out: float = sx * (WELL_X_IN + FLIGHT_STEPS * RUN + LANDING)
	# flight 1: hall floor (y 0) outward down to the landing at y -4
	StairFlight.build(holder, Vector3(x_in, 0.0, lane1_z), Vector3(dirx, 0, 0), LANE_W, FLIGHT_STEPS, RISER, RUN, PL, stone, col, tread)
	# landing: a solid block, top at -4
	var land_lo := Vector3(minf(x_land, x_out), PL, rect.position.y)
	var land_hi := Vector3(maxf(x_land, x_out), PL + 4.0, rect.end.y)
	Greybox.box_ab(holder, land_lo, land_hi, stone, col)
	# flight 2: back inward and down to the platform
	StairFlight.build(holder, Vector3(x_land, PL + 4.0, lane2_z), Vector3(-dirx, 0, 0), LANE_W, FLIGHT_STEPS, RISER, RUN, PL, stone, col, tread)
	# shaft walls (hall floor to platform): axis side, outer side, outer end, divider; inner end above the roof slab
	var x_a := minf(rect.position.x, rect.end.x)
	var x_b := maxf(rect.position.x, rect.end.x)
	var z_a := rect.position.y
	var z_b := rect.end.y
	var t := 0.3
	var top := 0.0
	# long walls
	var z_axis: float = rect.position.y if sz > 0 else rect.end.y   # |z| = WELL_Z_IN side
	var z_far: float = rect.end.y if sz > 0 else rect.position.y     # outer side
	Greybox.box(holder, Vector3(x_b - x_a + t * 2.0, top - PL, t), Vector3((x_a + x_b) * 0.5, (top + PL) * 0.5, z_axis - sz * t * 0.5), wall, col)
	Greybox.box(holder, Vector3(x_b - x_a + t * 2.0, top - PL, t), Vector3((x_a + x_b) * 0.5, (top + PL) * 0.5, z_far + sz * t * 0.5), wall, col)
	# outer end wall
	Greybox.box(holder, Vector3(t, top - PL, z_b - z_a), Vector3(x_out + sx * t * 0.5, (top + PL) * 0.5, (z_a + z_b) * 0.5), wall, col)
	# divider between the lanes, flush with the hall floor
	var div_z: float = sz * (WELL_Z_IN + LANE_W + DIVIDER * 0.5)
	Greybox.box(holder, Vector3(absf(x_land - x_in), top - PL, DIVIDER), Vector3((x_in + x_land) * 0.5, (top + PL) * 0.5, div_z), wall, col)
	# inner end of lane 2: open below the roof slab (the exit), walled above it
	var lane2_lo: float = sz * (WELL_Z_IN + LANE_W + DIVIDER)
	var lane2_hi: float = sz * (WELL_Z_IN + LANE_W * 2.0 + DIVIDER)
	Greybox.box(holder, Vector3(t, top - (CEIL_UNDER + SLAB), absf(lane2_hi - lane2_lo)), Vector3(x_in - sx * t * 0.5, (top + CEIL_UNDER + SLAB) * 0.5, (lane2_lo + lane2_hi) * 0.5), wall, col)
	# balustrade round the hole at the hall floor: both long sides, the outer end, the divider, lane 2's inner end
	var rail_mat := rail
	Greybox.railing(holder, Vector3(x_in, 0, z_axis), Vector3(x_out, 0, z_axis), rail_mat, col)
	Greybox.railing(holder, Vector3(x_in, 0, z_far), Vector3(x_out, 0, z_far), rail_mat, col)
	Greybox.railing(holder, Vector3(x_out, 0, z_axis), Vector3(x_out, 0, z_far), rail_mat, col)
	Greybox.railing(holder, Vector3(x_in, 0, div_z), Vector3(x_land, 0, div_z), rail_mat, col)
	Greybox.railing(holder, Vector3(x_in, 0, lane2_lo), Vector3(x_in, 0, lane2_hi), rail_mat, col)
	# the wellhead sign, standing on the divider's end: line colour header, big line name, destination
	var dest_name: String = routes.stop(line["stops"][1]["stop"])["name"]
	var order := {"west": 1, "east": 2, "tower": 3, "park": 4}[line["id"]] as int
	var sign_x: float = x_in - sx * 0.2
	var sign_c := Vector3(sign_x, 3.7, sz * (WELL_Z_IN + LANE_W * 0.5 + 0.1))
	var board_w := 3.6
	Greybox.box(holder, Vector3(0.14, 1.5, board_w), sign_c, Greybox.mat(Color(0.06, 0.07, 0.09)))
	Greybox.box(holder, Vector3(0.16, 0.45, board_w), sign_c + Vector3(0, 0.52, 0), Greybox.mat(color, 0.6, 0.8))
	for post_z in [sign_c.z - board_w * 0.5 + 0.1, sign_c.z + board_w * 0.5 - 0.1]:
		Greybox.box(holder, Vector3(0.12, 3.0, 0.12), Vector3(sign_x, 1.5, post_z), Greybox.mat(DARK), col)
	for face in [-1, 1]:
		var yaw: float = PI * 0.5 * face  # face toward -x (face=-1... see below) or +x
		var fx: float = sign_x + face * 0.09
		Greybox.label(holder, String(line["name"]).to_upper(), Vector3(fx, sign_c.y + 0.52, sign_c.z), yaw, 0.34, Color(0.05, 0.05, 0.05))
		Greybox.label(holder, "Platform %d  to %s" % [order, dest_name], Vector3(fx, sign_c.y - 0.12, sign_c.z), yaw, 0.26, Color(1, 1, 1))
		Greybox.label(holder, "v  trains every few minutes", Vector3(fx, sign_c.y - 0.5, sign_c.z), yaw, 0.2, Color(0.85, 0.85, 0.6))
	# a glow so the well mouth reads from across the hall
	var glow := Greybox.mat(color, 0.5, 1.2)
	Greybox.box_ab(holder, Vector3(x_in - sx * 0.05, 0.005, sz * WELL_Z_IN), Vector3(x_in + sx * 0.7, 0.012, sz * (WELL_Z_IN + LANE_W)), glow)
	Greybox.omni(holder, Vector3((x_in + x_land) * 0.5, -2.5, (z_axis + z_far) * 0.5), 1.4, 9.0, Color(1.0, 0.95, 0.85))
