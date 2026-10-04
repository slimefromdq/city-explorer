class_name CardFx
extends Node3D
## Throwaway visual effects for cards: explosions, flashes, afterimages, beam
## lines and trail puffs. Each one is a node that fades itself out and frees
## itself, so effect blocks can fire them and forget.

var _life := 0.3
var _t := 0.0
var _mat: StandardMaterial3D
var _grow := 0.0
var _start_scale := 1.0
var _light: OmniLight3D
var _light_energy := 0.0
var _alpha := 1.0


static func _parent(anchor: Node) -> Node:
	if anchor == null or not anchor.is_inside_tree():
		return null
	var p: Node = anchor.get_tree().current_scene
	return p if p != null else anchor.get_parent()


static func _unshaded(color: Color, alpha: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(color, alpha)
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


static func _make(anchor: Node, pos: Vector3, mesh: Mesh, color: Color, alpha: float, life: float) -> CardFx:
	var parent := _parent(anchor)
	if parent == null:
		return null
	var fx := CardFx.new()
	fx._life = life
	fx._mat = _unshaded(color, alpha)
	fx._alpha = alpha
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = fx._mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fx.add_child(mi)
	parent.add_child(fx)
	fx.global_position = pos
	return fx


## A sphere the size of the blast radius that pops and fades, plus a light.
static func explosion(anchor: Node, pos: Vector3, radius: float, color: Color) -> void:
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	var fx := _make(anchor, pos, sm, color.lightened(0.3), 0.55, 0.35)
	if fx == null:
		return
	fx._start_scale = radius * 0.4
	fx._grow = radius * 0.6
	fx.scale = Vector3.ONE * fx._start_scale
	fx._add_light(color, radius * 2.5, 6.0)


## A quick bright pop (teleport arrival, sticky blink).
static func flash(anchor: Node, pos: Vector3, color: Color, size := 0.6) -> void:
	var sm := SphereMesh.new()
	sm.radius = size * 0.5
	sm.height = size
	var fx := _make(anchor, pos, sm, color.lightened(0.5), 0.8, 0.2)
	if fx != null:
		fx._start_scale = 1.0
		fx._grow = 0.8
		fx._add_light(color, 4.0, 3.0)


## A see-through capsule where the hero used to stand (blink).
static func afterimage(anchor: Node, feet: Vector3, color: Color) -> void:
	var cm := CapsuleMesh.new()
	cm.radius = 0.3
	cm.height = 1.8
	var fx := _make(anchor, feet + Vector3.UP * 0.9, cm, color, 0.45, 0.4)
	if fx != null:
		fx._start_scale = 1.0


## A small fading puff left behind a flying body: its trail.
static func puff(anchor: Node, pos: Vector3, color: Color, size: float) -> void:
	var sm := SphereMesh.new()
	sm.radius = size
	sm.height = size * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var fx := _make(anchor, pos, sm, color, 0.5, 0.25)
	if fx != null:
		fx._start_scale = 1.0
		fx._grow = -0.8


## A thin glowing line from a to b that fades (beams).
static func line(anchor: Node, a: Vector3, b: Vector3, color: Color, width := 0.05) -> void:
	var length := a.distance_to(b)
	if length < 0.01:
		return
	var bm := BoxMesh.new()
	bm.size = Vector3(width, width, length)
	var fx := _make(anchor, (a + b) * 0.5, bm, color.lightened(0.4), 0.9, 0.12)
	if fx == null:
		return
	fx._start_scale = 1.0
	var up := Vector3.UP if absf((b - a).normalized().dot(Vector3.UP)) < 0.99 else Vector3.RIGHT
	fx.look_at(b, up)


func _add_light(color: Color, range_m: float, energy: float) -> void:
	_light = OmniLight3D.new()
	_light.light_color = color
	_light.omni_range = range_m
	_light.light_energy = energy
	_light_energy = energy
	add_child(_light)


func _process(dt: float) -> void:
	_t += dt
	var k := clampf(_t / _life, 0.0, 1.0)
	if _grow != 0.0:
		scale = Vector3.ONE * maxf(0.01, _start_scale + _grow * k)
	if _mat != null:
		_mat.albedo_color.a = _alpha * (1.0 - k)
	if _light != null:
		_light.light_energy = _light_energy * (1.0 - k)
	if _t >= _life:
		queue_free()
