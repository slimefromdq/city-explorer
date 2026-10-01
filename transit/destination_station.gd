class_name DestinationStation
extends Node3D
## A destination stop: an underground platform on the line (a chamber round the track with one side
## platform and a closed buffer end), a covered stair up to the surface (a level corridor, then a solid
## stair flight; open trench and retaining walls near the top), and a small district-styled entrance on
## the surface (hood, plaza, sign). Everything is built in a LOCAL frame: origin = the train's centre at
## the stop on the platform floor, +x along the track, +z toward the platform and the stairs. The node's
## transform turns that frame into the world, so every box here is axis-aligned.

const CHAMBER_BEFORE := 22.0      # the arrival end wall is this far before the train centre (m); the tunnel ends here
const PLATFORM_EDGE := 1.57       # local z of the platform edge (track centre is z = 0); 0.12 m from the train floor
const PLATFORM_BACK := 7.9        # local z of the back wall
const FAR_WALL := -3.2
const HEAD := 4.1
const TROUGH := -0.8
const SLAB := 0.5
const STAIR_W := 3.6
const WALL_T := 0.35
const STAIR_HEAD := 2.8           # clear height above the stair nosings
const RISER := 0.2
const RUN := 0.3
const HOOD_LEN := 7.0
const HOOD_H := 3.7
const PLAZA_DEPTH := 12.0
const PLAZA_HALF := 8.0
const APRON_LIFT := 0.15          # the walkable surface is the road level: terrain + this

const STYLES := {
	"hill": {"wall": Color(0.52, 0.38, 0.27), "floor": Color(0.55, 0.50, 0.44), "light": Color(1.0, 0.72, 0.42), "paving": Color(0.55, 0.45, 0.36), "hood": Color(0.60, 0.48, 0.36)},
	"harbour": {"wall": Color(0.82, 0.88, 0.92), "floor": Color(0.62, 0.66, 0.70), "light": Color(0.60, 0.80, 1.0), "paving": Color(0.62, 0.68, 0.72), "hood": Color(0.90, 0.92, 0.95)},
	"tower": {"wall": Color(0.20, 0.24, 0.30), "floor": Color(0.40, 0.42, 0.46), "light": Color(0.85, 0.95, 1.0), "paving": Color(0.24, 0.26, 0.30), "hood": Color(0.30, 0.34, 0.40)},
	"park": {"wall": Color(0.30, 0.42, 0.28), "floor": Color(0.55, 0.55, 0.50), "light": Color(0.72, 1.0, 0.72), "paving": Color(0.40, 0.58, 0.32), "hood": Color(0.45, 0.33, 0.22)},
}

var stop: Dictionary
var line: Dictionary
var routes: RouteData
var terrain
var service: LineService
var hole_ground: Array[Rect2] = []   # world (x, z) rectangles cut out of the ground mesh (the open trench)
var hole_water: Array[Rect2] = []    # ... and out of the water plane (the whole stair trench)
var apron_area := Rect2()            # world rectangle the walkable apron covers round the entrance
var entrance_world := Vector3.ZERO   # the true stair-top threshold, at road level

var _x_axis := Vector3.RIGHT
var _z_axis := Vector3.BACK
var _origin := Vector3.ZERO
var _style: Dictionary
var _style_id := ""
var _col: StaticBody3D
var _x_min := -CHAMBER_BEFORE
var _x_max := 30.0
var _hub_sign := -1.0
var _D := 0.0                         # lateral distance from the track centre to the stair top
var _u0 := 0.0                        # lateral offset of the stair centre line
var _H := 0.0                         # rise from the platform to the street
var _steps := 0
var _rise := RISER
var _v_foot := 0.0
var _open_from := 0.0                 # local v where the covered stair ends and the open trench begins
var _countdown: Label3D
var _clock := 0.0


## The world rectangle an entrance needs kept clear of buildings and trees (known from data alone, so the
## city can be planned around it).
static func reserve_rect(stop_data: Dictionary) -> Rect2:
	var e: Vector3 = stop_data["entrance"]
	var d: Vector2 = stop_data["stairs_dir"]
	var lat := Vector2(-d.y, d.x)
	var half := PLAZA_HALF + 2.0
	var p0 := Vector2(e.x, e.z) + d * (-(HOOD_LEN + 2.0)) - lat * half
	var p1 := Vector2(e.x, e.z) + d * (PLAZA_DEPTH + 2.0) + lat * half
	return Rect2(Vector2(minf(p0.x, p1.x), minf(p0.y, p1.y)), (p1 - p0).abs())


func setup(p_stop: Dictionary, p_line: Dictionary, p_routes: RouteData, p_terrain) -> void:
	stop = p_stop
	line = p_line
	routes = p_routes
	terrain = p_terrain
	_style_id = String(stop.get("style", "hill"))
	_style = STYLES[_style_id]
	name = "Station_%s" % stop["id"]
	var s_stop: float = line["stops"][1]["s"]
	var smp := RouteData.sample(line["path"], s_stop)
	var t: Vector3 = smp["dir"]
	t.y = 0.0
	t = t.normalized()
	_origin = smp["pos"]
	var sd: Vector2 = stop["stairs_dir"]
	_z_axis = Vector3(sd.x, 0, sd.y)
	var right := t.cross(Vector3.UP)
	_x_axis = t if _z_axis.dot(right) > 0.0 else -t
	_hub_sign = -1.0 if _x_axis.dot(t) > 0.0 else 1.0     # which local side the hub (arrival) lies on
	var length: float = line["length"]
	var after: float = minf(30.0, length - s_stop)
	if _hub_sign < 0.0:
		_x_min = -CHAMBER_BEFORE
		_x_max = after
	else:
		_x_min = -after
		_x_max = CHAMBER_BEFORE
	transform = Transform3D(Basis(_x_axis, Vector3.UP, _z_axis), _origin)
	# the stair
	var e: Vector3 = stop["entrance"]
	var rel := Vector3(e.x, 0, e.z) - Vector3(_origin.x, 0, _origin.z)
	_D = rel.dot(_z_axis)
	_u0 = rel.dot(_x_axis)
	var ground: float = terrain.height_at(Vector2(e.x, e.z)) + APRON_LIFT
	_H = ground - _origin.y
	_steps = int(ceil(_H / RISER))
	_rise = _H / float(_steps)
	_v_foot = _D - _steps * RUN
	entrance_world = Vector3(e.x, ground, e.z)
	if _v_foot < PLATFORM_BACK + 1.5:
		push_warning("%s: stairs need %.1f m but only %.1f m are available" % [name, _steps * RUN, _D - PLATFORM_BACK - 1.5])


func build() -> void:
	_col = Greybox.body(self, "Collision")
	_chamber()
	_stairs()
	_entrance()
	_platform_dressing()
	_holes()
	_countdown_sign()


# --------------------------------------------------------------------------- chamber

func _chamber() -> void:
	var wall := Greybox.mat(_style["wall"])
	var floor_m := Greybox.mat(_style["floor"])
	var dark := Greybox.mat(Color(0.12, 0.12, 0.14))
	var ceil_m := Greybox.mat(Color(0.28, 0.29, 0.32))
	var x0 := _x_min - 0.8
	var x1 := _x_max + 0.8
	var zf := FAR_WALL
	var zb := PLATFORM_BACK
	Greybox.box_ab(self, Vector3(x0, TROUGH - SLAB, zf - 0.6), Vector3(x1, TROUGH, zb + 0.6), dark, _col)
	Greybox.box_ab(self, Vector3(_x_min, TROUGH, PLATFORM_EDGE), Vector3(_x_max, 0.0, zb), floor_m, _col)
	Greybox.box_ab(self, Vector3(_x_min, 0.0, PLATFORM_EDGE), Vector3(_x_max, 0.02, PLATFORM_EDGE + 0.45), Greybox.mat(Color(0.85, 0.72, 0.18)))
	Greybox.box_ab(self, Vector3(_x_min, 0.0, PLATFORM_EDGE + 0.45), Vector3(_x_max, 0.025, PLATFORM_EDGE + 0.85), Greybox.mat(line["color"], 0.6, 0.5))
	# far wall (behind the track)
	Greybox.box_ab(self, Vector3(x0, TROUGH, zf - 0.6), Vector3(x1, HEAD + SLAB, zf), wall, _col)
	# back wall, with the stair opening
	var ou0 := _u0 - STAIR_W * 0.5 - 0.1
	var ou1 := _u0 + STAIR_W * 0.5 + 0.1
	Greybox.box_ab(self, Vector3(x0, 0.0, zb), Vector3(ou0, HEAD + SLAB, zb + 0.6), wall, _col)
	Greybox.box_ab(self, Vector3(ou1, 0.0, zb), Vector3(x1, HEAD + SLAB, zb + 0.6), wall, _col)
	Greybox.box_ab(self, Vector3(ou0, STAIR_HEAD + 0.4, zb), Vector3(ou1, HEAD + SLAB, zb + 0.6), wall, _col)
	Greybox.box_ab(self, Vector3(x0, TROUGH, zb), Vector3(x1, 0.0, zb + 0.6), dark, _col)
	# end walls: the hub side has the tunnel portal over the track, the other end is closed
	var hub_x: float = _x_min if _hub_sign < 0.0 else _x_max
	var far_x: float = _x_max if _hub_sign < 0.0 else _x_min
	var hub_out: float = hub_x + _hub_sign * 0.8
	var far_out: float = far_x - _hub_sign * 0.8
	Greybox.box_ab(self, Vector3(hub_x, TROUGH, zf - 0.6), Vector3(hub_out, HEAD + SLAB, -2.4), wall, _col)
	Greybox.box_ab(self, Vector3(hub_x, TROUGH, 2.4), Vector3(hub_out, HEAD + SLAB, zb + 0.6), wall, _col)
	Greybox.box_ab(self, Vector3(far_x, TROUGH, zf - 0.6), Vector3(far_out, HEAD + SLAB, zb + 0.6), wall, _col)
	# roof slab
	Greybox.box_ab(self, Vector3(x0, HEAD, zf - 0.6), Vector3(x1, HEAD + SLAB, zb + 0.6), ceil_m, _col)
	# track: two rails, a few sleepers, buffer stops at the closed end
	var steel := Greybox.mat(Color(0.55, 0.55, 0.58))
	for rz in [-0.72, 0.72]:
		Greybox.box_ab(self, Vector3(_x_min, TROUGH, rz - 0.05), Vector3(_x_max, TROUGH + 0.16, rz + 0.05), steel)
	var buf_x: float = far_x - _hub_sign * 1.0
	for rz in [-0.72, 0.72]:
		Greybox.box(self, Vector3(0.6, 0.9, 0.3), Vector3(buf_x, TROUGH + 0.45, rz), Greybox.mat(Color(0.85, 0.15, 0.12)), _col)
	# roof lights: two strips, and lights in the district colour
	var strip := Greybox.mat(Color(1.0, 0.97, 0.88), 0.5, 1.6)
	for z in [0.0, 5.0]:
		Greybox.box(self, Vector3(_x_max - _x_min - 2.0, 0.05, 0.4), Vector3((_x_min + _x_max) * 0.5, HEAD - 0.03, z), strip)
	for lx in [-9.0, 0.0, 9.0]:
		Greybox.omni(self, Vector3(lx, HEAD - 0.5, 3.5), 2.2, 16.0, _style["light"])


func _platform_dressing() -> void:
	var color: Color = line["color"]
	var wall_m := Greybox.mat(color.darkened(0.2), 0.6)
	var name_text: String = String(stop["name"]).to_upper()
	# station name on the far wall, twice, in the line colour
	for x in [-8.0, 8.0]:
		var panel := Vector3(x, 2.3, FAR_WALL - 0.03)
		Greybox.box(self, Vector3(8.0, 1.5, 0.08), panel, Greybox.mat(Color(0.06, 0.07, 0.09)))
		Greybox.box(self, Vector3(8.0, 0.3, 0.1), panel + Vector3(0, 0.6, 0), Greybox.mat(color, 0.6, 0.8))
		Greybox.label(self, name_text, panel + Vector3(0, -0.1, 0.06), 0.0, 0.8, Color(1, 1, 1)).rotation.y = PI
		Greybox.label(self, String(stop["district"]), panel + Vector3(0, -0.52, 0.06), 0.0, 0.3, Color(0.85, 0.85, 0.7)).rotation.y = PI
	# pillars between the doors (x = +-3.5, +-12.5) in the line colour
	for px in [-12.5, -3.5, 3.5, 12.5]:
		if px < _x_min + 1.0 or px > _x_max - 1.0:
			continue
		Greybox.box(self, Vector3(0.7, HEAD, 0.7), Vector3(px, HEAD * 0.5, 5.6), Greybox.mat(color.darkened(0.15), 0.7), _col)
	# a stripe on the back wall in the line colour, and the route map between the pillars
	Greybox.box_ab(self, Vector3(_x_min, 1.6, PLATFORM_BACK - 0.02), Vector3(_x_max, 2.0, PLATFORM_BACK - 0.06), wall_m)
	for mx in [-9.0, 9.0]:
		if mx < _x_min + 3.0 or mx > _x_max - 3.0:
			continue
		RouteMap.build(self, "RouteMap", routes, Vector3(mx, 2.15, PLATFORM_BACK - 0.14), PI, Vector2(3.8, 1.7), String(stop["id"]), String(line["id"]), RiverPath.load_path())
	_mood_decor()


func _mood_decor() -> void:
	var wz := FAR_WALL - 0.1
	match _style_id:
		"hill":
			for k in [-16.0, 0.0, 16.0]:
				Greybox.box(self, Vector3(2.2, 2.0, 0.1), Vector3(k, 1.9, wz), Greybox.mat(Color(0.20, 0.13, 0.09)))
				Greybox.cyl(self, 1.1, 0.1, Vector3(k, 2.9, wz), Greybox.mat(Color(0.20, 0.13, 0.09)), null, Vector3(PI * 0.5, 0, 0))
				Greybox.sphere(self, 0.22, Vector3(k, 2.3, wz + 0.3), Greybox.mat(Color(1.0, 0.75, 0.35), 0.5, 2.5))
		"harbour":
			for k in [-18.0, -13.0, 13.0, 18.0]:
				Greybox.cyl(self, 0.75, 0.12, Vector3(k, 2.5, wz), Greybox.mat(Color(0.95, 0.95, 0.95)), null, Vector3(PI * 0.5, 0, 0))
				Greybox.cyl(self, 0.58, 0.14, Vector3(k, 2.5, wz + 0.02), Greybox.mat(Color(0.15, 0.40, 0.65), 0.3, 0.8), null, Vector3(PI * 0.5, 0, 0))
		"tower":
			for k in [-18.0, -14.0, 14.0, 18.0]:
				Greybox.box(self, Vector3(0.18, 3.0, 0.1), Vector3(k, 2.0, wz), Greybox.mat(Color(0.8, 0.95, 1.0), 0.4, 2.2))
		"park":
			var leaf := Greybox.mat(Color(0.25, 0.55, 0.28))
			for k in [-17.0, 17.0]:
				Greybox.box(self, Vector3(1.6, 0.5, 1.6), Vector3(k, 0.25, 5.6), Greybox.mat(Color(0.45, 0.40, 0.34)), _col)
				Greybox.cyl(self, 0.12, 1.4, Vector3(k, 1.2, 5.6), Greybox.mat(Color(0.40, 0.28, 0.20)))
				Greybox.sphere(self, 0.9, Vector3(k, 2.3, 5.6), leaf)


# --------------------------------------------------------------------------- stairs

func _stairs() -> void:
	var stone := Greybox.mat(Color(0.62, 0.58, 0.52))
	var tread := Greybox.mat(Color(0.40, 0.28, 0.21))
	var wall := Greybox.mat(_style["wall"].darkened(0.1))
	var ceil_m := Greybox.mat(Color(0.30, 0.31, 0.34))
	var half := STAIR_W * 0.5
	var va := PLATFORM_BACK + 0.6
	# level corridor from the platform's back wall to the foot of the flight
	if _v_foot > va:
		Greybox.box_ab(self, Vector3(_u0 - half - WALL_T, -0.8, va), Vector3(_u0 + half + WALL_T, 0.0, _v_foot), wall, _col)
		for s in [-1, 1]:
			Greybox.box_ab(self, Vector3(_u0 + s * half, 0.0, va), Vector3(_u0 + s * (half + WALL_T), STAIR_HEAD + 0.4, _v_foot), wall, _col)
		Greybox.box_ab(self, Vector3(_u0 - half - WALL_T, STAIR_HEAD, va), Vector3(_u0 + half + WALL_T, STAIR_HEAD + 0.4, _v_foot), ceil_m, _col)
		var lamp := Greybox.mat(Color(1.0, 0.95, 0.8), 0.5, 1.6)
		var lv := va + 1.5
		while lv < _v_foot:
			Greybox.box(self, Vector3(1.2, 0.05, 0.6), Vector3(_u0, STAIR_HEAD - 0.03, lv), lamp)
			lv += 4.0
		Greybox.omni(self, Vector3(_u0, STAIR_HEAD - 0.4, (va + _v_foot) * 0.5), 1.4, 8.0, Color(1.0, 0.95, 0.85))
	# the flight (solid), with its ramp collider
	StairFlight.build(self, Vector3(_u0, 0.0, _v_foot), Vector3(0, 0, 1), STAIR_W, _steps, -_rise, RUN, TROUGH, stone, _col, tread)
	# walls and roof along the flight, 1 m at a time; open trench where a roof would stick out of the ground
	var seg := 1.0
	var n := int(ceil((_D - _v_foot) / seg))
	_open_from = _D
	var last_covered := true
	for k in range(n):
		var v0 := _v_foot + k * seg
		var v1 := minf(v0 + seg, _D)
		var y0 := (v0 - _v_foot) / RUN * _rise
		var y1 := (v1 - _v_foot) / RUN * _rise
		var g1 := _ground_local(v1)
		var covered := last_covered and (y1 + STAIR_HEAD + 0.4 + 0.5 <= g1)
		if not covered and last_covered:
			_open_from = v0
		last_covered = covered
		var lat := Vector3.RIGHT
		if covered:
			Greybox.prism(self, Vector3(_u0, y0 + STAIR_HEAD, v0), Vector3(_u0, y1 + STAIR_HEAD, v1), 0.4, STAIR_W + WALL_T * 2.0, lat, ceil_m, _col)
		for s in [-1, 1]:
			var ux: float = _u0 + s * (half + WALL_T * 0.5)
			if covered:
				Greybox.prism(self, Vector3(ux, y0 - 0.6, v0), Vector3(ux, y1 - 0.6, v1), STAIR_HEAD + 0.4 + 0.6, WALL_T, lat, wall, _col)
			else:
				# open trench: a retaining wall with a level top at the street
				var top: float = (_ground_local(v0) + _ground_local(v1)) * 0.5
				Greybox.box_ab(self, Vector3(ux - WALL_T * 0.5, minf(y0, y1) - 0.6, v0), Vector3(ux + WALL_T * 0.5, top, v1), wall, _col)
	# lights down the flight
	for k in range(int((_D - _v_foot) / 5.0)):
		var v := _v_foot + 2.5 + k * 5.0
		var y := (v - _v_foot) / RUN * _rise
		if y + STAIR_HEAD + 0.5 < _ground_local(v):
			Greybox.omni(self, Vector3(_u0, y + STAIR_HEAD - 0.5, v), 1.3, 7.0, Color(1.0, 0.95, 0.85))


## Local height of the road surface above the platform at local v along the stair line.
func _ground_local(v: float) -> float:
	var w := _origin + _x_axis * _u0 + _z_axis * v
	return terrain.height_at(Vector2(w.x, w.z)) + APRON_LIFT - _origin.y


# --------------------------------------------------------------------------- the surface entrance

func _entrance() -> void:
	var paving := Greybox.mat(_style["paving"])
	var hood_m := Greybox.mat(_style["hood"])
	var stone := Greybox.mat(Color(0.55, 0.55, 0.57))
	var yg := _H
	var half := STAIR_W * 0.5 + WALL_T
	var v_back := _D - HOOD_LEN
	# pad: plaza in front of the stairs, and the strips beside the trench under the hood
	Greybox.box_ab(self, Vector3(_u0 - PLAZA_HALF, yg - 2.5, _D), Vector3(_u0 + PLAZA_HALF, yg, _D + PLAZA_DEPTH), paving, _col)
	for s in [-1, 1]:
		Greybox.box_ab(self, Vector3(_u0 + s * half, yg - 2.5, v_back - 0.5), Vector3(_u0 + s * PLAZA_HALF, yg, _D), paving, _col)
	# hood: walls on the trench walls, roof, back wall
	for s in [-1, 1]:
		Greybox.box_ab(self, Vector3(_u0 + s * (half - WALL_T), yg, v_back), Vector3(_u0 + s * half, yg + HOOD_H, _D + 0.2), hood_m, _col)
	Greybox.box_ab(self, Vector3(_u0 - half, yg, v_back - 0.3), Vector3(_u0 + half, yg + HOOD_H, v_back + 0.1), hood_m, _col)
	Greybox.box_ab(self, Vector3(_u0 - half - 0.5, yg + HOOD_H, v_back - 0.3), Vector3(_u0 + half + 0.5, yg + HOOD_H + 0.4, _D + 0.9), hood_m, _col)
	Greybox.omni(self, Vector3(_u0, yg + HOOD_H - 0.5, _D - 2.5), 1.6, 8.0, Color(1.0, 0.92, 0.75))
	# the name above the opening (faces the plaza)
	var sign_pos := Vector3(_u0, yg + HOOD_H + 1.0, _D + 0.3)
	Greybox.box(self, Vector3(5.6, 1.0, 0.12), sign_pos, Greybox.mat(Color(0.06, 0.07, 0.09)))
	Greybox.box(self, Vector3(5.6, 0.2, 0.14), sign_pos + Vector3(0, 0.4, 0), Greybox.mat(line["color"], 0.6, 0.8))
	Greybox.label(self, String(stop["name"]).to_upper(), sign_pos + Vector3(0, -0.1, 0.07), 0.0, 0.5, Color(1, 1, 1))
	Greybox.box(self, Vector3(0.12, 1.5, 0.12), Vector3(_u0 - 2.6, yg + HOOD_H + 0.75, _D + 0.3), stone)
	Greybox.box(self, Vector3(0.12, 1.5, 0.12), Vector3(_u0 + 2.6, yg + HOOD_H + 0.75, _D + 0.3), stone)
	# a line badge on the plaza in front of the stairs
	Greybox.box_ab(self, Vector3(_u0 - 1.6, yg, _D + 1.0), Vector3(_u0 + 1.6, yg + 0.02, _D + 3.0), Greybox.mat(line["color"], 0.6, 0.4))
	match _style_id:
		"hill": _entrance_hill(yg)
		"harbour": _entrance_harbour(yg)
		"tower": _entrance_tower(yg)
		"park": _entrance_park(yg)


func _entrance_hill(yg: float) -> void:
	var stone := Greybox.mat(Color(0.60, 0.48, 0.36))
	var roof := Greybox.mat(Color(0.55, 0.22, 0.16))
	# a small campanile beside the hood
	var tp := Vector3(_u0 + 5.2, 0, _D - 3.0)
	Greybox.box(self, Vector3(2.6, 9.0, 2.6), tp + Vector3(0, yg + 4.5, 0), stone, _col)
	Greybox.box(self, Vector3(1.4, 1.6, 2.7), tp + Vector3(0, yg + 7.6, 0), Greybox.mat(Color(0.12, 0.08, 0.06)))
	Greybox.box(self, Vector3(2.7, 1.6, 1.4), tp + Vector3(0, yg + 7.6, 0), Greybox.mat(Color(0.12, 0.08, 0.06)))
	Greybox.pyramid(self, 3.2, 3.2, 2.6, tp + Vector3(0, yg + 9.0, 0), roof)
	Greybox.sphere(self, 0.35, tp + Vector3(0, yg + 7.4, 0), Greybox.mat(Color(0.85, 0.7, 0.25), 0.4))
	# cypress trees and a stone well on the plaza
	var leaf := Greybox.mat(Color(0.18, 0.38, 0.22))
	for p in [Vector2(-6.0, 4.0), Vector2(6.0, 9.0), Vector2(-6.0, 10.0)]:
		Greybox.cyl(self, 0.2, 1.0, Vector3(_u0 + p.x, yg + 0.5, _D + p.y), Greybox.mat(Color(0.35, 0.25, 0.18)), _col)
		Greybox.cyl(self, 0.9, 4.5, Vector3(_u0 + p.x, yg + 3.0, _D + p.y), leaf, null, Vector3.ZERO, 12, 0.05)
	Greybox.cyl(self, 1.0, 0.9, Vector3(_u0 - 3.0, yg + 0.45, _D + 7.0), stone, _col)
	Greybox.cyl(self, 0.8, 0.1, Vector3(_u0 - 3.0, yg + 0.92, _D + 7.0), Greybox.mat(Color(0.25, 0.5, 0.7), 0.1))


func _entrance_harbour(yg: float) -> void:
	# blue-and-white striped awning over the roof edge, a lighthouse, bollards
	for i in 6:
		var m := Greybox.mat(Color(0.2, 0.4, 0.75) if i % 2 == 0 else Color(0.95, 0.95, 0.97))
		Greybox.box(self, Vector3(0.8, 0.12, 3.0), Vector3(_u0 - 2.0 + i * 0.8, yg + HOOD_H - 0.1, _D + 1.7), m)
	var lp := Vector3(_u0 + 5.5, 0, _D - 2.0)
	Greybox.cyl(self, 1.2, 8.0, lp + Vector3(0, yg + 4.0, 0), Greybox.mat(Color(0.95, 0.95, 0.97)), _col, Vector3.ZERO, 16, 0.8)
	Greybox.cyl(self, 1.05, 1.2, lp + Vector3(0, yg + 4.2, 0), Greybox.mat(Color(0.85, 0.15, 0.12)), null, Vector3.ZERO, 16, 0.98)
	Greybox.cyl(self, 0.9, 1.1, lp + Vector3(0, yg + 8.6, 0), Greybox.mat(Color(1.0, 0.95, 0.6), 0.3, 3.0), null, Vector3.ZERO, 12)
	Greybox.cyl(self, 1.1, 0.3, lp + Vector3(0, yg + 9.3, 0), Greybox.mat(Color(0.2, 0.2, 0.25)), null, Vector3.ZERO, 12)
	var rope := Greybox.mat(Color(0.7, 0.55, 0.3))
	for p in [Vector2(-6.0, 3.0), Vector2(-6.0, 8.0), Vector2(-6.0, 13.0)]:
		Greybox.cyl(self, 0.18, 0.7, Vector3(_u0 + p.x, yg + 0.35, _D + p.y), Greybox.mat(Color(0.15, 0.15, 0.2)), _col)
	Greybox.box(self, Vector3(0.06, 0.06, 10.0), Vector3(_u0 - 6.0, yg + 0.6, _D + 8.0), rope)
	# an anchor: two crossed bars on the plaza
	var iron := Greybox.mat(Color(0.12, 0.12, 0.16))
	Greybox.box(self, Vector3(0.18, 0.1, 2.4), Vector3(_u0 + 4.0, yg + 0.06, _D + 8.0), iron)
	Greybox.box(self, Vector3(1.6, 0.1, 0.18), Vector3(_u0 + 4.0, yg + 0.06, _D + 7.2), iron)


func _entrance_tower(yg: float) -> void:
	# a glass prism over the opening, a tall glowing fin, black planters
	var glass := Greybox.mat(Color(0.45, 0.70, 0.90), 0.1, 0.4, 0.45)
	Greybox.box(self, Vector3(4.6, 0.12, 3.6), Vector3(_u0, yg + HOOD_H + 0.2, _D + 1.8), glass)
	var fin_m := Greybox.mat(Color(0.85, 0.95, 1.0), 0.4, 2.0)
	Greybox.box(self, Vector3(0.8, 14.0, 0.5), Vector3(_u0 + 5.0, yg + 7.0, _D - 1.0), Greybox.mat(Color(0.12, 0.14, 0.18)), _col)
	Greybox.box(self, Vector3(0.12, 13.0, 0.52), Vector3(_u0 + 5.0, yg + 7.0, _D - 0.99), fin_m)
	Greybox.box(self, Vector3(0.8, 14.0, 0.5), Vector3(_u0 - 5.0, yg + 7.0, _D - 1.0), Greybox.mat(Color(0.12, 0.14, 0.18)), _col)
	Greybox.box(self, Vector3(0.12, 13.0, 0.52), Vector3(_u0 - 5.0, yg + 7.0, _D - 0.99), fin_m)
	var black := Greybox.mat(Color(0.1, 0.1, 0.12))
	for p in [Vector2(-5.5, 5.0), Vector2(5.5, 5.0), Vector2(-5.5, 10.0), Vector2(5.5, 10.0)]:
		Greybox.box(self, Vector3(2.0, 0.6, 2.0), Vector3(_u0 + p.x, yg + 0.3, _D + p.y), black, _col)
		Greybox.box(self, Vector3(1.6, 0.1, 1.6), Vector3(_u0 + p.x, yg + 0.65, _D + p.y), Greybox.mat(Color(0.3, 0.55, 0.35)))
	for k in range(-3, 4):
		Greybox.box(self, Vector3(0.1, 0.02, 12.0), Vector3(_u0 + k * 2.0, yg + 0.015, _D + 6.0), Greybox.mat(Color(0.6, 0.85, 1.0), 0.4, 1.0))


func _entrance_park(yg: float) -> void:
	# a timber pergola over the roof edge, planters with trees, flower beds, benches
	var wood := Greybox.mat(Color(0.45, 0.32, 0.22))
	for s in [-1, 1]:
		for v in [1.2, 4.2]:
			Greybox.box(self, Vector3(0.3, 3.6, 0.3), Vector3(_u0 + s * 2.8, yg + 1.8, _D + v), wood, _col)
	for i in 4:
		Greybox.box(self, Vector3(6.4, 0.18, 0.25), Vector3(_u0, yg + 3.7, _D + 1.2 + i), wood)
	for s in [-1, 1]:
		Greybox.box(self, Vector3(0.25, 0.18, 4.6), Vector3(_u0 + s * 2.8, yg + 3.7, _D + 2.7), wood)
	var leaf := Greybox.mat(Color(0.25, 0.55, 0.28))
	var trunk := Greybox.mat(Color(0.40, 0.28, 0.20))
	for p in [Vector2(-5.5, 3.0), Vector2(5.5, 3.0), Vector2(-5.5, 9.0), Vector2(5.5, 9.0)]:
		Greybox.box(self, Vector3(2.4, 0.5, 2.4), Vector3(_u0 + p.x, yg + 0.25, _D + p.y), Greybox.mat(Color(0.5, 0.46, 0.4)), _col)
		Greybox.cyl(self, 0.2, 3.0, Vector3(_u0 + p.x, yg + 2.0, _D + p.y), trunk, _col)
		Greybox.sphere(self, 2.0, Vector3(_u0 + p.x, yg + 4.4, _D + p.y), leaf)
	var flowers := [Color(0.9, 0.3, 0.4), Color(0.95, 0.8, 0.3), Color(0.7, 0.4, 0.9)]
	for i in 3:
		Greybox.box(self, Vector3(1.4, 0.2, 3.0), Vector3(_u0 - 2.6 + i * 2.6, yg + 0.1, _D + 6.5), Greybox.mat(flowers[i]))
	Greybox.box(self, Vector3(2.0, 0.45, 0.6), Vector3(_u0 - 3.0, yg + 0.225, _D + 10.5), wood, _col)
	Greybox.box(self, Vector3(2.0, 0.45, 0.6), Vector3(_u0 + 3.0, yg + 0.225, _D + 10.5), wood, _col)


# --------------------------------------------------------------------------- holes, countdown

func _holes() -> void:
	# the open trench (ground mesh only): between the covered stair and the plaza
	hole_ground.append(_world_rect(_u0 - STAIR_W * 0.5 - 0.1, _u0 + STAIR_W * 0.5 + 0.1, minf(_open_from, _D - HOOD_LEN), _D + 0.05))
	# the whole flight (water plane too, because it crosses sea level)
	hole_water.append(_world_rect(_u0 - STAIR_W * 0.5 - 0.5, _u0 + STAIR_W * 0.5 + 0.5, _v_foot - 0.1, _D + 0.1))
	# the walkable apron round the entrance, plus the strip over the stair
	apron_area = _world_rect(_u0 - 22.0, _u0 + 22.0, _D - 14.0, _D + 26.0)


func _world_rect(u0: float, u1: float, v0: float, v1: float) -> Rect2:
	var corners := [
		_origin + _x_axis * u0 + _z_axis * v0, _origin + _x_axis * u1 + _z_axis * v0,
		_origin + _x_axis * u0 + _z_axis * v1, _origin + _x_axis * u1 + _z_axis * v1,
	]
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for c in corners:
		lo = Vector2(minf(lo.x, c.x), minf(lo.y, c.z))
		hi = Vector2(maxf(hi.x, c.x), maxf(hi.y, c.z))
	return Rect2(lo, hi - lo)


## A small display on the far wall: when the train leaves for Central Station.
func _countdown_sign() -> void:
	var color: Color = line["color"]
	var pos := Vector3(0.0, 2.4, FAR_WALL - 0.04)
	Greybox.box(self, Vector3(4.6, 1.1, 0.08), pos, Greybox.mat(Color(0.05, 0.05, 0.07)))
	Greybox.box(self, Vector3(4.6, 0.22, 0.1), pos + Vector3(0, 0.45, 0), Greybox.mat(color, 0.6, 0.8))
	var head := Greybox.label(self, "NEXT TRAIN - CENTRAL STATION", pos + Vector3(0, 0.45, 0.06), PI, 0.17, Color(0.05, 0.05, 0.05))
	head.rotation.y = PI
	_countdown = Greybox.label(self, "", pos + Vector3(0, -0.12, 0.06), PI, 0.55, Color(1.0, 0.75, 0.2))


func _process(delta: float) -> void:
	_clock += delta
	if _clock < 0.5 or _countdown == null or service == null:
		return
	_clock = 0.0
	var t := service.seconds_to_dest_departure()
	var status := "BOARDING" if t < 1.0 else TransitSystem.fmt_countdown(t)
	_countdown.text = status
