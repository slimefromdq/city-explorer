class_name TrainRunner
extends Node3D
## A train that periodically runs along a polyline path. Cars follow the head
## by arc length, so it works for straight tunnels and curved viaducts alike.
## With `hazard` on, each car shoves and lightly damages fighters it hits.

var path := PackedVector3Array()
var cars := 5
var car_len := 13.0
var gap := 1.2
var speed := 16.0
var interval := 26.0
var hazard := false
var loop := false            # closed path: runs forever, wraps around
var phase := 0.0             # 0..1 start offset around a loop
var body_color := Color(0.86, 0.88, 0.93)
var stripe_color := Color(0.9, 0.2, 0.25)

var _len := 0.0
var _lens := PackedFloat32Array()
var _s := 0.0
var _wait := 6.0
var _running := false
var _cars: Array[Node3D] = []
var _areas: Array[Area3D] = []
var _hit_cd := {}


func _ready() -> void:
	add_to_group(&"trains")
	if loop:
		path = path.duplicate()
		path.append(path[0])
	_lens.append(0.0)
	for i in path.size() - 1:
		_len += path[i].distance_to(path[i + 1])
		_lens.append(_len)
	for i in cars:
		var c := _make_car(i == 0)
		add_child(c)
		_cars.append(c)
	visible = loop
	if loop:
		_running = true
		_s = phase * _len + float(cars) * (car_len + gap)
	set_physics_process(true)


func _make_car(head: bool) -> Node3D:
	var n := Node3D.new()
	var body := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.0, 3.4, car_len)
	body.mesh = bm
	body.material_override = Mats.toon(body_color)
	body.position = Vector3(0, 2.1, 0)
	n.add_child(body)
	var stripe := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(3.05, 0.5, car_len - 0.2)
	stripe.mesh = sm
	stripe.material_override = Mats.toon(stripe_color)
	stripe.position = Vector3(0, 1.2, 0)
	n.add_child(stripe)
	var win := MeshInstance3D.new()
	var wm := BoxMesh.new()
	wm.size = Vector3(3.08, 0.95, car_len - 1.4)
	win.mesh = wm
	win.material_override = Mats.glow(Color(1.0, 0.9, 0.65), 2.4)
	win.position = Vector3(0, 2.6, 0)
	win.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(win)
	if head:
		for sx in [-0.9, 0.9]:
			var lamp := MeshInstance3D.new()
			var sp := SphereMesh.new()
			sp.radius = 0.25
			sp.height = 0.5
			lamp.mesh = sp
			lamp.material_override = Mats.glow(Color(1.0, 0.97, 0.85), 8.0)
			lamp.position = Vector3(sx, 1.6, -car_len * 0.5)
			n.add_child(lamp)
	if hazard:
		var a := Area3D.new()
		a.collision_layer = 0
		a.collision_mask = Fighter.LAYER_FIGHTER
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(3.2, 3.6, car_len)
		cs.shape = bs
		cs.position = Vector3(0, 1.9, 0)
		a.add_child(cs)
		n.add_child(a)
		_areas.append(a)
	return n


func _sample(s: float) -> Array:
	s = fposmod(s, _len) if loop else clampf(s, 0.0, _len)
	var i := 0
	while i < _lens.size() - 2 and _lens[i + 1] < s:
		i += 1
	var a := path[i]
	var b := path[i + 1]
	var seg := maxf(_lens[i + 1] - _lens[i], 0.001)
	var t := (s - _lens[i]) / seg
	return [a.lerp(b, t), (b - a).normalized()]


func _physics_process(dt: float) -> void:
	if path.size() < 2:
		return
	if not _running:
		_wait -= dt
		if _wait <= 0.0:
			_running = true
			_s = 0.0
			visible = true
		return
	_s += speed * dt
	var span := float(cars) * (car_len + gap)
	for i in cars:
		var head_s := _s - i * (car_len + gap)
		var mid := _sample(head_s - car_len * 0.5)
		var pos: Vector3 = mid[0]
		var dir: Vector3 = mid[1]
		_cars[i].global_position = pos
		_cars[i].global_transform.basis = Basis.looking_at(dir, Vector3.UP)
		_cars[i].visible = loop or (head_s > 0.0 and head_s - car_len < _len)
	if hazard:
		_shove(dt)
	if not loop and _s - span > _len:
		_running = false
		visible = false
		_wait = interval


func _shove(dt: float) -> void:
	for k in _hit_cd.keys():
		_hit_cd[k] -= dt
	for a in _areas:
		if not a.get_parent().visible or a.get_parent().global_position.y > 6.0:
			continue
		for b in a.get_overlapping_bodies():
			var f := b as Fighter
			if f == null or not f.alive or _hit_cd.get(f, 0.0) > 0.0:
				continue
			_hit_cd[f] = 1.0
			var dir: Vector3 = -a.get_parent().global_transform.basis.z
			var h := HitData.new()
			h.attacker = null
			h.damage = 10.0
			h.guard_damage = 0.0
			h.blockable = false
			h.dodgeable = true
			h.flinch = 0.3
			h.knockback = dir * 18.0 + Vector3.UP * 4.0
			h.from_dir = -dir
			h.position = f.global_position + Vector3.UP
			h.tag = &"train"
			f.receive_hit(h)
			Events.popup.emit("TRAIN!", f.global_position + Vector3.UP * 2.4, Color(1.0, 0.6, 0.3))
