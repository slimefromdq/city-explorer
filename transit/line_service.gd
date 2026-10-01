class_name LineService
extends Node3D
## One shuttle line: its Path3D, the PathFollow3D the train rides on, the train, the tunnel, and the
## timetable state machine. The train shuttles between the hub berth and the destination; it waits at
## each end with its doors open (on the platform side), then closes them and runs. A player aboard
## holds it at the stop until a destination is chosen.
##
## States:  DWELL (doors open, timer) -> CLOSING -> RUN -> OPENING -> DWELL ...

signal departed(service: LineService, from_index: int, to_index: int, with_player: bool)
signal arrived(service: LineService, stop_index: int, with_player: bool)
signal state_changed(service: LineService)

enum State { DWELL, CLOSING, RUN, OPENING }

const DWELL_TIME := 30.0
const CLOSE_TIME := 2.2
const OPEN_TIME := 1.2
const ACCEL := 3.5
const STOP_EASE := 0.0

var line: Dictionary
var routes: RouteData
var path3d: Path3D
var follow: PathFollow3D
var train: Train
var state := State.DWELL
var timer := DWELL_TIME
var stop_index := 0           # where the train is (or was last)
var target_index := 1         # where it is heading
var stop_s: Array[float] = []
var platform_dirs: Array[Vector3] = []   # per stop: world direction from the track to its platform
var player_on_board := false
var chosen_index := -1        # a destination picked by the rider (-1 = none)

var _run_time := 0.0
var _run_total := 0.0
var _run_dist := 0.0
var _run_from := 0.0
var _run_sign := 1.0
var _run_vmax := 26.0
var _facing := 1               # +1: the train's +x end leads while running away from the hub
var _carrying := false


func setup(p_line: Dictionary, p_routes: RouteData, p_platform_dirs: Array[Vector3], dwell_offset := 0.0) -> void:
	line = p_line
	routes = p_routes
	name = "Line_%s" % line["id"]
	platform_dirs = p_platform_dirs
	for st in line["stops"]:
		stop_s.append(st["s"])
	path3d = Path3D.new()
	path3d.name = "Path"
	var curve := Curve3D.new()
	curve.bake_interval = 1.0
	for p in line["path"]:
		curve.add_point(p)
	path3d.curve = curve
	add_child(path3d)
	follow = PathFollow3D.new()
	follow.name = "Follow"
	follow.rotation_mode = PathFollow3D.ROTATION_ORIENTED
	follow.loop = false
	path3d.add_child(follow)
	train = Train.new()
	train.build(line["id"], line["name"], line["color"])
	train.rotation.y = PI * 0.5
	follow.add_child(train)
	add_child(train.body)
	train.player_entered.connect(_on_player_entered)
	train.player_left.connect(_on_player_left)
	_run_vmax = float(line["cruise_speed"])
	follow.progress = stop_s[0]
	timer = DWELL_TIME + dwell_offset
	_open_doors_now(0)
	_face_for(1)


func _physics_process(delta: float) -> void:
	train.body.global_transform = train.global_transform
	match state:
		State.DWELL:
			if train.player_inside:
				pass   # held until the rider chooses (see request_departure)
			else:
				timer -= delta
				if timer <= 0.0:
					_begin_closing(1 - stop_index)
			if chosen_index >= 0 and chosen_index != stop_index:
				_begin_closing(chosen_index)
		State.CLOSING:
			timer -= delta
			if timer <= 0.0 and train.doors_closed():
				_begin_run()
		State.RUN:
			_run_time += delta
			var d := _run_distance_at(_run_time)
			follow.progress = _run_from + _run_sign * d
			if _run_time >= _run_total:
				_finish_run()
		State.OPENING:
			timer -= delta
			if timer <= 0.0:
				state = State.DWELL
				timer = DWELL_TIME
				state_changed.emit(self)


## Ask the train to leave for stop `index` (the rider's choice). Only acts while it is dwelling.
func request_departure(index: int) -> void:
	if state == State.DWELL and index != stop_index:
		chosen_index = index


func _begin_closing(to_index: int) -> void:
	target_index = to_index
	chosen_index = -1
	state = State.CLOSING
	timer = CLOSE_TIME
	train.set_doors(0, false)
	state_changed.emit(self)


func _begin_run() -> void:
	_run_from = stop_s[stop_index]
	var to_s: float = stop_s[target_index]
	_run_dist = absf(to_s - _run_from)
	_run_sign = 1.0 if to_s > _run_from else -1.0
	_run_time = 0.0
	var v := _run_vmax
	var d_acc := v * v / (2.0 * ACCEL)
	if _run_dist >= 2.0 * d_acc:
		_run_total = v / ACCEL + _run_dist / v
	else:
		_run_total = 2.0 * sqrt(_run_dist / ACCEL)
	# the +x end leads: turn the car round when it runs toward the hub
	_face_for(int(_run_sign))
	_carrying = train.player_inside
	state = State.RUN
	departed.emit(self, stop_index, target_index, _carrying)
	state_changed.emit(self)


func _finish_run() -> void:
	follow.progress = stop_s[target_index]
	stop_index = target_index
	state = State.OPENING
	timer = OPEN_TIME
	_open_doors_now(stop_index, false)
	arrived.emit(self, stop_index, _carrying)
	_carrying = false
	state_changed.emit(self)


## Distance covered `t` seconds into a run (trapezoid speed profile: accelerate, cruise, brake).
func _run_distance_at(t: float) -> float:
	var v := _run_vmax
	var d_acc := v * v / (2.0 * ACCEL)
	if _run_dist >= 2.0 * d_acc:
		var t_acc := v / ACCEL
		var t_cruise := (_run_dist - 2.0 * d_acc) / v
		if t < t_acc:
			return 0.5 * ACCEL * t * t
		if t < t_acc + t_cruise:
			return d_acc + v * (t - t_acc)
		var rem := maxf(_run_total - t, 0.0)
		return _run_dist - 0.5 * ACCEL * rem * rem
	var half := _run_total * 0.5
	if t < half:
		return 0.5 * ACCEL * t * t
	var rem2 := maxf(_run_total - t, 0.0)
	return _run_dist - 0.5 * ACCEL * rem2 * rem2


func speed_now() -> float:
	if state != State.RUN:
		return 0.0
	var eps := 0.05
	return absf(_run_distance_at(_run_time + eps) - _run_distance_at(maxf(_run_time - eps, 0.0))) / (2.0 * eps)


func progress_fraction() -> float:
	return clampf(_run_time / maxf(_run_total, 0.001), 0.0, 1.0) if state == State.RUN else 0.0


func run_time_left() -> float:
	return maxf(_run_total - _run_time, 0.0) if state == State.RUN else 0.0


func _face_for(direction: int) -> void:
	_facing = direction
	train.rotation.y = PI * 0.5 if direction > 0 else -PI * 0.5


func _open_doors_now(index: int, snap := true) -> void:
	var platform_dir: Vector3 = platform_dirs[index]
	# the train's +z side is the right-hand side of the track direction when its +x end leads outward
	var tangent: Vector3 = RouteData.sample(line["path"], stop_s[index])["dir"]
	var right := tangent.cross(Vector3.UP).normalized()
	var side_dir := right * float(_facing)
	var side := 1 if side_dir.dot(platform_dir) >= 0.0 else -1
	if snap:
		train.snap_doors(side, true)
	else:
		train.set_doors(side, true)


# ------------------------------------------------------------------ timetable (for the boards)

## Seconds until the train next leaves the hub (0 while it is boarding there).
func seconds_to_hub_departure() -> float:
	var run_t := _full_run_time()
	match state:
		State.DWELL:
			if stop_index == 0:
				return 0.0 if timer <= 0.0 else timer
			return timer + CLOSE_TIME + run_t + OPEN_TIME + DWELL_TIME
		State.CLOSING:
			if stop_index == 0:
				return maxf(timer, 0.0)
			return maxf(timer, 0.0) + run_t + OPEN_TIME + DWELL_TIME
		State.RUN:
			if target_index == 1:
				return run_time_left() + OPEN_TIME + DWELL_TIME + CLOSE_TIME + run_t + OPEN_TIME + DWELL_TIME
			return run_time_left() + OPEN_TIME + DWELL_TIME
		_:
			if stop_index == 0:
				return maxf(timer, 0.0) + DWELL_TIME
			return maxf(timer, 0.0) + DWELL_TIME + CLOSE_TIME + run_t + OPEN_TIME + DWELL_TIME


## Seconds until the train next leaves the destination stop (0 while it stands there boarding).
func seconds_to_dest_departure() -> float:
	var run_t := _full_run_time()
	match state:
		State.DWELL:
			if stop_index == 1:
				return 0.0 if timer <= 0.0 else timer
			return timer + CLOSE_TIME + run_t + OPEN_TIME + DWELL_TIME
		State.CLOSING:
			if stop_index == 1:
				return maxf(timer, 0.0)
			return maxf(timer, 0.0) + run_t + OPEN_TIME + DWELL_TIME
		State.RUN:
			if target_index == 1:
				return run_time_left() + OPEN_TIME + DWELL_TIME
			return run_time_left() + OPEN_TIME + DWELL_TIME + CLOSE_TIME + run_t + OPEN_TIME + DWELL_TIME
		_:
			if stop_index == 1:
				return maxf(timer, 0.0) + DWELL_TIME
			return maxf(timer, 0.0) + DWELL_TIME + CLOSE_TIME + run_t + OPEN_TIME + DWELL_TIME


## Seconds until the train next arrives at the hub (0 while it stands there).
func seconds_to_hub_arrival() -> float:
	var run_t := _full_run_time()
	match state:
		State.DWELL, State.CLOSING:
			if stop_index == 0:
				return 0.0
			return maxf(timer, 0.0) + (CLOSE_TIME if state == State.DWELL else 0.0) + run_t
		State.RUN:
			if target_index == 0:
				return run_time_left()
			return run_time_left() + OPEN_TIME + DWELL_TIME + CLOSE_TIME + run_t
		_:
			if stop_index == 0:
				return 0.0
			return maxf(timer, 0.0) + DWELL_TIME + CLOSE_TIME + run_t


func at_hub_boarding() -> bool:
	return stop_index == 0 and (state == State.DWELL or state == State.OPENING)


func _full_run_time() -> float:
	var d := absf(stop_s[1] - stop_s[0])
	var v := _run_vmax
	var d_acc := v * v / (2.0 * ACCEL)
	return v / ACCEL + d / v if d >= 2.0 * d_acc else 2.0 * sqrt(d / ACCEL)


func ride_time() -> float:
	return _full_run_time()


func _on_player_entered() -> void:
	player_on_board = true
	state_changed.emit(self)


func _on_player_left() -> void:
	player_on_board = false
	if state == State.DWELL:
		timer = maxf(timer, 8.0)
	state_changed.emit(self)


## For tests and screenshots: jump the train to arc length s (running state, no timetable change).
func debug_place(s: float) -> void:
	follow.progress = s
