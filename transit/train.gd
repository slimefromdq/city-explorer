class_name Train
extends Node3D
## One primitive shuttle train: a single 24 m car with a window band, a pair of sliding doors twice
## per side, benches, poles, lights and a line-colour livery. Local frame: x along the car (+x = the
## end that is "front" when the car is not turned round), y up from the walking surface, z across.
## Doors open on one side at a time (the platform side). Collision is an AnimatableBody3D, so it can
## be moved by the transit system and still carry a character standing on it.

signal player_entered
signal player_left

const LENGTH := 24.0
const WIDTH := 2.9
const HEIGHT := 3.0           # floor to roof underside
const WALL_T := 0.12
const DOOR_X := [-6.0, 6.0]
const DOOR_W := 1.6
const DOOR_H := 2.15
const WINDOW_BOTTOM := 0.95
const SLIDE := 0.85

var line_id := ""
var line_name := ""
var color := Color.WHITE
var body: AnimatableBody3D
var interior: Area3D
var _doors: Array[Dictionary] = []   # {node, base: Vector3, slide: float, side: int, shape: CollisionShape3D}
var _amount := {1: 0.0, -1: 0.0}     # how far open each side's doors are (0..1)
var _target := {1: 0.0, -1: 0.0}
var door_speed := 1.2                # 1/seconds: doors take under a second to move
var player_inside := false


func build(p_line_id: String, p_name: String, p_color: Color) -> void:
	line_id = p_line_id
	line_name = p_name
	color = p_color
	name = "Train_%s" % line_id
	# The collision body is NOT a child of the train: an AnimatableBody3D only follows changes of its own
	# transform, so its owner (LineService) copies the train's global transform onto it every physics step.
	body = AnimatableBody3D.new()
	body.name = "Body_%s" % line_id
	body.sync_to_physics = true
	var skin := Greybox.mat(color, 0.55)
	var skin_light := Greybox.mat(color.lightened(0.35), 0.55)
	var dark := Greybox.mat(Color(0.10, 0.10, 0.12))
	var roof_m := Greybox.mat(Color(0.82, 0.83, 0.86))
	var floor_m := Greybox.mat(Color(0.62, 0.62, 0.66))
	var glass := Greybox.mat(Color(0.45, 0.65, 0.78), 0.1, 0.0, 0.40)
	var hl := LENGTH * 0.5
	var hw := WIDTH * 0.5
	# underframe, floor, roof
	Greybox.box(self, Vector3(LENGTH, 0.55, WIDTH - 0.3), Vector3(0, -0.45, 0), dark, body)
	Greybox.box(self, Vector3(LENGTH, 0.12, WIDTH), Vector3(0, -0.06, 0), floor_m, body)
	Greybox.box(self, Vector3(LENGTH + 0.1, 0.18, WIDTH + 0.1), Vector3(0, HEIGHT + 0.09, 0), roof_m, body)
	for i in 4:  # roof equipment
		Greybox.box(self, Vector3(1.8, 0.28, 1.1), Vector3(-8.5 + i * 5.7, HEIGHT + 0.32, 0), Greybox.mat(Color(0.65, 0.66, 0.70)))
	# bogies
	for bx in [-8.0, 8.0]:
		for sz in [-1, 1]:
			Greybox.box(self, Vector3(2.2, 0.35, 0.18), Vector3(bx, -0.72, sz * (hw - 0.35)), Greybox.mat(Color(0.2, 0.2, 0.22)))
	# side walls: for each side, lower panel, window band, upper panel, with door gaps
	var gaps: Array = []
	for dx in DOOR_X:
		gaps.append(Vector2(dx - DOOR_W * 0.5, dx + DOOR_W * 0.5))
	var segs: Array = []   # solid x-ranges between the door gaps
	var x := -hl
	for g in gaps:
		segs.append(Vector2(x, g.x))
		x = g.y
	segs.append(Vector2(x, hl))
	for side in [-1, 1]:
		var wz: float = side * (hw - WALL_T * 0.5)
		# upper panel and header over everything (including above the doors)
		Greybox.box(self, Vector3(LENGTH, HEIGHT - 2.15, WALL_T), Vector3(0, (HEIGHT + 2.15) * 0.5, wz), skin, body)
		for seg in segs:
			var w: float = seg.y - seg.x
			var cx: float = (seg.x + seg.y) * 0.5
			Greybox.box(self, Vector3(w, WINDOW_BOTTOM, WALL_T), Vector3(cx, WINDOW_BOTTOM * 0.5, wz), skin, body)
			# window band: glass with pillars every 2.2 m
			Greybox.box(self, Vector3(w, 2.15 - WINDOW_BOTTOM, 0.04), Vector3(cx, (2.15 + WINDOW_BOTTOM) * 0.5, wz), glass)
			var n := int(floor(w / 2.2))
			for k in range(n + 1):
				var px: float = seg.x + (w * float(k) / maxf(n, 1))
				Greybox.box(self, Vector3(0.25, 2.15 - WINDOW_BOTTOM, WALL_T), Vector3(px, (2.15 + WINDOW_BOTTOM) * 0.5, wz), skin)
			# the window band is collision-free glass, but keep a solid body so nothing walks out through it
			Greybox.col_box(body, Vector3(w, 2.15 - WINDOW_BOTTOM, WALL_T), Vector3(cx, (2.15 + WINDOW_BOTTOM) * 0.5, wz))
		Greybox.col_box(body, Vector3(LENGTH, HEIGHT - 2.15, WALL_T), Vector3(0, (HEIGHT + 2.15) * 0.5, wz))
		# doors: two leaves per gap, sliding on the outside, with a small window
		for dx in DOOR_X:
			for leaf in [-1, 1]:
				var holder := Node3D.new()
				holder.name = "Door_%d_%d_%d" % [side, int(dx), leaf]
				holder.position = Vector3(dx + leaf * DOOR_W * 0.25, 0, side * (hw + 0.02))
				add_child(holder)
				Greybox.box(holder, Vector3(DOOR_W * 0.5, DOOR_H, 0.06), Vector3(0, DOOR_H * 0.5, 0), skin_light)
				Greybox.box(holder, Vector3(DOOR_W * 0.3, 0.7, 0.08), Vector3(0, 1.45, 0), glass)
				var cs := CollisionShape3D.new()
				var shape := BoxShape3D.new()
				shape.size = Vector3(DOOR_W * 0.5, DOOR_H, 0.08)
				cs.shape = shape
				cs.position = holder.position + Vector3(0, DOOR_H * 0.5, 0)
				body.add_child(cs)
				_doors.append({"node": holder, "base": holder.position, "slide": float(leaf) * SLIDE, "side": side, "shape": cs, "cs_base": cs.position})
			# door-side lamp above the gap
			Greybox.box(self, Vector3(0.5, 0.12, 0.05), Vector3(dx, 2.35, side * (hw + 0.01)), Greybox.mat(Color(0.3, 1.0, 0.45), 0.4, 1.5))
		# line name on the side, large
		for dx in [0.0]:
			Greybox.label(self, line_name.to_upper(), Vector3(dx, 2.6, side * (hw + 0.02)), 0.0 if side > 0 else PI, 0.34, Color(1, 1, 1))
	# end walls with a cab window, headlight and tail lamp
	for e in [-1, 1]:
		var ex: float = e * (hl - WALL_T * 0.5)
		Greybox.box(self, Vector3(WALL_T, HEIGHT, WIDTH), Vector3(ex, HEIGHT * 0.5, 0), skin, body)
		Greybox.box(self, Vector3(WALL_T + 0.04, 1.0, 1.9), Vector3(ex + e * 0.02, 1.9, 0), glass)
		if e > 0:
			Greybox.box(self, Vector3(0.1, 0.22, 0.4), Vector3(hl + 0.02, 0.8, -0.8), Greybox.mat(Color(1, 1, 0.9), 0.3, 4.0))
			Greybox.box(self, Vector3(0.1, 0.22, 0.4), Vector3(hl + 0.02, 0.8, 0.8), Greybox.mat(Color(1, 1, 0.9), 0.3, 4.0))
		else:
			Greybox.box(self, Vector3(0.1, 0.2, 0.3), Vector3(-hl - 0.02, 0.8, -0.8), Greybox.mat(Color(1, 0.1, 0.1), 0.3, 3.0))
			Greybox.box(self, Vector3(0.1, 0.2, 0.3), Vector3(-hl - 0.02, 0.8, 0.8), Greybox.mat(Color(1, 0.1, 0.1), 0.3, 3.0))
	# benches between the doors (against the walls), poles at the doors
	var bench := Greybox.mat(Color(0.28, 0.30, 0.38))
	var bench_ranges := [Vector2(-11.2, -7.4), Vector2(-4.6, 4.6), Vector2(7.4, 11.2)]
	for side in [-1, 1]:
		for r in bench_ranges:
			var w: float = r.y - r.x
			var cx: float = (r.x + r.y) * 0.5
			Greybox.box(self, Vector3(w, 0.45, 0.5), Vector3(cx, 0.225, side * (hw - 0.45)), bench, body)
			Greybox.box(self, Vector3(w, 0.45, 0.08), Vector3(cx, 0.8, side * (hw - 0.22)), bench)
	var steel := Greybox.mat(Color(0.78, 0.78, 0.82), 0.3)
	for dx in DOOR_X:
		for sz in [-0.7, 0.7]:
			Greybox.cyl(self, 0.03, HEIGHT, Vector3(dx + sz * 0.0, HEIGHT * 0.5, sz), steel, null, Vector3.ZERO, 8)
	# lighting: ceiling strips and two soft lights
	var strip := Greybox.mat(Color(1.0, 0.96, 0.86), 0.5, 1.6)
	for z in [-0.6, 0.6]:
		Greybox.box(self, Vector3(LENGTH - 2.0, 0.04, 0.2), Vector3(0, HEIGHT - 0.02, z), strip)
	for lx in [-6.0, 6.0]:
		Greybox.omni(self, Vector3(lx, HEIGHT - 0.4, 0), 1.2, 9.0, Color(1.0, 0.95, 0.85))
	# headlight: a spot out of the +x end; a dim red wash at the other
	var spot := SpotLight3D.new()
	spot.name = "Headlight"
	spot.position = Vector3(hl + 0.2, 0.9, 0)
	spot.rotation.y = -PI * 0.5      # a spot shines along its local -Z; turn it to +X
	spot.spot_range = 55.0
	spot.spot_angle = 38.0
	spot.light_energy = 6.0
	spot.shadow_enabled = false
	add_child(spot)
	var tail := Greybox.omni(self, Vector3(-hl - 0.5, 0.9, 0), 0.8, 6.0, Color(1, 0.1, 0.1))
	tail.name = "TailLight"
	# the interior volume: is the player aboard?
	interior = Area3D.new()
	interior.name = "Interior"
	interior.monitoring = true
	interior.collision_layer = 0
	interior.collision_mask = 1
	var ics := CollisionShape3D.new()
	var ibox := BoxShape3D.new()
	ibox.size = Vector3(LENGTH - 1.0, HEIGHT - 0.2, WIDTH - 0.4)
	ics.shape = ibox
	ics.position = Vector3(0, HEIGHT * 0.5, 0)
	interior.add_child(ics)
	add_child(interior)
	interior.body_entered.connect(_on_body_entered)
	interior.body_exited.connect(_on_body_exited)
	set_process(true)


func _on_body_entered(b: Node3D) -> void:
	if b.is_in_group("player"):
		player_inside = true
		player_entered.emit()


func _on_body_exited(b: Node3D) -> void:
	if b.is_in_group("player"):
		player_inside = false
		player_left.emit()


## Open or close the doors on one side (+1 = this train's +z side, -1 = its -z side, 0 = both closed).
func set_doors(side: int, open: bool) -> void:
	for s in [-1, 1]:
		_target[s] = 1.0 if (open and s == side) else 0.0


func doors_closed() -> bool:
	return _amount[1] < 0.01 and _amount[-1] < 0.01


func doors_open_on(side: int) -> bool:
	return _amount[side] > 0.99


func snap_doors(side: int, open: bool) -> void:
	set_doors(side, open)
	for s in [-1, 1]:
		_amount[s] = _target[s]
	_apply_doors()


func _process(delta: float) -> void:
	var changed := false
	for s in [-1, 1]:
		var a: float = _amount[s]
		var t: float = _target[s]
		if a != t:
			a = move_toward(a, t, delta * door_speed)
			_amount[s] = a
			changed = true
	if changed:
		_apply_doors()


func _apply_doors() -> void:
	for d in _doors:
		var a: float = _amount[d["side"]]
		var node: Node3D = d["node"]
		node.position = (d["base"] as Vector3) + Vector3(d["slide"] * a, 0, 0)
		var cs: CollisionShape3D = d["shape"]
		cs.position = (d["cs_base"] as Vector3) + Vector3(d["slide"] * a, 0, 0)
		cs.set_deferred("disabled", a > 0.35)
