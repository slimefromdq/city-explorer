class_name TransitSystem
extends Node3D
## The shuttle network: owns RouteData, one LineService per line (path, train, timetable), the tunnels
## between the hub and each destination. Build it once, at the world origin (everything is in world
## coordinates), after the station. Boards, route maps and the rider's UI read it.

const L := preload("res://station/station_layout.gd")
const HUB_PORTAL := 35.0           # |x - hub| beyond which the tunnel proper starts (chamber wall + 0.2)

var routes: RouteData
var terrain                        # TerrainHeight (optional; used to find where tunnels run under water)
var services: Dictionary = {}      # line id -> LineService
var tunnels: Node3D
var destinations: Dictionary = {}   # stop id -> DestinationStation
var station: StationComplex        # set before adding to the tree (the boards live in its hall)
var _dep_kiosk: ConcourseKiosk
var _arr_kiosk: ConcourseKiosk
var _board_clock := 0.0


func _ready() -> void:
	name = "Transit"
	build()


func build() -> void:
	if routes == null:
		routes = RouteData.load_default()
	tunnels = Node3D.new()
	tunnels.name = "Tunnels"
	add_child(tunnels)
	var order := 0
	for line in routes.lines:
		var service := LineService.new()
		var dirs: Array[Vector3] = [_hub_platform_dir(line), _dest_platform_dir(line)]
		service.setup(line, routes, dirs, float(order) * 12.0)
		add_child(service)
		services[line["id"]] = service
		_build_tunnel(line)
		_build_destination(line, service)
		order += 1
	_build_aprons()
	_hook_boards()


func _build_destination(line: Dictionary, service: LineService) -> void:
	var stop := routes.stop(line["stops"][1]["stop"])
	if terrain == null:
		return
	var ds := DestinationStation.new()
	ds.setup(stop, line, routes, terrain)
	ds.service = service
	add_child(ds)
	ds.build()
	destinations[stop["id"]] = ds


## Walkable ground: round the hub (with holes at the stairwells) and round each destination entrance.
func _build_aprons() -> void:
	if terrain == null:
		return
	var holes: Array[Rect2] = []
	if station != null:
		holes.append_array(station.hole_rects())
	TerrainApron.build(self, "HubApron", terrain, Rect2(630, 750, 390, 200), holes)
	for id in destinations:
		var ds: DestinationStation = destinations[id]
		TerrainApron.build(self, "Apron_%s" % id, terrain, ds.apron_area, ds.hole_ground)


## World (x, z) rectangles to cut out of the ground mesh / the water plane, from all stairwells and trenches.
func hole_rects_ground() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id in destinations:
		out.append_array((destinations[id] as DestinationStation).hole_ground)
	return out


func hole_rects_water() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id in destinations:
		out.append_array((destinations[id] as DestinationStation).hole_water)
	return out


## The areas buildings and trees must stay out of (from data alone).
static func reserve_rects(rd: RouteData) -> Array[Rect2]:
	var out: Array[Rect2] = []
	for id in rd.stops:
		if id != "central":
			out.append(DestinationStation.reserve_rect(rd.stops[id]))
	return out


## Hub berths: the south track (z > hub) has its platform on its north side, the north track on its south side.
func _hub_platform_dir(line: Dictionary) -> Vector3:
	var z: float = line["stops"][0]["pos"].z
	return Vector3(0, 0, -1) if z > L.HUB.z else Vector3(0, 0, 1)


func _dest_platform_dir(line: Dictionary) -> Vector3:
	var stop := routes.stop(line["stops"][1]["stop"])
	match String(stop.get("platform_side", "north")):
		"north": return Vector3(0, 0, -1)
		"south": return Vector3(0, 0, 1)
		"east": return Vector3(1, 0, 0)
		_: return Vector3(-1, 0, 0)


func _build_tunnel(line: Dictionary) -> void:
	var path: PackedVector3Array = line["path"]
	var length: float = line["length"]
	# the tunnel proper starts where the path leaves the hub chamber
	var s0 := 0.0
	while s0 < length:
		var p: Vector3 = RouteData.sample(path, s0)["pos"]
		if absf(p.x - L.HUB.x) > HUB_PORTAL:
			break
		s0 += 1.0
	var s1: float = line["stops"][1]["s"] - DestinationStation.CHAMBER_BEFORE - 0.2
	var river: Array = _river_ranges(path, s0, s1)
	TunnelBuilder.build(tunnels, "Tunnel_%s" % line["id"], path, s0, s1, river)


## Arc-length ranges where the ground above the path is below sea level (river, harbour): the tunnel is under water.
func _river_ranges(path: PackedVector3Array, s0: float, s1: float) -> Array:
	var out: Array = []
	if terrain == null:
		return out
	var start := -1.0
	var s := s0
	while s <= s1:
		var p: Vector3 = RouteData.sample(path, s)["pos"]
		var wet: bool = terrain.height_at(Vector2(p.x, p.z)) < 0.3
		if wet and start < 0.0:
			start = s
		if not wet and start >= 0.0:
			out.append(Vector2(start, s))
			start = -1.0
		s += 4.0
	if start >= 0.0:
		out.append(Vector2(start, s1))
	return out


# ------------------------------------------------------------------ departure / arrival boards

const BOARD_ROWS := 6
const BOARD_PERIOD := 0.5

func _hook_boards() -> void:
	if station == null or station.hall == null:
		return
	_dep_kiosk = station.hall.get_node_or_null("Generated/WallNegZ/Kiosk3") as ConcourseKiosk
	_arr_kiosk = station.hall.get_node_or_null("Generated/WallPosZ/Kiosk3") as ConcourseKiosk
	for k in [_dep_kiosk, _arr_kiosk]:
		if k != null:
			k.board_rows = _blank_rows()
			k.rebuild()
	_update_boards()


func _process(delta: float) -> void:
	_board_clock += delta
	if _board_clock >= BOARD_PERIOD:
		_board_clock = 0.0
		_update_boards()


func _blank_rows() -> Array:
	var rows: Array = []
	for i in BOARD_ROWS:
		rows.append({"time": "", "dest": "", "platform": "", "status": "", "color": Color(0, 0, 0, 0)})
	return rows


func _update_boards() -> void:
	if _dep_kiosk != null:
		_dep_kiosk.refresh_rows(departure_rows())
	if _arr_kiosk != null:
		_arr_kiosk.refresh_rows(arrival_rows())


## "m:ss" for a countdown, NOW at zero.
static func fmt_countdown(t: float) -> String:
	if t < 1.0:
		return "NOW"
	var secs := int(ceil(t))
	return "%d:%02d" % [secs / 60, secs % 60]


## The departures board: the next train out of the hub on each line (and the one after, to fill the rows).
func departure_rows() -> Array:
	var items: Array = []
	for line in routes.lines:
		var svc: LineService = services[line["id"]]
		var t := svc.seconds_to_hub_departure()
		items.append({"t": t, "svc": svc, "line": line, "second": false})
	items.sort_custom(func(a, b): return a["t"] < b["t"])
	var extra: Array = []
	for i in mini(2, items.size()):
		var svc: LineService = items[i]["svc"]
		var cycle: float = 2.0 * (svc.ride_time() + LineService.DWELL_TIME + LineService.CLOSE_TIME + LineService.OPEN_TIME)
		extra.append({"t": items[i]["t"] + cycle, "svc": svc, "line": items[i]["line"], "second": true})
	items.append_array(extra)
	items.sort_custom(func(a, b): return a["t"] < b["t"])
	var rows: Array = []
	for it in items.slice(0, BOARD_ROWS):
		var svc: LineService = it["svc"]
		var line: Dictionary = it["line"]
		var dest: String = routes.stop(line["stops"][1]["stop"])["name"]
		var status := "ON TIME"
		var status_color := Color(1.0, 0.58, 0.08)
		if not it["second"] and svc.at_hub_boarding():
			status = "BOARDING"
			status_color = Color(0.35, 1.0, 0.45)
		elif not it["second"] and svc.stop_index == 0 and svc.state == LineService.State.CLOSING:
			status = "DOORS CLOSING"
			status_color = Color(1.0, 0.35, 0.25)
		rows.append({"time": fmt_countdown(it["t"]), "dest": dest.to_upper(), "platform": str(PlatformLevel_order(line["id"])),
			"status": status, "color": line["color"], "status_color": status_color})
	return rows


## The arrivals board: the next train into the hub on each line, named by where it comes from.
func arrival_rows() -> Array:
	var items: Array = []
	for line in routes.lines:
		var svc: LineService = services[line["id"]]
		items.append({"t": svc.seconds_to_hub_arrival(), "svc": svc, "line": line, "second": false})
	items.sort_custom(func(a, b): return a["t"] < b["t"])
	var extra: Array = []
	for i in mini(2, items.size()):
		var svc: LineService = items[i]["svc"]
		var cycle: float = 2.0 * (svc.ride_time() + LineService.DWELL_TIME + LineService.CLOSE_TIME + LineService.OPEN_TIME)
		extra.append({"t": items[i]["t"] + cycle, "svc": svc, "line": items[i]["line"], "second": true})
	items.append_array(extra)
	items.sort_custom(func(a, b): return a["t"] < b["t"])
	var rows: Array = []
	for it in items.slice(0, BOARD_ROWS):
		var svc: LineService = it["svc"]
		var line: Dictionary = it["line"]
		var origin: String = routes.stop(line["stops"][1]["stop"])["name"]
		var status := "EXPECTED"
		var status_color := Color(0.18, 0.80, 0.36)
		if not it["second"] and it["t"] < 1.0:
			status = "AT PLATFORM"
			status_color = Color(1.0, 1.0, 1.0)
		elif not it["second"] and it["t"] < 8.0:
			status = "ARRIVING"
			status_color = Color(1.0, 0.85, 0.3)
		rows.append({"time": fmt_countdown(it["t"]), "dest": origin.to_upper(), "platform": str(PlatformLevel_order(line["id"])),
			"status": status, "color": line["color"], "status_color": status_color})
	return rows


static func PlatformLevel_order(line_id: String) -> int:
	return {"west": 1, "east": 2, "tower": 3, "park": 4}.get(line_id, 0)
